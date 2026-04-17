//
//  AdminReportsView.swift
//  lms_project
//
//  Admin Tab 7 — Reports
//  NEW FILE: Does not modify any existing views.
//

import SwiftUI

// MARK: - Reports View

struct AdminReportsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var exportingReport: ReportItem? = nil
    @State private var exportFormat: ExportFormat = .pdf
    @State private var showingBanner = false
    @State private var bannerMessage = ""
    @State private var showExportSheet: ReportItem? = nil

    // MARK: - Report Types

    private let reports: [ReportItem] = [
        ReportItem(
            id: "RPT-PERF",
            title: "Performance Report",
            description: "Loan officer productivity, approval rates, TAT analysis",
            icon: "chart.bar.fill",
            color: Theme.Colors.primary,
            lastGenerated: "Apr 15, 2025",
            size: "2.4 MB"
        ),
        ReportItem(
            id: "RPT-FIN",
            title: "Financial Report",
            description: "Disbursements, collections, interest income, NPA trends",
            icon: "indianrupeesign.circle.fill",
            color: Theme.Colors.success,
            lastGenerated: "Apr 14, 2025",
            size: "3.8 MB"
        ),
        ReportItem(
            id: "RPT-AUD",
            title: "Audit Report",
            description: "System access logs, configuration changes, override trail",
            icon: "list.bullet.clipboard.fill",
            color: Color(hex: "6F42C1"),
            lastGenerated: "Apr 13, 2025",
            size: "1.2 MB"
        ),
        ReportItem(
            id: "RPT-PORT",
            title: "Portfolio Report",
            description: "Product-wise breakdown, aging analysis, geographic spread",
            icon: "chart.pie.fill",
            color: Theme.Colors.warning,
            lastGenerated: "Apr 12, 2025",
            size: "5.1 MB"
        ),
        ReportItem(
            id: "RPT-COMP",
            title: "Compliance Report",
            description: "RBI regulatory compliance, KYC status, AML flags",
            icon: "checkmark.shield.fill",
            color: Color(hex: "0096C7"),
            lastGenerated: "Apr 10, 2025",
            size: "1.8 MB"
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        headerCard
                        reportListSection
                        scheduledReportsSection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }

                // Export Banner
                if showingBanner {
                    exportBanner
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingBanner)
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .sheet(item: $showExportSheet) { report in
                ExportOptionsSheet(
                    report: report,
                    onExport: { format in
                        triggerExport(report: report, format: format)
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Report Centre")
                    .font(Theme.Typography.title)
                Text("Generate and export compliance-ready reports")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "doc.richtext")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Colors.primary.opacity(0.4))
        }
        .padding(Theme.Spacing.lg)
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Report List

    private var reportListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Available Reports", icon: "doc.on.doc")

            VStack(spacing: Theme.Spacing.md) {
                ForEach(reports) { report in
                    ReportCard(
                        report: report,
                        colorScheme: colorScheme,
                        onExport: { showExportSheet = report }
                    )
                }
            }
        }
    }

    // MARK: - Scheduled Reports

    private var scheduledReportsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Scheduled Reports", icon: "calendar.badge.clock")

            VStack(spacing: 0) {
                scheduledRow(title: "Monthly Portfolio Digest",    frequency: "1st of every month",   status: "Active",  color: Theme.Colors.success)
                Divider().padding(.leading, Theme.Spacing.md)
                scheduledRow(title: "Weekly Performance Summary",  frequency: "Every Monday, 8:00 AM", status: "Active",  color: Theme.Colors.success)
                Divider().padding(.leading, Theme.Spacing.md)
                scheduledRow(title: "RBI Compliance Submission",   frequency: "Quarterly",             status: "Paused",  color: Theme.Colors.warning)
                Divider().padding(.leading, Theme.Spacing.md)
                scheduledRow(title: "NPA & Recovery Tracker",      frequency: "Every Friday",          status: "Active",  color: Theme.Colors.success)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func scheduledRow(title: String, frequency: String, status: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                Text(frequency)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GenericBadge(text: status, color: color)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    // MARK: - Export Banner

    private var exportBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
                .tint(.white)
            Text(bannerMessage)
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Export Trigger

    private func triggerExport(report: ReportItem, format: ExportFormat) {
        bannerMessage = "Generating \(report.title) as \(format.displayName)…"
        withAnimation { showingBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showingBanner = false }
        }
    }
}

// MARK: - Report Card

private struct ReportCard: View {
    let report:      ReportItem
    let colorScheme: ColorScheme
    let onExport:    () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(report.color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: report.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(report.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.title)
                        .font(Theme.Typography.headline)
                    Text(report.description)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Metadata row
            HStack(spacing: Theme.Spacing.md) {
                Label("Last: \(report.lastGenerated)", systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(report.size, systemImage: "doc")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Export buttons
            HStack(spacing: Theme.Spacing.sm) {
                exportButton(label: "Export PDF", icon: "doc.fill", primary: true, action: onExport)
                exportButton(label: "Export Excel", icon: "tablecells.fill", primary: false, action: onExport)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }

    private func exportButton(label: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(primary ? .white : Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(primary ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Options Sheet

private struct ExportOptionsSheet: View {
    let report:    ReportItem
    let onExport:  (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var dateRange = 0
    private let dateRanges = ["This Month", "Last 3 Months", "Last 6 Months", "This FY"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Report") {
                    LabeledContent("Type", value: report.title)
                    LabeledContent("Size (approx.)", value: report.size)
                }
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Date Range") {
                    Picker("Period", selection: $dateRange) {
                        ForEach(dateRanges.indices, id: \.self) { i in
                            Text(dateRanges[i]).tag(i)
                        }
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        dismiss()
                        onExport(selectedFormat)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Data Models

struct ReportItem: Identifiable {
    let id:            String
    let title:         String
    let description:   String
    let icon:          String
    let color:         Color
    let lastGenerated: String
    let size:          String
}

enum ExportFormat: String, CaseIterable {
    case pdf   = "pdf"
    case excel = "excel"
    case csv   = "csv"

    var displayName: String {
        switch self {
        case .pdf:   return "PDF"
        case .excel: return "Excel"
        case .csv:   return "CSV"
        }
    }
}
