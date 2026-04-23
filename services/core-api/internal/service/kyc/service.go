package kyc

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/sandbox"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	kycv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/kycv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const kycProviderSandbox = "sandbox"

type Service interface {
	RecordUserConsent(ctx context.Context, req *kycv1.RecordUserConsentRequest) (*kycv1.RecordUserConsentResponse, error)
	InitiateAadhaarKyc(ctx context.Context, req *kycv1.InitiateAadhaarKycRequest) (*kycv1.InitiateAadhaarKycResponse, error)
	VerifyAadhaarKycOtp(ctx context.Context, req *kycv1.VerifyAadhaarKycOtpRequest) (*kycv1.VerifyAadhaarKycOtpResponse, error)
	VerifyPanKyc(ctx context.Context, req *kycv1.VerifyPanKycRequest) (*kycv1.VerifyPanKycResponse, error)
	GetBorrowerKycStatus(ctx context.Context, req *kycv1.GetBorrowerKycStatusRequest) (*kycv1.GetBorrowerKycStatusResponse, error)
	ListBorrowerKycHistory(ctx context.Context, req *kycv1.ListBorrowerKycHistoryRequest) (*kycv1.ListBorrowerKycHistoryResponse, error)
}

type service struct {
	pool    *pgxpool.Pool
	queries *generated.Queries
	client  *sandbox.KYCClient
}

func NewService(pool *pgxpool.Pool, queries *generated.Queries, client *sandbox.KYCClient) Service {
	return &service{pool: pool, queries: queries, client: client}
}

func (s *service) RecordUserConsent(ctx context.Context, req *kycv1.RecordUserConsentRequest) (*kycv1.RecordUserConsentResponse, error) {
	userID, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("RecordUserConsent: resolveBorrowerContext failed: %v", err)
		return nil, err
	}
	_ = profile

	consentVersion := strings.TrimSpace(req.GetConsentVersion())
	consentText := strings.TrimSpace(req.GetConsentText())
	consentType, err := mapConsentType(req.GetConsentType())
	if err != nil {
		log.Printf("RecordUserConsent: mapConsentType failed: %v", err)
		return nil, err
	}
	if consentVersion == "" || consentText == "" {
		log.Printf("RecordUserConsent: missing consent_version or consent_text")
		return nil, status.Error(codes.InvalidArgument, "consent_type, consent_version, and consent_text are required")
	}

	metadataRaw := []byte(strings.TrimSpace(req.GetMetadataJson()))
	if len(metadataRaw) == 0 {
		metadataRaw = []byte("{}")
	}
	var metadataCheck map[string]any
	if err := json.Unmarshal(metadataRaw, &metadataCheck); err != nil {
		log.Printf("RecordUserConsent: metadata_json unmarshal failed: %v", err)
		return nil, status.Error(codes.InvalidArgument, "metadata_json must be a valid json object")
	}

	h := sha256.Sum256([]byte(consentText))
	now := time.Now().UTC()

	created, err := s.queries.CreateUserConsent(ctx, generated.CreateUserConsentParams{
		UserID:          pgtype.UUID{Bytes: userID, Valid: true},
		ConsentType:     consentType,
		ConsentVersion:  consentVersion,
		ConsentText:     consentText,
		ConsentTextHash: hex.EncodeToString(h[:]),
		IsGranted:       req.GetIsGranted(),
		Source:          textOrNull(req.GetSource()),
		IpAddress:       textOrNull(req.GetIpAddress()),
		UserAgent:       textOrNull(req.GetUserAgent()),
		Metadata:        metadataRaw,
		GrantedAt:       timeOrNull(now, req.GetIsGranted()),
		RevokedAt:       timeOrNull(now, !req.GetIsGranted()),
	})
	if err != nil {
		log.Printf("RecordUserConsent: CreateUserConsent query failed: %v", err)
		return nil, status.Error(codes.Internal, "failed to store user consent")
	}

	return &kycv1.RecordUserConsentResponse{Success: true, ConsentId: created.ID.String()}, nil
}

