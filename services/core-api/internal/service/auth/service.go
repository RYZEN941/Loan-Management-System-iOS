package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
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
	SelectLoginMFAFactor(ctx context.Context, req *authv1.SelectLoginMFAFactorRequest) (*authv1.SelectLoginMFAFactorResponse, error)
	VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error)
	ChangePassword(ctx context.Context, req *authv1.ChangePasswordRequest) (*authv1.ChangePasswordResponse, error)
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

const (
	mfaFactorTOTP     = "totp"
	mfaFactorEmailOTP = "email_otp"
	mfaFactorPhoneOTP = "phone_otp"

	mfaSessionTTL      = 5 * time.Minute
	mfaChallengeTTL    = 5 * time.Minute
	mfaChallengeMaxTry = 5
)

type mfaSessionState struct {
	UserID         string   `json:"user_id"`
	Role           string   `json:"role"`
	Email          string   `json:"email"`
	Phone          string   `json:"phone"`
	AllowedFactors []string `json:"allowed_factors"`
	SelectedFactor string   `json:"selected_factor"`
}

type mfaOTPChallenge struct {
	Factor    string `json:"factor"`
	OTPHash   string `json:"otp_hash"`
	Attempts  int    `json:"attempts"`
	MaxTry    int    `json:"max_try"`
	ExpiresAt int64  `json:"expires_at"`
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

	role, err := mapProtoRole(req.GetRole())
	if err != nil {
		return nil, err
	}

	user, err := s.queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        req.GetEmail(),
		Phone:        req.GetPhone(),
		PasswordHash: hash,
		Role:         role,
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

	userUUID, err := uuid.Parse(data["user_id"])
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid registration user id")
	}

	err = s.queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              pgtype.UUID{Bytes: userUUID, Valid: true},
		IsActive:        pgtype.Bool{Bool: false, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to verify user")
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

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
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
		allowedFactors = append(allowedFactors, mfaFactorTOTP)
	}
	if user.IsEmailVerified.Bool {
		allowedFactors = append(allowedFactors, mfaFactorEmailOTP)
	}
	if user.IsPhoneVerified.Bool {
		allowedFactors = append(allowedFactors, mfaFactorPhoneOTP)
	}

	if len(allowedFactors) == 0 {
		return nil, status.Error(codes.FailedPrecondition, "no mfa factors available")
	}

	mfaData, err := json.Marshal(mfaSessionState{
		UserID:         user.ID.String(),
		Role:           string(user.Role),
		Email:          user.Email,
		Phone:          user.Phone,
		AllowedFactors: allowedFactors,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to encode mfa session")
	}

	err = s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", mfaSessionID), mfaData, mfaSessionTTL).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create mfa session")
	}

	return &authv1.LoginPrimaryResponse{
		MfaSessionId:   mfaSessionID,
		AllowedFactors: allowedFactors,
	}, nil
}

func (s *service) SelectLoginMFAFactor(ctx context.Context, req *authv1.SelectLoginMFAFactorRequest) (*authv1.SelectLoginMFAFactorResponse, error) {
	session, err := s.getMFASession(ctx, req.GetMfaSessionId())
	if err != nil {
		return nil, err
	}

	factor := strings.TrimSpace(strings.ToLower(req.GetFactor()))
	if factor == "" {
		return nil, status.Error(codes.InvalidArgument, "mfa factor is required")
	}

	if !containsString(session.AllowedFactors, factor) {
		return nil, status.Error(codes.InvalidArgument, "selected mfa factor is not allowed")
	}

	challengeSent := false
	challengeTarget := ""

	session.SelectedFactor = factor

	switch factor {
	case mfaFactorTOTP:
		// No out-of-band challenge required.
	case mfaFactorEmailOTP, mfaFactorPhoneOTP:
		otp := generateOTP()
		challenge := mfaOTPChallenge{
			Factor:    factor,
			OTPHash:   hashOTP(otp),
			Attempts:  0,
			MaxTry:    mfaChallengeMaxTry,
			ExpiresAt: time.Now().Add(mfaChallengeTTL).Unix(),
		}

		challengeJSON, err := json.Marshal(challenge)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to encode mfa challenge")
		}

		if err := s.redis.Set(ctx, fmt.Sprintf("mfa_challenge:%s", req.GetMfaSessionId()), challengeJSON, mfaChallengeTTL).Err(); err != nil {
			return nil, status.Error(codes.Internal, "failed to create mfa challenge")
		}

		challengeSent = true
		if factor == mfaFactorEmailOTP {
			challengeTarget = maskEmail(session.Email)
			fmt.Printf("DEBUG: Login Email OTP for %s: %s\n", session.Email, otp)
		} else {
			challengeTarget = maskPhone(session.Phone)
			fmt.Printf("DEBUG: Login Phone OTP for %s: %s\n", session.Phone, otp)
		}
	default:
		return nil, status.Error(codes.InvalidArgument, "unsupported mfa factor")
	}

	if err := s.setMFASession(ctx, req.GetMfaSessionId(), session); err != nil {
		return nil, err
	}

	return &authv1.SelectLoginMFAFactorResponse{
		ChallengeSent:   challengeSent,
		ChallengeTarget: challengeTarget,
	}, nil
}

