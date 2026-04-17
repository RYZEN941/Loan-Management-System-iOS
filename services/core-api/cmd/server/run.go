package server

import (
	"context"
	"fmt"
	"log"
	"net"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/app"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/db"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/admin"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/auth"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/onboarding"
	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	onboardingv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/onboardingv1"
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
		return fmt.Errorf("failed to connect to redis: %w", err)
	}
	defer redisClient.Close()

	pgPool, err := db.NewPostgresPool(context.Background(), cfg.PostgresDSN)
	if err != nil {
		return fmt.Errorf("failed to connect to postgres: %w", err)
	}
	defer pgPool.Close()

	queries := generated.New(pgPool)

	lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
	if err != nil {
		return fmt.Errorf("listen on grpc port %s: %w", cfg.GRPCPort, err)
	}

	adminService := admin.NewService(queries)
	authService := auth.NewService(queries, redisClient, cfg)
	onboardingService := onboarding.NewService(queries)
	application := app.New(adminService, authService, onboardingService)

	publicMethods := map[string]struct{}{
		// BOOTSTRAP ADMIN ONLY:
		// Keep this line uncommented only for initial setup environments where the first admin
		// must be created without authentication. Comment this line in production to disable
		// unauthenticated admin bootstrap account creation.
		"/admin.v1.AdminService/CreateAdminAccount": {},
		"/auth.v1.AuthService/Hello":                {},
		"/auth.v1.AuthService/InitiateSignup":       {},
		"/auth.v1.AuthService/VerifySignupOTPs":     {},
		"/auth.v1.AuthService/LoginPrimary":         {},
		"/auth.v1.AuthService/SelectLoginMFAFactor": {},
		"/auth.v1.AuthService/VerifyLoginMFA":       {},
		"/auth.v1.AuthService/RefreshToken":         {},
		"/grpc.health.v1.Health/Check":              {},
		"/grpc.health.v1.Health/Watch":              {},
	}

	rbacPolicy := grpcinterceptors.RBACPolicy{
		"/admin.v1.AdminService/CreateEmployeeAccount":                {"admin"},
		"/admin.v1.AdminService/CreateDstAccount":                     {"manager"},
		"/admin.v1.AdminService/CreateBankBranch":                     {"admin"},
		"/admin.v1.AdminService/UpdateBankBranch":                     {"admin"},
		"/admin.v1.AdminService/UpdateBranchDstCommission":            {"manager", "admin"},
		"/admin.v1.AdminService/UpdateEmployeeAccount":                {"admin"},
		"/admin.v1.AdminService/AssignEmployeeBranch":                 {"admin"},
		"/auth.v1.AuthService/SetupTOTP":                              {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/VerifyTOTPSetup":                        {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/ChangePassword":                         {"borrower", "officer", "manager", "admin", "dst"},
		"/onboarding.v1.OnboardingService/CompleteBorrowerOnboarding": {"borrower"},
		"/auth.v1.AuthService/Logout":                                 {"borrower", "officer", "manager", "admin", "dst"},
		// Example future loan roles
		// "/loan.v1.LoanService/ApproveLoan": {"officer", "manager", "admin"},
	}

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			grpcinterceptors.LoggingUnaryInterceptor(),
			grpcinterceptors.JWTUnaryInterceptor(grpcinterceptors.JWTConfig{
				SigningKey:    []byte(cfg.JWTKey),
				RedisClient:   redisClient,
				PublicMethods: publicMethods,
			}),
			grpcinterceptors.RBACUnaryInterceptor(rbacPolicy),
		),
	)

	healthServer := health.NewServer()
	healthServer.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	adminv1.RegisterAdminServiceServer(grpcServer, application.AdminHandler)
	authv1.RegisterAuthServiceServer(grpcServer, application.AuthHandler)
	onboardingv1.RegisterOnboardingServiceServer(grpcServer, application.OnboardingHandler)
	reflection.Register(grpcServer)

	log.Printf("grpc server listening on :%s", cfg.GRPCPort)
	return grpcServer.Serve(lis)
}