func (s *service) InitiateAadhaarKyc(ctx context.Context, req *kycv1.InitiateAadhaarKycRequest) (*kycv1.InitiateAadhaarKycResponse, error) {
	userID, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("InitiateAadhaarKyc: resolveBorrowerContext failed: %v", err)
		return nil, err
	}

	if err := s.ensureGrantedConsent(ctx, userID, generated.ConsentTypeEnumAadharKyc); err != nil {
		log.Printf("InitiateAadhaarKyc: ensureGrantedConsent failed for user=%s: %v", userID, err)
		return nil, err
	}

	aadhaarNumber := strings.ReplaceAll(strings.TrimSpace(req.GetAadhaarNumber()), " ", "")
	if aadhaarNumber == "" {
		log.Printf("InitiateAadhaarKyc: missing aadhaar_number for user=%s", userID)
		return nil, status.Error(codes.InvalidArgument, "aadhaar_number is required")
	}
	reason := strings.TrimSpace(req.GetReason())
	if reason == "" {
		reason = "KYC verification"
	}

	apiReq := sandbox.AadhaarGenerateOTPRequest{
		Entity:        "in.co.sandbox.kyc.aadhaar.okyc.otp.request",
		AadhaarNumber: aadhaarNumber,
		Consent:       "Y",
		Reason:        reason,
	}
	apiResp, raw, err := s.client.GenerateAadhaarOTP(ctx, apiReq)
	if err != nil {
		log.Printf("InitiateAadhaarKyc: GenerateAadhaarOTP failed for user=%s aadhaar=%s: %v raw=%s", userID, aadhaarNumber, err, string(raw))
		return nil, status.Error(codes.Internal, fmt.Sprintf("aadhaar otp generation failed: %v", err))
	}
	log.Printf("InitiateAadhaarKyc: GenerateAadhaarOTP success for user=%s ref_id=%d tx_id=%s", userID, apiResp.Data.ReferenceID, apiResp.TransactionID)

	attemptedAt := nowPgTimestamptz()
	_, dbErr := s.queries.CreateBorrowerAadhaarKycHistory(ctx, generated.CreateBorrowerAadhaarKycHistoryParams{
		UserID:                pgtype.UUID{Bytes: userID, Valid: true},
		BorrowerProfileID:     profile.ID,
		Provider:              kycProviderSandbox,
		ProviderTransactionID: textOrNull(apiResp.TransactionID),
		ProviderReferenceID:   int64OrNull(apiResp.Data.ReferenceID),
		Status:                "OTP_SENT",
		ProviderMessage:       textOrNull(apiResp.Data.Message),
		RawResponse:           raw,
		AttemptedAt:           attemptedAt,
	})
	if dbErr != nil {
		log.Printf("InitiateAadhaarKyc: CreateBorrowerAadhaarKycHistory failed for user=%s: %v", userID, dbErr)
	}

	return &kycv1.InitiateAadhaarKycResponse{
		Success:               true,
		ReferenceId:           fmt.Sprintf("%d", apiResp.Data.ReferenceID),
		ProviderTransactionId: apiResp.TransactionID,
		Message:               apiResp.Data.Message,
	}, nil
}

