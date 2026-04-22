//
//  ManagerDashboardView.swift
//  lms_project
//
//  Manager Dashboard: Premium FinTech UI with gradient header and team portfolio oversight.
//

import SwiftUI

struct ManagerDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Simple Elegant Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        greetingBar
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.bottom, Theme.Spacing.md)
                    }
                    .background(Theme.Colors.adaptiveBackground(colorScheme))
                    .foregroundStyle(.primary)
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            managerKPIStrip
                            portfolioTrendSection
                            pendingApprovalsWorkspace
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Manager Dashboard")
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
    
    // MARK: - Greeting
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greetingText)
                    .font(Theme.Typography.titleLarge)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.primary)
                    Text("Branch Operations Oversight")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.md)
    }
    
    private var greetingText: String {
        let name = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Manager"
        return "Welcome Back, \(name)"
    }
    
    // MARK: - Manager KPIs
    private var managerKPIStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Branch Portfolio", icon: "chart.bar.fill")
                .description("High-level overview of branch-wide loan activity and risk metrics.")
                .info { /* Info Action */ }
            
            KPIStripView(cards: [
                KPIData(title: "Pending Approvals", value: "12",
                        icon: "clock.fill", color: Theme.Colors.warning),
                KPIData(title: "Total Disbursed", value: "₹4.2Cr",
                        icon: "checkmark.circle.fill", color: Theme.Colors.primary),
                KPIData(title: "Portfolio Risk", value: "Low",
                        icon: "shield.fill", color: Theme.Colors.success)
            ])
        }
    }
    
    // MARK: - Portfolio Trend
    private var portfolioTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Growth", icon: "chart.line.uptrend.xyaxis")
                .description("Monthly disbursement volume and approval velocity.")
                .info { /* Info Action */ }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PremiumLineChart(
                    data: [20, 25, 22, 30, 28, 35, 42],
                    labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"],
                    accentColor: Theme.Colors.secondary,
                    showPoints: true,
                    unit: "loans"
                )
                .frame(height: 200)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Pending Approvals
    private var pendingApprovalsWorkspace: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Critical Approvals", icon: "exclamationmark.shield.fill")
                .description("High-priority applications requiring immediate manager oversight.")
                .info { /* Info Action */ }
            
            VStack(spacing: 0) {
                ForEach(dashboardVM.activeApplications.prefix(3)) { app in
                    ApplicationRow(application: app, isSelected: false, useMinimalStyle: true)
                        .onTapGesture {
                            withAnimation {
                                dashboardVM.selectApplication(app)
                                selectedTab = 1
                            }
                        }
                    if app.id != dashboardVM.activeApplications.prefix(3).last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
    }
}
