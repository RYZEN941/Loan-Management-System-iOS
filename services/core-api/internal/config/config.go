package config

import "os"

type Config struct {
	GRPCPort string
	JWTKey   string

	PostgresDSN string
	RedisAddr   string
	RedisPass   string

	WebAuthnRPID          string
	WebAuthnRPOrigins     string
	WebAuthnRPDisplayName string

	SandboxBaseURL string
	SandboxAPIKey  string
	SandboxSecret  string
}

func Load() Config {
	return Config{
		GRPCPort:    envOrDefault("GRPC_PORT", "8080"),
		JWTKey:      envOrDefault("JWT_SIGNING_KEY", "dev-only-change-me"),
		PostgresDSN: envOrDefault("POSTGRES_DSN", "postgres://lms:lms@localhost:5432/lms?sslmode=disable"),
		RedisAddr:   envOrDefault("REDIS_ADDR", "localhost:6379"),
		RedisPass:   os.Getenv("REDIS_PASSWORD"),

		WebAuthnRPID:          envOrDefault("WEBAUTHN_RP_ID", "localhost"),
		WebAuthnRPOrigins:     envOrDefault("WEBAUTHN_RP_ORIGINS", "http://localhost:3000"),
		WebAuthnRPDisplayName: envOrDefault("WEBAUTHN_RP_DISPLAY_NAME", "LMS Monorepo"),

		SandboxBaseURL: envOrDefault("SANDBOX_BASE_URL", "https://api.sandbox.co.in"),
		SandboxAPIKey:  os.Getenv("SANDBOX_API_KEY"),
		SandboxSecret:  os.Getenv("SANDBOX_API_SECRET"),
	}
}

func envOrDefault(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}
