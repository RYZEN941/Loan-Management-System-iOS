package app

import (
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AuthHandler *transportgrpc.AuthHandler
}

func New(authService transportgrpc.AuthService) *Application {
	return &Application{
		AuthHandler: transportgrpc.NewAuthHandler(authService),
	}
}
