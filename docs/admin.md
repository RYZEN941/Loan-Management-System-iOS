# Admin API Guide (Frontend)

This document explains admin-only APIs for employee and branch management.

## Service

- gRPC service: `admin.v1.AdminService`

## Bootstrap Admin (Setup Only)

RPC: `CreateAdminAccount`

This endpoint is intended only for bootstrapping the first admin user.

- By default, the server currently exposes this method as public via `publicMethods` in `services/core-api/cmd/server/run.go`.
- For production, comment out the `"/admin.v1.AdminService/CreateAdminAccount"` line in `publicMethods` to disable unauthenticated bootstrap.

Request fields:

- `email`
- `phone_number`
- `password`

Response:

- `success`
- `user_id`
- `profile_id`

Example payload:

```json
{
  "email": "admin@bank.com",
  "phone_number": "+919900000000",
  "password": "StrongAdmin123!"
}
```

## Authentication and Role

- JWT required in metadata:
  - `authorization: Bearer <ACCESS_TOKEN>`
- Only `admin` role is allowed for methods in this service.

## 1) Create Employee Account

RPC: `CreateEmployeeAccount`

Purpose:

- Create manager/officer user accounts (no signup flow for employees).
- Automatically creates matching profile row in:
  - `manager_profiles` (if manager), or
  - `officer_profiles` (if officer).

Request fields:

- `name` (string)
- `email` (string)
- `phone_number` (string)
- `password` (string)
- `employee_type` (enum)
  - `EMPLOYEE_TYPE_MANAGER`
  - `EMPLOYEE_TYPE_OFFICER`
- `branch_id` (optional UUID)

Backend behavior:

- employee user is created as active and verified.
- `is_requiring_password_change` is set to `true`.
- if `branch_id` is provided, it is attached to manager/officer profile.
- duplicate email/phone returns `AlreadyExists`.

Response:

- `success`
- `user_id`
- `profile_id` (id from manager/officer profile table)

Example payload:

```json
{
  "name": "Riya Sharma",
  "email": "riya.manager@bank.com",
  "phone_number": "+919900001111",
  "password": "TempPass123!",
  "employee_type": "EMPLOYEE_TYPE_MANAGER",
  "branch_id": "527c4c88-7f16-42e7-bb38-5ed19a5d1517"
}
```

## 2) Create Bank Branch

RPC: `CreateBankBranch`

Purpose:

- Create a bank branch.

Request fields:

- `name` (string)
- `region` (string)
- `city` (string)
- `manager_id` (optional UUID, must be `manager_profiles.id`)

`manager_id` is no longer part of branch creation.

Behavior:

- if `manager_id` is provided, backend validates it exists in `manager_profiles`.
- branch is created independently; managers/officers are linked by assigning `branch_id` on profile tables.

Response:

- `success`
- `branch_id`

Example payload (without manager):

```json
{
  "name": "MG Road Branch",
  "region": "South",
  "city": "Bengaluru"
}
```

Example payload (with manager):

```json
{
  "name": "MG Road Branch",
  "region": "South",
  "city": "Bengaluru",
  "manager_id": "a4d1f2e2-9d8a-4c31-b2db-d9e21d8f2d11"
}
```

## 3) Update Bank Branch

RPC: `UpdateBankBranch`

Purpose:

- Update branch details (`name`, `region`, `city`).

Request fields:

- `branch_id` (required UUID)
- `name` (optional)
- `region` (optional)
- `city` (optional)

Behavior:

- Empty optional fields keep existing values.

Manager assignment is handled through `AssignEmployeeBranch`.

Response:

- `success`

Example payload:

```json
{
  "branch_id": "527c4c88-7f16-42e7-bb38-5ed19a5d1517",
  "name": "MG Road Main Branch",
  "region": "South Zone",
  "city": "Bengaluru"
}
```

## 4) Update Employee Account

RPC: `UpdateEmployeeAccount`

Purpose:

- Update manager/officer user contact fields and optionally reset password.

Request fields:

- `user_id` (required UUID)
- `email` (optional)
- `phone_number` (optional)
- `new_password` (optional)

Behavior:

- Only users with role `manager` or `officer` can be updated.
- Empty optional contact fields keep existing values.
- If `new_password` is provided:
  - password strength rules are enforced,
  - password is updated,
  - `is_requiring_password_change` is forced to `true`.

Response:

- `success`

Example payload:

```json
{
  "user_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "email": "new.email@bank.com",
  "phone_number": "+919911112222",
  "new_password": "TempPass456!"
}
```

## 5) Assign Employee Branch

RPC: `AssignEmployeeBranch`

Purpose:

- Assign or unassign branch for manager/officer users.

Request fields:

- `user_id` (required UUID of manager/officer user)
- `branch_id` (required unless clearing)
- `clear_branch` (optional bool)

Behavior:

- if `clear_branch=true`, employee branch is set to null.
- if assigning, backend validates `branch_id` exists.
- applies to both manager and officer profiles.

Response:

- `success`

Example payload (assign branch):

```json
{
  "user_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "branch_id": "527c4c88-7f16-42e7-bb38-5ed19a5d1517"
}
```

Example payload (clear branch):

```json
{
  "user_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "clear_branch": true
}
```

## Employee First Login Requirement

Employee users are created with `is_requiring_password_change=true`.

Frontend behavior after `LoginPrimary`:

- check `is_requiring_password_change`
- if `true`, route user to mandatory password change screen before normal app usage.
