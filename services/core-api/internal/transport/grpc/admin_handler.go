package grpc

import (
	"context"

	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
)

type AdminService interface {
	CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error)
	CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error)
	CreateDstAccount(ctx context.Context, req *adminv1.CreateDstAccountRequest) (*adminv1.CreateDstAccountResponse, error)
	GetDstAccount(ctx context.Context, req *adminv1.GetDstAccountRequest) (*adminv1.GetDstAccountResponse, error)
	ListDstAccounts(ctx context.Context, req *adminv1.ListDstAccountsRequest) (*adminv1.ListDstAccountsResponse, error)
	CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error)
	UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error)
	UpdateBranchDstCommission(ctx context.Context, req *adminv1.UpdateBranchDstCommissionRequest) (*adminv1.UpdateBranchDstCommissionResponse, error)
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

func (h *AdminHandler) CreateDstAccount(ctx context.Context, req *adminv1.CreateDstAccountRequest) (*adminv1.CreateDstAccountResponse, error) {
	return h.adminService.CreateDstAccount(ctx, req)
}

func (h *AdminHandler) GetDstAccount(ctx context.Context, req *adminv1.GetDstAccountRequest) (*adminv1.GetDstAccountResponse, error) {
	return h.adminService.GetDstAccount(ctx, req)
}

func (h *AdminHandler) ListDstAccounts(ctx context.Context, req *adminv1.ListDstAccountsRequest) (*adminv1.ListDstAccountsResponse, error) {
	return h.adminService.ListDstAccounts(ctx, req)
}

func (h *AdminHandler) CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error) {
	return h.adminService.CreateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error) {
	return h.adminService.UpdateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateBranchDstCommission(ctx context.Context, req *adminv1.UpdateBranchDstCommissionRequest) (*adminv1.UpdateBranchDstCommissionResponse, error) {
	return h.adminService.UpdateBranchDstCommission(ctx, req)
}

func (h *AdminHandler) UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error) {
	return h.adminService.UpdateEmployeeAccount(ctx, req)
}

func (h *AdminHandler) AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error) {
	return h.adminService.AssignEmployeeBranch(ctx, req)
}
