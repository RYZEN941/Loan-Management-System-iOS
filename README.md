# LMS Monorepo

This repository contains the backend API, protobuf contracts, and client/sdk code for the LMS project.

The main runnable service today is `core-api` (Go + gRPC), backed by Postgres and Redis.

## Monorepo Layout

```text
lms-monorepo/
├── apps/
│   └── borrower_client/             # iOS app workspace (early stage)
├── proto/
│   ├── auth/v1/auth.proto           # Auth service contract
│   └── loan/v1/loan.proto           # Loan service contract (stub)
├── services/
│   └── core-api/                    # Go backend (main service)
├── sdk/
│   └── swift/                       # Swift SDK workspace/artifacts
├── docker-compose.yml               # Local infra + core-api
├── Makefile                         # Helper commands (proto, sqlc, docker)
└── go.work                          # Go workspace (currently includes core-api)
```

## Architecture At A Glance

- Transport: gRPC (`AuthService`) using protobuf definitions from `proto/`
- Backend: Go service in `services/core-api`
- Data layer:
  - Postgres for users, refresh tokens, webauthn credentials
  - Redis for OTP/MFA/session state
- Auth model:
  - Password (Argon2)
  - OTP verification for signup
  - TOTP for MFA
  - JWT access token + refresh token rotation
  - WebAuthn scaffolding (partially implemented)

## Quick Start (Recommended: Docker)

### Prerequisites

- Docker Desktop / Docker Engine with Compose v2

### Run everything

From repo root:

```bash
docker compose up --build
```

or:

```bash
make docker-up
```

What starts:

- `postgres` on `localhost:5432`
- `redis` on `localhost:6379`
- `core-api` gRPC server on `localhost:8080`

### Database initialization

On first startup of the Postgres volume, schema is auto-loaded from:

- `services/core-api/internal/repository/schema/001_auth.sql`

If you already have an existing Postgres Docker volume and need a clean re-init:

```bash
docker compose down -v
docker compose up --build
```

## Quick Start (Local Go Service)

If you want to run API directly on your host and keep infra in Docker:

1. Start infra only (Postgres + Redis):

```bash
docker compose up -d postgres redis
```

2. Run backend:

```bash
cd services/core-api
go run .
```

Default config (if env vars are not set) is defined in `services/core-api/internal/config/config.go`.

Useful env vars:

- `GRPC_PORT` (default: `8080`)
- `POSTGRES_DSN` (default points to local postgres)
- `REDIS_ADDR` (default: `localhost:6379`)
- `REDIS_PASSWORD` (optional)
- `JWT_SIGNING_KEY` (default dev key; change for non-local use)

## Tooling & Code Generation

### 1) Protobuf to Go

Generates gRPC/Go types into `services/core-api/internal/transport/grpc/generated/*`.

```bash
make proto
```

Inputs:

- `proto/auth/v1/auth.proto`
- `proto/loan/v1/loan.proto`

### 2) SQL to Go (sqlc)

Generates typed query code into `services/core-api/internal/repository/generated/`.

```bash
make sqlc
```

Inputs:

- Schema: `services/core-api/internal/repository/schema/`
- Queries: `services/core-api/internal/repository/queries/`

Config file:

- `services/core-api/sqlc.yaml`

### 3) Basic Go validation

```bash
cd services/core-api
go test ./...
go build ./...
```

## How To Read The Codebase

If you are new to this repo, read in this order:

1. Contracts first
   - `proto/auth/v1/auth.proto`
2. Server entrypoint + wiring
   - `services/core-api/main.go`
   - `services/core-api/cmd/server/run.go`
3. Transport layer
   - `services/core-api/internal/transport/grpc/auth_handler.go`
   - `services/core-api/internal/transport/grpc/interceptors/auth.go`
4. Business logic
   - `services/core-api/internal/service/auth/service.go`
5. Persistence
   - `services/core-api/internal/repository/queries/*.sql`
   - `services/core-api/internal/repository/generated/*.go`
6. Infra/config utilities
   - `services/core-api/internal/db/*.go`
   - `services/core-api/internal/config/config.go`

## Backend Request Flow (Auth)

Typical call path:

1. gRPC method defined in proto
2. Handler receives request (`auth_handler.go`)
3. JWT/RBAC interceptors run (for protected methods)
4. Auth service executes business logic (`service.go`)
5. SQLC-generated repository methods read/write Postgres
6. Redis stores short-lived auth state (OTP/MFA/active token)

## gRPC API Surface (Current)

Defined in `proto/auth/v1/auth.proto`:

- Health/demo: `Hello`
- Signup: `InitiateSignup`, `VerifySignupOTPs`
- MFA setup/login: `SetupTOTP`, `VerifyTOTPSetup`, `LoginPrimary`, `SelectLoginMFAFactor`, `VerifyLoginMFA`
- Session/token: `RefreshToken`, `Logout`
- WebAuthn: begin/finish registration and login methods exist, but finish flows are not fully implemented yet

### Signup role enum

`SignupRequest.role` is a protobuf enum (`UserRole`), not a free-form string.

Allowed values:

- `USER_ROLE_ADMIN`
- `USER_ROLE_MANAGER`
- `USER_ROLE_OFFICER`
- `USER_ROLE_BORROWER`

Sample signup payload:

```json
{
  "email": "borrower@example.com",
  "phone": "+15550001111",
  "password": "StrongPassword123!",
  "role": "USER_ROLE_BORROWER"
}
```

### Login flow sequence

Current login requires explicit MFA factor selection:

1. `LoginPrimary`
2. `SelectLoginMFAFactor`
3. `VerifyLoginMFA`

`VerifyLoginMFA` without `SelectLoginMFAFactor` returns a failed precondition error.

## Troubleshooting

- `failed to connect to postgres`: verify Postgres is running and DSN is correct.
- `failed to connect to redis`: Redis is required at startup; check `REDIS_ADDR` and container health.
- Auth tables missing: if schema did not initialize, recreate Postgres volume (`docker compose down -v`).
- Generated code out of sync: rerun `make proto` and/or `make sqlc`.

## Current Gaps / Notes

- WebAuthn finish flows are still incomplete.
- OTP values are currently printed for local debugging.
- Loan service contract exists but implementation is currently a stub.

## Handy Commands

From repo root:

```bash
make docker-up
make docker-down
make proto
make sqlc
```
