package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/pquerna/otp/totp"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	Hello(ctx context.Context, name string) (string, error)
	InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error)
	VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error)
	SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error)
	VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error)
	LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error)
	VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error)
	RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error)
	Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error)
	BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error)
	FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error)
	BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error)
	FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error)
}

type service struct {
	queries  generated.Querier
	redis    redis.Cmdable
	cfg      config.Config
	webauthn *webauthn.WebAuthn
}

func NewService(queries generated.Querier, redis redis.Cmdable, cfg config.Config) Service {
	w, _ := webauthn.New(&webauthn.Config{
		RPDisplayName: "LMS Monorepo",
		RPID:          "localhost",
		RPOrigins:     []string{"http://localhost:3000"}, // Placeholder for frontend
	})

	return &service{
		queries:  queries,
		redis:    redis,
		cfg:      cfg,
		webauthn: w,
	}
}

func (s *service) Hello(ctx context.Context, name string) (string, error) {
	_ = ctx
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		trimmed = "world"
	}
	return "hello " + trimmed, nil
}

func (s *service) InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error) {
	hash, err := argon2.HashPassword(req.GetPassword(), argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	user, err := s.queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        req.GetEmail(),
		Phone:        req.GetPhone(),
		PasswordHash: hash,
		Role:         req.GetRole(),
	})
	if err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create user")
	}

	emailOTP := generateOTP()
	phoneOTP := generateOTP()

	regID := uuid.New().String()
	regData, _ := json.Marshal(map[string]string{
		"user_id":   user.ID.String(),
		"email_otp": emailOTP,
		"phone_otp": phoneOTP,
	})

	err = s.redis.Set(ctx, fmt.Sprintf("signup_reg:%s", regID), regData, 10*time.Minute).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to store registration state")
	}

	fmt.Printf("DEBUG: Email OTP for %s: %s\n", req.GetEmail(), emailOTP)
	fmt.Printf("DEBUG: Phone OTP for %s: %s\n", req.GetPhone(), phoneOTP)

	return &authv1.SignupResponse{
		RegistrationId: regID,
	}, nil
}

func (s *service) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	key := fmt.Sprintf("signup_reg:%s", req.GetRegistrationId())
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.NotFound, "registration session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to retrieve registration state")
	}

	var data map[string]string
	if err := json.Unmarshal([]byte(val), &data); err != nil {
		return nil, status.Error(codes.Internal, "corrupt registration state")
	}

	if req.GetEmailCode() != data["email_otp"] || req.GetPhoneCode() != data["phone_otp"] {
		return nil, status.Error(codes.InvalidArgument, "invalid verification codes")
	}

	userUUID, _ := uuid.Parse(data["user_id"])
	err = s.queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              pgtype.UUID{Bytes: userUUID, Valid: true},
		IsActive:        pgtype.Bool{Bool: true, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to activate user")
	}

	s.redis.Del(ctx, key)

	return &authv1.VerifyOTPsResponse{Verified: true}, nil
}