func (s *service) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	session, err := s.getMFASession(ctx, req.GetMfaSessionId())
	if err != nil {
		return nil, err
	}
	if session.SelectedFactor == "" {
		return nil, status.Error(codes.FailedPrecondition, "mfa factor not selected")
	}

	userID, err := uuid.Parse(session.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid mfa user id")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	switch session.SelectedFactor {
	case mfaFactorTOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_TotpCode)
		if !ok || strings.TrimSpace(f.TotpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "totp code is required")
		}
		if !totp.Validate(f.TotpCode, user.TotpSecret.String) {
			return nil, status.Error(codes.InvalidArgument, "invalid totp code")
		}
	case mfaFactorEmailOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_EmailOtpCode)
		if !ok || strings.TrimSpace(f.EmailOtpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "email otp code is required")
		}
		if err := s.verifyMFAOTP(ctx, req.GetMfaSessionId(), mfaFactorEmailOTP, f.EmailOtpCode); err != nil {
			return nil, err
		}
	case mfaFactorPhoneOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_PhoneOtpCode)
		if !ok || strings.TrimSpace(f.PhoneOtpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "phone otp code is required")
		}
		if err := s.verifyMFAOTP(ctx, req.GetMfaSessionId(), mfaFactorPhoneOTP, f.PhoneOtpCode); err != nil {
			return nil, err
		}
	default:
		return nil, status.Error(codes.InvalidArgument, "unsupported mfa factor")
	}

	if err := s.redis.Del(ctx, fmt.Sprintf("mfa_challenge:%s", req.GetMfaSessionId())).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear mfa challenge")
	}
	if err := s.redis.Del(ctx, fmt.Sprintf("mfa_session:%s", req.GetMfaSessionId())).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear mfa session")
	}

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
}

func (s *service) ChangePassword(ctx context.Context, req *authv1.ChangePasswordRequest) (*authv1.ChangePasswordResponse, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok || strings.TrimSpace(userIDStr) == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid user context")
	}

	currentPassword := strings.TrimSpace(req.GetCurrentPassword())
	newPassword := req.GetNewPassword()
	if currentPassword == "" || newPassword == "" {
		return nil, status.Error(codes.InvalidArgument, "current_password and new_password are required")
	}

	if err := validatePasswordStrength(newPassword); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	match, err := argon2.VerifyPassword(currentPassword, user.PasswordHash)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to verify current password")
	}
	if !match {
		return nil, status.Error(codes.Unauthenticated, "current password is incorrect")
	}

	if ok, _ := argon2.VerifyPassword(newPassword, user.PasswordHash); ok {
		return nil, status.Error(codes.InvalidArgument, "new password must be different from current password")
	}

	hash, err := argon2.HashPassword(newPassword, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash new password")
	}

	err = s.queries.ChangeUserPassword(ctx, generated.ChangeUserPasswordParams{
		ID:           pgtype.UUID{Bytes: userID, Valid: true},
		PasswordHash: hash,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update password")
	}

	return &authv1.ChangePasswordResponse{Success: true}, nil
}

func (s *service) getMFASession(ctx context.Context, sessionID string) (*mfaSessionState, error) {
	key := fmt.Sprintf("mfa_session:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.Unauthenticated, "mfa session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to load mfa session")
	}

	var session mfaSessionState
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		return nil, status.Error(codes.Internal, "corrupt mfa session")
	}

	if session.UserID == "" {
		return nil, status.Error(codes.Internal, "invalid mfa session")
	}

	return &session, nil
}

func (s *service) setMFASession(ctx context.Context, sessionID string, session *mfaSessionState) error {
	b, err := json.Marshal(session)
	if err != nil {
		return status.Error(codes.Internal, "failed to encode mfa session")
	}

	if err := s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", sessionID), b, mfaSessionTTL).Err(); err != nil {
		return status.Error(codes.Internal, "failed to persist mfa session")
	}

	return nil
}