func (s *service) VerifyAadhaarKycOtp(ctx context.Context, req *kycv1.VerifyAadhaarKycOtpRequest) (*kycv1.VerifyAadhaarKycOtpResponse, error) {
	log.Printf("VerifyAadhaarKycOtp: starting for borrower_user_id=%s", req.GetBorrowerUserId())
	userID, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("VerifyAadhaarKycOtp: resolveBorrowerContext failed: %v", err)
		return nil, err
	}
	log.Printf("VerifyAadhaarKycOtp: resolved borrower user_id=%s profile_id=%s", userID, profile.ID.String())

	if err := s.ensureGrantedConsent(ctx, userID, generated.ConsentTypeEnumAadharKyc); err != nil {
		log.Printf("VerifyAadhaarKycOtp: ensureGrantedConsent failed for user=%s: %v", userID, err)
		return nil, err
	}

	ref := strings.TrimSpace(req.GetReferenceId())
	otp := strings.TrimSpace(req.GetOtp())
	if ref == "" || otp == "" {
		log.Printf("VerifyAadhaarKycOtp: missing ref or otp for user=%s ref_empty=%v otp_empty=%v", userID, ref == "", otp == "")
		return nil, status.Error(codes.InvalidArgument, "reference_id and otp are required")
	}
	log.Printf("VerifyAadhaarKycOtp: calling VerifyAadhaarOTP for user=%s ref=%s", userID, ref)

	apiReq := sandbox.AadhaarVerifyOTPRequest{
		Entity:      "in.co.sandbox.kyc.aadhaar.okyc.request",
		ReferenceID: ref,
		OTP:         otp,
	}
	apiResp, raw, err := s.client.VerifyAadhaarOTP(ctx, apiReq)
	if err != nil {
		log.Printf("VerifyAadhaarKycOtp: VerifyAadhaarOTP API failed for user=%s ref=%s: %v raw=%s", userID, ref, err, string(raw))
		return nil, status.Error(codes.Internal, fmt.Sprintf("aadhaar otp verification failed: %v", err))
	}
	log.Printf("VerifyAadhaarKycOtp: API success for user=%s tx_id=%s status=%s message=%s name=%s dob=%s gender=%s",
		userID, apiResp.TransactionID, apiResp.Data.Status, apiResp.Data.Message, apiResp.Data.Name, apiResp.Data.DateOfBirth, apiResp.Data.Gender)

	isValid := strings.EqualFold(strings.TrimSpace(apiResp.Data.Status), "VALID")
	log.Printf("VerifyAadhaarKycOtp: isValid=%v for user=%s", isValid, userID)

	otpExpired := !isValid && strings.EqualFold(strings.TrimSpace(apiResp.Data.Message), "OTP Expired")
	if otpExpired {
		log.Printf("VerifyAadhaarKycOtp: OTP expired for user=%s ref=%s (status=%q message=%q)", userID, ref, apiResp.Data.Status, apiResp.Data.Message)
	}

	mismatchFailure := false
	if isValid && !aadhaarMatchesProfile(profile, apiResp.Data.Name, apiResp.Data.DateOfBirth, apiResp.Data.Gender) {
		log.Printf("VerifyAadhaarKycOtp: profile mismatch for user=%s profile_name=%s api_name=%s profile_dob=%s api_dob=%s profile_gender=%s api_gender=%s",
			userID, profile.FirstName+" "+profile.LastName, apiResp.Data.Name,
			profile.DateOfBirth.Time.Format("2006-01-02"), apiResp.Data.DateOfBirth,
			string(profile.Gender), apiResp.Data.Gender)
		isValid = false
		mismatchFailure = true
	}
	statusValue := "FAILED"
	failureCode := textOrNull("AADHAAR_VERIFY_FAILED")
	failureReason := textOrNull(apiResp.Data.Message)
	if otpExpired {
		failureCode = textOrNull("OTP_EXPIRED")
		failureReason = textOrNull("aadhaar otp has expired, please request a new one")
	} else if mismatchFailure {
		failureCode = textOrNull("PROFILE_MISMATCH")
		failureReason = textOrNull("profile details do not match with aadhaar data")
	}
	if !isValid && strings.TrimSpace(failureReason.String) == "" {
		failureReason = textOrNull("profile details do not match with aadhaar data")
	}
	if isValid {
		statusValue = "SUCCESS"
		failureCode = pgtype.Text{}
		failureReason = pgtype.Text{}
	}
	log.Printf("VerifyAadhaarKycOtp: final statusValue=%s isValid=%v otpExpired=%v mismatchFailure=%v for user=%s", statusValue, isValid, otpExpired, mismatchFailure, userID)

	historyRow, err := s.queries.CreateBorrowerAadhaarKycHistory(ctx, generated.CreateBorrowerAadhaarKycHistoryParams{
		UserID:                pgtype.UUID{Bytes: userID, Valid: true},
		BorrowerProfileID:     profile.ID,
		Provider:              kycProviderSandbox,
		ProviderTransactionID: textOrNull(apiResp.TransactionID),
		ProviderReferenceID:   int64OrNull(apiResp.Data.ReferenceID),
		Status:                statusValue,
		FailureCode:           failureCode,
		FailureReason:         failureReason,
		ProviderMessage:       textOrNull(apiResp.Data.Message),
		Name:                  textOrNull(apiResp.Data.Name),
		Gender:                textOrNull(apiResp.Data.Gender),
		DateOfBirth:           textOrNull(apiResp.Data.DateOfBirth),
		YearOfBirth:           textOrNull(apiResp.Data.YearOfBirth),
		CareOf:                textOrNull(apiResp.Data.CareOf),
		FullAddress:           textOrNull(apiResp.Data.FullAddress),
		Country:               textOrNull(apiResp.Data.Address.Country),
		District:              textOrNull(apiResp.Data.Address.District),
		House:                 textOrNull(apiResp.Data.Address.House),
		Landmark:              textOrNull(apiResp.Data.Address.Landmark),
		Pincode:               textOrNull(apiResp.Data.Address.Pincode),
		PostOffice:            textOrNull(apiResp.Data.Address.PostOffice),
		State:                 textOrNull(apiResp.Data.Address.State),
		Street:                textOrNull(apiResp.Data.Address.Street),
		Subdistrict:           textOrNull(apiResp.Data.Address.Subdistrict),
		Vtc:                   textOrNull(apiResp.Data.Address.VTC),
		EmailHash:             textOrNull(apiResp.Data.EmailHash),
		MobileHash:            textOrNull(apiResp.Data.MobileHash),
		RawResponse:           raw,
		AttemptedAt:           nowPgTimestamptz(),
	})
	if err != nil {
		log.Printf("VerifyAadhaarKycOtp: CreateBorrowerAadhaarKycHistory failed for user=%s: %v", userID, err)
		return nil, status.Error(codes.Internal, "failed to persist aadhaar kyc history")
	}
	log.Printf("VerifyAadhaarKycOtp: history persisted history_id=%s for user=%s", historyRow.ID.String(), userID)

	if isValid {
		if err := s.upsertAadhaarCurrentAndMarkVerified(ctx, userID, profile.ID, historyRow); err != nil {
			log.Printf("VerifyAadhaarKycOtp: upsertAadhaarCurrentAndMarkVerified failed for user=%s: %v", userID, err)
			return nil, err
		}
		log.Printf("VerifyAadhaarKycOtp: marked aadhaar verified for user=%s", userID)
	}

	log.Printf("VerifyAadhaarKycOtp: completed for user=%s success=%v status=%s otpExpired=%v", userID, isValid, apiResp.Data.Status, otpExpired)

	if otpExpired {
		return &kycv1.VerifyAadhaarKycOtpResponse{
			Success:               false,
			Status:                apiResp.Data.Status,
			Message:               "aadhaar otp has expired, please request a new one",
			ProviderTransactionId: apiResp.TransactionID,
		}, nil
	}

	return &kycv1.VerifyAadhaarKycOtpResponse{
		Success:               isValid,
		Status:                apiResp.Data.Status,
		Message:               apiResp.Data.Message,
		ProviderTransactionId: apiResp.TransactionID,
		Name:                  apiResp.Data.Name,
		DateOfBirth:           apiResp.Data.DateOfBirth,
		Gender:                apiResp.Data.Gender,
	}, nil
}

