import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class TrackViewModel: ObservableObject {
    @Published var applications: [BorrowerLoanApplication] = []
    @Published var selectedApplication: BorrowerLoanApplication? = nil
    @Published var isLoading: Bool = false
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
                if let idx = applications.firstIndex(where: { $0.id == applicationId }) {
                    applications[idx] = detail
                }
                selectedApplication = detail
            } catch {
                errorMessage = "Failed to load application detail"
            }
        }
    }

    var statusDisplayItems: [(app: BorrowerLoanApplication, statusLabel: String, statusColor: Color)] {
        applications.map { ($0, $0.status.displayName, $0.status.color) }
    }
}
