-- name: CreateApplicationRemark :one
INSERT INTO application_remarks (
    application_id,
    sender_user_id,
    sender_role,
    message
) VALUES (
    $1, $2, $3, $4
) RETURNING *;

-- name: ListApplicationRemarks :many
SELECT * FROM application_remarks
WHERE application_id = $1
ORDER BY created_at ASC;
