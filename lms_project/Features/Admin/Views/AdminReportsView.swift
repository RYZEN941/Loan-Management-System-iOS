//
//  AdminReportsView.swift
//  lms_project
//
//  TAB 4 — Reports with categories, filters, export, custom builder
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AdminReportsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var reportsVM: AdminReportsViewModel
    @Binding var showProfile: Bool

    @State private var selectedCategory = 0
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showingBanner = false
    @State private var bannerMessage = ""
    @State private var dateRange = "Last 30 Days"
    @State private var loanTypeFilter = "All Types"
    @State private var regionFilter = "All Regions"
    @State private var statusFilter = "All"

    private enum ActiveSheet: Identifiable {
        case exportOptions(ReportItem)
        case preview(ReportItem)
        case customBuilder
        case customPreview(CustomReportPayload)
        case share(ShareItem)

        var id: String {
            switch self {
            case .exportOptions(let r): return "export-\(r.id)"
            case .preview(let r):       return "preview-\(r.id)"
            case .customBuilder:        return "customBuilder"
            case .customPreview(let p): return "customPreview-\(p.generatedAt.timeIntervalSince1970)"
            case .share(let s):         return "share-\(s.id)"
            }
        }
    }

    private let categories = ["Portfolio","Disbursement","Collection","NPA","Risk & Credit"]
    private let dateRanges = ["Last 7 Days","Last 30 Days","Last 90 Days","This FY"]
    private let loanTypes = ["All Types","Home Loan","Personal Loan","Business Loan","Vehicle Loan"]
    private let regions = ["All Regions","Mumbai","Delhi NCR","Bangalore","Chennai"]
    private let statuses = ["All","Active","Closed","NPA"]

    private let reports: [ReportItem] = [
        ReportItem(id:"RPT-PERF",title:"Portfolio Performance",description:"Total portfolio, disbursements, NPA summary",icon:"chart.bar.fill",color:Theme.Colors.primary,lastGenerated:"Apr 15, 2025",size:"2.4 MB"),
        ReportItem(id:"RPT-DISB",title:"Disbursement Report",description:"Loans disbursed by branch, type, and officer",icon:"arrow.up.right.circle.fill",color:Theme.Colors.success,lastGenerated:"Apr 14, 2025",size:"1.8 MB"),
        ReportItem(id:"RPT-COLL",title:"Collection Report",description:"EMI recovery, DPD buckets, outstanding analysis",icon:"indianrupeesign.circle.fill",color:Theme.Colors.primary,lastGenerated:"Apr 13, 2025",size:"3.1 MB"),
        ReportItem(id:"RPT-NPA",title:"NPA Report",description:"Non-performing assets, aging, provisioning",icon:"exclamationmark.triangle.fill",color:Theme.Colors.critical,lastGenerated:"Apr 12, 2025",size:"1.2 MB"),
        ReportItem(id:"RPT-RISK",title:"Risk & Credit Report",description:"CIBIL distribution, FOIR analysis, fraud flags",icon:"shield.lefthalf.filled",color:Theme.Colors.warning,lastGenerated:"Apr 10, 2025",size:"2.8 MB"),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment:.top) {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        filterStrip

                        Button {
                            activeSheet = .customBuilder
                        } label: {
                            customReportBuilderCard
                        }
                        .buttonStyle(.plain)

                        allReportsSection
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }

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
            .onAppear {
                reportsVM.loadData()
            }
            // SINGLE .sheet modifier — fixes SwiftUI iOS 16/17 silent-ignore bug
            // where only the first .sheet in a chain actually fires.
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .exportOptions(let report):
                    ExportOptionsSheet(report: report, currentDateRange: dateRange, onExport: { format, exportDateRange in
                        triggerExport(report: report, format: format, dateRangeOverride: exportDateRange)
                    })
                case .preview(let report):
                    ReportPreviewSheet(
                        report: report,
                        dateRange: dateRange,
                        loanType: loanTypeFilter,
                        region: regionFilter,
                        status: statusFilter,
                        onExport: { format in
                        triggerExport(report: report, format: format)
                    })
                    .environmentObject(reportsVM)
                case .customBuilder:
                    AdminCustomReportBuilderSheet(onGenerate: { payload in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            activeSheet = .customPreview(payload)
                        }
                    })
                case .customPreview(let payload):
                    CustomReportPreviewSheet(
                        payload: payload,
                        onExport: { format in
                            triggerCustomExport(payload: payload, format: format)
                        }
                    )
                case .share(let item):
                    ShareSheet(activityItems: [item.url])
                }
            }
        }
    }

    // MARK: - Native Filters Strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(selection: $dateRange, options: dateRanges, icon: "calendar")
                filterChip(selection: $loanTypeFilter, options: loanTypes, icon: "briefcase")
                filterChip(selection: $regionFilter, options: regions, icon: "mappin.and.ellipse")
                filterChip(selection: $statusFilter, options: statuses, icon: "flag")
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func filterChip(selection: Binding<String>, options: [String], icon: String) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                Text(selection.wrappedValue).font(Theme.Typography.caption.weight(.medium)).foregroundStyle(.primary)
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Custom Report Builder Card

    private var customReportBuilderCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Report Builder")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                    Text("Combine metrics across Portfolio, Risk, and Collections into a single dynamic export.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.adaptivePrimary(colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.Colors.adaptivePrimary(colorScheme).opacity(0.08), radius: 4, x: 0, y: 2)
    }

    // MARK: - All Reports List

    private var allReportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "All Reports", icon: "folder.fill")

            VStack(spacing: 0) {
                ForEach(reports) { report in
                    AdminReportItemRow(
                        report: report,
                        onPreview: { activeSheet = .preview(report) },
                        onExport: { activeSheet = .exportOptions(report) }
                    )
                    if report.id != reports.last?.id {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Export Banner

    private var exportBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.8).tint(.white)
            Text(bannerMessage).font(Theme.Typography.subheadline).fontWeight(.medium).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.adaptivePrimary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Export Logic

    private func triggerExport(report: ReportItem, format: ExportFormat, dateRangeOverride: String? = nil) {
        // KEY FIX: Do NOT set activeSheet = nil here.
        // The sheet that triggered this (ExportOptionsSheet or ReportPreviewSheet)
        // already called dismiss() on itself before invoking onExport.
        // Setting activeSheet = nil here races with SwiftUI's dismissal animation
        // and causes the subsequent .share assignment to be swallowed silently.
        //
        // Instead, wait long enough for SwiftUI to fully complete the dismissal
        // (0.55s covers the default sheet dismiss spring animation) before
        // doing any work or presenting a new sheet.

        bannerMessage = "Generating \(report.title) as \(format.displayName)…"
        withAnimation { showingBanner = true }

        // Wait for backend data if still loading
        if reportsVM.isLoading {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                triggerExport(report: report, format: format, dateRangeOverride: dateRangeOverride)
            }
            return
        }

        let exportDateRange = dateRangeOverride ?? dateRange
        let pdfPayload = reportsVM.generatePDFReportData(
            reportTitle: report.title,
            dateRange: exportDateRange,
            loanType: loanTypeFilter,
            region: regionFilter,
            status: statusFilter
        )

        // 0.55s delay — lets the dismiss animation fully complete before
        // we assign a new activeSheet value. Without this, SwiftUI drops
        // the new sheet assignment because the old sheet is still animating out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            switch format {
            case .pdf:
                AdminReportPDFService.generatePDF(type: .standard(pdfPayload)) { fileURL in
                    withAnimation { self.showingBanner = false }
                    guard let fileURL else {
                        print("[AdminReports] PDF generation returned nil — skipping share sheet")
                        return
                    }
                    print("[AdminReports] Setting activeSheet to .share for: \(fileURL.lastPathComponent)")
                    self.activeSheet = .share(ShareItem(url: fileURL))
                }

            case .csv:
                AdminReportPDFService.generateCSV(payload: pdfPayload) { fileURL in
                    withAnimation { showingBanner = false }
                    guard let fileURL else {
                        print("[AdminReports] CSV generation returned nil — skipping share sheet")
                        return
                    }
                    print("[AdminReports] Setting activeSheet to .share for: \(fileURL.lastPathComponent)")
                    activeSheet = .share(ShareItem(url: fileURL))
                }
            }
        }
    }

    private func triggerCustomExport(payload: CustomReportPayload, format: ExportFormat) {
        bannerMessage = "Generating Custom Report as \(format.displayName)…"
        withAnimation { showingBanner = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            switch format {
            case .pdf:
                AdminReportPDFService.generatePDF(type: .custom(payload)) { fileURL in
                    withAnimation { self.showingBanner = false }
                    if let fileURL { self.activeSheet = .share(ShareItem(url: fileURL)) }
                }
            case .csv:
                AdminReportPDFService.generateCustomCSV(payload: payload) { fileURL in
                    withAnimation { self.showingBanner = false }
                    if let fileURL { self.activeSheet = .share(ShareItem(url: fileURL)) }
                }
            }
        }
    }
}

// MARK: - UIViewController Topmost Traversal

extension UIViewController {
    func topmostPresentedViewController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topmostPresentedViewController()
        }
        return self
    }
}

// MARK: - Share Helpers

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let preparedItems = activityItems.map { item -> Any in
            guard let url = item as? URL, url.pathExtension.lowercased() == "csv" else {
                return item
            }
            return CSVActivityItemSource(url: url)
        }
        let controller = UIActivityViewController(
            activityItems: preparedItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class CSVActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        UTType.commaSeparatedText.identifier
    }
}

// MARK: - Admin Report Item Row

private struct AdminReportItemRow: View {
    let report: ReportItem
    let onPreview: () -> Void
    let onExport: () -> Void

    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(report.color.opacity(0.1)).frame(width: 48, height: 48)
                    Image(systemName: report.icon).font(.system(size: 20)).foregroundStyle(report.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title).font(Theme.Typography.headline)
                    Text(report.description).font(Theme.Typography.caption).foregroundStyle(.secondary).lineLimit(1)