func (s *service) SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "user not found in context")
	}
	userID, _ := uuid.Parse(userIDStr)

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "LMS-Core",
		AccountName: user.Email,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate totp secret")
	}

	err = s.queries.SetTOTPSecret(ctx, generated.SetTOTPSecretParams{
		ID:         pgtype.UUID{Bytes: userID, Valid: true},
		TotpSecret: pgtype.Text{String: key.Secret(), Valid: true},
		HasTotp:    pgtype.Bool{Bool: false, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save totp secret")
	}

	return &authv1.SetupTOTPResponse{
		Secret:          key.Secret(),
		ProvisioningUri: key.URL(),
	}, nil
}

func (s *service) VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "user not found in context")
	}
	userID, _ := uuid.Parse(userIDStr)

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	if !totp.Validate(req.GetCode(), user.TotpSecret.String) {
		return nil, status.Error(codes.InvalidArgument, "invalid totp code")
	}

	err = s.queries.SetTOTPSecret(ctx, generated.SetTOTPSecretParams{
		ID:         pgtype.UUID{Bytes: userID, Valid: true},
		TotpSecret: user.TotpSecret,
		HasTotp:    pgtype.Bool{Bool: true, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to finalize totp setup")
	}

	return s.mintTokens(ctx, userID, user.Role, req.GetDeviceId())
}

func (s *service) LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	user, err := s.queries.GetUserByEmailOrPhone(ctx, req.GetEmailOrPhone())
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid credentials")
	}

	match, err := argon2.VerifyPassword(req.GetPassword(), user.PasswordHash)
	if err != nil || !match {
		return nil, status.Error(codes.Unauthenticated, "invalid credentials")
	}

	mfaSessionID := uuid.New().String()
	allowedFactors := []string{}
	if user.HasTotp.Bool {
		allowedFactors = append(allowedFactors, "totp")
	}

	mfaData, _ := json.Marshal(map[string]string{
		"user_id": user.ID.String(),
		"role":    user.Role,
	})

	err = s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", mfaSessionID), mfaData, 5*time.Minute).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create mfa session")
	}

	return &authv1.LoginPrimaryResponse{
		MfaSessionId:   mfaSessionID,
		AllowedFactors: allowedFactors,
	}, nil
}

func (s *service) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	key := fmt.Sprintf("mfa_session:%s", req.GetMfaSessionId())
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "mfa session expired or invalid")
	}

	var data map[string]string
	json.Unmarshal([]byte(val), &data)
	userID, _ := uuid.Parse(data["user_id"])

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	switch f := req.Factor.(type) {
	case *authv1.VerifyLoginMFARequest_TotpCode:
		if !totp.Validate(f.TotpCode, user.TotpSecret.String) {
			return nil, status.Error(codes.InvalidArgument, "invalid totp code")
		}
	default:
		return nil, status.Error(codes.InvalidArgument, "no mfa factor provided")
	}

	s.redis.Del(ctx, key)
	return s.mintTokens(ctx, userID, user.Role, req.GetDeviceId())
}

func (s *service) RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	hash := sha256.Sum256([]byte(req.GetRefreshToken()))
	hashedToken := hex.EncodeToString(hash[:])

	tokenRecord, err := s.queries.GetRefreshTokenByHashedToken(ctx, hashedToken)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid refresh token")
	}

	if tokenRecord.DeviceID != req.GetDeviceId() {
		return nil, status.Error(codes.Unauthenticated, "invalid device id")
	}

	s.queries.RevokeRefreshToken(ctx, hashedToken)
	userID := uuid.UUID(tokenRecord.UserID.Bytes)
	user, _ := s.queries.GetUserByID(ctx, tokenRecord.UserID)

	return s.mintTokens(ctx, userID, user.Role, req.GetDeviceId())
}

func (s *service) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	// 1. Revoke refresh token
	hash := sha256.Sum256([]byte(req.GetRefreshToken()))
	hashedToken := hex.EncodeToString(hash[:])
	s.queries.RevokeRefreshToken(ctx, hashedToken)

	// 2. Denylist access token (JTI) in Redis (Instruction 6)
	// First parse access token claims to get JTI and UserID
	token, _, err := new(jwt.Parser).ParseUnverified(req.GetAccessToken(), &interceptors.AuthClaims{})
	if err == nil {
		if claims, ok := token.Claims.(*interceptors.AuthClaims); ok {
			// Clear active token key in Redis
			s.redis.Del(ctx, fmt.Sprintf("active_token:%s", claims.Subject))
		}
	}

	return &authv1.LogoutResponse{Success: true}, nil
}

// --- WebAuthn Adapter ---

type webauthnUser struct {
	id          []byte
	email       string
	credentials []webauthn.Credential
}

func (u *webauthnUser) WebAuthnID() []byte                         { return u.id }
func (u *webauthnUser) WebAuthnName() string                       { return u.email }
func (u *webauthnUser) WebAuthnDisplayName() string                { return u.email }
func (u *webauthnUser) WebAuthnIcon() string                       { return "" }
func (u *webauthnUser) WebAuthnCredentials() []webauthn.Credential { return u.credentials }

