import SwiftUI
import Combine

// MARK: - View Model
class LoanCostViewModel: ObservableObject {
    @Published var principal: Double = 300000
    @Published var interestRate: Double = 10.5
    @Published var tenureMonths: Int = 36
    @Published var processingFeePercent: Double = 1.5

    var totalInterest: Double {
        let r = (interestRate / 12) / 100
        let n = Double(tenureMonths)
        let emi = (principal * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
        return (emi * n) - principal
    }

    var processingFee: Double {
        principal * (processingFeePercent / 100)
    }

    var totalPayable: Double {
        principal + totalInterest + processingFee
    }

    var emi: Double {
        (principal + totalInterest) / Double(tenureMonths)
    }
}

// MARK: - Main View
struct LoanCostBreakdownView: View {
    @StateObject var viewModel = LoanCostViewModel()
    @State private var animateChart = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost Breakdown")
                        .font(AppFonts.rounded(28, weight: .bold))
                        .foregroundColor(DS.textPrimary)
                    Text("Complete transparency on what you pay")
                        .font(AppFonts.rounded(14))
                        .foregroundColor(DS.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // MARK: Donut Chart Card
                VStack(spacing: 20) {
                    ImprovedDonutChartView(
                        principal: viewModel.principal,
                        interest: viewModel.totalInterest,
                        fees: viewModel.processingFee,
                        total: viewModel.totalPayable,
                        animate: animateChart
                    )
                    .frame(height: 200)

                    // Legend
                    HStack(spacing: 0) {
                        LegendItem(color: DS.primary, label: "Principal", tint: DS.primaryLight)
                        Spacer()
                        LegendItem(color: DS.warning, label: "Interest", tint: DS.warning.opacity(0.12))
                        Spacer()
                        LegendItem(color: DS.danger, label: "Fees", tint: DS.danger.opacity(0.10))
                    }
                    .padding(.horizontal, 12)
                }
                .padding(20)
                .background(DS.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                        animateChart = true
                    }
                }

                // MARK: Breakdown List Card
                VStack(spacing: 0) {
                    EnhancedBreakdownRow(
                        title: "Principal Amount",
                        subtitle: "Loan disbursed",
                        amount: viewModel.principal,
                        color: DS.primary,
                        tint: DS.primaryLight,
                        percent: viewModel.principal / viewModel.totalPayable
                    )
                    RowDivider()

                    EnhancedBreakdownRow(
                        title: "Total Interest",
                        subtitle: String(format: "%.1f%% p.a. · %d months", viewModel.interestRate, viewModel.tenureMonths),
                        amount: viewModel.totalInterest,
                        color: DS.warning,
                        tint: DS.warning.opacity(0.12),
                        percent: viewModel.totalInterest / viewModel.totalPayable
                    )
                    RowDivider()

                    EnhancedBreakdownRow(
                        title: "Processing Fee",
                        subtitle: String(format: "%.1f%% of principal", viewModel.processingFeePercent),
                        amount: viewModel.processingFee,
                        color: DS.danger,
                        tint: DS.danger.opacity(0.10),
                        percent: viewModel.processingFee / viewModel.totalPayable
                    )

                    Divider()
                        .padding(.vertical, 4)

                    // Total Row
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Amount Payable")
                                .font(AppFonts.rounded(15, weight: .semibold))
                                .foregroundColor(DS.textPrimary)
                            Text("Principal + Interest + Fees")
                                .font(AppFonts.rounded(12))
                                .foregroundColor(DS.textSecondary)
                        }
                        Spacer()
                        Text("₹\(viewModel.totalPayable.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                            .font(AppFonts.rounded(18, weight: .bold))
                            .foregroundColor(DS.textPrimary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(DS.primaryLight.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
                .background(DS.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)

                // MARK: EMI Card
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly EMI")
                            .font(AppFonts.rounded(12))
                            .foregroundColor(DS.textSecondary)
                        Text("₹\(viewModel.emi.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                            .font(AppFonts.rounded(26, weight: .bold))
                            .foregroundColor(DS.primary)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("\(viewModel.tenureMonths)")
                            .font(AppFonts.rounded(22, weight: .bold))
                            .foregroundColor(DS.primary)
                        Text("months")
                            .font(AppFonts.rounded(11))
                            .foregroundColor(DS.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
                .background(DS.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)

            }
            .padding(.bottom, 40)
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Improved Donut Chart
struct ImprovedDonutChartView: View {
    let principal: Double
    let interest: Double
    let fees: Double
    let total: Double
    let animate: Bool

    private var principalFrac: Double { principal / total }
    private var interestFrac:  Double { interest  / total }

    private let gap: Double = 0.008

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(DS.border, lineWidth: 26)

            // Principal arc — uses DS.gradient (blue)
            Circle()
                .trim(from: gap / 2,
                      to: CGFloat(animate ? (principalFrac - gap / 2) : 0))
                .stroke(
                    DS.gradient,
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: animate)

            // Interest arc — DS.warning (amber)
            Circle()
                .trim(from: CGFloat(principalFrac + gap / 2),
                      to: CGFloat(animate ? (principalFrac + interestFrac - gap / 2) : principalFrac))
                .stroke(
                    LinearGradient(
                        colors: [DS.warning, DS.warning.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.1), value: animate)

            // Fees arc — DS.dangerGradient (red)
            Circle()
                .trim(from: CGFloat(principalFrac + interestFrac + gap / 2),
                      to: CGFloat(animate ? (1.0 - gap / 2) : (principalFrac + interestFrac)))
                .stroke(
                    DS.dangerGradient,
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animate)

            // Center label
            VStack(spacing: 2) {
                Text("Total Payable")
                    .font(AppFonts.rounded(11, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                Text("₹\(total.formatted(.number.notation(.compactName).precision(.fractionLength(1))))")
                    .font(AppFonts.rounded(22, weight: .bold))
                    .foregroundColor(DS.textPrimary)
            }
        }
        .padding(16)
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(AppFonts.rounded(12, weight: .medium))
                .foregroundColor(DS.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Enhanced Breakdown Row
struct EnhancedBreakdownRow: View {
    let title: String
    let subtitle: String
    let amount: Double
    let color: Color
    let tint: Color
    let percent: Double

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFonts.rounded(14, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(subtitle)
                    .font(AppFonts.rounded(11))
                    .foregroundColor(DS.textSecondary)
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS.border)
                            .frame(height: 3)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(percent), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(AppFonts.rounded(15, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                Text(String(format: "%.1f%%", percent * 100))
                    .font(AppFonts.rounded(11, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
    }
}

// MARK: - Divider Helper
struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 20)
    }
}

// MARK: - Preview
struct LoanCostBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoanCostBreakdownView()
        }
    }
}
