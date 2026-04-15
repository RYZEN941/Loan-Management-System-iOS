# Auth API Guide (Frontend)

This document explains `auth.v1.AuthService` APIs and the required call order.

## Service

- gRPC service: `auth.v1.AuthService`

## RPC List

- `Hello`
- `InitiateSignup`
- `VerifySignupOTPs`
- `SetupTOTP`
- `VerifyTOTPSetup`
- `LoginPrimary`
- `SelectLoginMFAFactor`
- `VerifyLoginMFA`
- `ChangePassword`
- `BeginWebAuthnRegistration`
- `FinishWebAuthnRegistration`
- `BeginWebAuthnLogin`
- `FinishWebAuthnLogin`
- `RefreshToken`
- `Logout`

## 1) Signup Flow (Required Order)

1. `InitiateSignup`
2. `VerifySignupOTPs`

### 1.1 InitiateSignup

Request fields:

- `email`
- `phone`
- `password`
- `role` (`USER_ROLE_ADMIN|MANAGER|OFFICER|BORROWER`)

Response:

- `registration_id`

Frontend action:

- Move user to OTP verification UI.

### 1.2 VerifySignupOTPs

Request fields:

- `registration_id`
- `email_code`
- `phone_code`

Response:

- `verified` (`true` on success)

Notes:

- User is verified here, but activation may still depend on onboarding rules.

## 2) Login + MFA Flow (Strict Order)

1. `LoginPrimary`
2. `SelectLoginMFAFactor`
3. `VerifyLoginMFA`

If step 2 is skipped, step 3 fails with `FailedPrecondition`.

### 2.1 LoginPrimary

Request:

- `email_or_phone`
- `password`

Response:

- `mfa_session_id`
- `allowed_factors` (subset of: `totp`, `email_otp`, `phone_otp`)
- `is_requiring_password_change`

Frontend action:

- Show factor picker using `allowed_factors`.
- If `is_requiring_password_change=true`, force password-change flow after successful MFA.

### 2.2 SelectLoginMFAFactor

Request:

- `mfa_session_id`
- `factor` (`totp`, `email_otp`, `phone_otp`)

Response:

- `challenge_sent`
- `challenge_target` (masked destination for OTP channels)

Frontend action:

- For OTP factors, show input waiting for code.
- For TOTP, show authenticator code input directly.

### 2.3 VerifyLoginMFA

Request:

- `mfa_session_id`
- `device_id`
- exactly one factor payload:
  - `totp_code`, or
  - `email_otp_code`, or
  - `phone_otp_code`

Response:

- `access_token`
- `refresh_token`

Frontend action:

- Store tokens securely.
- Use `access_token` in authorization metadata for protected calls.

## 3) TOTP Setup Flow (Authenticated)

Use this for enrolling authenticator app MFA after user is logged in.

1. `SetupTOTP`
2. `VerifyTOTPSetup`

### 3.1 SetupTOTP

Auth: required.

Response:

- `secret`
- `provisioning_uri`

Frontend action:

- Render QR from `provisioning_uri`.

### 3.2 VerifyTOTPSetup

Auth: required.

Request:

- `code`
- `device_id`

Response:

- token pair (`access_token`, `refresh_token`)

## 4) Password Change (Authenticated)

RPC: `ChangePassword`

Auth: required.

Request:

- `current_password`
- `new_password`

Backend rules:

- Current password must match.
- New password must be strong:
  - min 8 chars
  - uppercase + lowercase + number + special char
- New password must differ from current password.
- On success, backend sets `is_requiring_password_change = false`.

Response:

- `success`

## 5) Token Refresh

RPC: `RefreshToken`

Auth: not required (uses refresh token).

Request:

- `refresh_token`
- `device_id`

Response:

- new token pair

Frontend action:

- Replace both old tokens atomically.

## 6) Logout (Authenticated)

RPC: `Logout`

Auth: required.

Request:

- `access_token`
- `refresh_token`

Response:

- `success`

Frontend action:

- Clear local auth state regardless of response retries.

## 7) WebAuthn (Current Status)

- Begin methods are present.
- Finish methods are not fully implemented yet in backend business logic.
- Treat WebAuthn as in-progress for production UI.

## Example Sequence (Borrower First Login)

1. Signup: `InitiateSignup` -> `VerifySignupOTPs`
2. Login: `LoginPrimary` -> `SelectLoginMFAFactor` -> `VerifyLoginMFA`
3. Borrower onboarding (other service): `OnboardingService/CompleteBorrowerOnboarding`
4. Optional: setup TOTP post-login
