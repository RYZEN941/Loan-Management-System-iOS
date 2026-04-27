-- +goose Up
ALTER TABLE loan_applications 
ADD COLUMN disbursement_account_number VARCHAR(50),
ADD COLUMN disbursement_ifsc_code VARCHAR(20),
ADD COLUMN disbursement_bank_name VARCHAR(100),
ADD COLUMN disbursement_account_holder_name VARCHAR(255);

-- +goose Down
ALTER TABLE loan_applications 
DROP COLUMN disbursement_account_number,
DROP COLUMN disbursement_ifsc_code,
DROP COLUMN disbursement_bank_name,
DROP COLUMN disbursement_account_holder_name;
