import SwiftUI

@available(iOS 18.0, *)
struct LoanApplicationView: View {
    let loan: LoanProduct

    @StateObject private var viewModel = LoanApplicationViewModel(service: ServiceContainer.loanService)
    @EnvironmentObject private var router: AppRouter
    @AppStorage("loanOS_selectedBranchId") private var persistedBranchId = ""

    private var minAmount: Double { max(Double(loan.minAmount) ?? 10_000, 1) }
    private var maxAmount: Double { max(Double(loan.maxAmount) ?? minAmount, minAmount) }
    private var interestRate: Double { Double(loan.baseInterestRate) ?? 0 }

    private var amountBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.requestedAmount) ?? minAmount },
            set: { viewModel.requestedAmount = String(Int($0.rounded())) }
        )
    }

    private var tenureBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.tenureMonths) },
            set: { viewModel.tenureMonths = max(Int($0.rounded()), 1) }
        )
    }

    private var minimumTenure: Double { 6 }
    private var maximumTenure: Double { 84 }

    private var estimatedEMI: Double {
        let principal = Double(viewModel.requestedAmount) ?? minAmount
        let monthlyRate = (interestRate / 12) / 100
        let periods = Double(max(viewModel.tenureMonths, 1))
        guard monthlyRate > 0 else { return principal / periods }
        let factor = pow(1 + monthlyRate, periods)
        return (principal * monthlyRate * factor) / (factor - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    amountSection
                    tenureSection
                    branchSection
                    infoSection

                    if let error = viewModel.submissionError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }

            footerSection
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.selectedProductId = loan.id
            if viewModel.requestedAmount.isEmpty {
                viewModel.requestedAmount = String(Int(minAmount.rounded()))
            }
            if viewModel.tenureMonths <= 0 {
                viewModel.tenureMonths = Int(minimumTenure)
            }
            viewModel.preloadSubmissionContext(persistedBranchId: persistedBranchId)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customize your loan")
                .font(.largeTitle).bold()
            Text("Submitting a real application for \(loan.name).")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Loan Amount")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(amountBinding.wrappedValue))
                    .font(.title2).bold()
                    .foregroundColor(.mainBlue)
            }

            Slider(value: amountBinding, in: minAmount...maxAmount, step: 1_000)
                .accentColor(.mainBlue)

            HStack {
                Text(formatCurrency(minAmount))
                Spacer()
                Text(formatCurrency(maxAmount))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var tenureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tenure (Months)")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.tenureMonths) Mos")
                    .font(.title2).bold()
                    .foregroundColor(.secondaryBlue)
            }

            Slider(value: tenureBinding, in: minimumTenure...maximumTenure, step: 1)
                .accentColor(.secondaryBlue)

            HStack {
                Text("\(Int(minimumTenure)) Mos")
                Spacer()
                Text("\(Int(maximumTenure)) Mos")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "building.2")
                    .foregroundColor(.mainBlue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing Branch")
                        .font(.headline)
                    Text("This backend still requires a branch UUID. We auto-fill it from your latest application when available.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            TextField("Enter branch UUID", text: $viewModel.selectedBranchId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote.monospaced())
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if !viewModel.detectedBranchName.isEmpty {
                Text("Resolved branch: \(viewModel.detectedBranchName)")
                    .font(.caption)
                    .foregroundColor(.secondaryBlue)
            }
        }
        .cardStyle()
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.mainBlue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Base rate \(String(format: "%.2f%%", interestRate)) p.a.")
                        .font(.subheadline).bold()
                    Text("Required documents: \(loan.requiredDocuments.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let rule = loan.eligibilityRule {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Eligibility Snapshot")
                        .font(.subheadline).bold()
                    Text("Minimum age: \(rule.minAge)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Minimum monthly income: \(formatCurrency(rule.minMonthlyIncome))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if rule.minBureauScore > 0 {
                        Text("Minimum bureau score: \(rule.minBureauScore)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .cardStyle(tint: DS.primaryLight.opacity(0.5))
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            Divider()
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated EMI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(estimatedEMI, minimumFractionDigits: 2))
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                }

                Spacer()

                Button {
                    Task {
                        guard let application = await viewModel.submitApplication() else { return }
                        persistedBranchId = application.branchId
                        if loan.requiredDocuments.isEmpty {
                            router.push(.reviewApplication(application))
                        } else {
                            router.push(.documentUpload(application))
                        }
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(DS.primary)
                            .clipShape(Capsule())
                    } else {
                        Text("Create Application")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(DS.primary)
                            .clipShape(Capsule())
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func formatCurrency(
        _ value: Double,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? value.formatted()
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        return formatCurrency(value)
    }
}

private extension View {
    func cardStyle(tint: Color = .white) -> some View {
        self
            .padding(20)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

@available(iOS 18.0, *)
#Preview {
    NavigationStack {
        LoanApplicationView(
            loan: LoanProduct(
                id: UUID().uuidString,
                name: "Personal Loan",
                category: .personal,
                interestType: .fixed,
                baseInterestRate: "10.5",
                minAmount: "10000",
                maxAmount: "500000",
                isRequiringCollateral: false,
                isActive: true,
                eligibilityRule: ProductEligibilityRule(
                    id: UUID().uuidString,
                    minAge: 21,
                    minMonthlyIncome: "30000",
                    minBureauScore: 700,
                    allowedEmploymentTypes: ["SALARIED"]
                ),
                fees: [],
                requiredDocuments: []
            )
        )
        .environmentObject(AppRouter())
    }
}
