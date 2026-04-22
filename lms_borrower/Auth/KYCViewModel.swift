import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
public final class KYCViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String?

    @Published public var fullName = ""
    @Published public var dateOfBirth = ""
    @Published public var panNumber = ""
    @Published public var aadhaarNumber = ""
    @Published public var aadhaarOTP = ""
    @Published public var aadhaarConsentGranted = false
    @Published public var panConsentGranted = false
    @Published public var aadhaarReferenceID = ""
    @Published public var aadhaarProviderTransactionID = ""
    @Published public var panProviderTransactionID = ""
    @Published public var isAadhaarVerified = false
    @Published public var isPanVerified = false
    @Published public var currentAddress = ""
    @Published public var city = ""
    @Published public var stateName = ""
    @Published public var postalCode = ""
    @Published public var selectedEmploymentStatus = "Salaried"
    @Published public var employerName = ""
    @Published public var netMonthlyIncome = ""

    private let kycRepository: KYCRepository

    public init(kycRepository: KYCRepository? = nil) {
        self.kycRepository = kycRepository ?? KYCRepository()
    }

    public var hasStartedAadhaarStep: Bool {
        !aadhaarReferenceID.isEmpty
    }

    public var isBackendImplementedFlowComplete: Bool {
        isAadhaarVerified && isPanVerified
    }

    public func submitPersonalDetails() async -> Bool {
        guard validateBasicDetails() else { return false }

        errorMessage = nil
        state = .loading("Saving borrower details...")
        do {
            try await kycRepository.submitBorrowerProfileBasics(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                dob: dateOfBirth,
                panNumber: normalizedPAN
            )
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func sendAadhaarOTP() async -> Bool {
        guard aadhaarConsentGranted else {
            return fail(with: "Please record Aadhaar consent before requesting OTP.")
        }

        let trimmedAadhaar = aadhaarNumber.filter(\.isNumber)
        guard trimmedAadhaar.count == 12 else {
            return fail(with: "Enter a valid 12-digit Aadhaar number.")
        }

        errorMessage = nil
        state = .loading("Recording Aadhaar consent...")
        do {
            try await kycRepository.recordUserConsent(type: .aadhaar)
            state = .loading("Sending Aadhaar OTP...")
            let response = try await kycRepository.initiateAadhaarKyc(aadhaarNumber: trimmedAadhaar)
            aadhaarNumber = trimmedAadhaar
            aadhaarReferenceID = response.referenceID
            aadhaarProviderTransactionID = response.providerTransactionID
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func verifyAadhaarOTP() async -> Bool {
        guard !aadhaarReferenceID.isEmpty else {
            return fail(with: "Request an Aadhaar OTP first.")
        }

        let trimmedOTP = aadhaarOTP.filter(\.isNumber)
        guard trimmedOTP.count == 6 else {
            return fail(with: "Enter the 6-digit OTP sent for Aadhaar verification.")
        }

        errorMessage = nil
        state = .loading("Verifying Aadhaar OTP...")
        do {
            let response = try await kycRepository.verifyAadhaarKycOtp(
                referenceID: aadhaarReferenceID,
                otp: trimmedOTP
            )

            guard response.isValid else {
                return fail(with: response.message)
            }

            aadhaarOTP = trimmedOTP
            aadhaarProviderTransactionID = response.providerTransactionID
            isAadhaarVerified = true
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func verifyPan() async -> Bool {
        guard panConsentGranted else {
            return fail(with: "Please record PAN consent before continuing.")
        }

        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fail(with: "Enter your full name to verify PAN.")
        }

        guard !dateOfBirth.isEmpty else {
            return fail(with: "Select your date of birth to verify PAN.")
        }

        guard normalizedPAN.count == 10 else {
            return fail(with: "Enter a valid 10-character PAN number.")
        }

        errorMessage = nil
        state = .loading("Recording PAN consent...")
        do {
            try await kycRepository.recordUserConsent(type: .pan)
            state = .loading("Verifying PAN...")
            let response = try await kycRepository.verifyPanKyc(
                pan: normalizedPAN,
                nameAsPerPan: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: dateOfBirth
            )

            guard response.isValid else {
                return fail(with: "PAN verification failed. Please review your details and try again.")
            }

            panNumber = normalizedPAN
            panProviderTransactionID = response.providerTransactionID
            isPanVerified = true
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func pollKYCStatus() async -> KYCStatus {
        do {
            let snapshot = try await kycRepository.getBorrowerKycStatus(
                isAadhaarVerified: isAadhaarVerified,
                isPanVerified: isPanVerified
            )

            if snapshot.isAadhaarVerified && snapshot.isPanVerified {
                return .approved
            }

            return .pending
        } catch {
            return .rejected
        }
    }

    public func submitAddressProof() async -> Bool {
        errorMessage = nil
        state = .loading("Saving address details...")
        do {
            try await kycRepository.submitAddressDetails(
                addressLine1: currentAddress,
                city: city,
                state: stateName,
                postalCode: postalCode
            )
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func submitIncomeDetails() async -> Bool {
        errorMessage = nil
        state = .loading("Saving income details...")
        do {
            try await kycRepository.submitIncomeDetails(
                employmentType: selectedEmploymentStatus,
                monthlyIncome: netMonthlyIncome
            )
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func submitESignature() async -> Bool {
        errorMessage = nil
        state = .loading("Saving e-signature...")
        do {
            try await kycRepository.submitESignature()
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }

    public var normalizedPAN: String {
        panNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    @discardableResult
    private func fail(with message: String) -> Bool {
        state = .error(message)
        errorMessage = message
        return false
    }

    private func validateBasicDetails() -> Bool {
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fail(with: "Enter your full name to continue.")
        }

        guard !dateOfBirth.isEmpty else {
            return fail(with: "Select your date of birth to continue.")
        }

        guard normalizedPAN.count == 10 else {
            return fail(with: "Enter a valid 10-character PAN number.")
        }

        errorMessage = nil
        return true
    }
}
