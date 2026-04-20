# Admin and Manager API Guide (Frontend)

This document explains admin/manager APIs in `admin.v1.AdminService`.

## Authentication and Role

- JWT required in metadata:
  - `authorization: Bearer <ACCESS_TOKEN>`
- Role access summary:
  - `admin`: create employee, create/update branches, update employee account, assign employee branch, update branch commission.
  - `manager`: create DST account, update DST commission for own branch.

## Bootstrap Admin (Setup Only)

RPC: `CreateAdminAccount`

Use only for creating the first admin user.

- This RPC is currently public via `publicMethods` in `services/core-api/cmd/server/run.go`.
- For production, comment out `"/admin.v1.AdminService/CreateAdminAccount"` in `publicMethods`.

Request fields:

- `email`
- `phone_number`
- `password`

Response:

- `success`
- `user_id`
- `profile_id`

## 1) Create Employee Account (Admin)

RPC: `CreateEmployeeAccount`

Creates manager/officer users and corresponding profile rows.

Request fields:

- `name`
- `email`
- `phone_number`
- `password`
- `employee_type` (`EMPLOYEE_TYPE_MANAGER` | `EMPLOYEE_TYPE_OFFICER`)
- `branch_id` (optional)

Behavior:

- creates active+verified user.
- sets `is_requiring_password_change=true`.
- if `branch_id` provided, stores it in profile.

## 2) Create Bank Branch (Admin)

RPC: `CreateBankBranch`

Request fields:

- `name`
- `region`
- `city`

Response:

- `success`
- `branch_id`

## 3) Update Bank Branch (Admin)

RPC: `UpdateBankBranch`

Request fields:

- `branch_id` (required)
- `name` (optional)
- `region` (optional)
- `city` (optional)

Behavior: empty optional fields retain existing values.

## 4) Update Employee Account (Admin)

RPC: `UpdateEmployeeAccount`

Request fields:

- `user_id` (required)
- `email` (optional)
- `phone_number` (optional)
- `new_password` (optional)

Behavior:

- allowed target roles: `manager`, `officer`, `dst`.
- if `new_password` provided, backend enforces strength and sets `is_requiring_password_change=true`.

## 5) Assign Employee Branch (Admin)

RPC: `AssignEmployeeBranch`

Request fields:

- `user_id` (manager/officer)
- `branch_id` (required unless clearing)
- `clear_branch` (optional)

Behavior:

- assign or clear branch for manager/officer profiles.

## 6) Create DST Account (Manager)

RPC: `CreateDstAccount`

Request fields:

- `name`
- `email`
- `phone_number`
- `password`

Behavior:

- caller must be manager.
- manager must have branch assigned.
- DST is created in manager's branch.
- DST user gets `is_requiring_password_change=true`.

Response:

- `success`
- `user_id`
- `profile_id`

## 7) Get DST Account (Admin/Manager)

RPC: `GetDstAccount`

Request fields:

- `user_id` (required DST user UUID)

Response:

- `account`
  - `user_id`, `profile_id`, `name`, `email`, `phone_number`
  - `is_active`, `is_requiring_password_change`
  - `branch_id`, `branch_name`, `branch_region`, `branch_city`
  - `created_at`

Behavior:

- admin can fetch any DST account.
- manager can fetch only DST accounts from their own branch.

## 8) List DST Accounts (Admin/Manager)

RPC: `ListDstAccounts`

Request fields:

- `branch_id` (optional for admin, ignored/validated against manager scope)
- `limit` (optional, default `20`, max `100`)
- `offset` (optional, default `0`)

Response:

- `items[]` of DST account objects (same shape as `GetDstAccountResponse.account`)

Behavior:

- admin can list by any branch.
- manager can list only their own branch.

## 9) Update Branch DST Commission (Admin/Manager)

RPC: `UpdateBranchDstCommission`

Request fields:

- `branch_id` (required UUID)
- `dst_commission` (required decimal string between `0` and `100`)

Behavior:

- admin can update any branch.
- manager can update only their own branch.

Response:

- `success`
