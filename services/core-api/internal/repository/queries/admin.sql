-- name: CreateEmployeeUser :one
INSERT INTO users (
    email,
    phone,
    password_hash,
    role,
    is_email_verified,
    is_phone_verified,
    is_active,
    is_requiring_password_change
) VALUES (
    $1,
    $2,
    $3,
    $4,
    true,
    true,
    true,
    true
) RETURNING *;

-- name: CreateManagerProfile :one
INSERT INTO manager_profiles (
    user_id,
    name
) VALUES (
    $1,
    $2
) RETURNING *;

-- name: CreateOfficerProfile :one
INSERT INTO officer_profiles (
    user_id,
    name
) VALUES (
    $1,
    $2
) RETURNING *;

-- name: GetManagerProfileByID :one
SELECT * FROM manager_profiles WHERE id = $1 LIMIT 1;

-- name: CreateBankBranch :one
INSERT INTO bank_branches (
    name,
    region,
    city,
    manager_id
) VALUES (
    $1,
    $2,
    $3,
    $4
) RETURNING *;

-- name: GetBankBranchByID :one
SELECT * FROM bank_branches WHERE id = $1 LIMIT 1;

-- name: UpdateBankBranch :exec
UPDATE bank_branches
SET name = $2,
    region = $3,
    city = $4,
    manager_id = $5
WHERE id = $1;

-- name: UpdateEmployeeEmailAndPhone :exec
UPDATE users
SET email = $2,
    phone = $3
WHERE id = $1
  AND is_deleted = false;

-- name: UpdateEmployeePasswordByAdmin :exec
UPDATE users
SET password_hash = $2,
    is_requiring_password_change = true
WHERE id = $1
  AND is_deleted = false;
