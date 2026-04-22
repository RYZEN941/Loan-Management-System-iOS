import Foundation

@available(iOS 18.0, *)
@MainActor
public final class KYCRepository: Sendable {

    public enum ConsentType {
        case aadhaar
        case pan
    }

    public struct AadhaarInitiationResult {
        public let referenceID: String
        public let providerTransactionID: String
        public let message: String
    }

    public struct AadhaarVerificationResult {
        public let isValid: Bool
        public let status: String
        public let message: String
        public let providerTransactionID: String
    }

    public struct PanVerificationResult {
        public let isValid: Bool
        public let status: String
        public let providerTransactionID: String
    }

    public struct BorrowerKycStatusSnapshot {
        public let isAadhaarVerified: Bool
        public let isPanVerified: Bool
    }

    public init() {}

    public func submitBorrowerProfileBasics(
        fullName: String,
        dob: String,
        panNumber: String
    ) async throws {
        _ = fullName
        _ = dob
        _ = panNumber
        try await Task.sleep(nanoseconds: 700_000_000)
    }

    public func submitAddressDetails(
        addressLine1: String,
        city: String,
        state: String,
        postalCode: String
    ) async throws {
        _ = addressLine1
        _ = city
        _ = state
        _ = postalCode
        try await Task.sleep(nanoseconds: 700_000_000)
    }

    public func submitIncomeDetails(
        employmentType: String,
        monthlyIncome: String
    ) async throws {
        _ = employmentType
        _ = monthlyIncome
        try await Task.sleep(nanoseconds: 700_000_000)
    }

    public func submitESignature() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    public func recordUserConsent(type: ConsentType) async throws {
        _ = type
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    public func initiateAadhaarKyc(aadhaarNumber: String) async throws -> AadhaarInitiationResult {
        _ = aadhaarNumber
        try await Task.sleep(nanoseconds: 900_000_000)

        return AadhaarInitiationResult(
            referenceID: String(Int.random(in: 1_000_000...9_999_999)),
            providerTransactionID: UUID().uuidString,
            message: "OTP sent successfully"
        )
    }

    public func verifyAadhaarKycOtp(referenceID: String, otp: String) async throws -> AadhaarVerificationResult {
        _ = referenceID
        try await Task.sleep(nanoseconds: 900_000_000)

        let success = otp.trimmingCharacters(in: .whitespacesAndNewlines).count == 6
        return AadhaarVerificationResult(
            isValid: success,
            status: success ? "VALID" : "",
            message: success ? "Aadhaar verified successfully" : "Invalid OTP",
            providerTransactionID: UUID().uuidString
        )
    }

    public func verifyPanKyc(
        pan: String,
        nameAsPerPan: String,
        dateOfBirth: String
    ) async throws -> PanVerificationResult {
        _ = nameAsPerPan
        _ = dateOfBirth
        try await Task.sleep(nanoseconds: 800_000_000)

        let normalizedPAN = pan.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let success = normalizedPAN.count == 10

        return PanVerificationResult(
            isValid: success,
            status: success ? "valid" : "invalid",
            providerTransactionID: UUID().uuidString
        )
    }

    public func getBorrowerKycStatus(
        isAadhaarVerified: Bool,
        isPanVerified: Bool
    ) async throws -> BorrowerKycStatusSnapshot {
        try await Task.sleep(nanoseconds: 500_000_000)
        return BorrowerKycStatusSnapshot(
            isAadhaarVerified: isAadhaarVerified,
            isPanVerified: isPanVerified
        )
    }
}