func (s *service) VerifyPanKyc(ctx context.Context, req *kycv1.VerifyPanKycRequest) (*kycv1.VerifyPanKycResponse, error) {
	log.Printf("VerifyPanKyc: starting for borrower_user_id=%s", req.GetBorrowerUserId())
	userID, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("VerifyPanKyc: resolveBorrowerContext failed: %v", err)
		return nil, err
	}

	if err := s.ensureGrantedConsent(ctx, userID, generated.ConsentTypeEnumPanKyc); err != nil {
		log.Printf("VerifyPanKyc: ensureGrantedConsent failed for user=%s: %v", userID, err)
		return nil, err
	}

	pan := strings.TrimSpace(req.GetPan())
	name := strings.TrimSpace(req.GetNameAsPerPan())
	dob := strings.TrimSpace(req.GetDateOfBirth())
	reason := strings.TrimSpace(req.GetReason())
	if pan == "" || name == "" || dob == "" {
		log.Printf("VerifyPanKyc: missing fields for user=%s pan_empty=%v name_empty=%v dob_empty=%v", userID, pan == "", name == "", dob == "")
		return nil, status.Error(codes.InvalidArgument, "pan, name_as_per_pan, and date_of_birth are required")
	}
	if reason == "" {
		reason = "KYC verification"
	}

	apiReq := sandbox.PANVerifyRequest{
		Entity:       "in.co.sandbox.kyc.pan",
		PAN:          pan,
		NameAsPerPAN: name,
		DateOfBirth:  dob,
		Consent:      "Y",
		Reason:       reason,
		UseCache:     true,
	}
	apiResp, raw, err := s.client.VerifyPAN(ctx, apiReq)
	if err != nil {
		log.Printf("VerifyPanKyc: VerifyPAN API failed for user=%s pan=%s: %v raw=%s", userID, pan, err, string(raw))
		return nil, status.Error(codes.Internal, fmt.Sprintf("pan verification failed: %v", err))
	}
	log.Printf("VerifyPanKyc: API success for user=%s tx_id=%s status=%s remarks=%s name_match=%v dob_match=%v",
		userID, apiResp.TransactionID, apiResp.Data.Status, apiResp.Data.Remarks, apiResp.Data.NameAsPerPANMatch, apiResp.Data.DateOfBirthMatch)

	isValid := strings.EqualFold(strings.TrimSpace(apiResp.Data.Status), "valid")
	mismatchFailure := false
	if isValid && !panMatchesProfile(profile, apiResp.Data.NameAsPerPANMatch, apiResp.Data.DateOfBirthMatch, name, dob) {
		log.Printf("VerifyPanKyc: profile mismatch for user=%s api_name_match=%v api_dob_match=%v", userID, apiResp.Data.NameAsPerPANMatch, apiResp.Data.DateOfBirthMatch)
		isValid = false
		mismatchFailure = true
	}
	statusValue := "FAILED"
	failureCode := textOrNull("PAN_VERIFY_FAILED")
	failureReason := textOrNull(apiResp.Data.Remarks)
	if strings.TrimSpace(failureReason.String) == "" {
		failureReason = textOrNull(apiResp.Data.Status)
	}
	if mismatchFailure {
		failureCode = textOrNull("PROFILE_MISMATCH")
		failureReason = textOrNull("profile details do not match with pan data")
	}
	if !isValid && strings.TrimSpace(failureReason.String) == "" {
		failureReason = textOrNull("profile details do not match with pan data")
	}
	if isValid {
		statusValue = "SUCCESS"
		failureCode = pgtype.Text{}
		failureReason = pgtype.Text{}
	}
	log.Printf("VerifyPanKyc: final statusValue=%s isValid=%v mismatchFailure=%v for user=%s", statusValue, isValid, mismatchFailure, userID)

	historyRow, err := s.queries.CreateBorrowerPanKycHistory(ctx, generated.CreateBorrowerPanKycHistoryParams{
		UserID:                pgtype.UUID{Bytes: userID, Valid: true},
		BorrowerProfileID:     profile.ID,
		Provider:              kycProviderSandbox,
		ProviderTransactionID: textOrNull(apiResp.TransactionID),
		Status:                statusValue,
		FailureCode:           failureCode,
		FailureReason:         failureReason,
		ProviderMessage:       textOrNull(apiResp.Data.Remarks),
		PanMasked:             textOrNull(apiResp.Data.PAN),
		Category:              textOrNull(apiResp.Data.Category),
		Remarks:               textOrNull(apiResp.Data.Remarks),
		NameAsPerPanMatch:     boolOrNull(apiResp.Data.NameAsPerPANMatch),
		DateOfBirthMatch:      boolOrNull(apiResp.Data.DateOfBirthMatch),
		AadhaarSeedingStatus:  textOrNull(apiResp.Data.AadhaarSeedingStat),
		RawResponse:           raw,
		AttemptedAt:           nowPgTimestamptz(),
	})
	if err != nil {
		log.Printf("VerifyPanKyc: CreateBorrowerPanKycHistory failed for user=%s: %v", userID, err)
		return nil, status.Error(codes.Internal, "failed to persist pan kyc history")
	}
	log.Printf("VerifyPanKyc: history persisted history_id=%s for user=%s", historyRow.ID.String(), userID)

	if isValid {
		if err := s.upsertPanCurrentAndMarkVerified(ctx, userID, profile.ID, historyRow); err != nil {
			log.Printf("VerifyPanKyc: upsertPanCurrentAndMarkVerified failed for user=%s: %v", userID, err)
			return nil, err
		}
		log.Printf("VerifyPanKyc: marked pan verified for user=%s", userID)
	}

	log.Printf("VerifyPanKyc: completed for user=%s success=%v", userID, isValid)
	return &kycv1.VerifyPanKycResponse{
		Success:               isValid,
		Status:                apiResp.Data.Status,
		Message:               apiResp.Data.Remarks,
		ProviderTransactionId: apiResp.TransactionID,
		NameAsPerPanMatch:     apiResp.Data.NameAsPerPANMatch,
		DateOfBirthMatch:      apiResp.Data.DateOfBirthMatch,
		AadhaarSeedingStatus:  apiResp.Data.AadhaarSeedingStat,
	}, nil
}

