//
//  ManagerDashboardView.swift
//  lms_project
//

import SwiftUI

struct ManagerDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        greetingBar
                        kpiStrip
                        recentApplicationsSection
                        pendingApprovalsSection
                        recentActivitySection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                dashboardVM.loadData()
                applicationsVM.loadData()
            }
        }
    }

    // MARK: - Greeting
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greetingText).font(Theme.Typography.titleLarge)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "building.2").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(authVM.currentUser?.branch ?? "Branch").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Manager"
        if hour < 12 { return "Good Morning, \(name)" }
        if hour < 17 { return "Good Afternoon, \(name)" }
        return "Good Evening, \(name)"
    }

    // MARK: - KPI Strip
    private var kpiStrip: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible(), spacing: Theme.Spacing.md)],
            spacing: Theme.Spacing.md
        ) {
            KPICard(title: "Pending Approvals", value: "\(underReviewCount)",
                    icon: "checkmark.circle.fill", color: Theme.Colors.warning)
            KPICard(title: "Approved This Month", value: "\(dashboardVM.approvedThisMonth)",
                    icon: "checkmark.seal.fill", color: Theme.Colors.success)
            KPICard(title: "Portfolio Value", value: dashboardVM.totalPortfolioValue.compactFormatted,
                    icon: "chart.line.uptrend.xyaxis", color: Theme.Colors.primary)
            KPICard(title: "NPA Rate", value: "2.4%",
                    icon: "exclamationmark.triangle.fill", color: Theme.Colors.critical,
                    subtitle: "↓ 0.3% from last month")
        }
    }

    private var underReviewCount: Int {
        applicationsVM.applications.filter { $0.status == .underReview }.count
    }

    // MARK: - Recent Applications (clickable → Approvals tab)
    private var recentApplicationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Applications", icon: "doc.text.fill")

            let recent = Array(applicationsVM.applications.prefix(5))

            if recent.isEmpty {
                emptyCard("No applications yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { app in
                        Button {
                            applicationsVM.selectApplication(app)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(statusColor(app.status).opacity(0.12)).frame(width: 38, height: 38)
                                    Text(app.borrower.name.prefix(1))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(statusColor(app.status))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.borrower.name).font(Theme.Typography.headline).foregroundStyle(.primary)
                                    Text(app.loan.amount.currencyFormatted + " · " + app.loan.type.displayName)
                                        .font(Theme.Typography.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    StatusBadge(status: app.status)
                                    Text(app.createdAt.shortFormatted)
                                        .font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if app.id != recent.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }

    private func statusColor(_ status: ApplicationStatus) -> Color {
        switch status {
        case .pending: return Theme.Colors.neutral
        case .underReview: return Theme.Colors.warning
        case .approved: return Theme.Colors.success
        case .rejected: return Theme.Colors.critical
        }
    }

    // MARK: - Pending Approvals (Under Review)
    private var pendingApprovalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Pending Approvals", icon: "clock.fill")

            let underReview = applicationsVM.applications.filter { $0.status == .underReview }

            if underReview.isEmpty {
                emptyCard("No pending approvals")
            } else {
                VStack(spacing: 0) {
                    ForEach(underReview) { app in
                        Button {
                            applicationsVM.selectApplication(app)
                        } label: {
                            ApplicationRow(application: app, isSelected: false)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if app.id != underReview.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }

    // MARK: - Recent Decisions
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Decisions", icon: "clock.arrow.circlepath")

            let decided = applicationsVM.applications.filter {
                $0.status == .approved || $0.status == .rejected
            }

            if decided.isEmpty {
                emptyCard("No recent decisions")
            } else {
                VStack(spacing: 0) {
                    ForEach(decided) { app in
                        Button {
                            applicationsVM.selectApplication(app)
                        } label: {
                            ApplicationRow(application: app, isSelected: false)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if app.id != decided.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                .padding(.vertical, Theme.Spacing.lg)
            Spacer()
        }
        .cardStyle(colorScheme: colorScheme)
    }
}
