package config

import "os"

type Config struct {
	GRPCPort string
	JWTKey   string

	PostgresDSN string
	RedisAddr   string
	RedisPass   string
}

func Load() Config {
	return Config{
		GRPCPort:    envOrDefault("GRPC_PORT", "8080"),
		JWTKey:      envOrDefault("JWT_SIGNING_KEY", "dev-only-change-me"),
		PostgresDSN: envOrDefault("POSTGRES_DSN", "postgres://lms:lms@localhost:5432/lms?sslmode=disable"),
		RedisAddr:   envOrDefault("REDIS_ADDR", "localhost:6379"),
		RedisPass:   os.Getenv("REDIS_PASSWORD"),
	}
}

func envOrDefault(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}
