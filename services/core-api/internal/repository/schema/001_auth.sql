CREATE TYPE user_role AS ENUM ('admin', 'manager', 'officer', 'borrower', 'dst');
CREATE TYPE borrower_gender AS ENUM ('MALE', 'FEMALE', 'OTHER');
CREATE TYPE borrower_employment_type AS ENUM ('SALARIED', 'SELF_EMPLOYED', 'BUSINESS');
CREATE TYPE consent_type_enum AS ENUM ('aadhar_kyc', 'pan_kyc');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    
    -- Status Flags
    is_email_verified BOOLEAN DEFAULT false,
    is_phone_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT false,
    is_requiring_password_change BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,

    -- MFA Data
    has_totp BOOLEAN DEFAULT false,
    totp_secret VARCHAR(255),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admin_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bank_branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    region VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    dst_commission NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (dst_commission >= 0 AND dst_commission <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE manager_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    branch_id UUID REFERENCES bank_branches(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE officer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    branch_id UUID REFERENCES bank_branches(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dst_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    branch_id UUID NOT NULL REFERENCES bank_branches(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrower_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender borrower_gender NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    pincode VARCHAR(20) NOT NULL,
    employment_type borrower_employment_type NOT NULL,
    monthly_income NUMERIC(12,2) NOT NULL,
    profile_completeness_percent INTEGER NOT NULL,
    is_aadhaar_verified BOOLEAN NOT NULL DEFAULT false,
    is_pan_verified BOOLEAN NOT NULL DEFAULT false,
    aadhaar_verified_at TIMESTAMP WITH TIME ZONE,
    pan_verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrower_aadhaar_kyc_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    provider_transaction_id VARCHAR(128),
    provider_reference_id BIGINT,
    status VARCHAR(32) NOT NULL,
    failure_code VARCHAR(64),
    failure_reason TEXT,
    provider_message TEXT,
    name VARCHAR(255),
    gender VARCHAR(16),
    date_of_birth VARCHAR(16),
    year_of_birth VARCHAR(8),
    care_of TEXT,
    full_address TEXT,
    country VARCHAR(100),
    district VARCHAR(100),
    house TEXT,
    landmark TEXT,
    pincode VARCHAR(20),
    post_office VARCHAR(100),
    state VARCHAR(100),
    street TEXT,
    subdistrict VARCHAR(100),
    vtc VARCHAR(100),
    email_hash TEXT,
    mobile_hash TEXT,
    raw_response JSONB,
    attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrower_aadhaar_kyc_current (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL UNIQUE REFERENCES borrower_profiles(id) ON DELETE CASCADE,
    source_history_id UUID NOT NULL REFERENCES borrower_aadhaar_kyc_history(id) ON DELETE RESTRICT,
    provider VARCHAR(64) NOT NULL,
    provider_transaction_id VARCHAR(128),
    provider_reference_id BIGINT,
    status VARCHAR(32) NOT NULL,
    provider_message TEXT,
    name VARCHAR(255),
    gender VARCHAR(16),
    date_of_birth VARCHAR(16),
    year_of_birth VARCHAR(8),
    care_of TEXT,
    full_address TEXT,
    country VARCHAR(100),
    district VARCHAR(100),
    house TEXT,
    landmark TEXT,
    pincode VARCHAR(20),
    post_office VARCHAR(100),
    state VARCHAR(100),
    street TEXT,
    subdistrict VARCHAR(100),
    vtc VARCHAR(100),
    email_hash TEXT,
    mobile_hash TEXT,
    raw_response JSONB,
    verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrower_pan_kyc_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    provider_transaction_id VARCHAR(128),
    status VARCHAR(32) NOT NULL,
    failure_code VARCHAR(64),
    failure_reason TEXT,
    provider_message TEXT,
    pan_masked VARCHAR(16),
    category VARCHAR(64),
    remarks TEXT,
    name_as_per_pan_match BOOLEAN,
    date_of_birth_match BOOLEAN,
    aadhaar_seeding_status VARCHAR(8),
    raw_response JSONB,
    attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrower_pan_kyc_current (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL UNIQUE REFERENCES borrower_profiles(id) ON DELETE CASCADE,
    source_history_id UUID NOT NULL REFERENCES borrower_pan_kyc_history(id) ON DELETE RESTRICT,
    provider VARCHAR(64) NOT NULL,
    provider_transaction_id VARCHAR(128),
    status VARCHAR(32) NOT NULL,
    provider_message TEXT,
    pan_masked VARCHAR(16),
    category VARCHAR(64),
    remarks TEXT,
    name_as_per_pan_match BOOLEAN,
    date_of_birth_match BOOLEAN,
    aadhaar_seeding_status VARCHAR(8),
    raw_response JSONB,
    verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type consent_type_enum NOT NULL,
    consent_version VARCHAR(32) NOT NULL,
    consent_text TEXT NOT NULL,
    consent_text_hash VARCHAR(128) NOT NULL,
    is_granted BOOLEAN NOT NULL,
    source VARCHAR(64),
    ip_address VARCHAR(64),
    user_agent TEXT,
    metadata JSONB,
    granted_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE media_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    original_file_name TEXT NOT NULL,
    content_type VARCHAR(128) NOT NULL,
    size_bytes BIGINT NOT NULL,
    storage_provider VARCHAR(32) NOT NULL DEFAULT 'r2',
    bucket_name TEXT NOT NULL,
    object_key TEXT NOT NULL UNIQUE,
    etag TEXT,
    file_url TEXT NOT NULL,
    note TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    hashed_token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE webauthn_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    credential_id BYTEA NOT NULL UNIQUE,
    public_key BYTEA NOT NULL,
    sign_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_aadhaar_kyc_history_profile_attempted_at
    ON borrower_aadhaar_kyc_history (borrower_profile_id, attempted_at DESC);

CREATE INDEX idx_aadhaar_kyc_history_status_attempted_at
    ON borrower_aadhaar_kyc_history (status, attempted_at DESC);

CREATE UNIQUE INDEX idx_aadhaar_kyc_history_provider_txn
    ON borrower_aadhaar_kyc_history (provider, provider_transaction_id)
    WHERE provider_transaction_id IS NOT NULL;

CREATE INDEX idx_pan_kyc_history_profile_attempted_at
    ON borrower_pan_kyc_history (borrower_profile_id, attempted_at DESC);

CREATE INDEX idx_pan_kyc_history_status_attempted_at
    ON borrower_pan_kyc_history (status, attempted_at DESC);

CREATE UNIQUE INDEX idx_pan_kyc_history_provider_txn
    ON borrower_pan_kyc_history (provider, provider_transaction_id)
    WHERE provider_transaction_id IS NOT NULL;

CREATE INDEX idx_user_consents_user_type_created_at
    ON user_consents (user_id, consent_type, created_at DESC);

CREATE INDEX idx_media_files_user_uploaded_at
    ON media_files (user_id, uploaded_at DESC);
