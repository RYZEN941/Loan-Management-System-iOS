//
//  ManagerDashboardView.swift
//  lms_project
//
//  Manager Dashboard: Premium FinTech UI with gradient header and team portfolio oversight.
//

import SwiftUI

struct ManagerDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                ManagerTheme.Colors.background(colorScheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    greetingBar
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            priorityQueueSection
                            recommendedActionsSection
                            riskSnapshotSection
                            portfolioHealthMinimal
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
                        .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
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
    
    // MARK: - Navigation Helpers
    private func navigateToApprovals(status: ApplicationStatus? = nil, risk: RiskLevel? = nil, sla: SLAStatus? = nil, highValue: Bool = false) {
        applicationsVM.filterStatus = status
        applicationsVM.filterRisk = risk
        applicationsVM.filterSLA = sla
        applicationsVM.filterHighValue = highValue
        selectedTab = 1
    }

    private func navigateToPortfolio(type: LoanType? = nil, risk: RiskLevel? = nil, status: ApplicationStatus? = nil) {
        dashboardVM.portfolioLoanType = type
        dashboardVM.portfolioRisk = risk
        dashboardVM.portfolioStatus = status
        selectedTab = 2
    }

    // MARK: - Priority Queue
    private var priorityQueueSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Priority Queue", icon: "exclamationmark.triangle.fill")
                .description("Actionable metrics requiring immediate manager attention.")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                KPIDataCard(title: "Pending", value: "12",
                        icon: "clock.fill", color: Theme.Colors.adaptiveWarning(colorScheme),
                        showCTA: true) {
                    navigateToApprovals(status: .underReview)
                }
                
                KPIDataCard(title: "Overdue", value: "3",
                        icon: "timer", color: Theme.Colors.adaptiveCritical(colorScheme),
                        showCTA: true) {
                    navigateToApprovals(sla: .overdue)
                }
                
                KPIDataCard(title: "High Risk", value: "5",
                        icon: "shield.fill", color: Theme.Colors.adaptiveCritical(colorScheme),
                        showCTA: true) {
                    navigateToApprovals(risk: .high)
                }
                
                KPIDataCard(title: "Near SLA", value: "2",
                        icon: "clock.badge.exclamationmark", color: Theme.Colors.adaptiveWarning(colorScheme),
                        showCTA: true) {
                    navigateToApprovals(sla: .urgent)
                }
                
                KPIDataCard(title: "High Value", value: "4",
                        icon: "indianrupeesign.circle.fill", color: ManagerTheme.Colors.primary(colorScheme),
                        showCTA: true) {
                    navigateToApprovals(highValue: true)
                }
            }
        }
    }

    // MARK: - Recommended Actions
    private var recommendedActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14, weight: .bold))
                
                HStack(spacing: 16) {
                    actionPill("3 high-risk applications")
                    actionPill("2 nearing SLA breach")
                    actionPill("Personal loan NPA rising")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(Theme.Radius.md)
        }
    }

    private func actionPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(.orange).frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func actionItem(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Risk Snapshot
    private var riskSnapshotSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Risk Snapshot", icon: "chart.pie.fill")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                KPIDataCard(title: "High Risk Pending", value: "3",
                        icon: "shield.exclamationmark.fill", color: Theme.Colors.adaptiveCritical(colorScheme)) {
                    navigateToApprovals(status: .underReview, risk: .high)
                }
                
                let approvedHighRiskCount = dashboardVM.applications.filter { $0.riskLevel == .high && $0.status == .approved }.count
                if approvedHighRiskCount > 0 {
                    KPIDataCard(title: "High Risk Approved", value: "\(approvedHighRiskCount)",
                            icon: "shield.checkmark.fill", color: Theme.Colors.adaptiveSuccess(colorScheme)) {
                        navigateToApprovals(status: .approved, risk: .high)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle().fill(Theme.Colors.adaptiveSuccess(colorScheme).opacity(0.12)).frame(width: 34, height: 34)
                                Image(systemName: "shield.checkmark.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.adaptiveSuccess(colorScheme))
                            }
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No high-risk approved applications").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ManagerTheme.Colors.surface(colorScheme))
                    .cornerRadius(Theme.Radius.lg)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Portfolio Health
    private var portfolioHealthMinimal: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Health", icon: "heart.text.square.fill")
            
            HStack(spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("NPA %").font(Theme.Typography.caption).foregroundStyle(.secondary)
                        Text("1.2%").font(Theme.Typography.headline).foregroundStyle(Theme.Colors.adaptiveSuccess(colorScheme))
                    }
                    Spacer()
                }
                .padding()
                .background(ManagerTheme.Colors.surface(colorScheme))
                .cornerRadius(Theme.Radius.md)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Portfolio Size").font(Theme.Typography.caption).foregroundStyle(.secondary)
                        Text("₹4.2Cr").font(Theme.Typography.headline)
                    }
                    Spacer()
                }
                .padding()
                .background(ManagerTheme.Colors.surface(colorScheme))
                .cornerRadius(Theme.Radius.md)
            }
        }
    }
    
}

// MARK: - Local Components

struct KPIDataCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var showCTA: Bool = false
    var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    if showCTA {
                        Text("Review Now →")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                            .padding(.top, 4)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .cornerRadius(Theme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
