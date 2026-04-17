//
//  AdminSystemControlView.swift
//  lms_project
//

import SwiftUI

struct AdminSystemControlView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var selectedSection = 0
    @State private var baseInterestRate = 8.5
    @State private var maxTenure = 30
    @State private var panOCRMatch = true
    @State private var coApplicantRule = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedSection) {
                        Text("Loan Config").tag(0)
                        Text("Doc Rules").tag(1)
                        Text("Risk Rules").tag(2)
                        Text("Audit Logs").tag(3)
                        Text("Alerts").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            switch selectedSection {
                            case 0: loanConfigsSection
                            case 1: documentRulesSection
                            case 2: riskRulesSection
                            case 3: auditLogsSection
                            case 4: systemAlertsSection
                            default: EmptyView()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("System Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                adminVM.loadData()
            }
        }
    }
    
    // MARK: - Global Loan Configuration
    
    private var loanConfigsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Global Loan Configuration", icon: "slider.horizontal.3")
            
            VStack(spacing: 0) {
                configRow(label: "Base Interest Rate") {
                    Text("\(baseInterestRate, specifier: "%.1f")%")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Max Tenure (Years)") {
                    Text("\(maxTenure)")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Maximum Loan Amount") {
                    Text(adminVM.maxLoanAmount.currencyFormatted)
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Auto-Assign to LO") {
                    Toggle("", isOn: $adminVM.autoAssignEnabled)
                        .labelsHidden()
                        .tint(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "SLA Duration") {
                    Text("7 days")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            .cardStyle(colorScheme: colorScheme)
            
            // Loan Types
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Active Loan Types")
                    .font(Theme.Typography.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                           spacing: Theme.Spacing.sm) {
                    ForEach(LoanType.allCases) { type in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Colors.success)
                            Text(type.displayName)
                                .font(Theme.Typography.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
            }
        }
    }
    
    // MARK: - Document Rules
    
    private var documentRulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Document Requirements", icon: "doc.badge.gearshape")
            
            VStack(spacing: 0) {
                configRow(label: "PAN OCR Match") {
                    Toggle("", isOn: $panOCRMatch)
                        .labelsHidden()
                        .tint(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Co-applicant Required (>₹15L)") {
                    Toggle("", isOn: $coApplicantRule)
                        .labelsHidden()
                        .tint(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Require Doc Verification") {
                    Toggle("", isOn: $adminVM.requireDocVerification)
                        .labelsHidden()
                        .tint(Theme.Colors.primary)
                }
            }
            .cardStyle(colorScheme: colorScheme)
            
            // Required docs per type
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Mandatory Documents")
                    .font(Theme.Typography.headline)
                
                VStack(spacing: 0) {
                    ForEach(DocumentType.allCases) { docType in
                        HStack {
                            Image(systemName: docType.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.Colors.primary)
                                .frame(width: 24)
                            Text(docType.displayName)
                                .font(Theme.Typography.subheadline)
                            Spacer()
                            GenericBadge(text: "Required", color: Theme.Colors.primary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 12)
                        
                        if docType != DocumentType.allCases.last {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Risk Rules
    
    private var riskRulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Risk Assessment Rules", icon: "exclamationmark.shield")
            
            VStack(spacing: 0) {
                configRow(label: "Minimum CIBIL Score") {
                    Text("\(adminVM.minCIBILScore)")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Maximum DTI Ratio") {
                    Text(adminVM.maxDTIRatio.percentFormatted)
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Colors.primary)
                }
                Divider().padding(.leading, Theme.Spacing.md)
                
                configRow(label: "Auto-Flag High Risk") {
                    Text("Enabled")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.success)
                }
            }
            .cardStyle(colorScheme: colorScheme)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Risk Level Thresholds")
                    .font(Theme.Typography.headline)
                
                VStack(spacing: Theme.Spacing.sm) {
                    thresholdRow(level: "Low", criteria: "CIBIL ≥ 750, DTI ≤ 30%", color: Theme.Colors.success)
                    thresholdRow(level: "Medium", criteria: "CIBIL 650-749, DTI 30-40%", color: Theme.Colors.warning)
                    thresholdRow(level: "High", criteria: "CIBIL < 650 or DTI > 40%", color: Theme.Colors.critical)
                }
            }
        }
    }
    
    private func thresholdRow(level: String, criteria: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(level)
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
                .frame(width: 70, alignment: .leading)
            Text(criteria)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
    
    // MARK: - Audit Logs
    
    private var auditLogsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Audit Logs", icon: "list.bullet.rectangle")
                Spacer()
                Button {
                    // Export CSV action
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 0) {
                ForEach(adminVM.auditLogs) { log in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.action)
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(log.timestamp.relativeFormatted)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(log.detail)
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text("by \(log.user)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 12)
                    
                    if log.id != adminVM.auditLogs.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }
    
    // MARK: - System Alerts (replaced System Healthy)
    
    private var systemAlertsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "System Alerts", icon: "bell.badge")
            
            VStack(spacing: Theme.Spacing.md) {
                alertCard(icon: "banknote", title: "Pending Disbursals",
                          description: "3 approved loans awaiting disbursal processing",
                          count: "3", color: Theme.Colors.warning)
                
                alertCard(icon: "xmark.shield", title: "Failed Verifications",
                          description: "2 OCR verification failures in last 24 hours",
                          count: "2", color: Theme.Colors.critical)
                
                alertCard(icon: "exclamationmark.triangle", title: "Rule Conflicts",
                          description: "1 application flagged with conflicting risk rules",
                          count: "1", color: Theme.Colors.warning)
            }
        }
    }
    
    private func alertCard(icon: String, title: String, description: String, count: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.headline)
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(count)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Config Row Helper
    
    private func configRow<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            value()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
    }
}
