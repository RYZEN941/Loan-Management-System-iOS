package auth

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
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
}

type service struct {
	queries generated.Querier
	redis   redis.Cmdable
}

func NewService(queries generated.Querier, redis redis.Cmdable) Service {
	return &service{
		queries: queries,
		redis:   redis,
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
	// 1. Hash password with Argon2id (Instruction 3)
	hash, err := argon2.HashPassword(req.GetPassword(), argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	// 2. Create user via sqlc (Instruction 4)
	user, err := s.queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        req.GetEmail(),
		Phone:        req.GetPhone(),
		PasswordHash: hash,
		Role:         req.GetRole(),
	})
	if err != nil {
		// Handle unique constraint violations
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create user")
	}

	// 3. Generate 6-digit OTPs (Instruction 4)
	emailOTP := generateOTP()
	phoneOTP := generateOTP()

	// 4. Save to Redis (Instruction 6)
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

	// TODO: Send OTPs via Email/SMS service (Placeholder)
	fmt.Printf("DEBUG: Email OTP for %s: %s\n", req.GetEmail(), emailOTP)
	fmt.Printf("DEBUG: Phone OTP for %s: %s\n", req.GetPhone(), phoneOTP)

	return &authv1.SignupResponse{
		RegistrationId: regID,
	}, nil
}

func (s *service) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	// 1. Retrieve registration data from Redis
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

	// 2. Verify both OTPs (Instruction 4)
	if req.GetEmailCode() != data["email_otp"] || req.GetPhoneCode() != data["phone_otp"] {
		return nil, status.Error(codes.InvalidArgument, "invalid verification codes")
	}

	// 3. Update user status via sqlc (Instruction 4)
	userUUID, _ := uuid.Parse(data["user_id"])
	err = s.queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID: pgtype.UUID{
			Bytes: userUUID,
			Valid: true,
		},
		IsActive: pgtype.Bool{
			Bool:  true,
			Valid: true,
		},
		IsEmailVerified: pgtype.Bool{
			Bool:  true,
			Valid: true,
		},
		IsPhoneVerified: pgtype.Bool{
			Bool:  true,
			Valid: true,
		},
	})

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to activate user")
	}

	// 4. Cleanup Redis
	s.redis.Del(ctx, key)

	return &authv1.VerifyOTPsResponse{
		Verified: true,
	}, nil
}

func generateOTP() string {
	max := big.NewInt(1000000)
	n, _ := rand.Int(rand.Reader, max)
	return fmt.Sprintf("%06d", n)
}

func (s *service) SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *service) VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *service) LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *service) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *service) RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *service) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	return nil, fmt.Errorf("not implemented")
}
