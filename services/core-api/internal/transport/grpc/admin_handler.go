package grpc

import (
	"context"

	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
)

type AdminService interface {
	CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error)
	CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error)
	CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error)
	UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error)
	UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error)
	AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error)
}

type AdminHandler struct {
	adminv1.UnimplementedAdminServiceServer
	adminService AdminService
}

func NewAdminHandler(adminService AdminService) *AdminHandler {
	return &AdminHandler{adminService: adminService}
}

func (h *AdminHandler) CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error) {
	return h.adminService.CreateAdminAccount(ctx, req)
}

func (h *AdminHandler) CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error) {
	return h.adminService.CreateEmployeeAccount(ctx, req)
}

func (h *AdminHandler) CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error) {
	return h.adminService.CreateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error) {
	return h.adminService.UpdateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error) {
	return h.adminService.UpdateEmployeeAccount(ctx, req)
}

func (h *AdminHandler) AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error) {
	return h.adminService.AssignEmployeeBranch(ctx, req)
}
