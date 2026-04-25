//
//  LODashboardView.swift
//  lms_project
//
//  Loan Officer Dashboard: Premium FinTech UI with gradient header and split view workspace.
//

import SwiftUI

struct LODashboardView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
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
                            kpiStrip
                            trendSection
                            activeWorkspaceSection
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
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
                applicationsVM.loadData(autoSelectFirst: false)
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
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.primary)
                    Text(authVM.currentUser?.branch ?? "Branch")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.md)
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Officer"
        if hour < 12 { return "Good Morning, \(name)" }
        if hour < 17 { return "Good Afternoon, \(name)" }
        return "Good Evening, \(name)"
    }
    
    // MARK: - KPI Strip
    private var kpiStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Overview", icon: "briefcase.fill")
                .description("Summary of your current assignment status and risk exposure.")
                .info { /* Info Action */ }
            
            KPIStripView(cards: [
                KPIData(title: "Active Cases", value: "\(assignedCount)",
                        icon: "doc.on.doc.fill", color: Theme.Colors.primary),
                KPIData(title: "Pending Review", value: "\(pendingReviewCount)",
                        icon: "timer", color: Theme.Colors.warning),
                KPIData(title: "High Risk", value: "\(highRiskCount)",
                        icon: "shield.righthalf.filled", color: Theme.Colors.critical)
            ])
        }
    }
    
    // MARK: - Trend Section
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Performance Trend", icon: "chart.line.uptrend.xyaxis")
                .description("Weekly approval metrics and disbursement velocity.")
                .info { /* Info Action */ }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(approvedCount) Loans Approved")
                            .font(Theme.Typography.headline)
                        Text("Live from Applications")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                        Text("\(approvalRateText)")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.success.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                PremiumLineChart(
                    data: weeklySeries,
                    labels: ["D-6", "D-5", "D-4", "D-3", "D-2", "D-1", "Today"],
                    accentColor: Theme.Colors.primary,
                    showPoints: true,
                    unit: "loans"
                )
                .frame(height: 180)
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
    
    // MARK: - Active Workspace
    private var activeWorkspaceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "Active Workspace", icon: "square.grid.2x2.fill")
                        .info { /* Info Action */ }
                    Text("Select and preview applications directly from your assigned list.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if applicationsVM.selectedApplication != nil {
                    Button {
                        openSelectedApplication()
                    } label: {
                        Label("Detailed View", systemImage: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // LEFT: Application List (38%)
                    applicationList
                        .frame(width: geometry.size.width * 0.38)
                    
                    Divider()
                        .padding(.vertical, Theme.Spacing.lg)
                    
                    // RIGHT: Preview Panel (62%)
                    previewPanel
                        .frame(width: geometry.size.width * 0.62)
                }
                .background(Theme.Colors.adaptiveSurface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
                )
            }
            .frame(height: 550)
        }
    }
    
    // MARK: - Application List
    private var applicationList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Applications")
                    .font(Theme.Typography.headline)
                Spacer()
                Text("\(activeApplications.count)")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 16)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(activeApplications) { app in
                        ApplicationRow(
                            application: app,
                            isSelected: applicationsVM.selectedApplication?.id == app.id,
                            useMinimalStyle: true
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                applicationsVM.selectApplication(app)
                            }
                        }
                        
                        Divider().padding(.leading, 72)
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Panel
    private var previewPanel: some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(app.borrower.name)
                                    .font(Theme.Typography.title)
                                Text(app.id)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                Text(app.loan.amount.currencyFormatted)
                                    .font(Theme.Typography.titleLarge)
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                            Spacer()
                            StatusBadge(status: app.status)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Financial Summary")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: Theme.Spacing.md) {
                                MiniMetric(label: "CIBIL", value: "\(app.financials.cibilScore)", color: Theme.Colors.primary)
                                MiniMetric(label: "DTI", value: app.financials.dtiRatio.percentFormatted, color: Theme.Colors.secondary)
                                MiniMetric(label: "Risk", value: app.riskLevel.displayName, color: app.riskLevel.color)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Recent Note")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                            Text(app.notes.last?.text ?? "No notes available")
                                .font(Theme.Typography.subheadline)
                                .padding(Theme.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.Colors.adaptiveSurface(colorScheme).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Select an application to preview details")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func openSelectedApplication() {
        withAnimation {
            selectedTab = 1
        }
    }
}

private extension LODashboardView {
    var liveApplications: [LoanApplication] { applicationsVM.applications }

    var activeApplications: [LoanApplication] {
        liveApplications.filter {
            $0.status == .pending || $0.status == .underReview || $0.status == .officerReview
        }
    }

    var assignedCount: Int { activeApplications.count }

    var pendingReviewCount: Int {
        activeApplications.filter { $0.status == .underReview || $0.status == .officerReview }.count
    }

    var highRiskCount: Int {
        activeApplications.filter { $0.riskLevel == .high }.count
    }

    var approvedCount: Int {
        liveApplications.filter { $0.status == .approved || $0.status == .officerApproved || $0.status == .managerApproved }.count
    }

    var approvalRateText: String {
        guard !liveApplications.isEmpty else { return "0%" }
        let rate = (Double(approvedCount) / Double(liveApplications.count)) * 100
        return "\(Int(rate.rounded()))%"
    }

    var weeklySeries: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            return Double(liveApplications.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count)
        }
    }
}

struct MiniMetric: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).textCase(.uppercase)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
