import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class ActiveLoanViewModel: ObservableObject {
    @Published var activeLoan: ActiveLoan? = nil
    @Published var emiSchedule: [EmiScheduleItem] = []
    @Published var payments: [LoanPayment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    var upcomingEMIs: [EmiScheduleItem] {
        emiSchedule
            .filter { $0.status == .upcoming }
            .sorted { $0.installmentNumber < $1.installmentNumber }
    }

    var overdueEMIs: [EmiScheduleItem] {
        emiSchedule.filter { $0.status == .overdue }
    }

    var repaymentProgress: Double {
        guard !emiSchedule.isEmpty else { return 0 }
        let paid = emiSchedule.filter { $0.status == .paid }.count
        return Double(paid) / Double(emiSchedule.count)
    }

    var outstandingBalanceFormatted: String {
        guard let loan = activeLoan else { return "—" }
        return formatCurrency(loan.outstandingBalance)
    }

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchAll(applicationId: String) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let loan = try await service.getLoan(loanId: nil, applicationId: applicationId)
                activeLoan = loan
                async let emi = service.listEmiSchedule(loanId: loan.id)
                async let pay = service.listPayments(loanId: loan.id)
                (emiSchedule, payments) = try await (emi, pay)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load loan"
            }
            isLoading = false
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let num = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? raw
    }
}
