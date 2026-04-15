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
			UserID: user.ID,
			Name:   name,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to create manager profile")
		}
		profileID = managerProfile.ID.String()
	case generated.UserRoleOfficer:
		officerProfile, err := s.queries.CreateOfficerProfile(ctx, generated.CreateOfficerProfileParams{
			UserID: user.ID,
			Name:   name,
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

// CreateBankBranch creates a branch and optionally links it to a manager profile id.
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

	managerID := pgtype.UUID{Valid: false}
	if rawManagerID := strings.TrimSpace(req.GetManagerId()); rawManagerID != "" {
		parsedManagerID, err := uuid.Parse(rawManagerID)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "manager_id must be a valid uuid")
		}

		_, err = s.queries.GetManagerProfileByID(ctx, pgtype.UUID{Bytes: parsedManagerID, Valid: true})
		if err != nil {
			return nil, status.Error(codes.NotFound, "manager profile not found")
		}

		managerID = pgtype.UUID{Bytes: parsedManagerID, Valid: true}
	}

	branch, err := s.queries.CreateBankBranch(ctx, generated.CreateBankBranchParams{
		Name:      name,
		Region:    region,
		City:      city,
		ManagerID: managerID,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create bank branch")
	}

	return &adminv1.CreateBankBranchResponse{
		Success:  true,
		BranchId: branch.ID.String(),
	}, nil
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
