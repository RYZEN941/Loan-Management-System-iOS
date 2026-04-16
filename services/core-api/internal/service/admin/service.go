package admin

import (
	"context"
	"strings"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error)
	CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error)
	UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error)
	UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error)
	AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error)
}

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

// CreateEmployeeAccount creates a manager/officer account and corresponding profile row.
// Created employee users are active and must change password on first login.
func (s *service) CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	name := strings.TrimSpace(req.GetName())
	email := strings.TrimSpace(req.GetEmail())
	phone := strings.TrimSpace(req.GetPhoneNumber())
	password := req.GetPassword()
	if name == "" || email == "" || phone == "" || password == "" {
		return nil, status.Error(codes.InvalidArgument, "name, email, phone_number, and password are required")
	}

	role, err := mapEmployeeTypeToRole(req.GetEmployeeType())
	if err != nil {
		return nil, err
	}

	if err := validatePasswordStrength(password); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	branchID := pgtype.UUID{Valid: false}
	if rawBranchID := strings.TrimSpace(req.GetBranchId()); rawBranchID != "" {
		parsedBranchID, err := uuid.Parse(rawBranchID)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
		}

		if _, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: parsedBranchID, Valid: true}); err != nil {
			return nil, status.Error(codes.NotFound, "branch not found")
		}

		branchID = pgtype.UUID{Bytes: parsedBranchID, Valid: true}
	}

	hash, err := argon2.HashPassword(password, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	user, err := s.queries.CreateEmployeeUser(ctx, generated.CreateEmployeeUserParams{
		Email:        email,
		Phone:        phone,
		PasswordHash: hash,
		Role:         role,
	})
	if err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create employee user")
	}

	profileID := ""
	switch role {
	case generated.UserRoleManager:
		managerProfile, err := s.queries.CreateManagerProfile(ctx, generated.CreateManagerProfileParams{
			UserID:   user.ID,
			Name:     name,
			BranchID: branchID,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to create manager profile")
		}
		profileID = managerProfile.ID.String()
	case generated.UserRoleOfficer:
		officerProfile, err := s.queries.CreateOfficerProfile(ctx, generated.CreateOfficerProfileParams{
			UserID:   user.ID,
			Name:     name,
			BranchID: branchID,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to create officer profile")
		}
		profileID = officerProfile.ID.String()
	default:
		return nil, status.Error(codes.InvalidArgument, "invalid employee role")
	}

	return &adminv1.CreateEmployeeAccountResponse{
		Success:   true,
		UserId:    user.ID.String(),
		ProfileId: profileID,
	}, nil
}

// CreateBankBranch creates a branch.
func (s *service) CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	name := strings.TrimSpace(req.GetName())
	region := strings.TrimSpace(req.GetRegion())
	city := strings.TrimSpace(req.GetCity())
	if name == "" || region == "" || city == "" {
		return nil, status.Error(codes.InvalidArgument, "name, region, and city are required")
	}

	branch, err := s.queries.CreateBankBranch(ctx, generated.CreateBankBranchParams{
		Name:   name,
		Region: region,
		City:   city,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create bank branch")
	}

	return &adminv1.CreateBankBranchResponse{
		Success:  true,
		BranchId: branch.ID.String(),
	}, nil
}

// UpdateBankBranch updates branch metadata.
func (s *service) UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	branchIDStr := strings.TrimSpace(req.GetBranchId())
	if branchIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "branch_id is required")
	}

	branchID, err := uuid.Parse(branchIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
	}

	currentBranch, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: branchID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "branch not found")
	}

	name := strings.TrimSpace(req.GetName())
	if name == "" {
		name = currentBranch.Name
	}
	region := strings.TrimSpace(req.GetRegion())
	if region == "" {
		region = currentBranch.Region
	}
	city := strings.TrimSpace(req.GetCity())
	if city == "" {
		city = currentBranch.City
	}

	err = s.queries.UpdateBankBranch(ctx, generated.UpdateBankBranchParams{
		ID:     pgtype.UUID{Bytes: branchID, Valid: true},
		Name:   name,
		Region: region,
		City:   city,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update branch")
	}

	return &adminv1.UpdateBankBranchResponse{Success: true}, nil
}

