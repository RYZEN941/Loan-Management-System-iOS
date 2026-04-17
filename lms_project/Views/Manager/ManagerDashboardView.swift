//
//  ManagerDashboardView.swift
//  lms_project
//

import SwiftUI

struct ManagerDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        greetingBar
                        kpiStrip
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
            }
        }
    }
    
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greetingText)
                    .font(Theme.Typography.titleLarge)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "building.2")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(authVM.currentUser?.branch ?? "Branch")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
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
    
    // MARK: - KPI Strip (with NPA Rate)
    
    private var kpiStrip: some View {
        KPIStripView(cards: [
            KPIData(title: "Pending Approvals", value: "\(dashboardVM.pendingApprovals)",
                    icon: "checkmark.circle.fill", color: Theme.Colors.warning),
            KPIData(title: "Approved This Month", value: "\(dashboardVM.approvedThisMonth)",
                    icon: "checkmark.seal.fill", color: Theme.Colors.success),
            KPIData(title: "Portfolio Value", value: dashboardVM.totalPortfolioValue.compactFormatted,
                    icon: "chart.line.uptrend.xyaxis", color: Theme.Colors.primary),
            KPIData(title: "NPA Rate", value: "2.4%",
                    icon: "exclamationmark.triangle.fill", color: Theme.Colors.critical,
                    subtitle: "↓ 0.3% from last month")
        ])
    }
    
    // MARK: - Pending Approvals
    
    private var pendingApprovalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Pending Approvals", icon: "clock.fill")
            
            let recommended = dashboardVM.applications.filter { $0.status == .recommended }
            
            if recommended.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No pending approvals")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                    Spacer()
                }
                .cardStyle(colorScheme: colorScheme)
            } else {
                VStack(spacing: 0) {
                    ForEach(recommended) { app in
                        ApplicationRow(application: app, isSelected: false)
                        if app.id != recommended.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Decisions", icon: "clock.arrow.circlepath")
            
            let decided = dashboardVM.applications.filter { $0.status == .approved || $0.status == .rejected }
            
            if decided.isEmpty {
                HStack {
                    Spacer()
                    Text("No recent decisions")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.lg)
                    Spacer()
                }
                .cardStyle(colorScheme: colorScheme)
            } else {
                VStack(spacing: 0) {
                    ForEach(decided) { app in
                        ApplicationRow(application: app, isSelected: false)
                        if app.id != decided.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }
}
