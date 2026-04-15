-- name: GetUserByEmailOrPhone :one
SELECT * FROM users 
WHERE (email = $1 OR phone = $1)
  AND is_deleted = false
LIMIT 1;

-- name: UpdateUserVerification :exec
UPDATE users 
SET is_email_verified = $2, is_phone_verified = $3, is_active = $4
WHERE id = $1;

-- name: SetTOTPSecret :exec
UPDATE users 
SET totp_secret = $2, has_totp = $3
WHERE id = $1;

-- name: GetRefreshTokenByHashedToken :one
SELECT * FROM refresh_tokens 
WHERE hashed_token = $1 AND is_revoked = false AND expires_at > NOW() 
LIMIT 1;

-- name: RevokeRefreshTokensForUserDevice :exec
UPDATE refresh_tokens 
SET is_revoked = true 
WHERE user_id = $1 AND device_id = $2;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens 
SET is_revoked = true 
WHERE hashed_token = $1;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (
    user_id, device_id, hashed_token, expires_at
) VALUES (
    $1, $2, $3, $4
) RETURNING *;

-- name: CreateUser :one
INSERT INTO users (
    email, phone, password_hash, role
) VALUES (
    $1, $2, $3, $4
) RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1 AND is_deleted = false LIMIT 1;
