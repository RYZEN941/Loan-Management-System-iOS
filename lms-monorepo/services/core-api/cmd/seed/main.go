package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// Simple float64 to pgtype.Numeric helper
func floatToNumeric(f float64) pgtype.Numeric {
	num := pgtype.Numeric{}
	num.Scan(fmt.Sprintf("%f", f))
	return num
}

func main() {
	dsn := os.Getenv("POSTGRES_DSN")
	if dsn == "" {
		// Default to the hosted IP provided by the user
		dsn = "postgres://lms:lms@161.118.175.181:15432/lms?sslmode=disable"
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer conn.Close(ctx)

	queries := generated.New(conn)

	fmt.Println("🚀 Starting database seeding...")
	fmt.Printf("📍 Targeting DB at: %s\n", dsn)

	// 1. Wipe database
	fmt.Println("🧹 Wiping existing data...")
	_, err = conn.Exec(ctx, `
		DO $$ 
		DECLARE r RECORD;
		BEGIN
			FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
				EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' RESTART IDENTITY CASCADE';
			END LOOP;
		END $$;
	`)
	if err != nil {
		log.Fatalf("Failed to wipe database: %v", err)
	}

	// Helper to hash passwords
	hash := func(p string) string {
		h, _ := argon2.HashPassword(p, argon2.DefaultConfig())
		return h
	}

	// 2. Create Admin
	fmt.Println("👤 Seeding Admin...")
	adminUser, err := queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        "admin@lms.com",
		Phone:        "+919999999999",
		PasswordHash: hash("Admin@123"),
		Role:         generated.UserRoleAdmin,
	})
	if err != nil {
		log.Fatalf("Failed to create admin: %v", err)
	}

	_ = queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              adminUser.ID,
		IsActive:        pgtype.Bool{Bool: true, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})

	// 3. Create Branch
	fmt.Println("🏢 Seeding Branches...")
	branch, err := queries.CreateBankBranch(ctx, generated.CreateBankBranchParams{
		Name:   "Main Metro Branch",
		Region: "West",
		City:   "Mumbai",
	})
	if err != nil {
		log.Fatalf("Failed to create branch: %v", err)
	}

	// Update commission separately since CreateBankBranch doesn't take it
	_ = queries.UpdateBranchDstCommissionByID(ctx, generated.UpdateBranchDstCommissionByIDParams{
		ID:            branch.ID,
		DstCommission: floatToNumeric(2.50),
	})

	// 4. Create Manager
	fmt.Println("👨‍💼 Seeding Manager...")
	managerUser, _ := queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        "manager@lms.com",
		Phone:        "+918888888888",
		PasswordHash: hash("Manager@123"),
		Role:         generated.UserRoleManager,
	})
	_ = queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              managerUser.ID,
		IsActive:        pgtype.Bool{Bool: true, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})
	_, err = queries.CreateManagerProfile(ctx, generated.CreateManagerProfileParams{
		UserID:   managerUser.ID,
		Name:     "Sarah Johnson",
		BranchID: pgtype.UUID{Bytes: branch.ID.Bytes, Valid: true},
	})
	if err != nil {
		log.Fatalf("Failed to create manager profile: %v", err)
	}

	// 5. Create Officer
	fmt.Println("👮 Seeding Officer...")
	officerUser, _ := queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        "officer@lms.com",
		Phone:        "+917777777777",
		PasswordHash: hash("Officer@123"),
		Role:         generated.UserRoleOfficer,
	})
	_ = queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              officerUser.ID,
		IsActive:        pgtype.Bool{Bool: true, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})
	_, err = queries.CreateOfficerProfile(ctx, generated.CreateOfficerProfileParams{
		UserID:   officerUser.ID,
		Name:     "Officer John",
		BranchID: pgtype.UUID{Bytes: branch.ID.Bytes, Valid: true},
	})
	if err != nil {
		log.Fatalf("Failed to create officer profile: %v", err)
	}

	// 6. Create Loan Products
	fmt.Println("💰 Seeding Loan Products...")
	personalLoan, err := queries.CreateLoanProduct(ctx, generated.CreateLoanProductParams{
		Name:                  "Speedy Personal Loan",
		Category:              generated.LoanProductCategoryPERSONAL,
		InterestType:          generated.LoanInterestTypeFIXED,
		BaseInterestRate:      floatToNumeric(12.00),
		MinAmount:             floatToNumeric(50000),
		MaxAmount:             floatToNumeric(500000),
		IsRequiringCollateral: false,
		IsActive:              true,
	})
	if err != nil {
		log.Fatalf("Failed to create personal loan product: %v", err)
	}

	_, err = queries.CreateLoanProduct(ctx, generated.CreateLoanProductParams{
		Name:                  "Elite Home Loan",
		Category:              generated.LoanProductCategoryHOME,
		InterestType:          generated.LoanInterestTypeFLOATING,
		BaseInterestRate:      floatToNumeric(8.50),
		MinAmount:             floatToNumeric(1000000),
		MaxAmount:             floatToNumeric(50000000),
		IsRequiringCollateral: true,
		IsActive:              true,
	})
	if err != nil {
		log.Fatalf("Failed to create home loan product: %v", err)
	}

	// 7. Create Borrower
	fmt.Println("👤 Seeding Borrower...")
	borrowerUser, _ := queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        "alice@example.com",
		Phone:        "+916666666666",
		PasswordHash: hash("Alice@123"),
		Role:         generated.UserRoleBorrower,
	})
	_ = queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              borrowerUser.ID,
		IsActive:        pgtype.Bool{Bool: true, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})
	borrowerProfile, err := queries.CreateBorrowerProfile(ctx, generated.CreateBorrowerProfileParams{
		UserID:                     borrowerUser.ID,
		FirstName:                  "Alice",
		LastName:                   "Wonderland",
		DateOfBirth:                pgtype.Date{Time: time.Date(1995, 1, 1, 0, 0, 0, 0, time.UTC), Valid: true},
		Gender:                     generated.BorrowerGenderFEMALE,
		AddressLine1:               "123 Wonderland Lane",
		City:                       "Mumbai",
		State:                      "Maharashtra",
		Pincode:                    "400001",
		EmploymentType:             generated.BorrowerEmploymentTypeSALARIED,
		MonthlyIncome:              floatToNumeric(75000.00),
		ProfileCompletenessPercent: 100,
	})
	if err != nil {
		log.Fatalf("Failed to create borrower profile: %v", err)
	}

	// 8. Create a Loan Application
	fmt.Println("📝 Seeding Loan Application...")
	application, err := queries.CreateLoanApplication(ctx, generated.CreateLoanApplicationParams{
		ReferenceNumber:          "LAPP-2026-0001",
		PrimaryBorrowerProfileID: borrowerProfile.ID,
		LoanProductID:            personalLoan.ID,
		BranchID:                 branch.ID,
		RequestedAmount:          floatToNumeric(250000.00),
		TenureMonths:             36,
		OfferedInterestRate:      floatToNumeric(12.00),
		Status:                   generated.LoanApplicationStatusSUBMITTED,
		CreatedByUserID:          borrowerUser.ID,
		CreatedByRole:            generated.UserRoleBorrower,
		CreatedByChannel:         generated.ApplicationCreatedByChannelSELF,
		ProductSnapshotJson:      []byte("{}"),
	})
	if err != nil {
		log.Fatalf("Failed to create loan application: %v", err)
	}

	fmt.Printf("\n✅ Seeding complete!\n")
	fmt.Printf("-----------------------------------\n")
	fmt.Printf("Admin:    admin@lms.com / Admin@123\n")
	fmt.Printf("Manager:  manager@lms.com / Manager@123\n")
	fmt.Printf("Officer:  officer@lms.com / Officer@123\n")
	fmt.Printf("Borrower: alice@example.com / Alice@123\n")
	fmt.Printf("-----------------------------------\n")
	fmt.Printf("Sample Application: %s (Status: SUBMITTED)\n", application.ReferenceNumber)
}
