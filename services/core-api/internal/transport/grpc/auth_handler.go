package grpc

import (
	"context"

	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type AuthService interface {
	Hello(ctx context.Context, name string) (string, error)
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

func (h *AuthHandler) InitiateSignup(context.Context, *authv1.SignupRequest) (*authv1.SignupResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) VerifySignupOTPs(context.Context, *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) SetupTOTP(context.Context, *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) VerifyTOTPSetup(context.Context, *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) LoginPrimary(context.Context, *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) VerifyLoginMFA(context.Context, *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) BeginWebAuthnRegistration(context.Context, *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
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

func (h *AuthHandler) RefreshToken(context.Context, *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}

func (h *AuthHandler) Logout(context.Context, *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	return nil, status.Error(codes.Unimplemented, "not implemented")
}
