//
//  LODashboardView.swift
//  lms_project
//
//  Loan Officer Dashboard: Portrait-first redesign with large readable cards,
//  colourful KPI tiles, and a clear at-a-glance layout.
//

import SwiftUI

struct LODashboardView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        greetingHeader
                        kpiSection
                        performanceTrendSection
                        recentApplicationsSection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxl)
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
                applicationsVM.loadData(autoSelectFirst: false)
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Date pill
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                Text(todayFormatted)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.primary.opacity(0.10))
            .clipShape(Capsule())

            // Greeting text
            HStack(alignment: .bottom, spacing: 10) {
                Text(greetingText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(authVM.currentUser?.branch ?? "Branch")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - KPI Section (Portfolio Overview)

    private var kpiSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel(title: "Portfolio Overview", icon: "briefcase.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    overviewCard(title: "Active Cases", value: "\(assignedCount)", icon: "doc.on.doc.fill", color: Theme.Colors.primary)
                    overviewCard(title: "Pending Review", value: "\(pendingReviewCount)", icon: "timer", color: Theme.Colors.warning)
                    overviewCard(title: "High Risk", value: "\(highRiskCount)", icon: "shield.righthalf.filled", color: Theme.Colors.critical)
                    overviewCard(title: "Approved", value: "\(approvedCount)", icon: "checkmark.seal.fill", color: Theme.Colors.success)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 24)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .layoutPriority(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Performance Trend

    private var performanceTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel(title: "Performance Trend", icon: "chart.line.uptrend.xyaxis")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(approvedCount) Loans Approved")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Live from your applications")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                        Text(approvalRateText)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.success.opacity(0.10))
                    .clipShape(Capsule())
                }

                PremiumLineChart(
                    data: weeklySeries,
                    labels: ["D-6", "D-5", "D-4", "D-3", "D-2", "D-1", "Today"],
                    accentColor: Theme.Colors.primary,
                    showPoints: true,
                    unit: "loans"
                )
                .frame(height: 190)
            }
            .padding(16)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Quick Actions

    private var recentApplicationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                sectionLabel(title: "Recent Applications", icon: "square.grid.2x2.fill")
                Spacer()
                Button {
                    withAnimation { selectedTab = 1 }
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                if activeApplications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No active applications")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(activeApplications.prefix(5)) { app in
                            Button {
                                applicationsVM.selectApplication(app)
                                withAnimation { selectedTab = 1 }
                            } label: {
                                recentAppRow(app)
                            }
                            .buttonStyle(.plain)

                            if app.id != activeApplications.prefix(5).last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
            )
        }
    }

    private func recentAppRow(_ app: LoanApplication) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(app.riskLevel.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(app.borrower.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(app.riskLevel.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(app.borrower.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(app.loan.amount.currencyFormatted)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.primary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(app.loan.type.displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: app.status)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Section Label Helper

    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.primary)
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Computed Helpers

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Date())
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Officer"
        if hour < 12 { return "Good Morning, \(name)" }
        if hour < 17 { return "Good Afternoon, \(name)" }
        return "Good Evening, \(name)"
    }
}

private extension LODashboardView {
    var liveApplications: [LoanApplication] { applicationsVM.applications }

    var activeApplications: [LoanApplication] {
        liveApplications.filter {
            $0.status == .pending || $0.status == .underReview || $0.status == .officerReview
        }
    }

    var assignedCount: Int { activeApplications.count }

    var pendingReviewCount: Int {
        activeApplications.filter { $0.status == .underReview || $0.status == .officerReview }.count
    }

    var highRiskCount: Int {
        activeApplications.filter { $0.riskLevel == .high }.count
    }

    var approvedCount: Int {
        liveApplications.filter { $0.status == .approved || $0.status == .officerApproved || $0.status == .managerApproved }.count
    }

    var approvalRateText: String {
        guard !liveApplications.isEmpty else { return "0%" }
        let rate = (Double(approvedCount) / Double(liveApplications.count)) * 100
        return "\(Int(rate.rounded()))%"
    }

    var weeklySeries: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            return Double(liveApplications.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count)
        }
    }
}

struct MiniMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary).textCase(.uppercase)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
