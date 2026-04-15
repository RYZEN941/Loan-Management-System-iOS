package onboarding

import (
	"context"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	onboardingv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/onboardingv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error)
}

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

func (s *service) CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error) {
	userIDStr, ok := ctx.Value(interceptors.ContextUserIDKey).(string)
	if !ok || strings.TrimSpace(userIDStr) == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid user context")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	if user.Role != generated.UserRoleBorrower {
		return nil, status.Error(codes.PermissionDenied, "only borrower can complete this onboarding")
	}

	firstName := strings.TrimSpace(req.GetFirstName())
	lastName := strings.TrimSpace(req.GetLastName())
	addressLine1 := strings.TrimSpace(req.GetAddressLine1())
	city := strings.TrimSpace(req.GetCity())
	state := strings.TrimSpace(req.GetState())
	pincode := strings.TrimSpace(req.GetPincode())
	if firstName == "" || lastName == "" || addressLine1 == "" || city == "" || state == "" || pincode == "" {
		return nil, status.Error(codes.InvalidArgument, "all profile fields are required")
	}

	dob, err := time.Parse("2006-01-02", req.GetDateOfBirth())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "date_of_birth must be YYYY-MM-DD")
	}

	if req.GetProfileCompletenessPercent() < 0 || req.GetProfileCompletenessPercent() > 100 {
		return nil, status.Error(codes.InvalidArgument, "profile_completeness_percent must be between 0 and 100")
	}

	gender, err := mapProtoBorrowerGender(req.GetGender())
	if err != nil {
		return nil, err
	}

	employmentType, err := mapProtoBorrowerEmploymentType(req.GetEmploymentType())
	if err != nil {
		return nil, err
	}

	var monthlyIncome pgtype.Numeric
	if err := monthlyIncome.Scan(strings.TrimSpace(req.GetMonthlyIncome())); err != nil {
		return nil, status.Error(codes.InvalidArgument, "monthly_income must be a valid decimal")
	}

	_, err = s.queries.CreateBorrowerProfile(ctx, generated.CreateBorrowerProfileParams{
		UserID:                     pgtype.UUID{Bytes: userID, Valid: true},
		FirstName:                  firstName,
		LastName:                   lastName,
		DateOfBirth:                pgtype.Date{Time: dob, Valid: true},
		Gender:                     gender,
		AddressLine1:               addressLine1,
		City:                       city,
		State:                      state,
		Pincode:                    pincode,
		EmploymentType:             employmentType,
		MonthlyIncome:              monthlyIncome,
		ProfileCompletenessPercent: req.GetProfileCompletenessPercent(),
	})
	if err != nil {
		lowerErr := strings.ToLower(err.Error())
		if strings.Contains(lowerErr, "duplicate") || strings.Contains(lowerErr, "unique") {
			return nil, status.Error(codes.AlreadyExists, "borrower profile already exists")
		}
		return nil, status.Error(codes.Internal, "failed to create borrower profile")
	}

	if err := s.queries.ActivateUser(ctx, pgtype.UUID{Bytes: userID, Valid: true}); err != nil {
		return nil, status.Error(codes.Internal, "failed to activate user")
	}

	return &onboardingv1.CompleteBorrowerOnboardingResponse{Success: true}, nil
}

func mapProtoBorrowerGender(gender onboardingv1.BorrowerGender) (generated.BorrowerGender, error) {
	switch gender {
	case onboardingv1.BorrowerGender_BORROWER_GENDER_MALE:
		return generated.BorrowerGenderMALE, nil
	case onboardingv1.BorrowerGender_BORROWER_GENDER_FEMALE:
		return generated.BorrowerGenderFEMALE, nil
	case onboardingv1.BorrowerGender_BORROWER_GENDER_OTHER:
		return generated.BorrowerGenderOTHER, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid borrower gender")
	}
}

func mapProtoBorrowerEmploymentType(employmentType onboardingv1.BorrowerEmploymentType) (generated.BorrowerEmploymentType, error) {
	switch employmentType {
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_SALARIED:
		return generated.BorrowerEmploymentTypeSALARIED, nil
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_SELF_EMPLOYED:
		return generated.BorrowerEmploymentTypeSELFEMPLOYED, nil
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_BUSINESS:
		return generated.BorrowerEmploymentTypeBUSINESS, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid borrower employment type")
	}
}
