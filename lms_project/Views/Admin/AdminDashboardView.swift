//
//  AdminDashboardView.swift
//  lms_project
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var adminVM: AdminViewModel
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
                        systemAlertsSection
                        userSummarySection
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
                adminVM.loadData()
            }
        }
    }
    
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
        }
        .padding(.top, Theme.Spacing.sm)
    }
    
    private var kpiStrip: some View {
        KPIStripView(cards: [
            KPIData(title: "Active Users", value: "\(adminVM.activeUsersCount)",
                    icon: "person.3.fill", color: Theme.Colors.primary),
            KPIData(title: "Processed Today", value: "\(dashboardVM.processedTodayCount)",
                    icon: "doc.text.fill", color: Theme.Colors.success),
            KPIData(title: "Total Applications", value: "\(dashboardVM.applications.count)",
                    icon: "tray.full.fill", color: Theme.Colors.warning)
        ])
    }
    
    // MARK: - System Alerts (replaced System Healthy)
    
    private var systemAlertsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "System Alerts", icon: "bell.badge")
            
            VStack(spacing: 0) {
                alertRow(icon: "banknote", label: "Pending Disbursals", value: "3", color: Theme.Colors.warning)
                Divider().padding(.leading, Theme.Spacing.md)
                alertRow(icon: "xmark.shield", label: "Failed Verifications", value: "2", color: Theme.Colors.critical)
                Divider().padding(.leading, Theme.Spacing.md)
                alertRow(icon: "exclamationmark.triangle", label: "Rule Conflicts", value: "1", color: Theme.Colors.warning)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    private func alertRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
    }
    
    // MARK: - User Summary
    
    private var userSummarySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "User Summary", icon: "person.3")
            
            HStack(spacing: Theme.Spacing.md) {
                ForEach(UserRole.allCases) { role in
                    let count = adminVM.usersByRole[role] ?? 0
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: role.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.Colors.primary)
                        Text("\(count)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(role.displayName + "s")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .cardStyle(colorScheme: colorScheme)
                }
            }
        }
    }
}
