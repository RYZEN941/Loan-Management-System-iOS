import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class TrackViewModel: ObservableObject {
    @Published var applications: [BorrowerLoanApplication] = []
    @Published var selectedApplication: BorrowerLoanApplication? = nil
    @Published var isLoading: Bool = false
    @Published var isAcceptingSanctionLetter: Bool = false
    @Published var errorMessage: String? = nil

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchApplications() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                applications = try await service.listLoanApplications(limit: 50, offset: 0)
                if selectedApplication == nil {
                    selectedApplication = applications.first
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
            }
            isLoading = false
        }
    }

    func fetchApplicationDetail(applicationId: String) {
        Task {
            do {
                let detail = try await service.getLoanApplication(applicationId: applicationId)
                applyUpdatedApplication(detail)
            } catch {
                errorMessage = "Failed to load application detail"
            }
        }
    }

    func acceptSanctionLetter(for application: BorrowerLoanApplication) async throws -> BorrowerLoanApplication {
        isAcceptingSanctionLetter = true
        errorMessage = nil
        defer { isAcceptingSanctionLetter = false }

        do {
            _ = try await service.createLoan(
                applicationId: application.id,
                principalAmount: application.requestedAmount
            )
        } catch let error as LoanError {
            switch error {
            case .preconditionFailed(let message) where message.localizedCaseInsensitiveContains("loan already exists"):
                break
            default:
                throw error
            }
        } catch {
            throw error
        }

        var refreshed = try await service.getLoanApplication(applicationId: application.id)
        if refreshed.status != .disbursed {
            try await service.updateLoanApplicationStatus(
                applicationId: application.id,
                status: .disbursed,
                escalationReason: nil
            )
            refreshed = try await service.getLoanApplication(applicationId: application.id)
        }

        applyUpdatedApplication(refreshed)
        return refreshed
    }

    private func applyUpdatedApplication(_ application: BorrowerLoanApplication) {
        if let idx = applications.firstIndex(where: { $0.id == application.id }) {
            applications[idx] = application
        }
        selectedApplication = application
    }

    var statusDisplayItems: [(app: BorrowerLoanApplication, statusLabel: String, statusColor: Color)] {
        applications.map { ($0, $0.status.displayName, $0.status.color) }
    }
}
