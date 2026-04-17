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
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        portfolioSummary
                        loanDistribution
                        riskOverview
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle("Portfolio & Reports")
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
            
            HStack(spacing: Theme.Spacing.md) {
                KPICard(title: "Total Applications", value: "\(dashboardVM.applications.count)",
                        icon: "doc.text.fill", color: Theme.Colors.primary)
                KPICard(title: "Total Value", value: totalLoanValue.compactFormatted,
                        icon: "indianrupeesign.circle.fill", color: Theme.Colors.success,
                        subtitle: "Across all applications")
                KPICard(title: "Avg. Loan Size", value: avgLoanSize.compactFormatted,
                        icon: "chart.bar.fill", color: Theme.Colors.warning)
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
            SectionHeader(title: "Loan Type Distribution", icon: "chart.bar.xaxis")
            
            let distribution = Dictionary(grouping: dashboardVM.applications, by: { $0.loan.type })
            
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(LoanType.allCases) { type in
                    let apps = distribution[type] ?? []
                    if !apps.isEmpty {
                        distributionRow(
                            label: type.displayName,
                            count: apps.count,
                            total: dashboardVM.applications.count,
                            value: apps.reduce(0) { $0 + $1.loan.amount }
                        )
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    private func distributionRow(label: String, count: Int, total: Int, value: Double) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count) apps")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.quaternary)
                Text(value.compactFormatted)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.primary)
                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(total, 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
    
    private var riskOverview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Risk Overview", icon: "exclamationmark.shield")
            
            HStack(spacing: Theme.Spacing.md) {
                ForEach(RiskLevel.allCases) { risk in
                    let count = dashboardVM.applications.filter { $0.riskLevel == risk }.count
                    riskCard(level: risk, count: count)
                }
            }
        }
    }
    
    private func riskCard(level: RiskLevel, count: Int) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Circle().fill(level.color).frame(width: 8, height: 8)
                Text(level.displayName)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("applications")
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }
    
}

