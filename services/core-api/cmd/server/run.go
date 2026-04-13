package server

import (
	"context"
	"fmt"
	"log"
	"net"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/app"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/db"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/auth"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	grpcinterceptors "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	grpc_health_v1 "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

func Run() error {
	cfg := config.Load()

	redisClient, err := db.NewRedisClient(context.Background(), cfg.RedisAddr, cfg.RedisPass)
	if err != nil {
		log.Printf("redis not connected at startup: %v", err)
	}

	lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
	if err != nil {
		return fmt.Errorf("listen on grpc port %s: %w", cfg.GRPCPort, err)
	}

	authService := auth.NewService()
	application := app.New(authService)

	publicMethods := map[string]struct{}{
		"/auth.v1.AuthService/Hello":   {},
		"/grpc.health.v1.Health/Check": {},
		"/grpc.health.v1.Health/Watch": {},
	}

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(grpcinterceptors.JWTUnaryInterceptor(grpcinterceptors.JWTConfig{
			SigningKey:    []byte(cfg.JWTKey),
			RedisClient:   redisClient,
			PublicMethods: publicMethods,
		})),
	)

	healthServer := health.NewServer()
	healthServer.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	authv1.RegisterAuthServiceServer(grpcServer, application.AuthHandler)
	reflection.Register(grpcServer)

	log.Printf("grpc server listening on :%s", cfg.GRPCPort)
	return grpcServer.Serve(lis)
}