func (s *service) getWebauthnUser(ctx context.Context, user generated.User) (*webauthnUser, error) {
	dbCreds, err := s.queries.GetWebAuthnCredentialsByUserID(ctx, user.ID)
	if err != nil {
		return nil, err
	}

	creds := make([]webauthn.Credential, len(dbCreds))
	for i, c := range dbCreds {
		creds[i] = webauthn.Credential{
			ID:              c.CredentialID,
			PublicKey:       c.PublicKey,
			AttestationType: "none",
			Authenticator: webauthn.Authenticator{
				SignCount: uint32(c.SignCount.Int32),
			},
		}
	}

	return &webauthnUser{
		id:          user.ID.Bytes[:],
		email:       user.Email,
		credentials: creds,
	}, nil
}

func (s *service) BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	uID, _ := uuid.Parse(userIDStr)

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: uID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "user fetch failed")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}

	options, session, err := s.webauthn.BeginRegistration(waUser)
	if err != nil {
		return nil, status.Error(codes.Internal, "webauthn begin failed")
	}

	sessJSON, _ := json.Marshal(session)
	s.redis.Set(ctx, fmt.Sprintf("webauthn_reg:%s", userIDStr), sessJSON, 5*time.Minute)

	optionsJSON, _ := json.Marshal(options.Response)
	return &authv1.WebAuthnRegResponse{
		PublicKeyCredentialCreationOptions: optionsJSON,
	}, nil
}

func (s *service) FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	uID, _ := uuid.Parse(userIDStr)

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: uID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "user fetch failed")
	}
	_ = user

	sessVal, err := s.redis.Get(ctx, fmt.Sprintf("webauthn_reg:%s", userIDStr)).Result()
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "registration session expired")
	}

	var session webauthn.SessionData
	json.Unmarshal([]byte(sessVal), &session)

	parsedCredential, err := protocol.ParseCredentialCreationResponse(nil) // Placeholder: Need binary parsing
	_ = parsedCredential

	return nil, status.Error(codes.Unimplemented, "binary credential parsing requires frontend integration helper")
}

func (s *service) BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error) {
	userUUID, _ := uuid.Parse(req.GetUserId())
	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userUUID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	waUser, _ := s.getWebauthnUser(ctx, user)
	options, session, err := s.webauthn.BeginLogin(waUser)
	if err != nil {
		return nil, status.Error(codes.Internal, "webauthn login begin failed")
	}

	mfaSessionID := uuid.New().String()
	sessJSON, _ := json.Marshal(session)
	s.redis.Set(ctx, fmt.Sprintf("webauthn_login:%s", mfaSessionID), sessJSON, 5*time.Minute)

	optionsJSON, _ := json.Marshal(options.Response)
	return &authv1.WebAuthnLoginResponse{
		MfaSessionId:                      mfaSessionID,
		PublicKeyCredentialRequestOptions: optionsJSON,
	}, nil
}

func (s *service) FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "finish webauthn login not yet implemented")
}

func (s *service) mintTokens(ctx context.Context, userID uuid.UUID, role, deviceID string) (*authv1.AuthTokens, error) {
	jti := uuid.New().String()

	claims := interceptors.AuthClaims{
		Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			ID:        jti,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	accessToken, _ := token.SignedString([]byte(s.cfg.JWTKey))

	refreshToken := uuid.New().String()
	hash := sha256.Sum256([]byte(refreshToken))
	hashedToken := hex.EncodeToString(hash[:])

	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	_, err := s.queries.CreateRefreshToken(ctx, generated.CreateRefreshTokenParams{
		UserID:      pgtype.UUID{Bytes: userID, Valid: true},
		DeviceID:    deviceID,
		HashedToken: hashedToken,
		ExpiresAt:   pgtype.Timestamptz{Time: expiresAt, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to persist refresh token")
	}

	err = s.redis.Set(ctx, fmt.Sprintf("active_token:%s", userID.String()), jti, 15*time.Minute).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to set active session")
	}

	return &authv1.AuthTokens{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}

func generateOTP() string {
	max := big.NewInt(1000000)
	n, _ := rand.Int(rand.Reader, max)
	return fmt.Sprintf("%06d", n)
}
