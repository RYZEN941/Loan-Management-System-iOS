import SwiftUI

@available(iOS 18.0, *)
struct ApplicationStatusListView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = TrackViewModel()

    private var inProgressApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter {
            !pastStatuses.contains($0.status) && $0.status != .draft && $0.status != .disbursed
        }
    }

    private var disbursedApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter { $0.status == .disbursed }
    }

    private var draftApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter { $0.status == .draft }
    }

    private var pastApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter { pastStatuses.contains($0.status) }
    }

    private let pastStatuses: Set<LoanApplicationStatus> = [.rejected, .cancelled, .officerRejected, .managerRejected]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if viewModel.isLoading && viewModel.applications.isEmpty {
                    ProgressView()
                        .padding(.top, 20)
                } else if let error = viewModel.errorMessage, viewModel.applications.isEmpty {
                    errorSection(error)
                } else {
                    if !inProgressApplications.isEmpty {
                        applicationSection(
                            title: "In Progress",
                            applications: inProgressApplications,
                            accent: .mainBlue
                        ) { app in
                            router.push(.detailedTracking(app))
                        }
                    }

                    if !disbursedApplications.isEmpty {
                        applicationSection(
                            title: "Active Loans",
                            applications: disbursedApplications,
                            accent: Color(hex: "#00C48C")
                        ) { app in
                            router.push(.activeLoanDetails(app))
                        }
                    }

                    if !draftApplications.isEmpty {
                        applicationSection(
                            title: "Drafts",
                            applications: draftApplications,
                            accent: .secondary
                        ) { app in
                            router.push(.documentUpload(app))
                        }
                    }

                    if !pastApplications.isEmpty {
                        applicationSection(
                            title: "Past Applications",
                            applications: pastApplications,
                            accent: .alertRed
                        ) { app in
                            if app.status == .rejected || app.status == .officerRejected || app.status == .managerRejected {
                                router.push(.rejectionReason(app))
                            } else {
                                router.push(.detailedTracking(app))
                            }
                        }
                    }

                    if viewModel.applications.isEmpty {
                        emptySection
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task {
            viewModel.fetchApplications()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Applications")
                .font(.largeTitle).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Track and manage your live loan requests.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func applicationSection(
        title: String,
        applications: [BorrowerLoanApplication],
        accent: Color,
        action: @escaping (BorrowerLoanApplication) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)

            ForEach(applications) { application in
                Button {
                    action(application)
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 50, height: 50)
                            Image(systemName: icon(for: application.status))
                                .foregroundColor(accent)
                                .font(.title3)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.loanProductName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("App ID: \(application.referenceNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(BorrowerSanctionLetterSupport.statusTitle(for: application))
                                .font(.caption).bold()
                                .foregroundColor(accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.12))
                                .clipShape(Capsule())
                            Text(formatCurrency(application.requestedAmount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptySection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("No applications yet")
                .font(.headline)
            Text("Create a loan application from Discover and it will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            Button("Retry") {
                viewModel.fetchApplications()
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func icon(for status: LoanApplicationStatus) -> String {
        switch status {
        case .draft:
            return "doc.text"
        case .disbursed:
            return "banknote"
        case .rejected, .officerRejected, .managerRejected, .cancelled:
            return "xmark"
        default:
            return "clock.fill"
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}