// UpdateEmployeeAccount updates manager/officer email/phone and optionally resets password.
// Admin password reset always forces is_requiring_password_change=true.
func (s *service) UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	userIDStr := strings.TrimSpace(req.GetUserId())
	if userIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "employee user not found")
	}

	if user.Role != generated.UserRoleManager && user.Role != generated.UserRoleOfficer {
		return nil, status.Error(codes.InvalidArgument, "user role must be manager or officer")
	}

	email := strings.TrimSpace(req.GetEmail())
	if email == "" {
		email = user.Email
	}

	phone := strings.TrimSpace(req.GetPhoneNumber())
	if phone == "" {
		phone = user.Phone
	}

	if err := s.queries.UpdateEmployeeEmailAndPhone(ctx, generated.UpdateEmployeeEmailAndPhoneParams{
		ID:    pgtype.UUID{Bytes: userID, Valid: true},
		Email: email,
		Phone: phone,
	}); err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to update employee contact")
	}

	newPassword := req.GetNewPassword()
	if strings.TrimSpace(newPassword) != "" {
		if err := validatePasswordStrength(newPassword); err != nil {
			return nil, status.Error(codes.InvalidArgument, err.Error())
		}

		hash, err := argon2.HashPassword(newPassword, argon2.DefaultConfig())
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to hash password")
		}

		if err := s.queries.UpdateEmployeePasswordByAdmin(ctx, generated.UpdateEmployeePasswordByAdminParams{
			ID:           pgtype.UUID{Bytes: userID, Valid: true},
			PasswordHash: hash,
		}); err != nil {
			return nil, status.Error(codes.Internal, "failed to update employee password")
		}
	}

	return &adminv1.UpdateEmployeeAccountResponse{Success: true}, nil
}

// AssignEmployeeBranch assigns or clears a branch on manager/officer profiles.
func (s *service) AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	userIDStr := strings.TrimSpace(req.GetUserId())
	if userIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "employee user not found")
	}

	if user.Role != generated.UserRoleManager && user.Role != generated.UserRoleOfficer {
		return nil, status.Error(codes.InvalidArgument, "user role must be manager or officer")
	}

	branchID := pgtype.UUID{Valid: false}
	if !req.GetClearBranch() {
		rawBranchID := strings.TrimSpace(req.GetBranchId())
		if rawBranchID == "" {
			return nil, status.Error(codes.InvalidArgument, "branch_id is required unless clear_branch is true")
		}

		parsedBranchID, err := uuid.Parse(rawBranchID)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
		}

		if _, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: parsedBranchID, Valid: true}); err != nil {
			return nil, status.Error(codes.NotFound, "branch not found")
		}

		branchID = pgtype.UUID{Bytes: parsedBranchID, Valid: true}
	}

	if user.Role == generated.UserRoleManager {
		if err := s.queries.UpdateManagerBranch(ctx, generated.UpdateManagerBranchParams{UserID: user.ID, BranchID: branchID}); err != nil {
			return nil, status.Error(codes.Internal, "failed to update manager branch")
		}
	} else {
		if err := s.queries.UpdateOfficerBranch(ctx, generated.UpdateOfficerBranchParams{UserID: user.ID, BranchID: branchID}); err != nil {
			return nil, status.Error(codes.Internal, "failed to update officer branch")
		}
	}

	return &adminv1.AssignEmployeeBranchResponse{Success: true}, nil
}

func mapEmployeeTypeToRole(employeeType adminv1.EmployeeType) (generated.UserRole, error) {
	switch employeeType {
	case adminv1.EmployeeType_EMPLOYEE_TYPE_MANAGER:
		return generated.UserRoleManager, nil
	case adminv1.EmployeeType_EMPLOYEE_TYPE_OFFICER:
		return generated.UserRoleOfficer, nil
	default:
		return "", status.Error(codes.InvalidArgument, "employee_type must be manager or officer")
	}
}

func validatePasswordStrength(password string) error {
	if len(password) < 8 {
		return status.Error(codes.InvalidArgument, "password must be at least 8 characters long")
	}

	var hasUpper, hasLower, hasDigit, hasSpecial bool
	for _, r := range password {
		switch {
		case r >= 'A' && r <= 'Z':
			hasUpper = true
		case r >= 'a' && r <= 'z':
			hasLower = true
		case r >= '0' && r <= '9':
			hasDigit = true
		case strings.ContainsRune("!@#$%^&*()-_=+[]{}|;:'\",.<>/?`~", r):
			hasSpecial = true
		}
	}

	if !hasUpper || !hasLower || !hasDigit || !hasSpecial {
		return status.Error(codes.InvalidArgument, "password must include uppercase, lowercase, number, and special character")
	}

	return nil
}