                    HStack(spacing: 12) {
                        Label(report.lastGenerated, systemImage: "clock").font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                        Label(report.size, systemImage: "doc").font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Menu {
                    Button(action: onPreview) {
                        Label("Preview Data", systemImage: "eye")
                    }
                    Divider()
                    Button(action: onExport) {
                        Label("Export Report", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.primary.opacity(0.8))
                        .padding(8)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Report Builder Modal

struct AdminCustomReportBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var reportsVM: AdminReportsViewModel
    var onGenerate: (CustomReportPayload) -> Void

    @State private var selectedMetrics: Set<String> = ["Total Amount"]
    @State private var selectedDimensions: Set<String> = ["Loan Type"]
    @State private var visualization: CustomReportConfig.VisualizationType = .bar
    
    @State private var dateRange = "Last 30 Days"
    @State private var loanType = "All Types"
    @State private var region = "All Regions"
    @State private var status = "All"
    
    let availableMetrics = ["Total Amount", "Disbursed", "Pending Amount", "Overdue Amount"]
    let availableDimensions = ["Loan Type", "Region", "Risk Level", "Branch"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Metrics") {
                    ForEach(availableMetrics, id: \.self) { metric in
                        Toggle(metric, isOn: Binding(
                            get: { selectedMetrics.contains(metric) },
                            set: { isOn in
                                if isOn { selectedMetrics.insert(metric) }
                                else { selectedMetrics.remove(metric) }
                            }
                        ))
                        .tint(Theme.Colors.primary)
                    }
                }
                
                Section("Dimensions") {
                    ForEach(availableDimensions, id: \.self) { dim in
                        Toggle(dim, isOn: Binding(
                            get: { selectedDimensions.contains(dim) },
                            set: { isOn in
                                if isOn { selectedDimensions.insert(dim) }
                                else { selectedDimensions.remove(dim) }
                            }
                        ))
                        .tint(Theme.Colors.primary)
                    }
                }
                
                Section("Visualization") {
                    Picker("Chart Type", selection: $visualization) {
                        ForEach(CustomReportConfig.VisualizationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Filters") {
                    Picker("Date Range", selection: $dateRange) {
                        ForEach(["Last 7 Days","Last 30 Days","Last 90 Days","This FY"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Loan Type", selection: $loanType) {
                        ForEach(["All Types","Home Loan","Personal Loan","Business Loan","Vehicle Loan"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Region", selection: $region) {
                        ForEach(["All Regions","Mumbai","Delhi NCR","Bangalore","Chennai"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(["All","Active","Closed","NPA"], id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("Custom Report Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    generateReport()
                } label: {
                    if reportsVM.isLoading {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Generate Report")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .disabled(reportsVM.isLoading || selectedMetrics.isEmpty || selectedDimensions.isEmpty)
                .foregroundStyle(.white)
                .background(Theme.Colors.primary.opacity(selectedMetrics.isEmpty || selectedDimensions.isEmpty ? 0.5 : 1.0))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveBackground(colorScheme).shadow(color: .black.opacity(0.05), radius: 10, y: -5))
            }
        }
    }

    private func generateReport() {
        let config = CustomReportConfig(
            metrics: Array(selectedMetrics),
            dimensions: Array(selectedDimensions),
            filters: CustomReportConfig.ReportFilters(dateRange: dateRange, loanType: loanType, region: region, status: status),
            visualization: visualization
        )
        Task {
            await reportsVM.fetchCustomReport(config: config)
            if let payload = reportsVM.customReportPayload {
                dismiss()
                onGenerate(payload)
            }
        }
    }
}

// MARK: - Export Options Sheet

private struct ExportOptionsSheet: View {
    let report: ReportItem
    let currentDateRange: String
    let onExport: (ExportFormat, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedDateRange: String
    private let dateRanges = ["Last 7 Days", "Last 30 Days", "Last 90 Days", "This FY"]

    init(report: ReportItem, currentDateRange: String, onExport: @escaping (ExportFormat, String) -> Void) {
        self.report = report
        self.currentDateRange = currentDateRange
        self.onExport = onExport
        _selectedDateRange = State(initialValue: currentDateRange)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Report") {
                    LabeledContent("Type", value: report.title)
                    LabeledContent("Size", value: report.size)
                }
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Date Range") {
                    Picker("Period", selection: $selectedDateRange) {
                        ForEach(dateRanges, id: \.self) { Text($0).tag($0) }
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
                        // Dismiss first, then call onExport.
                        // triggerExport deliberately does NOT nil activeSheet itself —
                        // this dismiss() call is the only thing that clears it, which
                        // prevents the race condition where two nil-assignments fight
                        // with the subsequent .share assignment.
                        dismiss()
                        onExport(selectedFormat, selectedDateRange)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Data Models

struct ReportItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let lastGenerated: String
    let size: String
}

enum ExportFormat: String, CaseIterable {
    case pdf = "pdf"
    case csv = "csv"

    var displayName: String {
        switch self {
        case .pdf:   return "PDF"
        case .csv:   return "CSV"
        }
    }
}

// MARK: - Admin PDF Rendering

private final class AdminReportPDFService {
    private struct VisualReportMeta {
        let generatedAt: Date
        let dateRange: String
        let filters: String
    }

    private struct ReportKPI {
        let title: String
        let value: String
        let note: String
    }

    private struct ReportTrendPoint {
        let period: String
        let value: String
    }

    private struct ReportDistributionItem {
        let name: String
        let value: String
        let percentage: String
    }

    private struct ReportBucket {
        let name: String
        let value: String
        let count: String
    }

    private struct DisbursementReport {
        let meta: VisualReportMeta
        let kpis: [ReportKPI]
        let disbursementTrend: [ReportTrendPoint]
        let byLoanType: [ReportDistributionItem]
        let byRegion: [ReportBucket]
        let insights: [String]
    }

    private struct CollectionReport {
        let meta: VisualReportMeta
        let kpis: [ReportKPI]
        let collectionTrend: [ReportTrendPoint]
        let dpdBuckets: [ReportBucket]
        let paidVsPending: [ReportDistributionItem]
        let insights: [String]
    }

    private struct NPAReport {
        let meta: VisualReportMeta
        let kpis: [ReportKPI]
        let agingBuckets: [ReportBucket]
        let npaVsHealthy: [ReportDistributionItem]
        let topRegions: [ReportBucket]
        let insights: [String]
    }

    private struct RiskCreditReport {
        let meta: VisualReportMeta
        let kpis: [ReportKPI]
        let cibilDistribution: [ReportBucket]
        let riskCategories: [ReportDistributionItem]
        let foirDistribution: [ReportBucket]
        let insights: [String]
    }

    private struct PortfolioReportMeta {
        let generatedAt: Date
        let dateRange: String
        let filters: String
    }

    private struct PortfolioKPI {
        let title: String
        let value: String
        let note: String
    }

    private struct PortfolioTrendPoint {
        let period: String
        let portfolioValue: String
        let disbursement: String
        let loanCount: String
    }

    private struct PortfolioDistributionItem {
        let name: String
        let value: String
        let percentage: String
    }

    private struct PortfolioNPAgingBucket {
        let bucket: String
        let amount: String
        let count: String
    }

    private struct PortfolioPerformanceReport {
        let meta: PortfolioReportMeta
        let kpis: [PortfolioKPI]
        let trends: [PortfolioTrendPoint]
        let loanTypeDistribution: [PortfolioDistributionItem]
        let regionDistribution: [PortfolioDistributionItem]
        let totalNpaAmount: String
        let npaPercentage: String
        let npaCount: String
        let agingBuckets: [PortfolioNPAgingBucket]
        let topInsights: [String]
    }

    static func generateCustomCSV(payload: CustomReportPayload, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var rows: [[String]] = []
            
            // Meta
            let formatter = ISO8601DateFormatter()
            appendRows([
                ["Report", "Custom Report"],
                ["Generated At", formatter.string(from: payload.generatedAt)],
                ["Date Range", payload.config.filters.dateRange],
                ["Metrics", payload.config.metrics.joined(separator: ", ")],
                ["Dimensions", payload.config.dimensions.joined(separator: ", ")]
            ], to: &rows)
            appendBlankRow(to: &rows)
            
            // KPIs
            appendSection("Metrics", to: &rows)
            appendRow(["Metric", "Value"], to: &rows)
            for kpi in payload.kpis {
                appendRow([kpi.title, rawMetricValue(kpi.value)], to: &rows)
            }
            appendBlankRow(to: &rows)
            
            // Grouped Data
            appendSection("Dimensions Breakdown", to: &rows)
            appendRow(["Dimension", "Value", "Count"], to: &rows)
            for bucket in payload.groupedData {
                appendRow([bucket.name, rawAmount(bucket.value), rawNumber(bucket.count)], to: &rows)
            }
            appendBlankRow(to: &rows)
            
            let csv = csvString(rows)
            let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CustomReport_\(Int(payload.generatedAt.timeIntervalSince1970)).csv")
            
            do {
                try csv.write(to: outputURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async { completion(outputURL) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    static func generateCSV(payload: AdminPDFReportPayload, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedAt = Date()
            let csv: String

            switch payload.reportName {
            case "Portfolio Performance":
                csv = portfolioCSV(Self.samplePortfolioPerformanceReport(generatedAt: generatedAt))
            case "Disbursement Report":
                csv = disbursementCSV(Self.sampleDisbursementReport(generatedAt: generatedAt))
            case "Collection Report":
                csv = collectionCSV(Self.sampleCollectionReport(generatedAt: generatedAt))
            case "NPA Report":
                csv = npaCSV(Self.sampleNPAReport(generatedAt: generatedAt))
            case "Risk & Credit Report":
                csv = riskCreditCSV(Self.sampleRiskCreditReport(generatedAt: generatedAt))
            default:
                csv = fallbackCSV(payload)
            }

            let safeName = payload.reportName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
            let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("\(safeName)_\(Int(generatedAt.timeIntervalSince1970)).csv")

            do {
                try csv.write(to: outputURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async { completion(outputURL) }
            } catch {
                print("[AdminReports] CSV FAILED with error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    enum ReportPayloadType {
        case standard(AdminPDFReportPayload)
        case custom(CustomReportPayload)
    }

    static func generatePDF(type: ReportPayloadType, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let reportName: String
            switch type {
            case .standard(let payload): reportName = payload.reportName
            case .custom: reportName = "Custom Report"
            }
            
            let safeName = reportName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
            let fileName = "\(safeName)_\(Int(Date().timeIntervalSince1970)).pdf"
            let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)

            let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = [
                kCGPDFContextTitle as String: "\(reportName) Report",
                kCGPDFContextCreator as String: "Loan Management System"
            ]

            let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

            do {
                try renderer.writePDF(to: outputURL) { context in
                    let margin: CGFloat = 36
                    let pageWidth = pageRect.width
                    let pageHeight = pageRect.height
                    let contentWidth = pageWidth - (margin * 2)
                    let bottomMargin: CGFloat = 54
                    var pageNumber = 1
                    var y: CGFloat = 36

                    let titleAttrs = attrs(size: 22, weight: .bold, color: .black)
                    let subtitleAttrs = attrs(size: 9.5, weight: .regular, color: UIColor(white: 0.34, alpha: 1))
                    let sectionAttrs = attrs(size: 13, weight: .semibold, color: .black)
                    let labelAttrs = attrs(size: 8.5, weight: .semibold, color: UIColor(white: 0.42, alpha: 1))
                    let valueAttrs = attrs(size: 10, weight: .regular, color: .black)
                    let metricValueAttrs = attrs(size: 14, weight: .bold, color: .black)
                    let tableHeaderAttrs = attrs(size: 9, weight: .semibold, color: UIColor(white: 0.22, alpha: 1))
                    let smallValueAttrs = attrs(size: 9, weight: .regular, color: UIColor(white: 0.16, alpha: 1))
                    let footerAttrs = attrs(size: 8.5, weight: .regular, color: UIColor(white: 0.48, alpha: 1))

                    let lineColor = UIColor(red: 220 / 255, green: 225 / 255, blue: 232 / 255, alpha: 1)
                    let panelFill = UIColor(red: 248 / 255, green: 250 / 255, blue: 252 / 255, alpha: 1)
                    let headerFill = UIColor(red: 237 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)

                    let headerFormatter = DateFormatter()
                    headerFormatter.dateFormat = "dd MMM yyyy, hh:mm a"
                    let rowDateFormatter = DateFormatter()
                    rowDateFormatter.dateFormat = "dd MMM yyyy"

                    func drawLine(_ yValue: CGFloat) {
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: margin, y: yValue))
                        path.addLine(to: CGPoint(x: pageWidth - margin, y: yValue))
                        path.lineWidth = 0.6
                        lineColor.setStroke()
                        path.stroke()
                    }

                    func drawFooter() {
                        drawLine(pageHeight - 38)
                        let footer = "Generated by Loan Management System | Page \(pageNumber)" as NSString
                        let size = footer.size(withAttributes: footerAttrs)
                        footer.draw(
                            at: CGPoint(x: (pageWidth - size.width) / 2, y: pageHeight - 28),
                            withAttributes: footerAttrs
                        )
                    }

                    func beginPage() {
                        context.beginPage()
                        y = 36
                    }

                    func ensureSpace(_ height: CGFloat) {
                        if y + height > pageHeight - bottomMargin {
                            drawFooter()
                            pageNumber += 1
                            beginPage()
                            drawContinuationHeader()
                        }
                    }

                    @discardableResult
                    func drawText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
                        let nsText = clean(text) as NSString
                        let measured = nsText.boundingRect(
                            with: rect.size,
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes,
                            context: nil
                        )
                        nsText.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                        return ceil(measured.height)
                    }

                    func textHeight(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
                        let nsText = clean(text) as NSString
                        let measured = nsText.boundingRect(
                            with: CGSize(width: width, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes,
                            context: nil
                        )
                        return ceil(measured.height)
                    }

                    func drawHeader(for payload: AdminPDFReportPayload) {
                        drawText("\(payload.reportName) Report", in: CGRect(x: margin, y: y, width: contentWidth, height: 30), attributes: titleAttrs)
                        y += 30
                        drawText("Generated on: \(headerFormatter.string(from: Date()))", in: CGRect(x: margin, y: y, width: contentWidth, height: 16), attributes: subtitleAttrs)
                        y += 15
                        drawText(payload.filters, in: CGRect(x: margin, y: y, width: contentWidth, height: 28), attributes: subtitleAttrs)
                        y += 30
                        drawLine(y)
                        y += 18
                    }

                    func drawContinuationHeader() {
                        let headerTitle = reportName == "Custom Report" ? "Custom Report" : "\(reportName) Report"
                        drawText(headerTitle, in: CGRect(x: margin, y: y, width: contentWidth, height: 20), attributes: attrs(size: 13, weight: .semibold, color: .black))
                        y += 22
                        drawLine(y)
                        y += 14
                    }

                    func drawSummary(for payload: AdminPDFReportPayload) {
                        drawText("Summary", in: CGRect(x: margin, y: y, width: contentWidth, height: 18), attributes: sectionAttrs)
                        y += 24

                        let items = [
                            ("Total Applications", "\(payload.summary.total)"),
                            ("Approved", "\(payload.summary.approved)"),
                            ("Pending", "\(payload.summary.pending)"),
                            ("Rejected", "\(payload.summary.rejected)"),
                            ("Total Loan Value", currency(payload.summary.totalValue)),
                            ("Avg Loan Size", currency(payload.summary.avgLoanSize)),
                            ("High Risk", "\(payload.summary.highRisk)")
                        ]

                        let columns = 4
                        let gap: CGFloat = 8
                        let cellWidth = (contentWidth - (gap * CGFloat(columns - 1))) / CGFloat(columns)
                        let cellHeight: CGFloat = 48

                        for (index, item) in items.enumerated() {
                            let col = index % columns
                            let row = index / columns
                            let x = margin + CGFloat(col) * (cellWidth + gap)
                            let cellY = y + CGFloat(row) * (cellHeight + gap)
                            let rect = CGRect(x: x, y: cellY, width: cellWidth, height: cellHeight)
                            roundedRect(rect, fill: panelFill, stroke: lineColor)
                            drawText(item.1, in: CGRect(x: x + 9, y: cellY + 8, width: cellWidth - 18, height: 18), attributes: metricValueAttrs)
                            drawText(item.0, in: CGRect(x: x + 9, y: cellY + 29, width: cellWidth - 18, height: 12), attributes: labelAttrs)
                        }

                        let rowCount = CGFloat((items.count + columns - 1) / columns)
                        y += rowCount * cellHeight + (rowCount - 1) * gap + 24
                    }

                    func drawSectionTitle(_ title: String) {
                        ensureSpace(30)
                        drawText(title, in: CGRect(x: margin, y: y, width: contentWidth, height: 18), attributes: sectionAttrs)
                        y += 24
                    }

                    func tableRowHeight(_ values: [String], widths: [CGFloat], attributes: [NSAttributedString.Key: Any], verticalPadding: CGFloat = 7) -> CGFloat {
                        let tallest = zip(values, widths).map { value, width in
                            textHeight(value, width: width - 12, attributes: attributes)
                        }.max() ?? 0
                        return tallest + (verticalPadding * 2)
                    }

                    func drawTableRow(
                        _ values: [String],
                        widths: [CGFloat],
                        fill: UIColor?,
                        attributes: [NSAttributedString.Key: Any],
                        verticalPadding: CGFloat = 7
                    ) {
                        let rowHeight = tableRowHeight(values, widths: widths, attributes: attributes, verticalPadding: verticalPadding)
                        ensureSpace(rowHeight + 1)

                        if let fill {
                            fill.setFill()
                            UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)).fill()
                        }

                        var x = margin
                        for (index, value) in values.enumerated() {
                            drawText(
                                value,
                                in: CGRect(x: x + 6, y: y + verticalPadding, width: widths[index] - 12, height: rowHeight - (verticalPadding * 2)),
                                attributes: attributes
                            )
                            x += widths[index]
                        }

                        let line = UIBezierPath()
                        line.move(to: CGPoint(x: margin, y: y + rowHeight))
                        line.addLine(to: CGPoint(x: pageWidth - margin, y: y + rowHeight))
                        line.lineWidth = 0.5
                        lineColor.setStroke()
                        line.stroke()

                        y += rowHeight
                    }

                    func drawPortfolioHeader(_ report: PortfolioPerformanceReport) {
                        drawText("Portfolio Performance Report", in: CGRect(x: margin, y: y, width: contentWidth, height: 30), attributes: titleAttrs)
                        y += 30
                        drawText("Generated on: \(headerFormatter.string(from: report.meta.generatedAt))", in: CGRect(x: margin, y: y, width: contentWidth, height: 16), attributes: subtitleAttrs)
                        y += 15
                        drawText("Date Range: \(report.meta.dateRange) | Filters: \(report.meta.filters)", in: CGRect(x: margin, y: y, width: contentWidth, height: 28), attributes: subtitleAttrs)
                        y += 30
                        drawLine(y)
                        y += 18
                    }

                    func drawPortfolioKPIs(_ report: PortfolioPerformanceReport) {
                        drawSectionTitle("Key Portfolio Metrics")

                        let columns = 4
                        let gap: CGFloat = 8
                        let cellWidth = (contentWidth - (gap * CGFloat(columns - 1))) / CGFloat(columns)
                        let cellHeight: CGFloat = 60

                        for (index, item) in report.kpis.enumerated() {
                            let col = index % columns
                            let row = index / columns
                            let x = margin + CGFloat(col) * (cellWidth + gap)
                            let cellY = y + CGFloat(row) * (cellHeight + gap)
                            let rect = CGRect(x: x, y: cellY, width: cellWidth, height: cellHeight)
                            roundedRect(rect, fill: panelFill, stroke: lineColor)
                            drawText(item.value, in: CGRect(x: x + 9, y: cellY + 8, width: cellWidth - 18, height: 18), attributes: metricValueAttrs)
                            drawText(item.title, in: CGRect(x: x + 9, y: cellY + 29, width: cellWidth - 18, height: 12), attributes: labelAttrs)
                            drawText(item.note, in: CGRect(x: x + 9, y: cellY + 43, width: cellWidth - 18, height: 10), attributes: attrs(size: 7.5, weight: .regular, color: UIColor(white: 0.48, alpha: 1)))
                        }

                        let rowCount = CGFloat((report.kpis.count + columns - 1) / columns)
                        y += rowCount * cellHeight + (rowCount - 1) * gap + 24
                    }

                    func numericValue(_ text: String) -> Double {
                        let filtered = text.filter { "0123456789.".contains($0) }
                        return Double(filtered) ?? 0
                    }

                    func chartColors(_ palette: Int) -> [UIColor] {
                        if palette == 1 {
                            return [
                                UIColor(red: 45 / 255, green: 116 / 255, blue: 230 / 255, alpha: 1),
                                UIColor(red: 29 / 255, green: 166 / 255, blue: 126 / 255, alpha: 1),
                                UIColor(red: 242 / 255, green: 153 / 255, blue: 74 / 255, alpha: 1),
                                UIColor(red: 154 / 255, green: 95 / 255, blue: 207 / 255, alpha: 1)
                            ]
                        }
                        return [
                            UIColor(red: 16 / 255, green: 146 / 255, blue: 195 / 255, alpha: 1),
                            UIColor(red: 230 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1),
                            UIColor(red: 110 / 255, green: 170 / 255, blue: 74 / 255, alpha: 1),
                            UIColor(red: 219 / 255, green: 166 / 255, blue: 58 / 255, alpha: 1)
                        ]
                    }

                    func drawChartCard(title: String, x: CGFloat, y startY: CGFloat, width: CGFloat, height: CGFloat, drawContent: (CGRect) -> Void) {
                        roundedRect(CGRect(x: x, y: startY, width: width, height: height), fill: .white, stroke: lineColor)
                        drawText(title, in: CGRect(x: x + 12, y: startY + 10, width: width - 24, height: 16), attributes: sectionAttrs)
                        drawContent(CGRect(x: x + 12, y: startY + 34, width: width - 24, height: height - 46))
                    }

                    func drawLineChart(points: [(label: String, value: Double, display: String)], in rect: CGRect, lineColor chartColor: UIColor) {
                        guard points.count > 1 else { return }
                        let axisLeft: CGFloat = 36
                        let axisBottom: CGFloat = 26
                        let axisTop: CGFloat = 10
                        let plot = CGRect(
                            x: rect.minX + axisLeft,
                            y: rect.minY + axisTop,
                            width: rect.width - axisLeft - 8,
                            height: rect.height - axisTop - axisBottom
                        )
                        let minValue = points.map(\.value).min() ?? 0
                        let maxValue = points.map(\.value).max() ?? 1
                        let range = max(maxValue - minValue, 1)

                        UIColor(white: 0.82, alpha: 1).setStroke()
                        let axis = UIBezierPath()
                        axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
                        axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                        axis.lineWidth = 0.7
                        axis.stroke()

                        for i in 0...2 {
                            let gridY = plot.minY + (plot.height / 2) * CGFloat(i)
                            let grid = UIBezierPath()
                            grid.move(to: CGPoint(x: plot.minX, y: gridY))
                            grid.addLine(to: CGPoint(x: plot.maxX, y: gridY))
                            grid.lineWidth = 0.3
                            UIColor(white: 0.9, alpha: 1).setStroke()
                            grid.stroke()
                        }

                        let path = UIBezierPath()
                        let step = plot.width / CGFloat(points.count - 1)
                        var chartPoints: [CGPoint] = []
                        for (index, point) in points.enumerated() {
                            let x = plot.minX + CGFloat(index) * step
                            let normalized = (point.value - minValue) / range
                            let yPoint = plot.maxY - CGFloat(normalized) * plot.height
                            let cgPoint = CGPoint(x: x, y: yPoint)
                            chartPoints.append(cgPoint)
                            index == 0 ? path.move(to: cgPoint) : path.addLine(to: cgPoint)
                        }

                        chartColor.setStroke()
                        path.lineWidth = 2
                        path.stroke()

                        for (index, cgPoint) in chartPoints.enumerated() {
                            chartColor.setFill()
                            UIBezierPath(ovalIn: CGRect(x: cgPoint.x - 3.2, y: cgPoint.y - 3.2, width: 6.4, height: 6.4)).fill()
                            drawText(points[index].label, in: CGRect(x: cgPoint.x - 18, y: plot.maxY + 7, width: 36, height: 10), attributes: attrs(size: 7, weight: .regular, color: UIColor(white: 0.38, alpha: 1)))
                        }

                        drawText("Portfolio Value", in: CGRect(x: rect.minX, y: plot.minY, width: axisLeft - 4, height: 20), attributes: attrs(size: 7, weight: .semibold, color: UIColor(white: 0.38, alpha: 1)))
                        drawText(points.last?.display ?? "", in: CGRect(x: plot.maxX - 50, y: plot.minY - 2, width: 58, height: 11), attributes: attrs(size: 7, weight: .semibold, color: chartColor))
                    }

                    func drawBarChart(items: [(label: String, value: Double, display: String)], in rect: CGRect, barColor: UIColor, yAxisTitle: String) {
                        guard !items.isEmpty else { return }
                        let axisLeft: CGFloat = 34
                        let axisBottom: CGFloat = 28
                        let axisTop: CGFloat = 16
                        let plot = CGRect(
                            x: rect.minX + axisLeft,
                            y: rect.minY + axisTop,
                            width: rect.width - axisLeft - 8,
                            height: rect.height - axisTop - axisBottom
                        )
                        let maxValue = max(items.map(\.value).max() ?? 1, 1)

                        UIColor(white: 0.82, alpha: 1).setStroke()
                        let axis = UIBezierPath()
                        axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
                        axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                        axis.lineWidth = 0.7
                        axis.stroke()

                        let slot = plot.width / CGFloat(items.count)
                        let barWidth = min(slot * 0.52, 28)
                        for (index, item) in items.enumerated() {
                            let barHeight = CGFloat(item.value / maxValue) * (plot.height - 8)
                            let barX = plot.minX + CGFloat(index) * slot + (slot - barWidth) / 2
                            let barY = plot.maxY - barHeight
                            let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
                            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: 3)
                            barColor.setFill()
                            barPath.fill()

                            drawText(item.display, in: CGRect(x: barX - 12, y: barY - 13, width: barWidth + 24, height: 10), attributes: attrs(size: 7, weight: .semibold, color: UIColor(white: 0.28, alpha: 1)))
                            drawText(item.label, in: CGRect(x: plot.minX + CGFloat(index) * slot, y: plot.maxY + 7, width: slot, height: 10), attributes: attrs(size: 7, weight: .regular, color: UIColor(white: 0.38, alpha: 1)))
                        }

                        drawText(yAxisTitle, in: CGRect(x: rect.minX, y: plot.minY, width: axisLeft - 4, height: 22), attributes: attrs(size: 7, weight: .semibold, color: UIColor(white: 0.38, alpha: 1)))
                    }

                    func drawPieChart(items: [PortfolioDistributionItem], in rect: CGRect, colors: [UIColor]) {
                        let total = max(items.map { numericValue($0.percentage) }.reduce(0, +), 1)
                        let diameter = min(rect.height - 12, rect.width * 0.42)
                        let pieRect = CGRect(x: rect.minX, y: rect.midY - diameter / 2, width: diameter, height: diameter)
                        let center = CGPoint(x: pieRect.midX, y: pieRect.midY)
                        let radius = diameter / 2
                        var startAngle = -CGFloat.pi / 2

                        for (index, item) in items.enumerated() {
                            let percent = numericValue(item.percentage) / total
                            let endAngle = startAngle + CGFloat(percent) * 2 * CGFloat.pi
                            let path = UIBezierPath()
                            path.move(to: center)
                            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                            path.close()
                            colors[index % colors.count].setFill()
                            path.fill()

                            let midAngle = (startAngle + endAngle) / 2
                            let labelPoint = CGPoint(
                                x: center.x + cos(midAngle) * radius * 0.62,
                                y: center.y + sin(midAngle) * radius * 0.62
                            )
                            drawText(item.percentage, in: CGRect(x: labelPoint.x - 12, y: labelPoint.y - 5, width: 24, height: 10), attributes: attrs(size: 7, weight: .bold, color: .white))
                            startAngle = endAngle
                        }

                        let legendX = pieRect.maxX + 12
                        var legendY = rect.minY + 8
                        for (index, item) in items.enumerated() {
                            colors[index % colors.count].setFill()
                            UIBezierPath(roundedRect: CGRect(x: legendX, y: legendY + 2, width: 8, height: 8), cornerRadius: 2).fill()
                            drawText("\(item.name)  \(item.percentage)", in: CGRect(x: legendX + 13, y: legendY, width: rect.maxX - legendX - 13, height: 14), attributes: smallValueAttrs)
                            legendY += 15
                        }
                    }

                    func drawPieChart(items: [ReportDistributionItem], in rect: CGRect, colors: [UIColor]) {
                        let total = max(items.map { numericValue($0.percentage) }.reduce(0, +), 1)
                        let diameter = min(rect.height - 12, rect.width * 0.42)
                        let pieRect = CGRect(x: rect.minX, y: rect.midY - diameter / 2, width: diameter, height: diameter)
                        let center = CGPoint(x: pieRect.midX, y: pieRect.midY)
                        let radius = diameter / 2
                        var startAngle = -CGFloat.pi / 2

                        for (index, item) in items.enumerated() {
                            let percent = numericValue(item.percentage) / total
                            let endAngle = startAngle + CGFloat(percent) * 2 * CGFloat.pi
                            let path = UIBezierPath()
                            path.move(to: center)
                            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                            path.close()
                            colors[index % colors.count].setFill()
                            path.fill()

                            let midAngle = (startAngle + endAngle) / 2
                            let labelPoint = CGPoint(
                                x: center.x + cos(midAngle) * radius * 0.62,
                                y: center.y + sin(midAngle) * radius * 0.62
                            )
                            drawText(item.percentage, in: CGRect(x: labelPoint.x - 12, y: labelPoint.y - 5, width: 24, height: 10), attributes: attrs(size: 7, weight: .bold, color: .white))
                            startAngle = endAngle
                        }

                        let legendX = pieRect.maxX + 12
                        var legendY = rect.minY + 8
                        for (index, item) in items.enumerated() {
                            colors[index % colors.count].setFill()
                            UIBezierPath(roundedRect: CGRect(x: legendX, y: legendY + 2, width: 8, height: 8), cornerRadius: 2).fill()
                            drawText("\(item.name)  \(item.percentage)", in: CGRect(x: legendX + 13, y: legendY, width: rect.maxX - legendX - 13, height: 14), attributes: smallValueAttrs)
                            legendY += 15
                        }
                    }

                    func drawVisualReportHeader(title: String, meta: VisualReportMeta) {
                        drawText(title, in: CGRect(x: margin, y: y, width: contentWidth, height: 30), attributes: titleAttrs)
                        y += 30
                        drawText("Generated on: \(headerFormatter.string(from: meta.generatedAt))", in: CGRect(x: margin, y: y, width: contentWidth, height: 16), attributes: subtitleAttrs)
                        y += 15
                        drawText("Date Range: \(meta.dateRange) | Filters: \(meta.filters)", in: CGRect(x: margin, y: y, width: contentWidth, height: 28), attributes: subtitleAttrs)
                        y += 30
                        drawLine(y)
                        y += 18
                    }

                    func drawKPIGrid(title: String, items: [ReportKPI]) {
                        drawSectionTitle(title)

                        let columns = 4
                        let gap: CGFloat = 8
                        let cellWidth = (contentWidth - (gap * CGFloat(columns - 1))) / CGFloat(columns)
                        let cellHeight: CGFloat = 60

                        for (index, item) in items.enumerated() {
                            let col = index % columns
                            let row = index / columns
                            let x = margin + CGFloat(col) * (cellWidth + gap)
                            let cellY = y + CGFloat(row) * (cellHeight + gap)
                            roundedRect(CGRect(x: x, y: cellY, width: cellWidth, height: cellHeight), fill: panelFill, stroke: lineColor)
                            drawText(item.value, in: CGRect(x: x + 9, y: cellY + 8, width: cellWidth - 18, height: 18), attributes: metricValueAttrs)
                            drawText(item.title, in: CGRect(x: x + 9, y: cellY + 29, width: cellWidth - 18, height: 12), attributes: labelAttrs)
                            drawText(item.note, in: CGRect(x: x + 9, y: cellY + 43, width: cellWidth - 18, height: 10), attributes: attrs(size: 7.5, weight: .regular, color: UIColor(white: 0.48, alpha: 1)))
                        }

                        let rowCount = CGFloat((items.count + columns - 1) / columns)
                        y += rowCount * cellHeight + (rowCount - 1) * gap + 24
                    }

                    func drawInsights(_ insights: [String]) {
                        drawSectionTitle("Top Insights")
                        let bulletIndent: CGFloat = 14
                        for insight in insights {
                            let text = "• \(insight)"
                            let height = textHeight(text, width: contentWidth - bulletIndent, attributes: valueAttrs)
                            ensureSpace(height + 8)
                            drawText(text, in: CGRect(x: margin + bulletIndent, y: y, width: contentWidth - bulletIndent, height: height), attributes: valueAttrs)
                            y += height + 8
                        }
                    }

                    func drawBucketSummary(title: String, buckets: [ReportBucket]) {
                        drawSectionTitle(title)
                        let widths = [contentWidth * 0.42, contentWidth * 0.30, contentWidth * 0.28]
                        drawTableRow(["Segment", "Amount / Value", "Count"], widths: widths, fill: headerFill, attributes: tableHeaderAttrs)
                        for bucket in buckets {
                            drawTableRow([bucket.name, bucket.value, bucket.count], widths: widths, fill: nil, attributes: smallValueAttrs)
                        }
                        y += 18
                    }

                    func trendItems(_ points: [ReportTrendPoint]) -> [(label: String, value: Double, display: String)] {
                        points.map {
                            (label: $0.period.replacingOccurrences(of: "Week ", with: "W"), value: numericValue($0.value), display: $0.value)
                        }
                    }

                    func bucketItems(_ buckets: [ReportBucket]) -> [(label: String, value: Double, display: String)] {
                        buckets.map {
                            (label: $0.name, value: numericValue($0.value), display: $0.value)
                        }
                    }

                    func drawDisbursementReport(_ report: DisbursementReport) {
                        drawVisualReportHeader(title: "Disbursement Report", meta: report.meta)
                        drawKPIGrid(title: "Disbursement Metrics", items: report.kpis)
                        drawSectionTitle("Charts")

                        let gap: CGFloat = 12
                        let topChartHeight: CGFloat = 162
                        ensureSpace(topChartHeight + 12)
                        drawChartCard(title: "Disbursement Trend", x: margin, y: y, width: contentWidth, height: topChartHeight) { rect in
                            drawBarChart(items: trendItems(report.disbursementTrend), in: rect, barColor: UIColor(red: 29 / 255, green: 166 / 255, blue: 126 / 255, alpha: 1), yAxisTitle: "Amount")
                        }
                        y += topChartHeight + 12

                        let halfWidth = (contentWidth - gap) / 2
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 24)
                        drawChartCard(title: "By Loan Type", x: margin, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.byLoanType, in: rect, colors: chartColors(1))
                        }
                        drawChartCard(title: "By Region", x: margin + halfWidth + gap, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawBarChart(items: bucketItems(report.byRegion), in: rect, barColor: UIColor(red: 45 / 255, green: 116 / 255, blue: 230 / 255, alpha: 1), yAxisTitle: "Amount")
                        }
                        y += chartHeight + 24

                        drawInsights(report.insights)
                    }

                    func drawCollectionReport(_ report: CollectionReport) {
                        drawVisualReportHeader(title: "Collection Report", meta: report.meta)
                        drawKPIGrid(title: "Collection Metrics", items: report.kpis)
                        drawSectionTitle("Charts")

                        let gap: CGFloat = 12
                        let topChartHeight: CGFloat = 162
                        ensureSpace(topChartHeight + 12)
                        drawChartCard(title: "Collection Trend", x: margin, y: y, width: contentWidth, height: topChartHeight) { rect in
                            drawLineChart(points: trendItems(report.collectionTrend), in: rect, lineColor: UIColor(red: 45 / 255, green: 116 / 255, blue: 230 / 255, alpha: 1))
                        }
                        y += topChartHeight + 12

                        let halfWidth = (contentWidth - gap) / 2
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 24)
                        drawChartCard(title: "DPD Buckets", x: margin, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawBarChart(items: bucketItems(report.dpdBuckets), in: rect, barColor: UIColor(red: 230 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1), yAxisTitle: "Amount")
                        }
                        drawChartCard(title: "Paid vs Pending", x: margin + halfWidth + gap, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.paidVsPending, in: rect, colors: chartColors(2))
                        }
                        y += chartHeight + 24

                        drawBucketSummary(title: "DPD Summary", buckets: report.dpdBuckets)
                        drawInsights(report.insights)
                    }

                    func drawNPAReport(_ report: NPAReport) {
                        drawVisualReportHeader(title: "NPA Report", meta: report.meta)
                        drawKPIGrid(title: "NPA Metrics", items: report.kpis)
                        drawSectionTitle("Charts")

                        let gap: CGFloat = 12
                        let halfWidth = (contentWidth - gap) / 2
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 24)
                        drawChartCard(title: "Aging Buckets", x: margin, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawBarChart(items: bucketItems(report.agingBuckets), in: rect, barColor: UIColor(red: 230 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1), yAxisTitle: "NPA")
                        }
                        drawChartCard(title: "NPA vs Healthy Loans", x: margin + halfWidth + gap, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.npaVsHealthy, in: rect, colors: chartColors(2))
                        }
                        y += chartHeight + 24

                        drawBucketSummary(title: "Top NPA Regions", buckets: report.topRegions)
                        drawInsights(report.insights)
                    }

                    func drawRiskCreditReport(_ report: RiskCreditReport) {
                        drawVisualReportHeader(title: "Risk & Credit Report", meta: report.meta)
                        drawKPIGrid(title: "Risk & Credit Metrics", items: report.kpis)
                        drawSectionTitle("Charts")

                        let gap: CGFloat = 12
                        let halfWidth = (contentWidth - gap) / 2
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 12)
                        drawChartCard(title: "CIBIL Distribution", x: margin, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawBarChart(items: bucketItems(report.cibilDistribution), in: rect, barColor: UIColor(red: 45 / 255, green: 116 / 255, blue: 230 / 255, alpha: 1), yAxisTitle: "Loans")
                        }
                        drawChartCard(title: "Risk Categories", x: margin + halfWidth + gap, y: y, width: halfWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.riskCategories, in: rect, colors: chartColors(1))
                        }
                        y += chartHeight + 12

                        ensureSpace(chartHeight + 24)
                        drawChartCard(title: "FOIR Distribution", x: margin, y: y, width: contentWidth, height: chartHeight) { rect in
                            drawBarChart(items: bucketItems(report.foirDistribution), in: rect, barColor: UIColor(red: 242 / 255, green: 153 / 255, blue: 74 / 255, alpha: 1), yAxisTitle: "Loans")
                        }
                        y += chartHeight + 24

                        drawInsights(report.insights)
                    }

                    func drawPortfolioTrends(_ report: PortfolioPerformanceReport) {
                        drawSectionTitle("Trends")
                        let gap: CGFloat = 12
                        let cardHeight: CGFloat = 150
                        let topChartHeight: CGFloat = 162
                        ensureSpace(topChartHeight + cardHeight + 32)

                        drawChartCard(title: "Portfolio Value Trend", x: margin, y: y, width: contentWidth, height: topChartHeight) { rect in
                            let points = report.trends.map {
                                (label: $0.period.replacingOccurrences(of: "Week ", with: "W"), value: numericValue($0.portfolioValue), display: $0.portfolioValue)
                            }
                            drawLineChart(points: points, in: rect, lineColor: UIColor(red: 45 / 255, green: 116 / 255, blue: 230 / 255, alpha: 1))
                        }
                        y += topChartHeight + 12

                        let halfWidth = (contentWidth - gap) / 2
                        drawChartCard(title: "Disbursement Trend", x: margin, y: y, width: halfWidth, height: cardHeight) { rect in
                            let items = report.trends.map {
                                (label: $0.period.replacingOccurrences(of: "Week ", with: "W"), value: numericValue($0.disbursement), display: $0.disbursement)
                            }
                            drawBarChart(items: items, in: rect, barColor: UIColor(red: 29 / 255, green: 166 / 255, blue: 126 / 255, alpha: 1), yAxisTitle: "Amount")
                        }
                        drawChartCard(title: "Loan Count Trend", x: margin + halfWidth + gap, y: y, width: halfWidth, height: cardHeight) { rect in
                            let items = report.trends.map {
                                (label: $0.period.replacingOccurrences(of: "Week ", with: "W"), value: numericValue($0.loanCount), display: $0.loanCount)
                            }
                            drawBarChart(items: items, in: rect, barColor: UIColor(red: 242 / 255, green: 153 / 255, blue: 74 / 255, alpha: 1), yAxisTitle: "Loans")
                        }
                        y += cardHeight + 24
                    }

                    func drawPortfolioDistributions(_ report: PortfolioPerformanceReport) {
                        drawSectionTitle("Distributions")
                        let gap: CGFloat = 12
                        let boxWidth = (contentWidth - gap) / 2
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 24)

                        drawChartCard(title: "Loan Type Mix", x: margin, y: y, width: boxWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.loanTypeDistribution, in: rect, colors: chartColors(1))
                        }
                        drawChartCard(title: "Region Mix", x: margin + boxWidth + gap, y: y, width: boxWidth, height: chartHeight) { rect in
                            drawPieChart(items: report.regionDistribution, in: rect, colors: chartColors(2))
                        }
                        y += chartHeight + 24
                    }

                    func drawPortfolioNPA(_ report: PortfolioPerformanceReport) {
                        drawSectionTitle("NPA Summary")
                        let summaryItems = [
                            ("Total NPA", report.totalNpaAmount),
                            ("NPA %", report.npaPercentage),
                            ("NPA Count", report.npaCount)
                        ]
                        let gap: CGFloat = 8
                        let cellWidth = (contentWidth - (gap * 2)) / 3
                        let cellHeight: CGFloat = 46

                        for (index, item) in summaryItems.enumerated() {
                            let x = margin + CGFloat(index) * (cellWidth + gap)
                            roundedRect(CGRect(x: x, y: y, width: cellWidth, height: cellHeight), fill: panelFill, stroke: lineColor)
                            drawText(item.1, in: CGRect(x: x + 9, y: y + 8, width: cellWidth - 18, height: 16), attributes: metricValueAttrs)
                            drawText(item.0, in: CGRect(x: x + 9, y: y + 28, width: cellWidth - 18, height: 12), attributes: labelAttrs)
                        }
                        y += cellHeight + 14

                        let chartHeight: CGFloat = 156
                        ensureSpace(chartHeight + 20)
                        drawChartCard(title: "NPA Aging Buckets", x: margin, y: y, width: contentWidth, height: chartHeight) { rect in
                            let items = report.agingBuckets.map {
                                (label: $0.bucket, value: numericValue($0.amount), display: $0.amount)
                            }
                            drawBarChart(items: items, in: rect, barColor: UIColor(red: 230 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1), yAxisTitle: "NPA")
                        }
                        y += chartHeight + 20
                    }

                    func drawPortfolioInsights(_ report: PortfolioPerformanceReport) {
                        drawSectionTitle("Top Insights")
                        let bulletIndent: CGFloat = 14
                        for insight in report.topInsights {
                            let text = "• \(insight)"
                            let height = textHeight(text, width: contentWidth - bulletIndent, attributes: valueAttrs)
                            ensureSpace(height + 8)
                            drawText(text, in: CGRect(x: margin + bulletIndent, y: y, width: contentWidth - bulletIndent, height: height), attributes: valueAttrs)
                            y += height + 8
                        }
                    }

                    func drawPortfolioReport(_ report: PortfolioPerformanceReport) {
                        drawPortfolioHeader(report)
                        drawPortfolioKPIs(report)
                        drawPortfolioTrends(report)
                        drawPortfolioDistributions(report)
                        drawPortfolioNPA(report)
                        drawPortfolioInsights(report)
                    }

                    func drawApplications(for payload: AdminPDFReportPayload) {
                        drawText("Loan Applications", in: CGRect(x: margin, y: y, width: contentWidth, height: 18), attributes: sectionAttrs)
                        y += 24

                        if payload.rows.isEmpty {
                            let rect = CGRect(x: margin, y: y, width: contentWidth, height: 58)
                            roundedRect(rect, fill: panelFill, stroke: lineColor)
                            drawText("No loan applications match the selected filters.", in: rect.insetBy(dx: 14, dy: 18), attributes: valueAttrs)
                            y += 72
                            return
                        }

                        for row in payload.rows {
                            let cardHeight = applicationCardHeight(row)
                            ensureSpace(cardHeight + 10)
                            drawApplicationCard(row, height: cardHeight)
                            y += cardHeight + 10
                        }
                    }

                    func fieldGroups(for row: AdminPDFReportRow) -> [[(String, String)]] {
                        [
                            [
                                ("Borrower Phone", row.borrowerPhone),
                                ("Borrower Email", row.borrowerEmail),
                                ("Branch", row.branch)
                            ],
                            [
                                ("Loan Type", row.loanType),
                                ("Amount", currency(row.amount)),
                                ("Tenure / Rate", "\(row.tenureMonths) months | \(percent(row.interestRate))")
                            ],
                            [
                                ("EMI", currency(row.emi)),
                                ("Risk / SLA", "\(row.risk) | \(row.slaStatus)"),
                                ("Created", rowDateFormatter.string(from: row.createdAt))
                            ]
                        ]
                    }

                    func fieldHeight(label: String, value: String, width: CGFloat) -> CGFloat {
                        let labelHeight = textHeight(label, width: width, attributes: labelAttrs)
                        let valueHeight = textHeight(value, width: width, attributes: valueAttrs)
                        return labelHeight + 4 + valueHeight
                    }

                    func columnHeight(_ fields: [(String, String)], width: CGFloat) -> CGFloat {
                        let fieldSpacing: CGFloat = 10
                        let contentHeight = fields.reduce(CGFloat.zero) { partial, field in
                            partial + fieldHeight(label: field.0, value: field.1, width: width)
                        }
                        return contentHeight + CGFloat(max(fields.count - 1, 0)) * fieldSpacing
                    }

                    func applicationHeaderHeight(_ row: AdminPDFReportRow) -> CGFloat {
                        let horizontalPadding: CGFloat = 12
                        let columnGap: CGFloat = 8
                        let statusWidth: CGFloat = 104
                        let idWidth: CGFloat = 120
                        let nameWidth = contentWidth - (horizontalPadding * 2) - idWidth - statusWidth - (columnGap * 2)
                        let headerAttrs = attrs(size: 10, weight: .bold, color: .black)
                        let borrowerAttrs = attrs(size: 10, weight: .semibold, color: .black)
                        let statusAttrs = attrs(size: 9.5, weight: .semibold, color: statusColor(row.status))
                        let contentHeight = max(
                            textHeight(row.applicationId, width: idWidth, attributes: headerAttrs),
                            textHeight(row.borrowerName, width: nameWidth, attributes: borrowerAttrs),
                            textHeight(row.status, width: statusWidth, attributes: statusAttrs)
                        )
                        return max(28, contentHeight + 14)
                    }

                    func applicationCardHeight(_ row: AdminPDFReportRow) -> CGFloat {
                        let horizontalPadding: CGFloat = 12
                        let columnGap: CGFloat = 12
                        let bodyTopPadding: CGFloat = 12
                        let bottomPadding: CGFloat = 14
                        let columnWidth = (contentWidth - (horizontalPadding * 2) - (columnGap * 2)) / 3
                        let bodyHeight = fieldGroups(for: row)
                            .map { columnHeight($0, width: columnWidth) }
                            .max() ?? 0
                        return applicationHeaderHeight(row) + bodyTopPadding + bodyHeight + bottomPadding
                    }

                    func drawApplicationCard(_ row: AdminPDFReportRow, height: CGFloat) {
                        let rect = CGRect(x: margin, y: y, width: contentWidth, height: height)
                        roundedRect(rect, fill: .white, stroke: lineColor)

                        let headerHeight = applicationHeaderHeight(row)
                        let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: headerHeight)
                        headerFill.setFill()
                        UIBezierPath(
                            roundedRect: headerRect,
                            byRoundingCorners: [.topLeft, .topRight],
                            cornerRadii: CGSize(width: 6, height: 6)
                        ).fill()

                        let horizontalPadding: CGFloat = 12
                        let columnGap: CGFloat = 12
                        let idWidth: CGFloat = 120
                        let statusWidth: CGFloat = 104
                        let headerGap: CGFloat = 8
                        let nameWidth = contentWidth - (horizontalPadding * 2) - idWidth - statusWidth - (headerGap * 2)
                        let headerY = y + 7
                        let headerTextHeight = headerHeight - 14

                        drawText(row.applicationId, in: CGRect(x: margin + horizontalPadding, y: headerY, width: idWidth, height: headerTextHeight), attributes: attrs(size: 10, weight: .bold, color: .black))
                        drawText(row.borrowerName, in: CGRect(x: margin + horizontalPadding + idWidth + headerGap, y: headerY, width: nameWidth, height: headerTextHeight), attributes: attrs(size: 10, weight: .semibold, color: .black))
                        drawText(row.status, in: CGRect(x: margin + contentWidth - horizontalPadding - statusWidth, y: headerY, width: statusWidth, height: headerTextHeight), attributes: attrs(size: 9.5, weight: .semibold, color: statusColor(row.status)))

                        let columnWidth = (contentWidth - (horizontalPadding * 2) - (columnGap * 2)) / 3
                        let columnXs = [
                            margin + horizontalPadding,
                            margin + horizontalPadding + columnWidth + columnGap,
                            margin + horizontalPadding + (columnWidth + columnGap) * 2
                        ]
                        let bodyY = y + headerHeight + 12

                        for (columnIndex, fields) in fieldGroups(for: row).enumerated() {
                            var fieldY = bodyY
                            for field in fields {
                                let drawnHeight = drawField(field.0, field.1, x: columnXs[columnIndex], y: fieldY, width: columnWidth)
                                fieldY += drawnHeight + 10
                            }
                        }
                    }

                    @discardableResult
                    func drawField(_ label: String, _ value: String, x: CGFloat, y fieldY: CGFloat, width: CGFloat) -> CGFloat {
                        let labelHeight = textHeight(label, width: width, attributes: labelAttrs)
                        let valueHeight = textHeight(value, width: width, attributes: valueAttrs)
                        drawText(label, in: CGRect(x: x, y: fieldY, width: width, height: labelHeight), attributes: labelAttrs)
                        drawText(value, in: CGRect(x: x, y: fieldY + labelHeight + 4, width: width, height: valueHeight), attributes: valueAttrs)
                        return labelHeight + 4 + valueHeight
                    }

                    func drawCustomReport(_ payload: CustomReportPayload) {
                        drawText("Custom Report", in: CGRect(x: margin, y: y, width: contentWidth, height: 30), attributes: titleAttrs)
                        y += 30
                        drawText("Generated on: \(headerFormatter.string(from: payload.generatedAt))", in: CGRect(x: margin, y: y, width: contentWidth, height: 16), attributes: subtitleAttrs)
                        y += 15
                        drawText("Date Range: \(payload.config.filters.dateRange)", in: CGRect(x: margin, y: y, width: contentWidth, height: 16), attributes: subtitleAttrs)
                        y += 30
                        drawLine(y)
                        y += 18

                        ensureSpace(30)
                        drawText("Metrics", in: CGRect(x: margin, y: y, width: contentWidth, height: 18), attributes: sectionAttrs)
                        y += 24

                        let columns = 4
                        let gap: CGFloat = 8
                        let cellWidth = (contentWidth - (gap * CGFloat(columns - 1))) / CGFloat(columns)
                        let cellHeight: CGFloat = 60

                        for (index, item) in payload.kpis.enumerated() {
                            let col = index % columns
                            let row = index / columns
                            let x = margin + CGFloat(col) * (cellWidth + gap)
                            let cellY = y + CGFloat(row) * (cellHeight + gap)
                            ensureSpace(cellHeight + gap)
                            roundedRect(CGRect(x: x, y: cellY, width: cellWidth, height: cellHeight), fill: panelFill, stroke: lineColor)
                            drawText(item.value, in: CGRect(x: x + 9, y: cellY + 8, width: cellWidth - 18, height: 18), attributes: metricValueAttrs)
                            drawText(item.title, in: CGRect(x: x + 9, y: cellY + 29, width: cellWidth - 18, height: 12), attributes: labelAttrs)
                        }

                        let rowCount = CGFloat((payload.kpis.count + columns - 1) / columns)
                        y += rowCount * cellHeight + (rowCount - 1) * gap + 24

                        ensureSpace(30)
                        drawText("Dimensions Breakdown", in: CGRect(x: margin, y: y, width: contentWidth, height: 18), attributes: sectionAttrs)
                        y += 24
                        
                        let chartHeight: CGFloat = 176
                        ensureSpace(chartHeight + 12)
                        
                        let chartRect = CGRect(x: margin, y: y, width: contentWidth, height: chartHeight)
                        roundedRect(chartRect, fill: .white, stroke: lineColor)
                        drawText(payload.config.visualization.rawValue, in: CGRect(x: margin + 12, y: y + 10, width: contentWidth - 24, height: 16), attributes: sectionAttrs)
                        
                        let plotRect = CGRect(x: margin + 12, y: y + 34, width: contentWidth - 24, height: chartHeight - 46)
                        
                        let chartItems = payload.groupedData.map {
                            (label: $0.name, value: numericComponent($0.value), display: $0.value)
                        }
                        
                        switch payload.config.visualization {
                        case .line:
                            drawLineChart(points: chartItems, in: plotRect, lineColor: UIColor(red: 45/255, green: 116/255, blue: 230/255, alpha: 1))
                        case .bar:
                            drawBarChart(items: chartItems, in: plotRect, barColor: UIColor(red: 29/255, green: 166/255, blue: 126/255, alpha: 1), yAxisTitle: "Amount")
                        case .pie:
                            let pieItems = payload.groupedData.map {
                                ReportDistributionItem(name: $0.name, value: $0.value, percentage: "\(Int.random(in: 10...50))%")
                            }
                            drawPieChart(items: pieItems, in: plotRect, colors: chartColors(1))
                        }
                        y += chartHeight + 24
                    }

                    beginPage()
                    
                    switch type {
                    case .standard(let payload):
                        switch payload.reportName {
                        case "Portfolio Performance":
                            drawPortfolioReport(Self.samplePortfolioPerformanceReport(generatedAt: Date()))
                        case "Disbursement Report":
                            drawDisbursementReport(Self.sampleDisbursementReport(generatedAt: Date()))
                        case "Collection Report":
                            drawCollectionReport(Self.sampleCollectionReport(generatedAt: Date()))
                        case "NPA Report":
                            drawNPAReport(Self.sampleNPAReport(generatedAt: Date()))
                        case "Risk & Credit Report":
                            drawRiskCreditReport(Self.sampleRiskCreditReport(generatedAt: Date()))
                        default:
                            drawHeader(for: payload)
                            drawSummary(for: payload)
                            drawApplications(for: payload)
                        }
                    case .custom(let payload):
                        drawCustomReport(payload)
                    }
                    
                    drawFooter()
                }

                DispatchQueue.main.async { completion(outputURL) }
            } catch {
                print("[AdminReports] PDF FAILED with error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }



    private static func samplePortfolioPerformanceReport(generatedAt: Date) -> PortfolioPerformanceReport {
        PortfolioPerformanceReport(
            meta: PortfolioReportMeta(
                generatedAt: generatedAt,
                dateRange: "Last 30 days",
                filters: "All types, All regions, All status"
            ),
            kpis: [
                PortfolioKPI(title: "Portfolio Value", value: "₹48.6 Cr", note: "+6.8% vs prev."),
                PortfolioKPI(title: "Active Loans", value: "1,284", note: "+42 loans"),
                PortfolioKPI(title: "Disbursed Amount", value: "₹7.4 Cr", note: "MTD"),
                PortfolioKPI(title: "Avg Loan Size", value: "₹5.76 L", note: "portfolio avg"),
                PortfolioKPI(title: "NPA Amount", value: "₹1.18 Cr", note: "watch closely"),
                PortfolioKPI(title: "NPA %", value: "2.43%", note: "-0.18 pp"),
                PortfolioKPI(title: "Approval Rate", value: "71.6%", note: "+3.1 pp")
            ],
            trends: [
                PortfolioTrendPoint(period: "Week 1", portfolioValue: "₹45.5 Cr", disbursement: "₹1.3 Cr", loanCount: "1,198"),
                PortfolioTrendPoint(period: "Week 2", portfolioValue: "₹46.7 Cr", disbursement: "₹1.8 Cr", loanCount: "1,224"),
                PortfolioTrendPoint(period: "Week 3", portfolioValue: "₹47.9 Cr", disbursement: "₹2.0 Cr", loanCount: "1,257"),
                PortfolioTrendPoint(period: "Week 4", portfolioValue: "₹48.6 Cr", disbursement: "₹2.3 Cr", loanCount: "1,284")
            ],
            loanTypeDistribution: [
                PortfolioDistributionItem(name: "Home Loan", value: "₹22.4 Cr", percentage: "46%"),
                PortfolioDistributionItem(name: "Business Loan", value: "₹11.9 Cr", percentage: "25%"),
                PortfolioDistributionItem(name: "Personal Loan", value: "₹8.2 Cr", percentage: "17%"),
                PortfolioDistributionItem(name: "Vehicle Loan", value: "₹6.1 Cr", percentage: "12%")
            ],
            regionDistribution: [
                PortfolioDistributionItem(name: "Mumbai", value: "₹16.8 Cr", percentage: "35%"),
                PortfolioDistributionItem(name: "Delhi NCR", value: "₹12.7 Cr", percentage: "26%"),
                PortfolioDistributionItem(name: "Bangalore", value: "₹10.4 Cr", percentage: "21%"),
                PortfolioDistributionItem(name: "Chennai", value: "₹8.7 Cr", percentage: "18%")
            ],
            totalNpaAmount: "₹1.18 Cr",
            npaPercentage: "2.43%",
            npaCount: "38",
            agingBuckets: [
                PortfolioNPAgingBucket(bucket: "0-30 days", amount: "₹22 L", count: "9"),
                PortfolioNPAgingBucket(bucket: "31-60 days", amount: "₹31 L", count: "11"),
                PortfolioNPAgingBucket(bucket: "61-90 days", amount: "₹27 L", count: "8"),
                PortfolioNPAgingBucket(bucket: "90+ days", amount: "₹38 L", count: "10")
            ],
            topInsights: [
                "Portfolio value grew steadily over the last 30 days, led by home loans and business loans.",
                "NPA percentage improved by 18 bps, but the 90+ day bucket still represents the largest delinquency exposure.",
                "Mumbai and Delhi NCR contribute 61% of portfolio value, indicating concentrated regional exposure."
            ]
        )
    }

    private static func sampleDisbursementReport(generatedAt: Date) -> DisbursementReport {
        DisbursementReport(
            meta: VisualReportMeta(
                generatedAt: generatedAt,
                dateRange: "Last 30 days",
                filters: "All types, All regions, All status"
            ),
            kpis: [
                ReportKPI(title: "Total Disbursed", value: "₹7.4 Cr", note: "last 30 days"),
                ReportKPI(title: "Avg Size", value: "₹5.8 L", note: "per disbursal"),
                ReportKPI(title: "Growth", value: "+12.6%", note: "vs previous period"),
                ReportKPI(title: "Count", value: "128", note: "loans funded")
            ],
            disbursementTrend: [
                ReportTrendPoint(period: "Week 1", value: "₹1.3 Cr"),
                ReportTrendPoint(period: "Week 2", value: "₹1.8 Cr"),
                ReportTrendPoint(period: "Week 3", value: "₹2.0 Cr"),
                ReportTrendPoint(period: "Week 4", value: "₹2.3 Cr")
            ],
            byLoanType: [
                ReportDistributionItem(name: "Home Loan", value: "₹3.2 Cr", percentage: "43%"),
                ReportDistributionItem(name: "Business Loan", value: "₹1.9 Cr", percentage: "26%"),
                ReportDistributionItem(name: "Personal Loan", value: "₹1.4 Cr", percentage: "19%"),
                ReportDistributionItem(name: "Vehicle Loan", value: "₹0.9 Cr", percentage: "12%")
            ],
            byRegion: [
                ReportBucket(name: "Mumbai", value: "₹2.4 Cr", count: "38"),
                ReportBucket(name: "Delhi NCR", value: "₹1.9 Cr", count: "32"),
                ReportBucket(name: "Bangalore", value: "₹1.7 Cr", count: "29"),
                ReportBucket(name: "Chennai", value: "₹1.4 Cr", count: "29")
            ],
            insights: [
                "Disbursement growth improved 12.6%, driven mainly by home loans and business loans.",
                "Mumbai and Delhi NCR together contributed 58% of total disbursed value.",
                "Average disbursement size stayed stable, indicating growth is volume-led rather than ticket-size-led."
            ]
        )
    }

    private static func sampleCollectionReport(generatedAt: Date) -> CollectionReport {
        CollectionReport(
            meta: VisualReportMeta(
                generatedAt: generatedAt,
                dateRange: "Last 30 days",
                filters: "All types, All regions, All status"
            ),
            kpis: [
                ReportKPI(title: "EMI Collected", value: "₹5.9 Cr", note: "cash received"),
                ReportKPI(title: "Efficiency", value: "94.2%", note: "+1.8 pp"),
                ReportKPI(title: "Pending", value: "₹36 L", note: "current cycle"),
                ReportKPI(title: "Overdue", value: "₹62 L", note: "past due")
            ],
            collectionTrend: [
                ReportTrendPoint(period: "Week 1", value: "₹1.25 Cr"),
                ReportTrendPoint(period: "Week 2", value: "₹1.42 Cr"),
                ReportTrendPoint(period: "Week 3", value: "₹1.56 Cr"),
                ReportTrendPoint(period: "Week 4", value: "₹1.67 Cr")
            ],
            dpdBuckets: [
                ReportBucket(name: "0-30", value: "₹24 L", count: "42"),
                ReportBucket(name: "31-60", value: "₹18 L", count: "24"),
                ReportBucket(name: "61-90", value: "₹12 L", count: "13"),
                ReportBucket(name: "90+", value: "₹8 L", count: "7")
            ],
            paidVsPending: [
                ReportDistributionItem(name: "Paid", value: "₹5.9 Cr", percentage: "86%"),
                ReportDistributionItem(name: "Pending", value: "₹36 L", percentage: "5%"),
                ReportDistributionItem(name: "Overdue", value: "₹62 L", percentage: "9%")
            ],
            insights: [
                "Collection efficiency increased to 94.2%, with consistent weekly improvement.",
                "Most delinquency remains in the 0-30 DPD bucket, keeping recovery action relatively early-stage.",
                "The 90+ DPD bucket is smaller by count but should remain prioritized due to higher loss risk."
            ]
        )
    }

    private static func sampleNPAReport(generatedAt: Date) -> NPAReport {
        NPAReport(
            meta: VisualReportMeta(
                generatedAt: generatedAt,
                dateRange: "Last 30 days",
                filters: "All types, All regions, All status"
            ),
            kpis: [
                ReportKPI(title: "Total NPA", value: "₹1.18 Cr", note: "exposure"),
                ReportKPI(title: "NPA %", value: "2.43%", note: "-0.18 pp"),
                ReportKPI(title: "NPA Count", value: "38", note: "accounts")
            ],
            agingBuckets: [
                ReportBucket(name: "0-30", value: "₹22 L", count: "9"),
                ReportBucket(name: "31-60", value: "₹31 L", count: "11"),
                ReportBucket(name: "61-90", value: "₹27 L", count: "8"),
                ReportBucket(name: "90+", value: "₹38 L", count: "10")
            ],
            npaVsHealthy: [
                ReportDistributionItem(name: "Healthy", value: "₹47.42 Cr", percentage: "97.57%"),
                ReportDistributionItem(name: "NPA", value: "₹1.18 Cr", percentage: "2.43%")
            ],
            topRegions: [
                ReportBucket(name: "Mumbai", value: "₹38 L", count: "12"),
                ReportBucket(name: "Delhi NCR", value: "₹31 L", count: "10"),
                ReportBucket(name: "Chennai", value: "₹27 L", count: "8"),
                ReportBucket(name: "Bangalore", value: "₹22 L", count: "8")
            ],
            insights: [
                "NPA percentage improved, but 90+ day aging remains the largest exposure bucket.",
                "Mumbai and Delhi NCR contribute 58% of NPA value, indicating concentrated recovery risk.",
                "Early-stage NPA accounts should be prioritized before they migrate into harder recovery buckets."
            ]
        )
    }

    private static func sampleRiskCreditReport(generatedAt: Date) -> RiskCreditReport {
        RiskCreditReport(
            meta: VisualReportMeta(
                generatedAt: generatedAt,
                dateRange: "Last 30 days",
                filters: "All types, All regions, All status"
            ),
            kpis: [
                ReportKPI(title: "Avg CIBIL", value: "742", note: "+8 pts"),
                ReportKPI(title: "High Risk", value: "14.8%", note: "of applicants"),
                ReportKPI(title: "Fraud Flags", value: "17", note: "manual review"),
                ReportKPI(title: "Avg FOIR", value: "41%", note: "portfolio")
            ],
            cibilDistribution: [
                ReportBucket(name: "300-600", value: "94", count: "high risk"),
                ReportBucket(name: "600-750", value: "412", count: "moderate"),
                ReportBucket(name: "750+", value: "778", count: "strong")
            ],
            riskCategories: [
                ReportDistributionItem(name: "Low", value: "826", percentage: "64%"),
                ReportDistributionItem(name: "Medium", value: "273", percentage: "21%"),
                ReportDistributionItem(name: "High", value: "185", percentage: "15%")
            ],
            foirDistribution: [
                ReportBucket(name: "<35%", value: "504", count: "low stress"),
                ReportBucket(name: "35-50%", value: "548", count: "acceptable"),
                ReportBucket(name: "50%+", value: "232", count: "elevated")
            ],
            insights: [
                "Credit quality is healthy overall, with 64% of borrowers classified as low risk.",
                "High-risk share remains below 15%, but fraud-flagged cases require manual review discipline.",
                "FOIR concentration above 50% should be monitored before approval expansion."
            ]
        )
    }

    private static func portfolioCSV(_ report: PortfolioPerformanceReport) -> String {
        var rows: [[String]] = []
        appendMeta(title: "Portfolio Performance Report", generatedAt: report.meta.generatedAt, dateRange: report.meta.dateRange, filters: report.meta.filters, to: &rows)
        appendSection("KPIs", to: &rows)
        appendRows([
            ["Metric", "Value"],
            ["Total Portfolio Value", rawAmount(kpiValue(report.kpis, at: 0))],
            ["Total Active Loans", rawNumber(kpiValue(report.kpis, at: 1))],
            ["Total Disbursed Amount", rawAmount(kpiValue(report.kpis, at: 2))],
            ["Avg Loan Size", rawAmount(kpiValue(report.kpis, at: 3))],
            ["NPA Amount", rawAmount(kpiValue(report.kpis, at: 4))],
            ["NPA Percentage", rawPercentage(kpiValue(report.kpis, at: 5))],
            ["Approval Rate", rawPercentage(kpiValue(report.kpis, at: 6))]
        ], to: &rows)
        appendBlankRow(to: &rows)

        appendSection("Trends", to: &rows)
        appendRow(["Date", "Portfolio Value", "Disbursement", "Loan Count"], to: &rows)
        for item in report.trends {
            appendRow([item.period, rawAmount(item.portfolioValue), rawAmount(item.disbursement), rawNumber(item.loanCount)], to: &rows)
        }
        appendBlankRow(to: &rows)

        appendDistributionSection("Loan Type Distribution", firstColumn: "Loan Type", items: report.loanTypeDistribution, to: &rows)
        appendDistributionSection("Region Distribution", firstColumn: "Region", items: report.regionDistribution, to: &rows)

        appendSection("NPA Summary", to: &rows)
        appendRow(["Bucket", "NPA Amount", "Loan Count"], to: &rows)
        for bucket in report.agingBuckets {
            appendRow([bucket.bucket, rawAmount(bucket.amount), rawNumber(bucket.count)], to: &rows)
        }
        appendBlankRow(to: &rows)
        return csvString(rows)
    }

    private static func disbursementCSV(_ report: DisbursementReport) -> String {
        var rows: [[String]] = []
        appendMeta(title: "Disbursement Report", generatedAt: report.meta.generatedAt, dateRange: report.meta.dateRange, filters: report.meta.filters, to: &rows)
        appendKPISection(report.kpis, to: &rows)

        appendSection("Disbursement Trend", to: &rows)
        appendRow(["Date", "Disbursement Amount"], to: &rows)
        for item in report.disbursementTrend {
            appendRow([item.period, rawAmount(item.value)], to: &rows)
        }
        appendBlankRow(to: &rows)

        appendDistributionSection("Loan Type Breakdown", firstColumn: "Loan Type", items: report.byLoanType, to: &rows)
        appendBucketSection("Region Breakdown", firstColumn: "Region", valueColumn: "Disbursement Amount", countColumn: "Loan Count", buckets: report.byRegion, valueFormat: rawAmount, to: &rows)
        return csvString(rows)
    }

    private static func collectionCSV(_ report: CollectionReport) -> String {
        var rows: [[String]] = []
        appendMeta(title: "Collection Report", generatedAt: report.meta.generatedAt, dateRange: report.meta.dateRange, filters: report.meta.filters, to: &rows)
        appendKPISection(report.kpis, to: &rows)

        appendSection("Collection Trend", to: &rows)
        appendRow(["Date", "Collection Amount"], to: &rows)
        for item in report.collectionTrend {
            appendRow([item.period, rawAmount(item.value)], to: &rows)
        }
        appendBlankRow(to: &rows)

        appendBucketSection("DPD Buckets", firstColumn: "Bucket", valueColumn: "Overdue Amount", countColumn: "Loan Count", buckets: report.dpdBuckets, valueFormat: rawAmount, to: &rows)
        appendDistributionSection("Paid vs Pending", firstColumn: "Status", items: report.paidVsPending, to: &rows)
        return csvString(rows)
    }

    private static func npaCSV(_ report: NPAReport) -> String {
        var rows: [[String]] = []
        appendMeta(title: "NPA Report", generatedAt: report.meta.generatedAt, dateRange: report.meta.dateRange, filters: report.meta.filters, to: &rows)
        appendKPISection(report.kpis, to: &rows)
        appendBucketSection("Aging Buckets", firstColumn: "Bucket", valueColumn: "NPA Amount", countColumn: "Loan Count", buckets: report.agingBuckets, valueFormat: rawAmount, to: &rows)
        appendBucketSection("Region Contribution", firstColumn: "Region", valueColumn: "NPA Amount", countColumn: "Loan Count", buckets: report.topRegions, valueFormat: rawAmount, to: &rows)
        return csvString(rows)
    }

    private static func riskCreditCSV(_ report: RiskCreditReport) -> String {
        var rows: [[String]] = []
        appendMeta(title: "Risk & Credit Report", generatedAt: report.meta.generatedAt, dateRange: report.meta.dateRange, filters: report.meta.filters, to: &rows)
        appendKPISection(report.kpis, to: &rows)
        appendBucketSection("CIBIL Score Distribution", firstColumn: "CIBIL Bucket", valueColumn: "Loan Count", countColumn: "Description", buckets: report.cibilDistribution, valueFormat: rawNumber, countFormat: rawText, to: &rows)
        appendDistributionSection("Risk Category Breakdown", firstColumn: "Risk Category", items: report.riskCategories, valueFormat: rawNumber, to: &rows)
        appendBucketSection("FOIR Distribution", firstColumn: "FOIR Bucket", valueColumn: "Loan Count", countColumn: "Description", buckets: report.foirDistribution, valueFormat: rawNumber, countFormat: rawText, to: &rows)
        return csvString(rows)
    }

    private static func fallbackCSV(_ payload: AdminPDFReportPayload) -> String {
        var rows: [[String]] = []
        appendSection(payload.reportName, to: &rows)
        appendRow(["Filters", payload.filters], to: &rows)
        appendSection("KPIs", to: &rows)
        appendRows([
            ["Metric", "Value"],
            ["Total Applications", "\(payload.summary.total)"],
            ["Approved", "\(payload.summary.approved)"],
            ["Pending", "\(payload.summary.pending)"],
            ["Rejected", "\(payload.summary.rejected)"],
            ["Total Loan Value", cleanNumber(payload.summary.totalValue)],
            ["Avg Loan Size", cleanNumber(payload.summary.avgLoanSize)],
            ["High Risk", "\(payload.summary.highRisk)"]
        ], to: &rows)
        appendBlankRow(to: &rows)
        return csvString(rows)
    }

    private static func appendMeta(title: String, generatedAt: Date, dateRange: String, filters: String, to rows: inout [[String]]) {
        let formatter = ISO8601DateFormatter()
        appendRows([
            ["Report", title],
            ["Generated At", formatter.string(from: generatedAt)],
            ["Date Range", dateRange],
            ["Filters", filters]
        ], to: &rows)
        appendBlankRow(to: &rows)
    }

    private static func appendKPISection(_ kpis: [ReportKPI], to rows: inout [[String]]) {
        appendSection("KPIs", to: &rows)
        appendRow(["Metric", "Value"], to: &rows)
        for kpi in kpis {
            appendRow([kpi.title, rawMetricValue(kpi.value)], to: &rows)
        }
        appendBlankRow(to: &rows)
    }

    private static func appendDistributionSection(_ title: String, firstColumn: String, items: [PortfolioDistributionItem], to rows: inout [[String]]) {
        appendSection(title, to: &rows)
        appendRow([firstColumn, "Value", "Percentage"], to: &rows)
        for item in items {
            appendRow([item.name, rawAmount(item.value), rawPercentage(item.percentage)], to: &rows)
        }
        appendBlankRow(to: &rows)
    }

    private static func appendDistributionSection(_ title: String, firstColumn: String, items: [ReportDistributionItem], valueFormat: (String?) -> String = rawAmount, to rows: inout [[String]]) {
        appendSection(title, to: &rows)
        appendRow([firstColumn, "Value", "Percentage"], to: &rows)
        for item in items {
            appendRow([item.name, valueFormat(item.value), rawPercentage(item.percentage)], to: &rows)
        }
        appendBlankRow(to: &rows)
    }

    private static func appendBucketSection(
        _ title: String,
        firstColumn: String,
        valueColumn: String,
        countColumn: String,
        buckets: [ReportBucket],
        valueFormat: (String?) -> String,
        countFormat: (String?) -> String = rawNumber,
        to rows: inout [[String]]
    ) {
        appendSection(title, to: &rows)
        appendRow([firstColumn, valueColumn, countColumn], to: &rows)
        for bucket in buckets {
            appendRow([bucket.name, valueFormat(bucket.value), countFormat(bucket.count)], to: &rows)
        }
        appendBlankRow(to: &rows)
    }

    private static func appendSection(_ title: String, to rows: inout [[String]]) {
        appendRow([title], to: &rows)
    }

    private static func appendRows(_ newRows: [[String]], to rows: inout [[String]]) {
        for row in newRows {
            appendRow(row, to: &rows)
        }
    }

    private static func appendRow(_ row: [String], to rows: inout [[String]]) {
        rows.append(row)
    }

    private static func appendBlankRow(to rows: inout [[String]]) {
        rows.append([])
    }

    private static func csvString(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map(csvEscape).joined(separator: ",")
        }
        .joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        if normalized.contains(",") || normalized.contains("\"") {
            return "\"\(normalized.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return normalized
    }

    private static func rawMetricValue(_ value: String) -> String {
        if value.contains("₹") { return rawAmount(value) }
        if value.contains("%") { return rawPercentage(value) }
        return rawNumber(value)
    }

    private static func kpiValue(_ kpis: [PortfolioKPI], at index: Int) -> String {
        guard kpis.indices.contains(index) else { return "0" }
        return kpis[index].value
    }

    private static func rawAmount(_ value: String?) -> String {
        guard let value else { return "0" }
        let number = numericComponent(value)
        let lower = value.lowercased()
        let multiplier: Double
        if lower.contains("cr") {
            multiplier = 10_000_000
        } else if lower.contains("l") {
            multiplier = 100_000
        } else {
            multiplier = 1
        }
        return cleanNumber(number * multiplier)
    }

    private static func rawPercentage(_ value: String?) -> String {
        cleanNumber(numericComponent(value ?? "0"))
    }

    private static func rawNumber(_ value: String?) -> String {
        cleanNumber(numericComponent(value ?? "0"))
    }

    private static func rawText(_ value: String?) -> String {
        value ?? ""
    }

    private static func numericComponent(_ value: String) -> Double {
        let filtered = value.filter { "0123456789.".contains($0) }
        return Double(filtered) ?? 0
    }

    private static func cleanNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int64(value))
        }
        return String(format: "%.2f", value)
    }

    private static func attrs(size: CGFloat, weight: UIFont.Weight, color: UIColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        return [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }

    private static func clean(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "N/A" : trimmed
    }

    private static func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    private static func roundedRect(_ rect: CGRect, fill: UIColor, stroke: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = 0.6
        path.stroke()
    }

    private static func statusColor(_ status: String) -> UIColor {
        let lower = status.lowercased()
        if lower.contains("reject") { return UIColor(red: 180 / 255, green: 48 / 255, blue: 48 / 255, alpha: 1) }
        if lower.contains("approved") { return UIColor(red: 22 / 255, green: 130 / 255, blue: 86 / 255, alpha: 1) }
        return UIColor(red: 168 / 255, green: 111 / 255, blue: 18 / 255, alpha: 1)
    }
}

// MARK: - Custom Report Preview Sheet
struct CustomReportPreviewSheet: View {
    let payload: CustomReportPayload
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Report")
                            .font(.title2.bold())
                        Text("Generated on \(payload.generatedAt.formatted())")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Theme.Spacing.md)
                    
                    // KPIs
                    Text("Selected Metrics")
                        .font(Theme.Typography.headline)
                        .padding(.horizontal, Theme.Spacing.md)
                        
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                        ForEach(payload.kpis, id: \.title) { kpi in
                            VStack(spacing: 8) {
                                Text(kpi.value).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.Colors.primary)
                                Text(kpi.title).font(Theme.Typography.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.adaptiveSurface(colorScheme))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    
                    // Chart Placeholder (We could draw chart here, but as required, UI is simple, PDF draws it)
                    Text("Visualization: \(payload.config.visualization.rawValue)")
                        .font(Theme.Typography.headline)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, 8)
                        
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(payload.groupedData, id: \.name) { bucket in
                            HStack {
                                Text(bucket.name).font(Theme.Typography.subheadline)
                                Spacer()
                                Text(bucket.value).font(Theme.Typography.headline)
                            }
                            Divider()
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                    .cornerRadius(12)
                    .padding(.horizontal, Theme.Spacing.md)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Options")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        HStack(spacing: 16) {
                            exportButton("PDF",   icon: "doc.text.fill",              format: .pdf,   color: .red)
                            exportButton("CSV",   icon: "list.bullet.rectangle.fill", format: .csv,   color: Theme.Colors.adaptivePrimary(colorScheme))
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(Theme.Colors.adaptiveBackground(colorScheme))
            .navigationTitle("Preview Custom Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func exportButton(_ label: String, icon: String, format: ExportFormat, color: Color) -> some View {
        Button {
            dismiss()
            onExport(format)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                }
                Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Report Preview Sheet


private struct ReportPreviewSheet: View {
    let report: ReportItem
    let dateRange: String
    let loanType: String
    let region: String
    let status: String
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var reportsVM: AdminReportsViewModel

    private var statsRows: [ReportRow] {
        AdminReportsViewModel.liveReportRows(
            for: reportsVM.normalizedReportID(report.id),
            from: reportsVM.applications
        )
    }

    private var highlights: [ReportRow] {
        Array(statsRows.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Report header
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
                            Text(report.title).font(Theme.Typography.headline)
                            Text(report.description).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last: \(report.lastGenerated)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                            Text(report.size).font(Theme.Typography.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .cardStyle(colorScheme: colorScheme)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected Filters")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        filterRow("Date Range", dateRange)
                        filterRow("Loan Type", loanType)
                        filterRow("Region", region)
                        filterRow("Status", status)
                    }
                    .padding(Theme.Spacing.md)
                    .cardStyle(colorScheme: colorScheme)

                    if !highlights.isEmpty {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(highlights) { row in
                                previewStat(label: row.label, value: row.value, color: row.isPositive ? Theme.Colors.success : Theme.Colors.warning)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Options")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        HStack(spacing: 16) {
                            exportButton("PDF",   icon: "doc.text.fill",              format: .pdf,   color: .red)
                            exportButton("CSV",   icon: "list.bullet.rectangle.fill", format: .csv,   color: Theme.Colors.adaptivePrimary(colorScheme))
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.adaptiveBackground(colorScheme))
            .navigationTitle("Preview: \(report.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func filterRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    private func previewStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.sm)
        .cardStyle(colorScheme: colorScheme)
    }

    private func exportButton(_ label: String, icon: String, format: ExportFormat, color: Color) -> some View {
        Button {
            dismiss()
            onExport(format)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                }
                Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