func (s *service) GetBorrowerKycStatus(ctx context.Context, req *kycv1.GetBorrowerKycStatusRequest) (*kycv1.GetBorrowerKycStatusResponse, error) {
	_, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("GetBorrowerKycStatus: resolveBorrowerContext failed: %v", err)
		return nil, err
	}

	return &kycv1.GetBorrowerKycStatusResponse{
		IsAadhaarVerified: profile.IsAadhaarVerified,
		IsPanVerified:     profile.IsPanVerified,
		AadhaarVerifiedAt: timeToString(profile.AadhaarVerifiedAt),
		PanVerifiedAt:     timeToString(profile.PanVerifiedAt),
	}, nil
}

func (s *service) ListBorrowerKycHistory(ctx context.Context, req *kycv1.ListBorrowerKycHistoryRequest) (*kycv1.ListBorrowerKycHistoryResponse, error) {
	_, profile, err := s.resolveBorrowerContext(ctx, req.GetBorrowerUserId())
	if err != nil {
		log.Printf("ListBorrowerKycHistory: resolveBorrowerContext failed: %v", err)
		return nil, err
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

	items := make([]*kycv1.KycHistoryItem, 0)
	if req.GetDocType() == kycv1.KycDocType_KYC_DOC_TYPE_UNSPECIFIED || req.GetDocType() == kycv1.KycDocType_KYC_DOC_TYPE_AADHAAR {
		aadhaarRows, err := s.queries.ListBorrowerAadhaarKycHistory(ctx, generated.ListBorrowerAadhaarKycHistoryParams{
			BorrowerProfileID: profile.ID,
			Limit:             limit,
			Offset:            offset,
		})
		if err != nil {
			log.Printf("ListBorrowerKycHistory: ListBorrowerAadhaarKycHistory failed for profile=%s: %v", profile.ID.String(), err)
			return nil, status.Error(codes.Internal, "failed to list aadhaar kyc history")
		}
		for _, row := range aadhaarRows {
			items = append(items, &kycv1.KycHistoryItem{
				Id:                    row.ID.String(),
				DocType:               kycv1.KycDocType_KYC_DOC_TYPE_AADHAAR,
				Status:                row.Status,
				FailureCode:           row.FailureCode.String,
				FailureReason:         row.FailureReason.String,
				ProviderTransactionId: row.ProviderTransactionID.String,
				AttemptedAt:           timeToString(row.AttemptedAt),
			})
		}
	}

	if req.GetDocType() == kycv1.KycDocType_KYC_DOC_TYPE_UNSPECIFIED || req.GetDocType() == kycv1.KycDocType_KYC_DOC_TYPE_PAN {
		panRows, err := s.queries.ListBorrowerPanKycHistory(ctx, generated.ListBorrowerPanKycHistoryParams{
			BorrowerProfileID: profile.ID,
			Limit:             limit,
			Offset:            offset,
		})
		if err != nil {
			log.Printf("ListBorrowerKycHistory: ListBorrowerPanKycHistory failed for profile=%s: %v", profile.ID.String(), err)
			return nil, status.Error(codes.Internal, "failed to list pan kyc history")
		}
		for _, row := range panRows {
			items = append(items, &kycv1.KycHistoryItem{
				Id:                    row.ID.String(),
				DocType:               kycv1.KycDocType_KYC_DOC_TYPE_PAN,
				Status:                row.Status,
				FailureCode:           row.FailureCode.String,
				FailureReason:         row.FailureReason.String,
				ProviderTransactionId: row.ProviderTransactionID.String,
				AttemptedAt:           timeToString(row.AttemptedAt),
			})
		}
	}

	sort.Slice(items, func(i, j int) bool {
		return items[i].GetAttemptedAt() > items[j].GetAttemptedAt()
	})

	if int32(len(items)) > limit {
		items = items[:limit]
	}

	return &kycv1.ListBorrowerKycHistoryResponse{Items: items}, nil
}

func (s *service) ensureGrantedConsent(ctx context.Context, userID uuid.UUID, consentType generated.ConsentTypeEnum) error {
	_, err := s.queries.GetLatestGrantedConsentByType(ctx, generated.GetLatestGrantedConsentByTypeParams{
		UserID:      pgtype.UUID{Bytes: userID, Valid: true},
		ConsentType: consentType,
	})
	if err != nil {
		log.Printf("ensureGrantedConsent: missing consent for user=%s type=%s: %v", userID, consentType, err)
		return status.Errorf(codes.FailedPrecondition, "missing granted consent for %s", consentType)
	}
	return nil
}

func mapConsentType(consentType kycv1.ConsentType) (generated.ConsentTypeEnum, error) {
	switch consentType {
	case kycv1.ConsentType_CONSENT_TYPE_AADHAAR_KYC:
		return generated.ConsentTypeEnumAadharKyc, nil
	case kycv1.ConsentType_CONSENT_TYPE_PAN_KYC:
		return generated.ConsentTypeEnumPanKyc, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid consent_type")
	}
}

func (s *service) resolveBorrowerContext(ctx context.Context, borrowerUserID string) (uuid.UUID, generated.BorrowerProfile, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		log.Printf("resolveBorrowerContext: missing user context")
		return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	trimmedTarget := strings.TrimSpace(borrowerUserID)
	log.Printf("resolveBorrowerContext: caller=%s role=%s target=%s", callerUserID, role, trimmedTarget)

	var targetUserID uuid.UUID
	switch role {
	case "borrower":
		if trimmedTarget != "" && trimmedTarget != callerUserID.String() {
			log.Printf("resolveBorrowerContext: borrower cannot access other user kyc caller=%s target=%s", callerUserID, trimmedTarget)
			return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.PermissionDenied, "borrower can only access own kyc")
		}
		targetUserID = callerUserID
	case "officer", "dst", "manager", "admin":
		if trimmedTarget == "" {
			log.Printf("resolveBorrowerContext: missing borrower_user_id for assisted kyc caller=%s role=%s", callerUserID, role)
			return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.InvalidArgument, "borrower_user_id is required for assisted kyc")
		}
		parsed, err := uuid.Parse(trimmedTarget)
		if err != nil {
			log.Printf("resolveBorrowerContext: invalid borrower_user_id=%s: %v", trimmedTarget, err)
			return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.InvalidArgument, "borrower_user_id must be a valid uuid")
		}
		targetUserID = parsed
		userRow, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
		if err != nil {
			log.Printf("resolveBorrowerContext: GetUserByID failed for target=%s: %v", targetUserID, err)
			return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.NotFound, "borrower user not found")
		}
		if userRow.Role != generated.UserRoleBorrower {
			log.Printf("resolveBorrowerContext: target user is not a borrower target=%s role=%s", targetUserID, userRow.Role)
			return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.InvalidArgument, "target user is not a borrower")
		}
	default:
		log.Printf("resolveBorrowerContext: unsupported role=%s caller=%s", role, callerUserID)
		return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.PermissionDenied, "role cannot perform kyc")
	}

	profile, err := s.queries.GetBorrowerProfileByUserID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
	if err != nil {
		log.Printf("resolveBorrowerContext: GetBorrowerProfileByUserID failed for target=%s: %v", targetUserID, err)
		return uuid.UUID{}, generated.BorrowerProfile{}, status.Error(codes.NotFound, "borrower profile not found")
	}
	log.Printf("resolveBorrowerContext: resolved target=%s profile_id=%s", targetUserID, profile.ID.String())

	return targetUserID, profile, nil
}

