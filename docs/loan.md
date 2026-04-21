# Loan API Guide (Frontend)

This document explains `loan.v1.LoanService` APIs for product setup, application lifecycle, underwriting artifacts, and loan ledger operations.

## Service

- gRPC service: `loan.v1.LoanService`

## Product Configuration (Admin)

- `CreateLoanProduct`
- `UpdateLoanProduct`
- `DeleteLoanProduct` (soft delete via `is_deleted=true`)
- `UpsertProductEligibilityRule`
- `ReplaceProductFees`
- `ReplaceProductRequiredDocuments`

Read operations:

- `GetLoanProduct`
- `ListLoanProducts`

## Application Flow

- Create application: `CreateLoanApplication`
- Fetch application with related entities: `GetLoanApplication`
- List applications: `ListLoanApplications`
- Update status/escalation: `UpdateLoanApplicationStatus`
- Assign officer: `AssignLoanApplicationOfficer`
- Add coapplicant: `AddApplicationCoapplicant`
- Upsert collateral base: `UpsertApplicationCollateral`
- Upsert vehicle details: `UpsertLoanVehicle`
- Upsert real-estate details: `UpsertLoanRealEstate`
- Add/upload document metadata: `AddApplicationDocument`
- Update document verification: `UpdateApplicationDocumentVerification`
- Add bureau score snapshot: `AddBureauScore`

## Loan & Repayments

- Create loan ledger entry (post approval): `CreateLoan`
- Fetch loan by `loan_id` or `application_id`: `GetLoan`
- Add EMI schedule row: `AddEmiScheduleItem`
- List EMI schedule: `ListEmiSchedule`
- Record payment: `RecordPayment`
- List payments: `ListPayments`

## Application Source Tracking

`loan_applications` stores:

- `created_by_user_id`
- `created_by_role`
- `created_by_channel` (`SELF`, `DST`, `OFFICER`)

This identifies whether the application was initiated by borrower self-serve, DST, or officer.

## Product Snapshot

- `loan_applications.product_snapshot_json` stores a JSON snapshot of key product terms at creation time.
- This protects application records from future product edits.

## Document Linkage

- `application_documents` uses `media_file_id` (FK to `media_files.id`) instead of raw file URL storage.
- `AddApplicationDocument` validates that the media file exists and belongs to the borrower profile's user.

## Current RBAC Snapshot

- Product mutations: `admin`
- Application create: `borrower`, `dst`, `officer`
- Branch/portfolio operations: role-scoped for `dst`/`officer`/`manager`
- Cross-branch access and full control: `admin`
