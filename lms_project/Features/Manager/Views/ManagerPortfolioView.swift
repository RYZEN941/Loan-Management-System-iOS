//
//  ManagerPortfolioView.swift
//  lms_project
//

import SwiftUI

struct ManagerPortfolioView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool
    
    @State private var timeRange: String = "6M"
    
    var body: some View {
        NavigationStack {
            ZStack {
                ManagerTheme.Colors.background(colorScheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    globalFilterBar
                    
                    if dashboardVM.portfolioLoanType != nil || dashboardVM.portfolioRisk != nil || dashboardVM.portfolioStatus != nil {
                        filterActiveIndicator
                    }
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            portfolioSummary
                            dynamicInsightsSection
                            loanDistribution
                            riskOverview
                            npaSection
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
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

    private var globalFilterBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio Analysis")
                    .font(Theme.Typography.titleLarge)
                Text("Real-time branch metrics and distribution")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Menu {
                Button("All Loans") { dashboardVM.portfolioLoanType = nil }
                ForEach(LoanType.allCases) { type in
                    Button(type.displayName) { dashboardVM.portfolioLoanType = type }
                }
            } label: {
                HStack {
                    Text(dashboardVM.portfolioLoanType?.displayName ?? "All Loans")
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ManagerTheme.Colors.surface(colorScheme))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1))
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(ManagerTheme.Colors.background(colorScheme))
    }

    private var filterActiveIndicator: some View {
        HStack {
            if let type = dashboardVM.portfolioLoanType {
                Text("Viewing: **\(type.displayName)**")
                    .font(.system(size: 12))
                Button {
                    dashboardVM.portfolioLoanType = nil
                } label: {
                    HStack(spacing: 4) {
                        Text("Reset")
                        Image(systemName: "xmark.circle.fill")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
    }

    private var dynamicInsightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text(insightText)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(Theme.Radius.md)
        }
    }

    private var insightText: String {
        if let type = dashboardVM.portfolioLoanType {
            return "\(type.displayName) metrics are stable with 0.5% growth this month."
        } else {
            return "Personal loans represent the highest risk segment currently."
        }
    }
    
    private var portfolioSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Summary", icon: "chart.pie.fill")
                .description("Key metrics of total loan volume and average disbursement value.")
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: Theme.Spacing.md) {
                let highRiskCount = dashboardVM.filteredPortfolioApplications.filter { $0.riskLevel == .high }.count
                let totalCount = max(1, dashboardVM.filteredPortfolioApplications.count)
                let highRiskPct = (Double(highRiskCount) / Double(totalCount)) * 100
                
                KPICard(title: "High Risk Distribution", value: String(format: "%.1f%%", highRiskPct),
                        icon: "shield.fill", color: Theme.Colors.critical) {
                    applicationsVM.filterRisk = .high
                    applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                    selectedTab = 1
                }
                
                KPICard(title: "NPA Rate", value: "1.2%",
                        icon: "exclamationmark.shield.fill", color: Theme.Colors.adaptiveCritical(colorScheme))
                
                KPICard(title: "Avg. Loan Size", value: avgLoanSize.compactFormatted,
                        icon: "chart.bar.fill", color: Theme.Colors.adaptiveWarning(colorScheme),
                        subtitle: "↑ 2.4% vs last period")
            }
        }
    }
    
    private var totalLoanValue: Double {
        dashboardVM.filteredPortfolioApplications.reduce(0) { $0 + $1.loan.amount }
    }
    
    private var avgLoanSize: Double {
        guard !dashboardVM.filteredPortfolioApplications.isEmpty else { return 0 }
        return totalLoanValue / Double(dashboardVM.filteredPortfolioApplications.count)
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
                        Text("Based on \(dashboardVM.portfolioLoanType?.displayName ?? "All Loans")")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Picker("Time Range", selection: $timeRange) {
                        Text("3M").tag("3M")
                        Text("6M").tag("6M")
                        Text("12M").tag("12M")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                
                PremiumLineChart(
                    data: [3200000, 3800000, 3500000, 4200000, 4800000, 5100000],
                    labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
                    accentColor: ManagerTheme.Colors.primary(colorScheme),
                    showPoints: true,
                    unit: "cr"
                )
                .frame(height: 140)
            }
            .padding(Theme.Spacing.lg)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
            )
        }
    }
    
    private var riskOverview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Risk Analysis", icon: "shield.fill")
                .description("Categorical breakdown of applications based on calculated risk profiles.")
            
            VStack(spacing: Theme.Spacing.md) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                    let total = max(1, Double(dashboardVM.filteredPortfolioApplications.count))
                    let lowCount = Double(dashboardVM.filteredPortfolioApplications.filter { $0.riskLevel == .low }.count)
                    let medCount = Double(dashboardVM.filteredPortfolioApplications.filter { $0.riskLevel == .medium }.count)
                    let highCount = Double(dashboardVM.filteredPortfolioApplications.filter { $0.riskLevel == .high }.count)
                    
                    riskDistCard(label: "Low %", value: String(format: "%.0f%%", (lowCount/total)*100), color: Theme.Colors.adaptiveSuccess(colorScheme)) {
                        applicationsVM.filterRisk = .low
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                    riskDistCard(label: "Med %", value: String(format: "%.0f%%", (medCount/total)*100), color: ManagerTheme.Colors.primary(colorScheme)) {
                        applicationsVM.filterRisk = .medium
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                    riskDistCard(label: "High %", value: String(format: "%.0f%%", (highCount/total)*100), color: Theme.Colors.adaptiveCritical(colorScheme)) {
                        applicationsVM.filterRisk = .high
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: Theme.Spacing.md) {
                    ForEach(RiskLevel.allCases) { risk in
                        let count = dashboardVM.filteredPortfolioApplications.filter { $0.riskLevel == risk }.count
                        riskCard(level: risk, count: count) {
                            applicationsVM.filterRisk = risk
                            applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                            selectedTab = 1
                        }
                    }
                }
            }
        }
    }
    
    private func riskDistCard(label: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(label).font(Theme.Typography.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .cornerRadius(Theme.Radius.md)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
    
    private func riskCard(level: RiskLevel, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
            .background(ManagerTheme.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var npaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "NPA Analysis", icon: "exclamationmark.shield.fill")
            
            if dashboardVM.portfolioLoanType == nil {
                VStack(spacing: 0) {
                    npaRow(type: .personalLoan, value: "2.1%", color: .red)
                    Divider()
                    npaRow(type: .homeLoan, value: "0.4%", color: .green)
                    Divider()
                    npaRow(type: .businessLoan, value: "3.2%", color: .red)
                    Divider()
                    npaRow(type: .vehicleLoan, value: "1.5%", color: .orange)
                }
                .background(ManagerTheme.Colors.surface(colorScheme))
                .cornerRadius(Theme.Radius.lg)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1))
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("NPA Status for \(dashboardVM.portfolioLoanType?.displayName ?? "")")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text("NPA: \(npaValueFor(dashboardVM.portfolioLoanType))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                    }
                    Spacer()
                }
                .padding()
                .background(ManagerTheme.Colors.surface(colorScheme))
                .cornerRadius(Theme.Radius.lg)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1))
            }
        }
    }

    private func npaValueFor(_ type: LoanType?) -> String {
        switch type {
        case .personalLoan: return "2.1%"
        case .homeLoan: return "0.4%"
        case .businessLoan: return "3.2%"
        case .vehicleLoan: return "1.5%"
        default: return "1.2%"
        }
    }

    private func npaRow(type: LoanType, value: String, color: Color) -> some View {
        Button {
            withAnimation {
                dashboardVM.portfolioLoanType = type
                dashboardVM.loadData() // Refresh page simulation
            }
        } label: {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(type.displayName)
                    .font(Theme.Typography.subheadline)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

