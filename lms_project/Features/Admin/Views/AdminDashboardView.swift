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
                        actionRequiredSection
                        metricsSection
                        alertsFlagsPanel
                        recentActivityFeed
                        slaBreachTrendSection
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
    
    // MARK: - Action Required Section
    
    private var actionRequiredSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "ACTION REQUIRED", icon: "exclamationmark.triangle.fill")
            
            HStack(spacing: Theme.Spacing.sm) {
                actionRequiredCard(title: "SLA Breaches", count: "12", color: Theme.Colors.critical)
                actionRequiredCard(title: "Fraud Alerts", count: "3", color: Theme.Colors.critical)
                actionRequiredCard(title: "Policy Violations", count: "8", color: Theme.Colors.warning)
                actionRequiredCard(title: "Stuck Apps", count: "24", color: Theme.Colors.warning)
            }
        }
    }
    
    private func actionRequiredCard(title: String, count: String, color: Color) -> some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(count)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 90)
            .cardStyle(colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Key Metrics", icon: "chart.xyaxis.line")
            
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
    
    // MARK: - Alerts & Flags Panel
    
    private var alertsFlagsPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Alerts & Flags", icon: "bell.badge")
            
            HStack(spacing: Theme.Spacing.sm) {
                alertFlagCard(
                    icon: "percent",
                    label: "High FOIR Cases",
                    count: "3",
                    color: Theme.Colors.warning
                )
                alertFlagCard(
                    icon: "chart.bar.fill",
                    label: "Low CIBIL Approvals",
                    count: "2",
                    color: Theme.Colors.warning
                )
                alertFlagCard(
                    icon: "exclamationmark.triangle.fill",
                    label: "Fraud Flags",
                    count: "1",
                    color: Theme.Colors.critical
                )
            }
        }
    }
    
    private func alertFlagCard(icon: String, label: String, count: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(count).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(colorScheme: colorScheme)
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
    
    // MARK: - SLA Breach Trend
    
    private var slaBreachTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "SLA Breach Trend (Last 7 Days)", icon: "chart.line.downtrend.xyaxis")
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PremiumLineChart(
                    data: [5.0, 7.0, 4.0, 8.0, 3.0, 2.0, 4.0],
                    labels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
                    accentColor: Theme.Colors.critical,
                    showPoints: true
                )
                .frame(height: 120)
            }
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
        }
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

