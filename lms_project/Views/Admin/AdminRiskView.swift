//
//  AdminRiskView.swift
//  lms_project
//
//  Admin Tab 5 — Risk & Decisioning
//  NEW FILE: Does not modify any existing views.
//

import SwiftUI

// MARK: - Risk & Decisioning View

struct AdminRiskView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var riskFilter: RiskFilter = .all
    @State private var selectedTab = 0

    enum RiskFilter: String, CaseIterable {
        case all = "All"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    // MARK: - Dummy Data

    private let foirData: [(label: String, value: Double)] = [
        ("Home Loan",      0.38),
        ("Personal Loan",  0.52),
        ("Business Loan",  0.44),
        ("Vehicle Loan",   0.31),
        ("Education Loan", 0.28),
    ]

    private let ltvData: [(label: String, value: Double)] = [
        ("Home Loan",    0.72),
        ("Vehicle Loan", 0.65),
        ("Business Loan",0.55),
        ("Education Loan",0.40),
        ("Personal Loan", 0.0),  // unsecured
    ]

    private let flaggedApps: [FlaggedApplication] = [
        FlaggedApplication(id: "APP-2024-031", borrower: "Ramesh Gupta",   loanType: "Personal Loan", amount: "₹5.5L",  riskScore: 88, risk: .high,   flag: "CIBIL 542, DTI 61%"),
        FlaggedApplication(id: "APP-2024-047", borrower: "Kavitha Nair",   loanType: "Business Loan", amount: "₹18L",   riskScore: 76, risk: .high,   flag: "Multiple active loans"),
        FlaggedApplication(id: "APP-2024-055", borrower: "Ajay Sharma",    loanType: "Home Loan",     amount: "₹42L",   riskScore: 61, risk: .medium, flag: "LTV 84% exceeds cap"),
        FlaggedApplication(id: "APP-2024-062", borrower: "Priya Menon",    loanType: "Vehicle Loan",  amount: "₹8.2L",  riskScore: 54, risk: .medium, flag: "Income verification gap"),
        FlaggedApplication(id: "APP-2024-071", borrower: "Suresh Pillai",  loanType: "Education Loan",amount: "₹3.8L",  riskScore: 38, risk: .low,    flag: "Document mismatch"),
    ]

    private var filteredApps: [FlaggedApplication] {
        switch riskFilter {
        case .all:    return flaggedApps
        case .high:   return flaggedApps.filter { $0.risk == .high }
        case .medium: return flaggedApps.filter { $0.risk == .medium }
        case .low:    return flaggedApps.filter { $0.risk == .low }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Section Picker
                    Picker("Section", selection: $selectedTab) {
                        Text("Analytics").tag(0)
                        Text("Fraud Engine").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            if selectedTab == 0 {
                                foirSection
                                ltvSection
                                riskThresholdSummary
                            } else {
                                fraudEngineSection
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Risk & Decisioning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
        }
    }

    // MARK: - FOIR Section

    private var foirSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "FOIR Ratio by Product", icon: "chart.bar")
            Text("Fixed Obligation to Income Ratio — target ≤ 50%")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(foirData, id: \.label) { item in
                    RiskBarRow(
                        label: item.label,
                        value: item.value,
                        valueText: "\(Int(item.value * 100))%",
                        warningThreshold: 0.50,
                        dangerThreshold: 0.60,
                        colorScheme: colorScheme
                    )
                    if item.label != foirData.last?.label {
                        Divider().padding(.leading, Theme.Spacing.md)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - LTV Section

    private var ltvSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "LTV Ratio by Product", icon: "percent")
            Text("Loan to Value Ratio — target ≤ 80%")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(ltvData, id: \.label) { item in
                    if item.value > 0 {
                        RiskBarRow(
                            label: item.label,
                            value: item.value,
                            valueText: "\(Int(item.value * 100))%",
                            warningThreshold: 0.70,
                            dangerThreshold: 0.80,
                            colorScheme: colorScheme
                        )
                        if item.label != ltvData.last?.label {
                            Divider().padding(.leading, Theme.Spacing.md)
                        }
                    } else {
                        HStack {
                            Text(item.label)
                                .font(Theme.Typography.subheadline)
                            Spacer()
                            Text("Unsecured")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 12)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - Risk Threshold Summary

    private var riskThresholdSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Current Risk Rules", icon: "shield.lefthalf.filled")

            VStack(spacing: Theme.Spacing.sm) {
                ruleRow(label: "Min CIBIL Score",    value: "\(adminVM.minCIBILScore)",   icon: "chart.line.uptrend.xyaxis")
                ruleRow(label: "Max DTI Ratio",      value: "\(Int(adminVM.maxDTIRatio * 100))%", icon: "arrow.left.arrow.right")
                ruleRow(label: "Max Loan Amount",    value: adminVM.maxLoanAmount.compactFormatted, icon: "indianrupeesign.circle")
                ruleRow(label: "Auto-Flag High Risk", value: "Enabled",                   icon: "flag.fill")
            }
        }
    }

    private func ruleRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 22)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text(value)
                .font(Theme.Typography.mono)
                .foregroundStyle(Theme.Colors.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Fraud Engine

    private var fraudEngineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Flagged Applications", icon: "shield.slash")
                Spacer()
                Text("\(filteredApps.count) flagged")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Risk filter picker
            Picker("Risk Level", selection: $riskFilter) {
                ForEach(RiskFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            if filteredApps.isEmpty {
                emptyFraudState
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        FlaggedAppRow(app: app, colorScheme: colorScheme)
                        if app.id != filteredApps.last?.id {
                            Divider().padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }

            // Summary counts
            riskSummaryCounts
        }
    }

    private var emptyFraudState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.success)
            Text("No flags in this category")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xxl)
        .cardStyle(colorScheme: colorScheme)
    }

    private var riskSummaryCounts: some View {
        HStack(spacing: Theme.Spacing.md) {
            riskCountPill(label: "High", count: flaggedApps.filter { $0.risk == .high }.count, color: Theme.Colors.critical)
            riskCountPill(label: "Medium", count: flaggedApps.filter { $0.risk == .medium }.count, color: Theme.Colors.warning)
            riskCountPill(label: "Low", count: flaggedApps.filter { $0.risk == .low }.count, color: Theme.Colors.success)
        }
    }

    private func riskCountPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label + " Risk")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }
}

