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
                applicationsVM.loadData()
            }
        }
    }

    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color, subtitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        let card = HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 44)

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .layoutPriority(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        
        if let action = action {
            return AnyView(Button(action: action) { card }.buttonStyle(.plain))
        } else {
            return AnyView(card)
        }
    }

    private var globalFilterBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio Analysis")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
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
            sectionLabel(title: "Portfolio Summary", icon: "chart.pie.fill")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                let highRiskCount = filteredPortfolioApplications.filter { $0.riskLevel == .high }.count
                let totalCount = max(1, filteredPortfolioApplications.count)
                let highRiskPct = (Double(highRiskCount) / Double(totalCount)) * 100
                
                summaryCard(title: "High Risk Distribution", value: String(format: "%.1f%%", highRiskPct),
                        icon: "shield.fill", color: Theme.Colors.adaptiveCritical(colorScheme)) {
                    applicationsVM.filterRisk = .high
                    applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                    selectedTab = 1
                }
                
                summaryCard(title: "Avg. Loan Size", value: avgLoanSize.compactFormatted,
                        icon: "chart.bar.fill", color: Theme.Colors.adaptiveWarning(colorScheme),
                        subtitle: "↑ 2.4% vs last period")
            }
        }
    }
    
    private var totalLoanValue: Double {
        filteredPortfolioApplications.reduce(0) { $0 + $1.loan.amount }
    }
    
    private var avgLoanSize: Double {
        guard !filteredPortfolioApplications.isEmpty else { return 0 }
        return totalLoanValue / Double(filteredPortfolioApplications.count)
    }
    
    private var loanDistribution: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel(title: "Disbursement Trend", icon: "chart.line.uptrend.xyaxis")
            
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
                    data: [3.2, 3.8, 3.5, 4.2, 4.8, 5.1],
                    labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
                    accentColor: ManagerTheme.Colors.primary(colorScheme),
                    showPoints: true,
                    unit: "Cr"
                )
                .frame(height: 180)
                .padding(.leading, 16)
            }
            .padding(Theme.Spacing.lg)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
            )
        }
    }
    
    private var riskOverview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel(title: "Risk Analysis", icon: "shield.fill")
            
            VStack(spacing: Theme.Spacing.md) {
                let lowCount = filteredPortfolioApplications.filter { $0.riskLevel == .low }.count
                let medCount = filteredPortfolioApplications.filter { $0.riskLevel == .medium }.count
                let highCount = filteredPortfolioApplications.filter { $0.riskLevel == .high }.count
                let total = max(1, Double(filteredPortfolioApplications.count))
                
                HStack(spacing: 8) {
                    summaryCard(title: "Low Risk", value: "\(lowCount)", icon: "shield.fill", color: Theme.Colors.adaptiveSuccess(colorScheme), subtitle: String(format: "%.0f%%", (Double(lowCount)/total)*100)) {
                        applicationsVM.filterRisk = .low
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                    summaryCard(title: "Med Risk", value: "\(medCount)", icon: "shield.fill", color: ManagerTheme.Colors.primary(colorScheme), subtitle: String(format: "%.0f%%", (Double(medCount)/total)*100)) {
                        applicationsVM.filterRisk = .medium
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                    summaryCard(title: "High Risk", value: "\(highCount)", icon: "shield.fill", color: Theme.Colors.adaptiveCritical(colorScheme), subtitle: String(format: "%.0f%%", (Double(highCount)/total)*100)) {
                        applicationsVM.filterRisk = .high
                        applicationsVM.filterLoanType = dashboardVM.portfolioLoanType
                        selectedTab = 1
                    }
                }
            }
        }
    }

    private var npaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel(title: "NPA Analysis", icon: "exclamationmark.shield.fill")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                npaCard(type: .personalLoan, value: "2.1%", color: Theme.Colors.adaptiveCritical(colorScheme))
                npaCard(type: .homeLoan, value: "0.4%", color: Theme.Colors.adaptiveSuccess(colorScheme))
                npaCard(type: .businessLoan, value: "3.2%", color: Theme.Colors.adaptiveCritical(colorScheme))
                npaCard(type: .vehicleLoan, value: "1.5%", color: Theme.Colors.adaptiveWarning(colorScheme))
            }
        }
    }

    private func npaCard(type: LoanType, value: String, color: Color) -> some View {
        summaryCard(title: type.displayName, value: value, icon: "percent", color: color) {
            withAnimation {
                dashboardVM.portfolioLoanType = type
                selectedTab = 2 // stay on portfolio to show filtered state
            }
        }
    }

    // MARK: - Live Portfolio Data (Backed by ApplicationsViewModel)
    private var filteredPortfolioApplications: [LoanApplication] {
        var result = applicationsVM.applications

        if let type = dashboardVM.portfolioLoanType {
            result = result.filter { $0.loan.type == type }
        }

        if let risk = dashboardVM.portfolioRisk {
            result = result.filter { $0.riskLevel == risk }
        }

        if let status = dashboardVM.portfolioStatus {
            result = result.filter { $0.status == status }
        }

        return result
    }
}

