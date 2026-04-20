package admin

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
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

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

// CreateAdminAccount is a bootstrap-only endpoint used to create the first admin user.
// Keep this RPC non-public in production by commenting out the publicMethods entry in run.go.
func (s *service) CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error) {
	email := strings.TrimSpace(req.GetEmail())
	phone := strings.TrimSpace(req.GetPhoneNumber())
	password := req.GetPassword()
	if email == "" || phone == "" || password == "" {
		return nil, status.Error(codes.InvalidArgument, "email, phone_number, and password are required")
	}

	if err := validatePasswordStrength(password); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	hash, err := argon2.HashPassword(password, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	user, err := s.queries.CreateAdminUser(ctx, generated.CreateAdminUserParams{
		Email:        email,
		Phone:        phone,
		PasswordHash: hash,
	})
	if err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create admin user")
	}

	adminProfile, err := s.queries.CreateAdminProfile(ctx, user.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create admin profile")
	}

	return &adminv1.CreateAdminAccountResponse{
		Success:   true,
		UserId:    user.ID.String(),
		ProfileId: adminProfile.ID.String(),
	}, nil
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

// CreateDstAccount creates a DST user under the same branch as the manager who invokes this RPC.
func (s *service) CreateDstAccount(ctx context.Context, req *adminv1.CreateDstAccountRequest) (*adminv1.CreateDstAccountResponse, error) {
	managerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role != "manager" {
		return nil, status.Error(codes.PermissionDenied, "only managers can create dst accounts")
	}

	managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, pgtype.UUID{Bytes: managerUserID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "manager profile not found")
	}
	if !managerProfile.BranchID.Valid {
		return nil, status.Error(codes.FailedPrecondition, "manager is not assigned to a branch")
	}

	name := strings.TrimSpace(req.GetName())
	email := strings.TrimSpace(req.GetEmail())
	phone := strings.TrimSpace(req.GetPhoneNumber())
	password := req.GetPassword()
	if name == "" || email == "" || phone == "" || password == "" {
		return nil, status.Error(codes.InvalidArgument, "name, email, phone_number, and password are required")
	}

	if err := validatePasswordStrength(password); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	hash, err := argon2.HashPassword(password, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	user, err := s.queries.CreateDstUser(ctx, generated.CreateDstUserParams{
		Email:        email,
		Phone:        phone,
		PasswordHash: hash,
	})
	if err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create dst user")
	}

	dstProfile, err := s.queries.CreateDstProfile(ctx, generated.CreateDstProfileParams{
		UserID:   user.ID,
		Name:     name,
		BranchID: managerProfile.BranchID,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create dst profile")
	}

	return &adminv1.CreateDstAccountResponse{
		Success:   true,
		UserId:    user.ID.String(),
		ProfileId: dstProfile.ID.String(),
	}, nil
}

func (s *service) GetDstAccount(ctx context.Context, req *adminv1.GetDstAccountRequest) (*adminv1.GetDstAccountResponse, error) {
	callerRole, callerBranchID, err := s.requireAdminOrManagerScope(ctx)
	if err != nil {
		return nil, err
	}

	userIDStr := strings.TrimSpace(req.GetUserId())
	if userIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	row, err := s.queries.GetDstAccountByUserID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "dst account not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch dst account")
	}

	if callerRole == "manager" && (!row.BranchID.Valid || row.BranchID.Bytes != callerBranchID) {
		return nil, status.Error(codes.PermissionDenied, "manager can only access dst accounts from their own branch")
	}

	return &adminv1.GetDstAccountResponse{Account: mapDstAccountRow(row)}, nil
}

