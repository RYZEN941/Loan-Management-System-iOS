package auth

import (
	"context"
	"strings"
)

type Service interface {
	Hello(ctx context.Context, name string) (string, error)
}

type service struct{}

func NewService() Service {
	return &service{}
}

func (s *service) Hello(ctx context.Context, name string) (string, error) {
	_ = ctx
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		trimmed = "world"
	}
	return "hello " + trimmed, nil
}
