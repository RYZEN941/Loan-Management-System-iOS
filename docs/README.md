# Frontend API Docs

This folder contains frontend-focused integration docs for the gRPC backend.

## Start Here

- `docs/api-conventions.md` - auth headers, token handling, error handling, and common request rules.
- `docs/auth.md` - all auth APIs with exact call order for signup, login, MFA, password change, refresh, and logout.
- `docs/onboarding.md` - borrower onboarding API and when to call it in the app lifecycle.

## Current Service Endpoints

- Auth service: `auth.v1.AuthService`
- Onboarding service: `onboarding.v1.OnboardingService`

## Local Dev Default (current compose)

- gRPC host: `localhost:18080`
- Postgres host port: `15432`
- Redis host port: `16379`
