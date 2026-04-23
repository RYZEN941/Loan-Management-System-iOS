//
//  ManagerPortfolioView.swift
//  lms_project
//

import SwiftUI

struct ManagerPortfolioView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Simple Elegant Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Portfolio Analysis")
                                    .font(Theme.Typography.titleLarge)
                                Text("Real-time branch metrics and distribution")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                    }
                    .background(Theme.Colors.adaptiveBackground(colorScheme))
                    .foregroundStyle(.primary)
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            portfolioSummary
                            loanDistribution
                            riskOverview
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Portfolio")
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
    
    private var portfolioSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Summary", icon: "chart.pie.fill")
                .description("Key metrics of total loan volume and average disbursement value.")
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: Theme.Spacing.md) {
                KPICard(title: "Total Applications", value: "\(dashboardVM.applications.count)",
                        icon: "doc.text.fill", color: Theme.Colors.adaptivePrimary(colorScheme))
                KPICard(title: "Total Value", value: totalLoanValue.compactFormatted,
                        icon: "indianrupeesign.circle.fill", color: Theme.Colors.adaptiveSuccess(colorScheme),
                        subtitle: "Across all applications")
                KPICard(title: "Avg. Loan Size", value: avgLoanSize.compactFormatted,
                        icon: "chart.bar.fill", color: Theme.Colors.adaptiveWarning(colorScheme))
            }
        }
    }
    
    private var totalLoanValue: Double {
        dashboardVM.applications.reduce(0) { $0 + $1.loan.amount }
    }
    
    private var avgLoanSize: Double {
        guard !dashboardVM.applications.isEmpty else { return 0 }
        return totalLoanValue / Double(dashboardVM.applications.count)
    }
    
    private var loanDistribution: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Disbursement Trend", icon: "chart.line.uptrend.xyaxis")
                .description("Analysis of loan approvals and disbursement performance over time.")
            
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disbursements")
                            .font(Theme.Typography.headline)
                        Text("Past 6 months")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+14.2%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.adaptiveSuccess(colorScheme))
                }
                
                PremiumLineChart(
                    data: [3200000, 3800000, 3500000, 4200000, 4800000, 5100000],
                    labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
                    accentColor: Theme.Colors.adaptivePrimary(colorScheme),
                    showPoints: true,
                    unit: "cr"
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
    
    private var riskOverview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Risk Analysis", icon: "shield.fill")
                .description("Categorical breakdown of applications based on calculated risk profiles.")
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: Theme.Spacing.md) {
                ForEach(RiskLevel.allCases) { risk in
                    let count = dashboardVM.applications.filter { $0.riskLevel == risk }.count
                    riskCard(level: risk, count: count)
                }
            }
        }
    }
    
    private func riskCard(level: RiskLevel, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(level.adaptiveColor(colorScheme))
                Text(level.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("applications")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}
