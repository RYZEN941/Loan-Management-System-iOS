package grpc

import (
	"context"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/remark"
	remarkv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/remarkv1"
)

type RemarkHandlerService interface {
	remark.Service
}

type RemarkHandler struct {
	remarkv1.UnimplementedRemarkServiceServer
	remarkService remark.Service
}

func NewRemarkHandler(remarkService remark.Service) *RemarkHandler {
	return &RemarkHandler{remarkService: remarkService}
}

func (h *RemarkHandler) AddRemark(ctx context.Context, req *remarkv1.AddRemarkRequest) (*remarkv1.AddRemarkResponse, error) {
	return h.remarkService.AddRemark(ctx, req)
}

func (h *RemarkHandler) ListRemarks(ctx context.Context, req *remarkv1.ListRemarksRequest) (*remarkv1.ListRemarksResponse, error) {
	return h.remarkService.ListRemarks(ctx, req)
}
