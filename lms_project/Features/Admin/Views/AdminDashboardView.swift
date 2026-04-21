//
//  AdminDashboardView.swift
//  lms_project
//
//  TAB 1 — Enhanced Admin Dashboard
//  Provides high-level overview: KPIs, funnel, alerts, activity, SLA, quick actions.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int
    
    // MARK: - Mock executive data
    private let portfolioValue    = "₹2,450 Cr"
    private let collectionEff     = 94.7
    private let npaRatio          = 2.4
    private let dailyDisbursement: [Double] = [12.4, 15.1, 9.8, 18.2, 14.6, 22.0, 16.8]
    private let weeklyDisbursement: [Double] = [72.0, 85.0, 68.5, 91.2]
    
    @State private var refreshTimer: Timer?
    @State private var lastRefresh = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        greetingBar
                        topSummaryCards
                        metricsSection
                        applicationFunnel
                        alertsFlagsPanel
                        recentActivityFeed
                        slaTrackingSection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
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
                dashboardVM.loadData()
                adminVM.loadData()
                loansVM.loadData()
                startAutoRefresh()
            }
            .onDisappear { stopAutoRefresh() }
        }
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            lastRefresh = Date()
            dashboardVM.loadData()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Greeting Bar
    
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Welcome, \(authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Admin")")
                    .font(Theme.Typography.titleLarge)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "building.2")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(authVM.currentUser?.branch ?? "Head Office")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Updated \(lastRefresh.relativeFormatted)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }
    
    // MARK: - Top Summary Cards
    
    private var topSummaryCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            DashboardKPICard(
                label: "Total Loan Value",
                value: portfolioValue,
                icon: "building.columns.fill",
                color: Theme.Colors.primary,
                trend: "+4.2%",
                trendPositive: true,
                colorScheme: colorScheme
            )
            
            DashboardKPICard(
                label: "Active Loans",
                value: "\(dashboardVM.applications.filter { $0.status != .rejected }.count)",
                icon: "doc.text.fill",
                color: Theme.Colors.success,
                trend: "+3",
                trendPositive: true,
                colorScheme: colorScheme
            )
            
            DashboardKPICard(
                label: "Closed Loans",
                value: "\(dashboardVM.applications.filter { $0.status == .rejected }.count + 24)",
                icon: "checkmark.circle.fill",
                color: Theme.Colors.neutral,
                trend: "+2",
                trendPositive: true,
                colorScheme: colorScheme
            )
        }
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Key Metrics", icon: "chart.xyaxis.line")
            
            // Disbursement Chart
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // High-Fid Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Disbursement")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Transaction volume across the week")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("₹124.5k")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.primary)
                        HStack(spacing: 4) {
                            Text("↗")
                            Text("12.4%")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.green)
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)
                
                PremiumLineChart(
                    data: dailyDisbursement,
                    labels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
                    accentColor: Theme.Colors.primary,
                    showPoints: true
                )
                .frame(height: 180)
            }
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.horizontal, Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
            
            // Collection Efficiency & NPA
            HStack(spacing: Theme.Spacing.md) {
                metricGaugeCard(
                    title: "Collection Efficiency",
                    value: collectionEff,
                    suffix: "%",
                    color: Theme.Colors.success,
                    icon: "checkmark.seal.fill"
                )
                metricGaugeCard(
                    title: "NPA Ratio",
                    value: npaRatio,
                    suffix: "%",
                    color: Theme.Colors.critical,
                    icon: "exclamationmark.triangle.fill"
                )
            }
        }
    }
    
    private func dayLabel(_ index: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days[index % days.count]
    }
    
    private func metricGaugeCard(title: String, value: Double, suffix: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(suffix)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(color.opacity(0.7))
            }
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(value / 100, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Application Funnel
    
    private var applicationFunnel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Application Funnel", icon: "arrow.right.arrow.left")
            
            let submitted = loansVM.totalCount
            let underReview = loansVM.underReviewCount
            let approved = loansVM.approvedCount
            
            VStack(spacing: Theme.Spacing.sm) {
                funnelBar(label: "Submitted", count: submitted, total: max(submitted, 1), color: Theme.Colors.primary)
                funnelBar(label: "Under Review", count: underReview, total: max(submitted, 1), color: Theme.Colors.warning)
                funnelBar(label: "Approved", count: approved, total: max(submitted, 1), color: Theme.Colors.success)
            }
            .padding(Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    private func funnelBar(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Theme.Typography.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(total), height: 10)
                }
            }
            .frame(height: 10)
        }
    }
    
    // MARK: - Alerts & Flags Panel
    
    private var alertsFlagsPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Alerts & Flags", icon: "bell.badge")
            
            VStack(spacing: 0) {
                alertFlagRow(
                    icon: "percent",
                    label: "High FOIR Cases",
                    detail: "3 applications with FOIR > 50%",
                    count: "3",
                    color: Theme.Colors.warning
                )
                Divider().padding(.leading, Theme.Spacing.md)
                alertFlagRow(
                    icon: "chart.bar.fill",
                    label: "Low CIBIL Approvals",
                    detail: "2 approved with CIBIL < 650",
                    count: "2",
                    color: Theme.Colors.warning
                )
                Divider().padding(.leading, Theme.Spacing.md)
                alertFlagRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Fraud Flags",
                    detail: "1 suspicious application detected",
                    count: "1",
                    color: Theme.Colors.critical
                )
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    private func alertFlagRow(icon: String, label: String, detail: String, count: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(count)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
    
    // MARK: - Recent Activity Feed
    
    private var recentActivityFeed: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Activity", icon: "clock.arrow.circlepath")
            
            VStack(spacing: 0) {
                activityRow(
                    icon: "checkmark.circle.fill",
                    label: "Loan APP-2024-006 approved",
                    actor: "Deepak Mehta",
                    time: Date().addingTimeInterval(-1800),
                    color: Theme.Colors.success
                )
                Divider().padding(.leading, 48)
                activityRow(
                    icon: "xmark.circle.fill",
                    label: "Loan APP-2024-010 rejected",
                    actor: "Sunita Patel",
                    time: Date().addingTimeInterval(-5400),
                    color: Theme.Colors.critical
                )
                Divider().padding(.leading, 48)
                activityRow(
                    icon: "indianrupeesign.circle.fill",
                    label: "₹42L disbursed for APP-2024-003",
                    actor: "System",
                    time: Date().addingTimeInterval(-10800),
                    color: Theme.Colors.primary
                )
                Divider().padding(.leading, 48)
                activityRow(
                    icon: "arrow.up.circle.fill",
                    label: "APP-2024-005 escalated to Admin",
                    actor: "Neha Kapoor",
                    time: Date().addingTimeInterval(-18000),
                    color: Theme.Colors.warning
                )
                Divider().padding(.leading, 48)
                activityRow(
                    icon: "person.badge.plus",
                    label: "New user Ravi Shankar created",
                    actor: "Sunita Patel",
                    time: Date().addingTimeInterval(-43200),
                    color: Theme.Colors.secondary
                )
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    private func activityRow(icon: String, label: String, actor: String, time: Date, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typography.subheadline)
                HStack(spacing: Theme.Spacing.sm) {
                    Text("by \(actor)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(time.relativeFormatted)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
    
    // MARK: - SLA Tracking
    
    private var slaTrackingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "SLA Tracking", icon: "timer")
            
            let slaData: [(stage: String, avgHours: Double, targetHours: Double)] = [
                ("Application Intake",  4.2,  8.0),
                ("Document Review",     12.5, 24.0),
                ("Risk Assessment",     6.8,  8.0),
                ("Manager Approval",    18.4, 16.0),
                ("Disbursement",        8.0,  12.0),
            ]
            
            VStack(spacing: 0) {
                ForEach(slaData, id: \.stage) { item in
                    let isDelayed = item.avgHours > item.targetHours
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: isDelayed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(isDelayed ? Theme.Colors.critical : Theme.Colors.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.stage)
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(isDelayed ? Theme.Colors.critical : .primary)
                            Text("Avg: \(String(format: "%.1f", item.avgHours))h / Target: \(String(format: "%.0f", item.targetHours))h")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isDelayed {
                            GenericBadge(text: "Delayed", color: Theme.Colors.critical)
                        } else {
                            GenericBadge(text: "On Track", color: Theme.Colors.success)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 12)
                    .background(isDelayed ? Theme.Colors.critical.opacity(0.04) : Color.clear)
                    
                    if item.stage != slaData.last?.stage {
                        Divider().padding(.leading, Theme.Spacing.md)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    // Removed Quick Actions
}
    
// MARK: - Dashboard KPI Card
    
    private struct DashboardKPICard: View {
        let label: String
        let value: String
        let icon: String
        let color: Color
        let trend: String
        let trendPositive: Bool
        let colorScheme: ColorScheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 30, height: 30)
                        .background(color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    Spacer()
                    Text(trend)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trendPositive ? Theme.Colors.success : Theme.Colors.critical)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 130)
            .cardStyle(colorScheme: colorScheme)
        }
        
    }

