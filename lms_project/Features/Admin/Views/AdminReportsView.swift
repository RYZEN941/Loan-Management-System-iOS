//
//  AdminReportsView.swift
//  lms_project
//
//  TAB 4 — Reports with categories, filters, export, custom builder
//

import SwiftUI

struct AdminReportsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var reportsVM: AdminReportsViewModel
    @Binding var showProfile: Bool

    @State private var selectedCategory = 0
    @State private var showExportSheet: ReportItem? = nil
    @State private var previewingReport: ReportItem? = nil
    @State private var shareItem: ShareItem? = nil
    @State private var showingBanner = false
    @State private var bannerMessage = ""
    @State private var dateRange = "Last 30 Days"
    @State private var loanTypeFilter = "All Types"
    @State private var regionFilter = "All Regions"
    @State private var statusFilter = "All"

    private let categories = ["Portfolio","Disbursement","Collection","NPA","Risk & Credit"]
    private let dateRanges = ["Last 7 Days","Last 30 Days","Last 90 Days","This FY"]
    private let loanTypes = ["All Types","Home Loan","Personal Loan","Business Loan","Vehicle Loan"]
    private let regions = ["All Regions","Mumbai","Delhi NCR","Bangalore","Chennai"]
    private let statuses = ["All","Active","Closed","NPA"]

    private let reports: [ReportItem] = [
        ReportItem(id:"RPT-PERF",title:"Portfolio Performance",description:"Total portfolio, disbursements, NPA summary",icon:"chart.bar.fill",color:Theme.Colors.primary,lastGenerated:"Apr 15, 2025",size:"2.4 MB"),
        ReportItem(id:"RPT-DISB",title:"Disbursement Report",description:"Loans disbursed by branch, type, and officer",icon:"arrow.up.right.circle.fill",color:Theme.Colors.success,lastGenerated:"Apr 14, 2025",size:"1.8 MB"),
        ReportItem(id:"RPT-COLL",title:"Collection Report",description:"EMI recovery, DPD buckets, outstanding analysis",icon:"indianrupeesign.circle.fill",color:Color(hex:"6F42C1"),lastGenerated:"Apr 13, 2025",size:"3.1 MB"),
        ReportItem(id:"RPT-NPA",title:"NPA Report",description:"Non-performing assets, aging, provisioning",icon:"exclamationmark.triangle.fill",color:Theme.Colors.critical,lastGenerated:"Apr 12, 2025",size:"1.2 MB"),
        ReportItem(id:"RPT-RISK",title:"Risk & Credit Report",description:"CIBIL distribution, FOIR analysis, fraud flags",icon:"shield.lefthalf.filled",color:Theme.Colors.warning,lastGenerated:"Apr 10, 2025",size:"2.8 MB"),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment:.top) {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                ScrollView {
                    VStack(spacing:Theme.Spacing.lg) {
                        headerCard
                        filtersSection
                        reportCategoryTabs
                        reportListSection
                    }
                    .padding(.horizontal,Theme.Spacing.lg)
                    .padding(.bottom,Theme.Spacing.lg)
                }
                if showingBanner { exportBanner.padding(.top,8).transition(.move(edge:.top).combined(with:.opacity)) }
            }
            .animation(.spring(response:0.35,dampingFraction:0.8),value:showingBanner)
            .navigationTitle("Reports").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { ProfileNavButton(showProfile:$showProfile) } }
            .sheet(item:$showExportSheet) { report in
                ExportOptionsSheet(report:report,onExport:{format in triggerExport(report:report,format:format)})
            }
            .sheet(item:$previewingReport) { report in
                ReportPreviewSheet(report:report,onExport:{format in triggerExport(report:report,format:format)})
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing:Theme.Spacing.lg) {
            VStack(alignment:.leading,spacing:Theme.Spacing.xs) {
                Text("Report Centre").font(Theme.Typography.title)
                Text("Generate, preview, and export compliance-ready reports").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName:"doc.richtext").font(.system(size:32)).foregroundStyle(Theme.Colors.primary.opacity(0.4))
        }.padding(Theme.Spacing.lg).cardStyle(colorScheme:colorScheme)
    }

    // MARK: - Filters
    private var filtersSection: some View {
        VStack(alignment:.leading,spacing:Theme.Spacing.md) {
            SectionHeader(title:"Filters",icon:"line.3.horizontal.decrease.circle")
            HStack(spacing:Theme.Spacing.sm) {
                filterPicker(label:"Date Range",selection:$dateRange,options:dateRanges)
                filterPicker(label:"Loan Type",selection:$loanTypeFilter,options:loanTypes)
                filterPicker(label:"Region",selection:$regionFilter,options:regions)
                filterPicker(label:"Status",selection:$statusFilter,options:statuses)
            }
        }
    }

    private func filterPicker(label:String,selection:Binding<String>,options:[String]) -> some View {
        VStack(alignment:.leading,spacing:4) {
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
            Picker(label,selection:selection) {
                ForEach(options,id:\.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.horizontal,12).padding(.vertical,8)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.sm))
        }.frame(maxWidth:.infinity,alignment:.leading)
    }

    // MARK: - Category Tabs
    private var reportCategoryTabs: some View {
        ScrollView(.horizontal,showsIndicators:false) {
            HStack(spacing:Theme.Spacing.sm) {
                ForEach(categories.indices,id:\.self) { idx in
                    Button {
                        withAnimation { selectedCategory = idx }
                    } label: {
                        Text(categories[idx])
                            .font(Theme.Typography.caption).fontWeight(selectedCategory==idx ? .semibold : .regular)
                            .foregroundStyle(selectedCategory==idx ? .white : Theme.Colors.primary)
                            .padding(.horizontal,14).padding(.vertical,8)
                            .background(selectedCategory==idx ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Report List
    private var reportListSection: some View {
        VStack(alignment:.leading,spacing:Theme.Spacing.md) {
            SectionHeader(title:"Available Reports",icon:"doc.on.doc")
            let filtered = selectedCategory < reports.count ? [reports[selectedCategory]] : reports
            ForEach(filtered) { report in
                ReportCard(report:report,colorScheme:colorScheme,onExport:{showExportSheet=report},onPreview:{previewingReport=report})
            }
        }
    }



    // MARK: - Export
    private var exportBanner: some View {
        HStack(spacing:Theme.Spacing.sm) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.8).tint(.white)
            Text(bannerMessage).font(Theme.Typography.subheadline).fontWeight(.medium).foregroundStyle(.white)
        }.frame(maxWidth:.infinity).padding(.vertical,12).background(Theme.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.md)).padding(.horizontal,Theme.Spacing.lg)
    }

    private func triggerExport(report:ReportItem,format:ExportFormat) {
        bannerMessage = "Generating \(report.title) as \(format.displayName)…"
        withAnimation{showingBanner=true}
        
        DispatchQueue.main.asyncAfter(deadline:.now()+1.5) {
            withAnimation{showingBanner=false}
            
            let fileName = "\(report.title.replacingOccurrences(of: " ", with: "_")).\(format.rawValue)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try? "Mock report data for \(report.title)".write(to: tempURL, atomically: true, encoding: .utf8)
            
            self.shareItem = ShareItem(url: tempURL)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Report Card
private struct ReportCard: View {
    let report:ReportItem; let colorScheme:ColorScheme; let onExport:()->Void; let onPreview:()->Void
    var body: some View {
        VStack(alignment:.leading,spacing:Theme.Spacing.md) {
            HStack(spacing:Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius:Theme.Radius.md).fill(report.color.opacity(0.12)).frame(width:44,height:44)
                    Image(systemName:report.icon).font(.system(size:20)).foregroundStyle(report.color)
                }
                VStack(alignment:.leading,spacing:3) {
                    Text(report.title).font(Theme.Typography.headline)
                    Text(report.description).font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing:Theme.Spacing.md) {
                Label("Last: \(report.lastGenerated)",systemImage:"clock").font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
                Label(report.size,systemImage:"doc").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            HStack(spacing:Theme.Spacing.sm) {
                expBtn(label:"Preview",icon:"eye",primary:false,action:onPreview)
                expBtn(label:"PDF",icon:"doc.fill",primary:true,action:onExport)
                expBtn(label:"Excel",icon:"tablecells.fill",primary:false,action:onExport)
                expBtn(label:"CSV",icon:"list.bullet",primary:false,action:onExport)
            }
        }.padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
    }
    private func expBtn(label:String,icon:String,primary:Bool,action:@escaping ()->Void) -> some View {
        Button(action:action) {
            HStack(spacing:6) {
                Image(systemName:icon).font(.system(size:13))
                Text(label).font(.system(size:13,weight:.semibold))
            }
            .foregroundStyle(primary ? .white : Theme.Colors.primary)
            .frame(maxWidth:.infinity).padding(.vertical,10)
            .background(primary ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.sm))
        }.buttonStyle(.plain)
    }
}

// MARK: - Export Options Sheet
private struct ExportOptionsSheet: View {
    let report:ReportItem; let onExport:(ExportFormat)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var dateRange = 0
    private let dateRanges = ["This Month","Last 3 Months","Last 6 Months","This FY"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Report") { LabeledContent("Type",value:report.title); LabeledContent("Size",value:report.size) }
                Section("Format") {
                    Picker("Format",selection:$selectedFormat) {
                        ForEach(ExportFormat.allCases,id:\.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Date Range") {
                    Picker("Period",selection:$dateRange) {
                        ForEach(dateRanges.indices,id:\.self) { Text(dateRanges[$0]).tag($0) }
                    }
                }
            }
            .navigationTitle("Export Options").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel"){dismiss()} }
                ToolbarItem(placement:.confirmationAction) { Button("Generate"){dismiss();onExport(selectedFormat)}.fontWeight(.semibold) }
            }
        }
    }
}



// MARK: - Data Models
struct ReportItem: Identifiable {
    let id:String; let title:String; let description:String; let icon:String; let color:Color; let lastGenerated:String; let size:String
}

enum ExportFormat: String, CaseIterable {
    case pdf="pdf",excel="excel",csv="csv"
    var displayName: String { switch self { case .pdf: return "PDF"; case .excel: return "Excel"; case .csv: return "CSV" } }
}

// MARK: - Report Preview Sheet
private struct ReportPreviewSheet: View {
    let report: ReportItem
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let sampleColumns = ["Loan ID", "Borrower", "Amount", "Status", "Risk"]
    private let sampleRows: [[String]] = [
        ["APP-2024-001", "Rajesh Kumar", "₹25L", "Approved", "Low"],
        ["APP-2024-002", "Priya Sharma", "₹42L", "Under Review", "Medium"],
        ["APP-2024-003", "Amit Singh", "₹18L", "Approved", "Low"],
        ["APP-2024-004", "Kavitha Nair", "₹8.5L", "Pending", "High"],
        ["APP-2024-005", "Suresh Pillai", "₹55L", "Rejected", "High"],
        ["APP-2024-006", "Deepa Menon", "₹12L", "Approved", "Low"],
    ]

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

                    // Data table
                    VStack(spacing: 0) {
                        // Table header
                        HStack(spacing: 0) {
                            ForEach(sampleColumns, id: \.self) { col in
                                Text(col)
                                    .font(Theme.Typography.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                        }
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))

                        // Table rows
                        ForEach(sampleRows.indices, id: \.self) { rowIdx in
                            HStack(spacing: 0) {
                                ForEach(sampleRows[rowIdx].indices, id: \.self) { colIdx in
                                    Text(sampleRows[rowIdx][colIdx])
                                        .font(Theme.Typography.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 10)
                                }
                            }
                            if rowIdx < sampleRows.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .cardStyle(colorScheme: colorScheme)

                    // Summary stats
                    HStack(spacing: Theme.Spacing.md) {
                        previewStat(label: "Total Records", value: "248", color: Theme.Colors.primary)
                        previewStat(label: "Approved", value: "142", color: Theme.Colors.success)
                        previewStat(label: "Pending", value: "68", color: Theme.Colors.warning)
                        previewStat(label: "Rejected", value: "38", color: Theme.Colors.critical)
                    }

                    // Export buttons
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Export Full Report").font(Theme.Typography.subheadline).fontWeight(.medium)
                        HStack(spacing: Theme.Spacing.sm) {
                            exportButton("PDF", icon: "doc.fill", format: .pdf)
                            exportButton("Excel", icon: "tablecells.fill", format: .excel)
                            exportButton("CSV", icon: "list.bullet", format: .csv)
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

    private func previewStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.sm)
        .cardStyle(colorScheme: colorScheme)
    }

    private func exportButton(_ label: String, icon: String, format: ExportFormat) -> some View {
        Button {
            dismiss()
            onExport(format)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
