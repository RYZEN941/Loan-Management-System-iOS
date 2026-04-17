//
//  LODashboardView.swift
//  lms_project
//

import SwiftUI

struct LODashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Greeting
                    greetingBar
                    
                    // KPI Strip
                    kpiStrip
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    
                    // Active Workspace
                    activeWorkspace
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
            }
        }
    }
    
    // MARK: - Greeting Bar
    
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greetingText)
                    .font(Theme.Typography.titleLarge)
                    .foregroundStyle(.primary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "building.2")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(authVM.currentUser?.branch ?? "Branch")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // User avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(authVM.currentUser?.initials ?? "AS")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
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
        KPIStripView(cards: [
            KPIData(title: "Assigned Applications", value: "\(dashboardVM.assignedCount)",
                    icon: "doc.text.fill", color: Theme.Colors.primary),
            KPIData(title: "Pending Review", value: "\(dashboardVM.pendingReviewCount)",
                    icon: "clock.fill", color: Theme.Colors.warning),
            KPIData(title: "High Risk Cases", value: "\(dashboardVM.highRiskCount)",
                    icon: "exclamationmark.triangle.fill", color: Theme.Colors.critical)
        ])
    }
    
    // MARK: - Active Workspace (Split Layout)
    
    private var activeWorkspace: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Active Workspace", icon: "rectangle.split.2x1")
                .padding(.horizontal, Theme.Spacing.lg)
            
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    // LEFT: Application List (40%)
                    applicationList
                        .frame(width: geometry.size.width * Theme.Layout.splitLeftRatio)
                    
                    Divider()
                    
                    // RIGHT: Preview Panel (60%)
                    previewPanel
                        .frame(width: geometry.size.width * Theme.Layout.splitRightRatio - 1)
                }
                .background(Theme.Colors.adaptiveSurface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
                )
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    // MARK: - Application List
    
    private var applicationList: some View {
        VStack(spacing: 0) {
            // List Header
            HStack {
                Text("Applications")
                    .font(Theme.Typography.headline)
                Spacer()
                Text("\(dashboardVM.activeApplications.count)")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(dashboardVM.activeApplications) { app in
                        ApplicationRow(
                            application: app,
                            isSelected: dashboardVM.selectedApplication?.id == app.id
                        )
                        .onTapGesture {
                            dashboardVM.selectApplication(app)
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
            if let app = dashboardVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(app.borrower.name)
                                    .font(Theme.Typography.title)
                                Text(app.loan.amount.currencyFormatted)
                                    .font(Theme.Typography.titleLarge)
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                            
                            Spacer()
                            
                            StatusBadge(status: app.status)
                        }
                        
                        Divider()
                        
                        // Financial Summary
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Financial Summary")
                                .font(Theme.Typography.headline)
                            
                            HStack(spacing: Theme.Spacing.lg) {
                                financialItem(label: "Monthly Income", value: app.financials.monthlyIncome.currencyFormatted)
                                financialItem(label: "CIBIL Score", value: "\(app.financials.cibilScore)", color: cibilColor(app.financials.cibilScore))
                                financialItem(label: "DTI Ratio", value: app.financials.dtiRatio.percentFormatted, color: dtiColor(app.financials.dtiRatio))
                            }
                        }
                        
                        Divider()
                        
                        // Document Status
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Documents")
                                .font(Theme.Typography.headline)
                            
                            ForEach(app.documents) { doc in
                                HStack {
                                    Image(systemName: doc.type.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(doc.label)
                                        .font(Theme.Typography.subheadline)
                                    Spacer()
                                    DocStatusBadge(status: doc.status)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Latest Note
                        if let latestNote = app.notes.last {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Latest Comment")
                                    .font(Theme.Typography.headline)
                                
                                Text(latestNote.text)
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text("\(latestNote.author) • \(latestNote.timestamp.relativeFormatted)")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select an application to preview")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func financialItem(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func cibilColor(_ score: Int) -> Color {
        if score >= 750 { return Theme.Colors.success }
        if score >= 650 { return Theme.Colors.warning }
        return Theme.Colors.critical
    }
    
    private func dtiColor(_ ratio: Double) -> Color {
        if ratio <= 0.30 { return Theme.Colors.success }
        if ratio <= 0.40 { return Theme.Colors.warning }
        return Theme.Colors.critical
    }
}
