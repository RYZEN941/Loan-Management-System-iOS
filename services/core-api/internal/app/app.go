package app

import (
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AuthHandler       *transportgrpc.AuthHandler
	OnboardingHandler *transportgrpc.OnboardingHandler
}

func New(authService transportgrpc.AuthService, onboardingService transportgrpc.OnboardingService) *Application {
	return &Application{
		AuthHandler:       transportgrpc.NewAuthHandler(authService),
		OnboardingHandler: transportgrpc.NewOnboardingHandler(onboardingService),
	}
}