func (s *service) verifyMFAOTP(ctx context.Context, sessionID, factor, code string) error {
	key := fmt.Sprintf("mfa_challenge:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return status.Error(codes.Unauthenticated, "mfa challenge expired or missing")
		}
		return status.Error(codes.Internal, "failed to load mfa challenge")
	}

	var challenge mfaOTPChallenge
	if err := json.Unmarshal([]byte(val), &challenge); err != nil {
		return status.Error(codes.Internal, "corrupt mfa challenge")
	}

	if challenge.Factor != factor {
		return status.Error(codes.InvalidArgument, "mfa factor mismatch")
	}

	if challenge.MaxTry <= 0 {
		challenge.MaxTry = mfaChallengeMaxTry
	}

	if subtle.ConstantTimeCompare([]byte(hashOTP(code)), []byte(challenge.OTPHash)) != 1 {
		challenge.Attempts++
		if challenge.Attempts >= challenge.MaxTry {
			_ = s.redis.Del(ctx, key).Err()
			_ = s.redis.Del(ctx, fmt.Sprintf("mfa_session:%s", sessionID)).Err()
			return status.Error(codes.PermissionDenied, "too many invalid mfa attempts")
		}

		challengeJSON, err := json.Marshal(challenge)
		if err != nil {
			return status.Error(codes.Internal, "failed to encode mfa challenge")
		}

		if err := s.redis.Set(ctx, key, challengeJSON, mfaChallengeTTL).Err(); err != nil {
			return status.Error(codes.Internal, "failed to persist mfa challenge")
		}

		return status.Error(codes.InvalidArgument, "invalid otp code")
	}

	return nil
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

	if err := s.queries.RevokeRefreshToken(ctx, hashedToken); err != nil {
		return nil, status.Error(codes.Internal, "failed to revoke previous refresh token")
	}
	userID := uuid.UUID(tokenRecord.UserID.Bytes)
	user, err := s.queries.GetUserByID(ctx, tokenRecord.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to load user for refresh")
	}

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
}

func (s *service) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	// 1. Revoke refresh token
	hash := sha256.Sum256([]byte(req.GetRefreshToken()))
	hashedToken := hex.EncodeToString(hash[:])
	if err := s.queries.RevokeRefreshToken(ctx, hashedToken); err != nil {
		return nil, status.Error(codes.Internal, "failed to revoke refresh token")
	}

	// 2. Denylist access token (JTI) in Redis (Instruction 6)
	// First parse access token claims to get JTI and UserID
	token, err := jwt.ParseWithClaims(req.GetAccessToken(), &interceptors.AuthClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, status.Error(codes.Unauthenticated, "unexpected signing method")
		}
		return []byte(s.cfg.JWTKey), nil
	})
	if err == nil && token.Valid {
		if claims, ok := token.Claims.(*interceptors.AuthClaims); ok && claims.Subject != "" {
			if err := s.redis.Del(ctx, fmt.Sprintf("active_token:%s", claims.Subject)).Err(); err != nil {
				return nil, status.Error(codes.Internal, "failed to clear active session")
			}
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
	if err := json.Unmarshal([]byte(sessVal), &session); err != nil {
		return nil, status.Error(codes.Internal, "invalid registration session")
	}

	parsedCredential, err := protocol.ParseCredentialCreationResponse(nil) // Placeholder: Need binary parsing
	_ = parsedCredential

	return nil, status.Error(codes.Unimplemented, "binary credential parsing requires frontend integration helper")
}

func (s *service) BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error) {
	userUUID, err := uuid.Parse(req.GetUserId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user id")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userUUID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}
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

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func hashOTP(code string) string {
	h := sha256.Sum256([]byte(code))
	return hex.EncodeToString(h[:])
}

func maskEmail(email string) string {
	parts := strings.SplitN(email, "@", 2)
	if len(parts) != 2 {
		return ""
	}
	local := parts[0]
	if len(local) <= 2 {
		return "**@" + parts[1]
	}
	return local[:2] + "***@" + parts[1]
}

func maskPhone(phone string) string {
	if len(phone) <= 4 {
		return "****"
	}
	return "***" + phone[len(phone)-4:]
}

func mapProtoRole(role authv1.UserRole) (generated.UserRole, error) {
	switch role {
	case authv1.UserRole_USER_ROLE_ADMIN:
		return generated.UserRoleAdmin, nil
	case authv1.UserRole_USER_ROLE_MANAGER:
		return generated.UserRoleManager, nil
	case authv1.UserRole_USER_ROLE_OFFICER:
		return generated.UserRoleOfficer, nil
	case authv1.UserRole_USER_ROLE_BORROWER:
		return generated.UserRoleBorrower, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid role")
	}
}

func validatePasswordStrength(password string) error {
	if len(password) < 8 {
		return fmt.Errorf("new password must be at least 8 characters long")
	}

	var hasUpper, hasLower, hasDigit, hasSpecial bool
	for _, r := range password {
		switch {
		case r >= 'A' && r <= 'Z':
			hasUpper = true
		case r >= 'a' && r <= 'z':
			hasLower = true
		case r >= '0' && r <= '9':
			hasDigit = true
		case strings.ContainsRune("!@#$%^&*()-_=+[]{}|;:'\",.<>/?`~", r):
			hasSpecial = true
		}
	}

	if !hasUpper || !hasLower || !hasDigit || !hasSpecial {
		return fmt.Errorf("new password must include uppercase, lowercase, number, and special character")
	}

	return nil
}
