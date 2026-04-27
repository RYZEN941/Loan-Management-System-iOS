import SwiftUI

@available(iOS 18.0, *)
struct SanctionLetterReviewView: View {
    let application: BorrowerLoanApplication
    let acceptAction: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    @State private var latestApplication: BorrowerLoanApplication?
    @State private var product: LoanProduct?
    @State private var isSubmitting = false
    @State private var isLoadingReadiness = false
    @State private var errorMessage: String?

    private let loanService: LoanServiceProtocol = ServiceContainer.loanService

    private var currentApplication: BorrowerLoanApplication {
        latestApplication ?? application
    }

    private var content: BorrowerSanctionLetterContent {
        BorrowerSanctionLetterSupport.makeLetter(
            for: currentApplication,
            borrowerName: session.userName,
            mobileNumber: session.userPhone
        )
    }

    // MARK: - Document Logic

    private var mandatoryRequirements: [ProductRequiredDocument] {
        product?.requiredDocuments.filter(\.isMandatory) ?? []
    }

    private var approvedRequirementIDs: Set<String> {
        Set(
            currentApplication.documents
                .filter { $0.verificationStatus == .pass }
                .map(\.requiredDocId)
        )
    }

    private var approvedMandatoryCount: Int {
        mandatoryRequirements.filter {
            approvedRequirementIDs.contains($0.id)
        }.count
    }

    private var pendingMandatoryRequirements: [ProductRequiredDocument] {
        mandatoryRequirements.filter {
            !approvedRequirementIDs.contains($0.id)
        }
    }

    private var readinessMessage: String? {
        if isLoadingReadiness {
            return "Checking mandatory document approvals before final acceptance."
        }
        if product == nil {
            return "Unable to verify mandatory document approvals right now."
        }
        if pendingMandatoryRequirements.isEmpty {
            return nil
        }
        return "All mandatory documents must be verified before you can accept the sanction letter."
    }

    private var canAcceptSanctionLetter: Bool {
        !isSubmitting &&
        !isLoadingReadiness &&
        product != nil &&
        pendingMandatoryRequirements.isEmpty
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }

                    Button("Accept Sanction Letter") {
                        Task {
                            isSubmitting = true
                            do {
                                try await acceptAction()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(!canAcceptSanctionLetter)
                }
                .padding()
            }
            .navigationTitle("Sanction Letter")
            .task {
                await loadReadinessData()
            }
        }
    }

    // MARK: - Helpers

    private func enhancedErrorMessage(for error: LoanError) -> String {
        switch error {
        case .preconditionFailed(let message)
            where message.localizedCaseInsensitiveContains("mandatory documents"):
            if mandatoryRequirements.isEmpty {
                return "\(message)\nBackend product configuration may be out of sync."
            }
            return message
        default:
            return error.localizedDescription
        }
    }

    private func documentStatusText(for requirement: ProductRequiredDocument) -> String {
        if let document = currentApplication.documents.first(where: { $0.requiredDocId == requirement.id }) {
            return document.verificationStatus.displayName
        }
        return "Not Uploaded"
    }

    private func loadReadinessData() async {
        isLoadingReadiness = true
        defer { isLoadingReadiness = false }

        do {
            async let fetchedApplication = loanService.getLoanApplication(applicationId: application.id)
            async let fetchedProduct = loanService.getLoanProduct(productId: application.loanProductId)

            let (detail, fetchedLoanProduct) = try await (fetchedApplication, fetchedProduct)

            latestApplication = detail
            product = fetchedLoanProduct

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
