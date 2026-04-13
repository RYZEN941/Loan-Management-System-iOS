package app

import (
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
)

type Application struct {
	AuthHandler *transportgrpc.AuthHandler
}

func New(authService transportgrpc.AuthService, queries generated.Querier) *Application {
	return &Application{
		AuthHandler: transportgrpc.NewAuthHandler(authService),
	}
}
