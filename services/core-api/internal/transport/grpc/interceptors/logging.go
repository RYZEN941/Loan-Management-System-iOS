package interceptors

import (
	"context"
	"log"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// LoggingUnaryInterceptor logs one line per unary request with method, duration,
// status code, and identity metadata when available.
func LoggingUnaryInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		_ = req
		started := time.Now()

		resp, err := handler(ctx, req)

		userID := ""
		if uid, ok := UserIDFromContext(ctx); ok {
			userID = uid.String()
		}

		role := ""
		if r, ok := ctx.Value(ContextRoleKey).(string); ok {
			role = r
		}

		requestID := ""
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			if values := md.Get("x-request-id"); len(values) > 0 {
				requestID = values[0]
			}
		}

		code := status.Code(err)
		log.Printf(
			"grpc_request method=%s code=%s duration_ms=%d user_id=%s role=%s request_id=%s",
			info.FullMethod,
			code.String(),
			time.Since(started).Milliseconds(),
			userID,
			role,
			requestID,
		)

		return resp, err
	}
}
