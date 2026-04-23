import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class LoanApplicationViewModel: ObservableObject {

    @Published var selectedProductId: String = ""
    @Published var selectedBranchId: String = ""
    @Published var detectedBranchName: String = ""
    @Published var requestedAmount: String = ""
    @Published var tenureMonths: Int = 12
    @Published var borrowerProfileId: String = ""

    @Published var isSubmitting: Bool = false
    @Published var submissionError: String? = nil
    @Published var submittedApplication: BorrowerLoanApplication? = nil
    @Published var isApplicationSubmitted: Bool = false

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func preloadSubmissionContext(persistedBranchId: String) {
        if selectedBranchId.isEmpty {
            selectedBranchId = persistedBranchId.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        Task {
            do {
                let existingApplications = try await service.listLoanApplications(limit: 20, offset: 0)
                guard let latestApplication = existingApplications.first else { return }
                if selectedBranchId.isEmpty {
                    selectedBranchId = latestApplication.branchId
                }
                if detectedBranchName.isEmpty {
                    detectedBranchName = latestApplication.branchName
                }
            } catch {
                // Keep the form usable even when prior applications cannot be loaded.
            }
        }
    }

    func checkEligibility(product: LoanProduct, monthlySalary: Double, age: Int) -> String? {
        if let rule = product.eligibilityRule {
            if age < rule.minAge {
                return "Minimum age is \(rule.minAge) years."
            }
            if let minIncome = Double(rule.minMonthlyIncome), monthlySalary < minIncome {
                return "Minimum monthly income required is ₹\(rule.minMonthlyIncome)."
            }
        }
        if let amount = Double(requestedAmount),
           let min = Double(product.minAmount),
           let max = Double(product.maxAmount),
           amount < min || amount > max {
            return "Loan amount must be between ₹\(product.minAmount) and ₹\(product.maxAmount)."
        }
        return nil
    }

    func submitApplication() async -> BorrowerLoanApplication? {
        guard !isSubmitting else { return nil }

        let trimmedProductId = selectedProductId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBranchId = selectedBranchId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAmount = requestedAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedProductId.isEmpty else {
            submissionError = "Loan product is missing. Please reopen the application flow."
            return nil
        }

        guard !trimmedBranchId.isEmpty else {
            submissionError = "Branch ID is required until the branch listing API is available."
            return nil
        }

        guard !trimmedAmount.isEmpty else {
            submissionError = "Please choose a loan amount."
            return nil
        }

        isSubmitting = true
        submissionError = nil
        defer { isSubmitting = false }

        do {
            let application = try await service.createLoanApplication(
                primaryBorrowerProfileId: borrowerProfileId.trimmingCharacters(in: .whitespacesAndNewlines),
                loanProductId: trimmedProductId,
                branchId: trimmedBranchId,
                requestedAmount: trimmedAmount,
                tenureMonths: tenureMonths
            )
            submittedApplication = application
            isApplicationSubmitted = true
            if detectedBranchName.isEmpty {
                detectedBranchName = application.branchName
            }
            return application
        } catch {
            submissionError = (error as? LocalizedError)?.errorDescription ?? "Application failed"
            return nil
        }
    }
}
