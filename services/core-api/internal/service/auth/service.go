package auth

import (
	"context"
	"fmt"
	"strings"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"github.com/redis/go-redis/v9"
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
	redis   *redis.Client
}

func NewService(queries generated.Querier, redis *redis.Client) Service {
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
	return nil, fmt.Errorf("not implemented")
}

func (s *service) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	return nil, fmt.Errorf("not implemented")
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
