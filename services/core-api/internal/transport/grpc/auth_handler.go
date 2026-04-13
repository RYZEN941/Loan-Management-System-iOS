package grpc

import (
	"context"

	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type AuthService interface {
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

type AuthHandler struct {
	authv1.UnimplementedAuthServiceServer
	authService AuthService
}

func NewAuthHandler(authService AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Hello(ctx context.Context, req *authv1.HelloRequest) (*authv1.HelloResponse, error) {
	msg, err := h.authService.Hello(ctx, req.GetName())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to process hello")
	}
	return &authv1.HelloResponse{Message: msg}, nil
}

func (h *AuthHandler) InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error) {
	return h.authService.InitiateSignup(ctx, req)
}

func (h *AuthHandler) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	return h.authService.VerifySignupOTPs(ctx, req)
}

func (h *AuthHandler) SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	return h.authService.SetupTOTP(ctx, req)
}

func (h *AuthHandler) VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	return h.authService.VerifyTOTPSetup(ctx, req)
}

func (h *AuthHandler) LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	return h.authService.LoginPrimary(ctx, req)
}

func (h *AuthHandler) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	return h.authService.VerifyLoginMFA(ctx, req)
}

func (h *AuthHandler) RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	return h.authService.RefreshToken(ctx, req)
}

func (h *AuthHandler) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	return h.authService.Logout(ctx, req)
}

func (h *AuthHandler) FinishWebAuthnRegistration(context.Context, *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) BeginWebAuthnLogin(context.Context, *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) FinishWebAuthnLogin(context.Context, *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) BeginWebAuthnRegistration(context.Context, *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}