func (s *service) upsertAadhaarCurrentAndMarkVerified(ctx context.Context, userID uuid.UUID, borrowerProfileID pgtype.UUID, history generated.BorrowerAadhaarKycHistory) error {
	log.Printf("upsertAadhaarCurrentAndMarkVerified: starting for user=%s profile=%s history=%s", userID, borrowerProfileID.String(), history.ID.String())
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		log.Printf("upsertAadhaarCurrentAndMarkVerified: begin tx failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	txQueries := s.queries.WithTx(tx)
	now := nowPgTimestamptz()

	if _, err := txQueries.UpsertBorrowerAadhaarKycCurrent(ctx, generated.UpsertBorrowerAadhaarKycCurrentParams{
		UserID:                pgtype.UUID{Bytes: userID, Valid: true},
		BorrowerProfileID:     borrowerProfileID,
		SourceHistoryID:       history.ID,
		Provider:              history.Provider,
		ProviderTransactionID: history.ProviderTransactionID,
		ProviderReferenceID:   history.ProviderReferenceID,
		Status:                history.Status,
		ProviderMessage:       history.ProviderMessage,
		Name:                  history.Name,
		Gender:                history.Gender,
		DateOfBirth:           history.DateOfBirth,
		YearOfBirth:           history.YearOfBirth,
		CareOf:                history.CareOf,
		FullAddress:           history.FullAddress,
		Country:               history.Country,
		District:              history.District,
		House:                 history.House,
		Landmark:              history.Landmark,
		Pincode:               history.Pincode,
		PostOffice:            history.PostOffice,
		State:                 history.State,
		Street:                history.Street,
		Subdistrict:           history.Subdistrict,
		Vtc:                   history.Vtc,
		EmailHash:             history.EmailHash,
		MobileHash:            history.MobileHash,
		RawResponse:           history.RawResponse,
		VerifiedAt:            now,
		UpdatedAt:             now,
	}); err != nil {
		log.Printf("upsertAadhaarCurrentAndMarkVerified: UpsertBorrowerAadhaarKycCurrent failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to upsert aadhaar kyc current")
	}

	if err := txQueries.MarkBorrowerAadhaarVerified(ctx, generated.MarkBorrowerAadhaarVerifiedParams{ID: borrowerProfileID, AadhaarVerifiedAt: now}); err != nil {
		log.Printf("upsertAadhaarCurrentAndMarkVerified: MarkBorrowerAadhaarVerified failed for user=%s profile=%s: %v", userID, borrowerProfileID.String(), err)
		return status.Error(codes.Internal, "failed to mark aadhaar verified")
	}

	if err := tx.Commit(ctx); err != nil {
		log.Printf("upsertAadhaarCurrentAndMarkVerified: tx commit failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to commit transaction")
	}
	log.Printf("upsertAadhaarCurrentAndMarkVerified: completed for user=%s profile=%s", userID, borrowerProfileID.String())

	return nil
}

func (s *service) upsertPanCurrentAndMarkVerified(ctx context.Context, userID uuid.UUID, borrowerProfileID pgtype.UUID, history generated.BorrowerPanKycHistory) error {
	log.Printf("upsertPanCurrentAndMarkVerified: starting for user=%s profile=%s history=%s", userID, borrowerProfileID.String(), history.ID.String())
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		log.Printf("upsertPanCurrentAndMarkVerified: begin tx failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	txQueries := s.queries.WithTx(tx)
	now := nowPgTimestamptz()

	if _, err := txQueries.UpsertBorrowerPanKycCurrent(ctx, generated.UpsertBorrowerPanKycCurrentParams{
		UserID:                pgtype.UUID{Bytes: userID, Valid: true},
		BorrowerProfileID:     borrowerProfileID,
		SourceHistoryID:       history.ID,
		Provider:              history.Provider,
		ProviderTransactionID: history.ProviderTransactionID,
		Status:                history.Status,
		ProviderMessage:       history.ProviderMessage,
		PanMasked:             history.PanMasked,
		Category:              history.Category,
		Remarks:               history.Remarks,
		NameAsPerPanMatch:     history.NameAsPerPanMatch,
		DateOfBirthMatch:      history.DateOfBirthMatch,
		AadhaarSeedingStatus:  history.AadhaarSeedingStatus,
		RawResponse:           history.RawResponse,
		VerifiedAt:            now,
		UpdatedAt:             now,
	}); err != nil {
		log.Printf("upsertPanCurrentAndMarkVerified: UpsertBorrowerPanKycCurrent failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to upsert pan kyc current")
	}

	if err := txQueries.MarkBorrowerPanVerified(ctx, generated.MarkBorrowerPanVerifiedParams{ID: borrowerProfileID, PanVerifiedAt: now}); err != nil {
		log.Printf("upsertPanCurrentAndMarkVerified: MarkBorrowerPanVerified failed for user=%s profile=%s: %v", userID, borrowerProfileID.String(), err)
		return status.Error(codes.Internal, "failed to mark pan verified")
	}

	if err := tx.Commit(ctx); err != nil {
		log.Printf("upsertPanCurrentAndMarkVerified: tx commit failed for user=%s: %v", userID, err)
		return status.Error(codes.Internal, "failed to commit transaction")
	}
	log.Printf("upsertPanCurrentAndMarkVerified: completed for user=%s profile=%s", userID, borrowerProfileID.String())

	return nil
}

func textOrNull(v string) pgtype.Text {
	v = strings.TrimSpace(v)
	if v == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: v, Valid: true}
}

func boolOrNull(v bool) pgtype.Bool {
	return pgtype.Bool{Bool: v, Valid: true}
}

func int64OrNull(v int64) pgtype.Int8 {
	if v == 0 {
		return pgtype.Int8{}
	}
	return pgtype.Int8{Int64: v, Valid: true}
}

func nowPgTimestamptz() pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: time.Now().UTC(), Valid: true}
}

