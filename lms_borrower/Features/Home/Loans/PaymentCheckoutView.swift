import SwiftUI
import Combine

// MARK: - Payment ViewModel

@MainActor
@available(iOS 18.0, *)
final class PaymentViewModel: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var completedPayment: LoanPayment? = nil

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func recordPayment(loanId: String, emiScheduleId: String, amount: Double) async -> LoanPayment? {
        isProcessing = true
        errorMessage = nil
        let externalTxnId = "TXN-\(UUID().uuidString.prefix(8).uppercased())"
        do {
            let payment = try await service.recordPayment(
                loanId: loanId,
                emiScheduleId: emiScheduleId,
                amount: String(format: "%.0f", amount),
                externalTransactionId: externalTxnId
            )
            completedPayment = payment
            isProcessing = false
            return payment
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Payment failed. Please try again."
            isProcessing = false
            return nil
        }
    }
}

// MARK: - Payment Checkout View

@available(iOS 18.0, *)
struct PaymentCheckoutView: View {
    let loanId: String
    let emiScheduleId: String
    let amount: Double
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = PaymentViewModel()
    @State private var selectedMethod: String = "Google Pay"

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {

                    // Amount Header
                    VStack(spacing: 8) {
                        Text("Amount to Pay")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(amount.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 30)

                    // Payment Method Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("UPI")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            PaymentMethodRow(title: "Google Pay", icon: "g.circle.fill", isSelected: selectedMethod == "Google Pay") { selectedMethod = "Google Pay" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "PhonePe", icon: "p.circle.fill", isSelected: selectedMethod == "PhonePe") { selectedMethod = "PhonePe" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "Other UPI ID", icon: "link.circle.fill", isSelected: selectedMethod == "Other UPI ID") { selectedMethod = "Other UPI ID" }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        Text("Net Banking & Cards")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        VStack(spacing: 0) {
                            PaymentMethodRow(title: "Debit Card", icon: "creditcard.fill", isSelected: selectedMethod == "Debit Card") { selectedMethod = "Debit Card" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "Net Banking", icon: "building.columns.fill", isSelected: selectedMethod == "Net Banking") { selectedMethod = "Net Banking" }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 100)
                }
            }

            // Sticky Bottom Button
            VStack {
                Divider()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.alertRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                Button {
                    Task {
                        if let payment = await viewModel.recordPayment(
                            loanId: loanId,
                            emiScheduleId: emiScheduleId,
                            amount: amount
                        ) {
                            router.push(.paymentSuccess(transactionID: payment.externalTransactionId))
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(viewModel.isProcessing ? "Processing…" : "Proceed to Pay")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.isProcessing ? Color.secondary : DS.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isProcessing)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.mainBlue)
                    .frame(width: 32)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mainBlue)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(16)
        }
    }
}