// MARK: - Risk Bar Row

private struct RiskBarRow: View {
    let label:              String
    let value:              Double
    let valueText:          String
    let warningThreshold:   Double
    let dangerThreshold:    Double
    let colorScheme:        ColorScheme

    private var barColor: Color {
        if value >= dangerThreshold  { return Theme.Colors.critical }
        if value >= warningThreshold { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(Theme.Typography.subheadline)
                Spacer()
                Text(valueText)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(value, 1.0), height: 6)
                    // threshold markers
                    Rectangle()
                        .fill(Theme.Colors.neutral.opacity(0.4))
                        .frame(width: 1.5, height: 10)
                        .offset(x: geo.size.width * warningThreshold - 0.75, y: -2)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Flagged App Row

private struct FlaggedAppRow: View {
    let app: FlaggedApplication
    let colorScheme: ColorScheme

    private var riskColor: Color {
        switch app.risk {
        case .high:   return Theme.Colors.critical
        case .medium: return Theme.Colors.warning
        case .low:    return Theme.Colors.success
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Risk score ring
            ZStack {
                Circle()
                    .stroke(riskColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: Double(app.riskScore) / 100)
                    .stroke(riskColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text("\(app.riskScore)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(riskColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(app.borrower)
                        .font(Theme.Typography.headline)
                    Spacer()
                    GenericBadge(text: app.risk.displayName, color: riskColor)
                }
                Text("\(app.id) · \(app.loanType) · \(app.amount)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(riskColor)
                    Text(app.flag)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(riskColor)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Data Models (local to this file)

private struct FlaggedApplication: Identifiable {
    let id:        String
    let borrower:  String
    let loanType:  String
    let amount:    String
    let riskScore: Int
    let risk:      RiskLevel
    let flag:      String
}
