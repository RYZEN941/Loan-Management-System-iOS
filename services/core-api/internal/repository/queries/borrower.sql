-- name: CreateBorrowerProfile :one
INSERT INTO borrower_profiles (
    user_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    address_line1,
    city,
    state,
    pincode,
    employment_type,
    monthly_income,
    profile_completeness_percent
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12
) RETURNING *;

-- name: GetBorrowerProfileByUserID :one
SELECT * FROM borrower_profiles WHERE user_id = $1 LIMIT 1;

-- name: ActivateUser :exec
UPDATE users
SET is_active = true
WHERE id = $1;
