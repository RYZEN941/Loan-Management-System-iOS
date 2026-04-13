package interceptors

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type contextKey string

const (
	ContextUserIDKey contextKey = "user_id"
	ContextRoleKey   contextKey = "role"
)

type AuthClaims struct {
	Role string `json:"role"`
	jwt.RegisteredClaims
}

type JWTConfig struct {
	SigningKey    []byte
	RedisClient   redis.Cmdable
	PublicMethods map[string]struct{}
}

func JWTUnaryInterceptor(cfg JWTConfig) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		_ = req

		if _, ok := cfg.PublicMethods[info.FullMethod]; ok {
			return handler(ctx, req)
		}

		token, err := extractBearerToken(ctx)
		if err != nil {
			return nil, status.Error(codes.Unauthenticated, err.Error())
		}

		claims, err := parseAndValidateJWT(token, cfg.SigningKey)
		if err != nil {
			return nil, status.Error(codes.Unauthenticated, "invalid token")
		}

		if cfg.RedisClient == nil {
			return nil, status.Error(codes.Internal, "redis auth state unavailable")
		}

		key := fmt.Sprintf("active_token:%s", claims.Subject)
		activeJTI, err := cfg.RedisClient.Get(ctx, key).Result()
		if err != nil {
			if errors.Is(err, redis.Nil) {
				return nil, status.Error(codes.Unauthenticated, "session expired")
			}
			return nil, status.Error(codes.Internal, "failed auth state lookup")
		}

		if activeJTI != claims.ID {
			return nil, status.Error(codes.Unauthenticated, "token is no longer active")
		}

		ctx = context.WithValue(ctx, ContextUserIDKey, claims.Subject)
		ctx = context.WithValue(ctx, ContextRoleKey, claims.Role)

		return handler(ctx, req)
	}
}

func extractBearerToken(ctx context.Context) (string, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", errors.New("missing metadata")
	}

	authHeaders := md.Get("authorization")
	if len(authHeaders) == 0 {
		return "", errors.New("missing authorization header")
	}

	header := strings.TrimSpace(authHeaders[0])
	if !strings.HasPrefix(strings.ToLower(header), "bearer ") {
		return "", errors.New("invalid authorization scheme")
	}

	token := strings.TrimSpace(header[len("Bearer "):])
	if token == "" {
		return "", errors.New("empty bearer token")
	}

	return token, nil
}

func parseAndValidateJWT(token string, key []byte) (*AuthClaims, error) {
	if len(key) == 0 {
		return nil, errors.New("empty jwt key")
	}

	claims := &AuthClaims{}
	parsedToken, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return key, nil
	})
	if err != nil || !parsedToken.Valid {
		return nil, errors.New("jwt parse failed")
	}

	if claims.Subject == "" || claims.ID == "" || claims.Role == "" {
		return nil, errors.New("missing required jwt claims")
	}

	return claims, nil
}
