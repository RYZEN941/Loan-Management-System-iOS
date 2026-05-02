package remark

import (
	"context"
	"strings"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	remarkv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/remarkv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	AddRemark(ctx context.Context, req *remarkv1.AddRemarkRequest) (*remarkv1.AddRemarkResponse, error)
	ListRemarks(ctx context.Context, req *remarkv1.ListRemarksRequest) (*remarkv1.ListRemarksResponse, error)
}

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

func (s *service) AddRemark(ctx context.Context, req *remarkv1.AddRemarkRequest) (*remarkv1.AddRemarkResponse, error) {
	userID, role, err := s.requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	appID, err := s.parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}

	// Permission check: admin, branch manager, or assigned officer
	if err := s.ensureRemarkPermission(ctx, appID, userID, role); err != nil {
		return nil, err
	}

	remark, err := s.queries.CreateApplicationRemark(ctx, generated.CreateApplicationRemarkParams{
		ApplicationID: s.uuidToPg(appID),
		SenderUserID:  s.uuidToPg(userID),
		SenderRole:    generated.UserRole(role),
		Message:       req.GetMessage(),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to add remark")
	}

	return &remarkv1.AddRemarkResponse{
		Remark: s.mapRemark(remark),
	}, nil
}

func (s *service) ListRemarks(ctx context.Context, req *remarkv1.ListRemarksRequest) (*remarkv1.ListRemarksResponse, error) {
	userID, role, err := s.requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	appID, err := s.parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}

	// Permission check
	if err := s.ensureRemarkPermission(ctx, appID, userID, role); err != nil {
		return nil, err
	}

	remarks, err := s.queries.ListApplicationRemarks(ctx, s.uuidToPg(appID))
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list remarks")
	}

	items := make([]*remarkv1.Remark, len(remarks))
	for i, r := range remarks {
		items[i] = s.mapRemark(r)
	}

	return &remarkv1.ListRemarksResponse{
		Remarks: items,
	}, nil
}

func (s *service) ensureRemarkPermission(ctx context.Context, appID, userID uuid.UUID, role string) error {
	if role == "admin" {
		return nil
	}

	app, err := s.queries.GetLoanApplicationByID(ctx, s.uuidToPg(appID))
	if err != nil {
		return status.Error(codes.NotFound, "application not found")
	}

	if role == "officer" {
		if app.AssignedOfficerUserID.Valid && uuid.UUID(app.AssignedOfficerUserID.Bytes) == userID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "you are not the assigned officer for this application")
	}

	if role == "manager" {
		managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, s.uuidToPg(userID))
		if err != nil || !managerProfile.BranchID.Valid {
			return status.Error(codes.FailedPrecondition, "manager profile not found or branch not assigned")
		}
		if managerProfile.BranchID == app.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "this application does not belong to your branch")
	}

	return status.Error(codes.PermissionDenied, "you do not have permission to access remarks for this application")
}

// Helpers (duplicated from loan service for now to keep it separate as requested)

func (s *service) requireUserAndRole(ctx context.Context) (uuid.UUID, string, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user context")
	}
	role, ok := ctx.Value(interceptors.ContextRoleKey).(string)
	if !ok || strings.TrimSpace(role) == "" {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user role")
	}
	return userID, role, nil
}

func (s *service) parseUUID(v, field string) (uuid.UUID, error) {
	id, err := uuid.Parse(v)
	if err != nil {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "invalid %s", field)
	}
	return id, nil
}

func (s *service) uuidToPg(v uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: v, Valid: true}
}

func (s *service) mapRemark(row generated.ApplicationRemark) *remarkv1.Remark {
	return &remarkv1.Remark{
		Id:            row.ID.String(),
		ApplicationId: row.ApplicationID.String(),
		SenderUserId:  row.SenderUserID.String(),
		SenderRole:    string(row.SenderRole),
		Message:       row.Message,
		CreatedAt:     row.CreatedAt.Time.Format("2006-01-02T15:04:05Z"),
	}
}