func (s *service) ListDstAccounts(ctx context.Context, req *adminv1.ListDstAccountsRequest) (*adminv1.ListDstAccountsResponse, error) {
	callerRole, callerBranchID, err := s.requireAdminOrManagerScope(ctx)
	if err != nil {
		return nil, err
	}

	branchID := callerBranchID
	branchIDStr := strings.TrimSpace(req.GetBranchId())
	if branchIDStr != "" {
		parsedBranchID, err := uuid.Parse(branchIDStr)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
		}
		branchID = parsedBranchID
	}

	if callerRole == "manager" && branchID != callerBranchID {
		return nil, status.Error(codes.PermissionDenied, "manager can only list dst accounts from their own branch")
	}

	if _, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: branchID, Valid: true}); err != nil {
		return nil, status.Error(codes.NotFound, "branch not found")
	}

	limit := req.GetLimit()
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	offset := req.GetOffset()
	if offset < 0 {
		offset = 0
	}

	rows, err := s.queries.ListDstAccountsByBranchID(ctx, generated.ListDstAccountsByBranchIDParams{
		BranchID: pgtype.UUID{Bytes: branchID, Valid: true},
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list dst accounts")
	}

	items := make([]*adminv1.DstAccount, 0, len(rows))
	for _, row := range rows {
		item := row
		items = append(items, mapDstListRow(item))
	}

	return &adminv1.ListDstAccountsResponse{Items: items}, nil
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

// UpdateBranchDstCommission updates branch DST commission percentage.
// Managers can only update their own branch; admins can update any branch.
func (s *service) UpdateBranchDstCommission(ctx context.Context, req *adminv1.UpdateBranchDstCommissionRequest) (*adminv1.UpdateBranchDstCommissionResponse, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role != "manager" && role != "admin" {
		return nil, status.Error(codes.PermissionDenied, "only manager or admin can update dst commission")
	}

	branchIDStr := strings.TrimSpace(req.GetBranchId())
	if branchIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "branch_id is required")
	}
	branchID, err := uuid.Parse(branchIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
	}

	branch, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: branchID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "branch not found")
	}
	_ = branch

	if role == "manager" {
		managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, pgtype.UUID{Bytes: callerUserID, Valid: true})
		if err != nil {
			return nil, status.Error(codes.NotFound, "manager profile not found")
		}
		if !managerProfile.BranchID.Valid || managerProfile.BranchID.Bytes != branchID {
			return nil, status.Error(codes.PermissionDenied, "manager can only update their own branch commission")
		}
	}

	commissionRaw := strings.TrimSpace(req.GetDstCommission())
	if commissionRaw == "" {
		return nil, status.Error(codes.InvalidArgument, "dst_commission is required")
	}

	var commission pgtype.Numeric
	if err := commission.Scan(commissionRaw); err != nil {
		return nil, status.Error(codes.InvalidArgument, "dst_commission must be a valid decimal")
	}

	floatVal, err := commission.Float64Value()
	if err != nil || !floatVal.Valid {
		return nil, status.Error(codes.InvalidArgument, "invalid dst_commission")
	}
	if floatVal.Float64 < 0 || floatVal.Float64 > 100 {
		return nil, status.Error(codes.InvalidArgument, "dst_commission must be between 0 and 100")
	}

	if err := s.queries.UpdateBranchDstCommissionByID(ctx, generated.UpdateBranchDstCommissionByIDParams{
		ID:            pgtype.UUID{Bytes: branchID, Valid: true},
		DstCommission: commission,
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to update dst commission")
	}

	return &adminv1.UpdateBranchDstCommissionResponse{Success: true}, nil
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

	if user.Role != generated.UserRoleManager && user.Role != generated.UserRoleOfficer && user.Role != generated.UserRoleDst {
		return nil, status.Error(codes.InvalidArgument, "user role must be manager, officer, or dst")
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

func (s *service) requireAdminOrManagerScope(ctx context.Context) (string, uuid.UUID, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return "", uuid.UUID{}, status.Error(codes.Unauthenticated, "missing user context")
	}

	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role != "admin" && role != "manager" {
		return "", uuid.UUID{}, status.Error(codes.PermissionDenied, "only admin or manager can access dst accounts")
	}

	if role == "admin" {
		return role, uuid.UUID{}, nil
	}

	managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, pgtype.UUID{Bytes: callerUserID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", uuid.UUID{}, status.Error(codes.NotFound, "manager profile not found")
		}
		return "", uuid.UUID{}, status.Error(codes.Internal, "failed to load manager profile")
	}
	if !managerProfile.BranchID.Valid {
		return "", uuid.UUID{}, status.Error(codes.FailedPrecondition, "manager is not assigned to a branch")
	}

	return role, uuid.UUID(managerProfile.BranchID.Bytes), nil
}

func mapDstAccountRow(row generated.GetDstAccountByUserIDRow) *adminv1.DstAccount {
	return &adminv1.DstAccount{
		UserId:                    row.UserID.String(),
		ProfileId:                 row.ProfileID.String(),
		Name:                      row.Name,
		Email:                     row.Email,
		PhoneNumber:               row.Phone,
		IsActive:                  row.IsActive.Bool,
		IsRequiringPasswordChange: row.IsRequiringPasswordChange.Bool,
		BranchId:                  row.BranchID.String(),
		BranchName:                row.BranchName,
		BranchRegion:              row.BranchRegion,
		BranchCity:                row.BranchCity,
		CreatedAt:                 timeToString(row.CreatedAt),
	}
}

func mapDstListRow(row generated.ListDstAccountsByBranchIDRow) *adminv1.DstAccount {
	return &adminv1.DstAccount{
		UserId:                    row.UserID.String(),
		ProfileId:                 row.ProfileID.String(),
		Name:                      row.Name,
		Email:                     row.Email,
		PhoneNumber:               row.Phone,
		IsActive:                  row.IsActive.Bool,
		IsRequiringPasswordChange: row.IsRequiringPasswordChange.Bool,
		BranchId:                  row.BranchID.String(),
		BranchName:                row.BranchName,
		BranchRegion:              row.BranchRegion,
		BranchCity:                row.BranchCity,
		CreatedAt:                 timeToString(row.CreatedAt),
	}
}

func timeToString(t pgtype.Timestamptz) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
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
