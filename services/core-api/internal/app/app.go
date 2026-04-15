package app

import (
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AdminHandler      *transportgrpc.AdminHandler
	AuthHandler       *transportgrpc.AuthHandler
	OnboardingHandler *transportgrpc.OnboardingHandler
}

func New(adminService transportgrpc.AdminService, authService transportgrpc.AuthService, onboardingService transportgrpc.OnboardingService) *Application {
	return &Application{
		AdminHandler:      transportgrpc.NewAdminHandler(adminService),
		AuthHandler:       transportgrpc.NewAuthHandler(authService),
		OnboardingHandler: transportgrpc.NewOnboardingHandler(onboardingService),
	}
}