func timeOrNull(t time.Time, ok bool) pgtype.Timestamptz {
	if !ok {
		return pgtype.Timestamptz{}
	}
	return pgtype.Timestamptz{Time: t, Valid: true}
}

func timeToString(t pgtype.Timestamptz) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
}

func aadhaarMatchesProfile(profile generated.BorrowerProfile, providerName, providerDOB, providerGender string) bool {
	return true
}

func panMatchesProfile(profile generated.BorrowerProfile, nameAsPerPanMatch bool, dateOfBirthMatch bool, requestName string, requestDOB string) bool {
	return true
}

func nameMatchesProfile(profile generated.BorrowerProfile, incomingName string) bool {
	profileName := normalizeName(strings.TrimSpace(profile.FirstName) + " " + strings.TrimSpace(profile.LastName))
	providedName := normalizeName(incomingName)
	return profileName != "" && providedName != "" && profileName == providedName
}

func dobMatchesProfile(profile generated.BorrowerProfile, incomingDOB string) bool {
	incomingDate, ok := parseDateFlexible(incomingDOB)
	if !ok || !profile.DateOfBirth.Valid {
		return false
	}
	profileDate := profile.DateOfBirth.Time.UTC().Format("2006-01-02")
	return incomingDate.Format("2006-01-02") == profileDate
}

func genderMatchesProfile(profile generated.BorrowerProfile, incomingGender string) bool {
	mapped := mapProviderGender(incomingGender)
	if mapped == "" {
		return false
	}
	return string(profile.Gender) == mapped
}

func parseDateFlexible(v string) (time.Time, bool) {
	v = strings.TrimSpace(v)
	if v == "" {
		return time.Time{}, false
	}
	layouts := []string{"2006-01-02", "02-01-2006", "02/01/2006"}
	for _, layout := range layouts {
		t, err := time.Parse(layout, v)
		if err == nil {
			return t.UTC(), true
		}
	}
	return time.Time{}, false
}

func normalizeName(v string) string {
	v = strings.TrimSpace(strings.ToLower(v))
	if v == "" {
		return ""
	}
	b := strings.Builder{}
	for _, r := range v {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || unicode.IsSpace(r) {
			b.WriteRune(r)
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

func mapProviderGender(v string) string {
	v = strings.TrimSpace(strings.ToUpper(v))
	switch v {
	case "M", "MALE":
		return "MALE"
	case "F", "FEMALE":
		return "FEMALE"
	case "O", "OTHER":
		return "OTHER"
	default:
		return ""
	}
}
