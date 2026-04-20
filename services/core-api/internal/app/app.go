package app

import (
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AdminHandler      *transportgrpc.AdminHandler
	AuthHandler       *transportgrpc.AuthHandler
	DstHandler        *transportgrpc.DstHandler
	KycHandler        *transportgrpc.KycHandler
	MediaHandler      *transportgrpc.MediaHandler
	OnboardingHandler *transportgrpc.OnboardingHandler
}

func New(adminService transportgrpc.AdminService, authService transportgrpc.AuthService, dstService transportgrpc.DstService, kycService transportgrpc.KycService, mediaService transportgrpc.MediaService, onboardingService transportgrpc.OnboardingService) *Application {
	return &Application{
		AdminHandler:      transportgrpc.NewAdminHandler(adminService),
		AuthHandler:       transportgrpc.NewAuthHandler(authService),
		DstHandler:        transportgrpc.NewDstHandler(dstService),
		KycHandler:        transportgrpc.NewKycHandler(kycService),
		MediaHandler:      transportgrpc.NewMediaHandler(mediaService),
		OnboardingHandler: transportgrpc.NewOnboardingHandler(onboardingService),
	}
}
