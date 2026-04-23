package app

import (
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AdminHandler      *transportgrpc.AdminHandler
	AuthHandler       *transportgrpc.AuthHandler
	ChatHandler       *transportgrpc.ChatHandler
	DstHandler        *transportgrpc.DstHandler
	KycHandler        *transportgrpc.KycHandler
	LoanHandler       *transportgrpc.LoanHandler
	MediaHandler      *transportgrpc.MediaHandler
	OnboardingHandler *transportgrpc.OnboardingHandler
	BranchHandler     *transportgrpc.BranchHandler
}

func New(adminService transportgrpc.AdminService, authService transportgrpc.AuthService, chatService transportgrpc.ChatService, dstService transportgrpc.DstService, kycService transportgrpc.KycService, loanService transportgrpc.LoanService, mediaService transportgrpc.MediaService, onboardingService transportgrpc.OnboardingService, branchService transportgrpc.BranchService) *Application {
	return &Application{
		AdminHandler:      transportgrpc.NewAdminHandler(adminService),
		AuthHandler:       transportgrpc.NewAuthHandler(authService),
		ChatHandler:       transportgrpc.NewChatHandler(chatService),
		DstHandler:        transportgrpc.NewDstHandler(dstService),
		KycHandler:        transportgrpc.NewKycHandler(kycService),
		LoanHandler:       transportgrpc.NewLoanHandler(loanService),
		MediaHandler:      transportgrpc.NewMediaHandler(mediaService),
		OnboardingHandler: transportgrpc.NewOnboardingHandler(onboardingService),
		BranchHandler:     transportgrpc.NewBranchHandler(branchService),
	}
}
