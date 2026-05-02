//
//  AdminReportsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Report Models

struct ReportType: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

struct ScheduledReport: Identifiable, Hashable {
    let id: String
    let reportName: String
    let frequency: String      // "Daily", "Weekly", "Monthly"
    let nextRun: Date
    let recipients: String
    var isActive: Bool
}

struct ReportRow: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
    let change: String         // e.g. "+5%" or "-2%"
    let isPositive: Bool
}

struct AdminPDFReportRow {
    let applicationId: String
    let borrowerName: String
    let borrowerPhone: String
    let borrowerEmail: String
    let branch: String
    let loanType: String
    let amount: Double
    let tenureMonths: Int
    let interestRate: Double
    let emi: Double
    let status: String
    let risk: String
    let slaStatus: String
    let createdAt: Date
}

struct AdminPDFReportSummary {
    let total: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let totalValue: Double
    let avgLoanSize: Double
    let highRisk: Int
}

struct AdminPDFReportPayload {
    let reportName: String
    let filters: String
    let rows: [AdminPDFReportRow]
    let summary: AdminPDFReportSummary
    var portfolioResponse: PortfolioPerformanceResponse? = nil
    var disbursementResponse: DisbursementResponse? = nil
    var collectionResponse: CollectionResponse? = nil
    var npaResponse: NPAResponse? = nil
    var riskCreditResponse: RiskCreditResponse? = nil
}

// MARK: - Admin Reports View Model

class AdminReportsViewModel: ObservableObject {
    private let supportsBackendReports = false
    private struct LocalReportBundle {
        let portfolio: PortfolioPerformanceResponse
        let disbursement: DisbursementResponse
        let collection: CollectionResponse
        let npa: NPAResponse
        let risk: RiskCreditResponse
    }

    @Published var selectedReportType: ReportType? = nil
    @Published var selectedBranch = "All Branches"
    @Published var selectedLoanType = "All Types"
    @Published var dateRangeLabel = "Last 30 Days"
    @Published var scheduledReports: [ScheduledReport] = []
    @Published var reportRows: [ReportRow] = []
    @Published var showExportAlert = false
    @Published var exportFormat = "PDF"
    @Published var isLoading = false
    @Published var reportError: String? = nil

    // MARK: - Per-Report Loading Flags
    @Published var isLoadingPortfolio = false
    @Published var isLoadingDisbursement = false
    @Published var isLoadingCollection = false
    @Published var isLoadingNPA = false
    @Published var isLoadingRisk = false

    func isLoadingReport(_ reportId: String) -> Bool {
        switch normalizedReportID(reportId) {
        case "RPT-01":  return isLoadingPortfolio
        case "RPT-02":  return isLoadingCollection
        case "RPT-03":  return isLoadingDisbursement
        case "RPT-NPA": return isLoadingNPA
        case "RPT-04":  return isLoadingRisk
        default:        return false
        }
    }

    // MARK: - Backend Report Responses
    @Published var portfolioReport: PortfolioPerformanceResponse? = nil
    @Published var disbursementReport: DisbursementResponse? = nil
    @Published var collectionReport: CollectionResponse? = nil
    @Published var npaReport: NPAResponse? = nil
    @Published var riskCreditReport: RiskCreditResponse? = nil

    @Published private(set) var applications: [LoanApplication] = []

    private let loanAPI = LoanAPI()

    // Active filter state (set by View, consumed by loadReport)
    var activeDateRange: String = "Last 30 Days"
    var activeLoanType: String = "All Types"
    var activeRegion: String = "All Regions"
    var activeStatus: String = "All"

    let reportTypes: [ReportType] = [
        ReportType(id: "RPT-01", name: "Portfolio Overview",    icon: "chart.pie.fill",          description: "Total portfolio, disbursements, NPA summary"),
        ReportType(id: "RPT-02", name: "Collection Report",     icon: "indianrupeesign.circle",   description: "EMI recovery, DPD buckets, outstanding"),
        ReportType(id: "RPT-03", name: "Disbursement Report",   icon: "arrow.up.right.circle",    description: "Loans disbursed by branch & type"),
        ReportType(id: "RPT-04", name: "Risk & CIBIL Report",   icon: "exclamationmark.shield",   description: "CIBIL distribution, FOIR, fraud flags"),
        ReportType(id: "RPT-05", name: "SLA Compliance",        icon: "clock.badge.checkmark",    description: "SLA adherence by officer & branch")
    ]

    let branches   = ["All Branches", "Mumbai Central", "Delhi North", "Bangalore South"]
    let loanTypes  = ["All Types", "Home Loan", "Personal Loan", "Business Loan", "Vehicle Loan", "Education Loan"]
    let dateRanges = ["Last 7 Days", "Last 30 Days", "Last 90 Days", "This Year"]

    // MARK: - Load

    func loadData() {
        isLoading = true
        Task {
            defer { Task { @MainActor in self.isLoading = false } }
            guard #available(iOS 18.0, *) else { return }

            _ = try await loadApplications()
            await loadAllReports()

            await MainActor.run {
                self.scheduledReports = Self.mockScheduledReports()
                self.selectedReportType = self.reportTypes.first
                self.refreshReportData()
            }
        }
    }

    func refreshReportData(for reportId: String? = nil) {
        let id = reportId ?? selectedReportType?.id ?? "RPT-01"
        reportRows = reportRowsFromBackend(for: id)
    }

    // MARK: - Backend Report Loading

    func loadAllReports() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.portfolioReport = bundle.portfolio
                self.disbursementReport = bundle.disbursement
                self.collectionReport = bundle.collection
                self.npaReport = bundle.npa
                self.riskCreditReport = bundle.risk
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPortfolioReport() }
            group.addTask { await self.loadDisbursementReport() }
            group.addTask { await self.loadCollectionReport() }
            group.addTask { await self.loadNPAReport() }
            group.addTask { await self.loadRiskCreditReport() }
        }
    }

    func loadPortfolioReport() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.portfolioReport = bundle.portfolio
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await MainActor.run { isLoadingPortfolio = true }
        defer { Task { @MainActor in isLoadingPortfolio = false } }
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.portfolioPerformance(query: query)
            await MainActor.run {
                self.portfolioReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run {
                self.reportError = error.localizedDescription
            }
        }
    }

    func loadDisbursementReport() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.disbursementReport = bundle.disbursement
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await MainActor.run { isLoadingDisbursement = true }
        defer { Task { @MainActor in isLoadingDisbursement = false } }
        do {
            let query = buildReportQuery(status: "DISBURSED")
            let response = try await ReportsAPI.disbursement(query: query)
            await MainActor.run {
                self.disbursementReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadCollectionReport() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.collectionReport = bundle.collection
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await MainActor.run { isLoadingCollection = true }
        defer { Task { @MainActor in isLoadingCollection = false } }
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.collection(query: query)
            await MainActor.run {
                self.collectionReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadNPAReport() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.npaReport = bundle.npa
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await MainActor.run { isLoadingNPA = true }
        defer { Task { @MainActor in isLoadingNPA = false } }
        do {
            let query = buildReportQuery(status: "NPA")
            let response = try await ReportsAPI.npa(query: query)
            await MainActor.run {
                self.npaReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadRiskCreditReport() async {
        guard supportsBackendReports else {
            let bundle = buildLocalReportBundle(
                dateRange: activeDateRange,
                loanType: activeLoanType,
                region: activeRegion,
                status: activeStatus
            )
            await MainActor.run {
                self.riskCreditReport = bundle.risk
                self.reportError = nil
                self.refreshReportData()
            }
            return
        }
        await MainActor.run { isLoadingRisk = true }
        defer { Task { @MainActor in isLoadingRisk = false } }
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.riskCredit(query: query)
            await MainActor.run {
                self.riskCreditReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    /// Reload a single report by its UI report ID (e.g. "RPT-PERF")
    func reloadReport(reportId: String) {
        guard supportsBackendReports else {
            Task { await loadAllReports() }
            return
        }
        Task {
            switch normalizedReportID(reportId) {
            case "RPT-01":  await loadPortfolioReport()
            case "RPT-02":  await loadCollectionReport()
            case "RPT-03":  await loadDisbursementReport()
            case "RPT-NPA": await loadNPAReport()
            case "RPT-04":  await loadRiskCreditReport()
            default: break
            }
        }
    }

    // MARK: - Query Builder

    func buildReportQuery(status overrideStatus: String? = nil, format: String = "json") -> ReportQuery {
        let (from, to) = dateRangeToISO(activeDateRange)
        return ReportQuery(
            from: from,
            to: to,
            loanType: mapLoanType(activeLoanType),
            region: mapRegion(activeRegion),
            status: overrideStatus ?? mapStatus(activeStatus),
            format: format
        )
    }

    func dateRangeToISO(_ label: String) -> (String, String) {
        let calendar = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let to = fmt.string(from: now)

        let from: String
        switch label {
        case "Last 7 Days":
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            from = fmt.string(from: start)
        case "Last 30 Days":
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            from = fmt.string(from: start)
        case "Last 90 Days":
            let start = calendar.date(byAdding: .day, value: -90, to: now)!
            from = fmt.string(from: start)
        case "This FY":
            let year = calendar.component(.month, from: now) >= 4
                ? calendar.component(.year, from: now)
                : calendar.component(.year, from: now) - 1
            let start = calendar.date(from: DateComponents(year: year, month: 4, day: 1))!
            from = fmt.string(from: start)
        case "This Year":
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            from = fmt.string(from: start)
        default:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            from = fmt.string(from: start)
        }
        return (from, to)
    }

    private func mapLoanType(_ label: String) -> String {
        switch label {
        case "All Types":      return "ALL"
        case "Home Loan":      return "HOME"
        case "Personal Loan":  return "PERSONAL"
        case "Business Loan":  return "BUSINESS"
        case "Vehicle Loan":   return "VEHICLE"
        default:               return "ALL"
        }
    }

    private func mapRegion(_ label: String) -> String {
        switch label {
        case "All Regions": return "ALL"
        default:            return label.uppercased()
        }
    }

    private func mapStatus(_ label: String) -> String {
        switch label {
        case "All":     return "ALL"
        case "Active":  return "ACTIVE"
        case "Closed":  return "CLOSED"
        case "NPA":     return "NPA"
        default:        return "ALL"
        }
    }

    // MARK: - Applications (fallback data source)

    private func loadApplications() async throws {
        guard #available(iOS 18.0, *) else { return }
        do {
            let list = try await loanAPI.listLoanApplications(limit: 500, offset: 0, branchID: nil, authorized: true)
            let mapped = list.map { LoanApplication.from(proto: $0) }
            await MainActor.run { self.applications = mapped }
        } catch {
            await MainActor.run { self.applications = [] }
        }
    }

    // MARK: - Actions

    func exportReport(format: String) {
        exportFormat = format
        showExportAlert = true
    }

    func toggleScheduled(_ report: ScheduledReport) {
        if let idx = scheduledReports.firstIndex(where: { $0.id == report.id }) {
            scheduledReports[idx].isActive.toggle()
        }
    }

    // MARK: - Report Rows from Backend

    func normalizedReportID(_ uiReportID: String) -> String {
        switch uiReportID {
        case "RPT-PERF": return "RPT-01"
        case "RPT-COLL": return "RPT-02"
        case "RPT-DISB": return "RPT-03"
        case "RPT-RISK": return "RPT-04"
        case "RPT-NPA":  return "RPT-NPA"
        default:         return uiReportID
        }
    }

    /// Derive ReportRow from backend response when available, else fall back to application data
    func reportRowsFromBackend(for reportId: String) -> [ReportRow] {
        let id = normalizedReportID(reportId)
        switch id {
        case "RPT-01":
            if let r = portfolioReport {
                return [
                    ReportRow(id: "r1", label: "Portfolio Value",     value: r.kpis.totalPortfolioValue.lakhsFormatted, change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Active Loans",        value: "\(r.kpis.totalActiveLoans)",                 change: "—", isPositive: true),
                    ReportRow(id: "r3", label: "Disbursed Amount",    value: r.kpis.totalDisbursedAmount.lakhsFormatted, change: "—", isPositive: true),
                    ReportRow(id: "r4", label: "NPA %",               value: String(format: "%.2f%%", r.kpis.npaPercentage), change: "—", isPositive: r.kpis.npaPercentage < 3),
                    ReportRow(id: "r5", label: "Approval Rate",       value: String(format: "%.1f%%", r.kpis.approvalRate), change: "—", isPositive: r.kpis.approvalRate >= 70),
                    ReportRow(id: "r6", label: "Avg Loan Size",       value: r.kpis.avgLoanSize.lakhsFormatted,         change: "—", isPositive: true)
                ]
            }
        case "RPT-02":
            if let r = collectionReport {
                return [
                    ReportRow(id: "r1", label: "EMI Collected",       value: r.kpis.totalEmiCollected.lakhsFormatted,           change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Collection Efficiency", value: String(format: "%.1f%%", r.kpis.collectionEfficiencyPercentage), change: "—", isPositive: r.kpis.collectionEfficiencyPercentage >= 90),
                    ReportRow(id: "r3", label: "Pending Amount",      value: r.kpis.pendingAmount.lakhsFormatted,               change: "—", isPositive: r.kpis.pendingAmount == 0),
                    ReportRow(id: "r4", label: "Overdue Amount",       value: r.kpis.overdueAmount.lakhsFormatted,               change: "—", isPositive: r.kpis.overdueAmount == 0)
                ]
            }
        case "RPT-03":
            if let r = disbursementReport {
                return [
                    ReportRow(id: "r1", label: "Total Disbursed",     value: r.kpis.totalDisbursedAmount.lakhsFormatted,       change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Avg Disbursement",    value: r.kpis.avgDisbursementSize.lakhsFormatted,         change: "—", isPositive: true),
                    ReportRow(id: "r3", label: "Growth %",            value: String(format: "%.1f%%", r.kpis.disbursementGrowthPercentage), change: "—", isPositive: r.kpis.disbursementGrowthPercentage > 0),
                    ReportRow(id: "r4", label: "Count",               value: "\(r.kpis.totalDisbursementCount)",                   change: "—", isPositive: true)
                ]
            }
        case "RPT-04":
            if let r = riskCreditReport {
                return [
                    ReportRow(id: "r1", label: "Avg CIBIL Score",     value: "\(r.kpis.avgCibilScore)",                            change: "—", isPositive: r.kpis.avgCibilScore >= 700),
                    ReportRow(id: "r2", label: "High Risk %",         value: String(format: "%.1f%%", r.kpis.highRiskPercentage),  change: "—", isPositive: r.kpis.highRiskPercentage < 15),
                    ReportRow(id: "r3", label: "Fraud Flags",         value: "\(r.kpis.fraudFlagsCount)",                          change: "—", isPositive: r.kpis.fraudFlagsCount == 0),
                    ReportRow(id: "r4", label: "Avg FOIR",            value: String(format: "%.0f%%", r.kpis.avgFoir),             change: "—", isPositive: r.kpis.avgFoir <= 50)
                ]
            }
        case "RPT-NPA":
            if let r = npaReport {
                return [
                    ReportRow(id: "r1", label: "Total NPA",           value: r.kpis.totalNpaAmount.lakhsFormatted,              change: "—", isPositive: false),
                    ReportRow(id: "r2", label: "NPA %",               value: String(format: "%.2f%%", r.kpis.npaPercentage),       change: "—", isPositive: r.kpis.npaPercentage < 3),
                    ReportRow(id: "r3", label: "NPA Count",           value: "\(r.kpis.totalNpaCount)",                            change: "—", isPositive: r.kpis.totalNpaCount == 0)
                ]
            }
        default:
            break
        }
        // Fallback: derive from local applications
        return Self.liveReportRows(for: id, from: filteredApplications())
    }

    static func liveReportRows(for reportId: String, from apps: [LoanApplication]) -> [ReportRow] {
        let total = apps.count
        let approved = apps.filter { $0.status == .approved || $0.status == .managerApproved }.count
        let pending = apps.filter { $0.status == .pending || $0.status == .underReview }.count
        let rejected = apps.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count

        let avgCibil: Int = {
            let scores = apps.map { $0.financials.cibilScore }.filter { $0 > 0 }
            guard !scores.isEmpty else { return 0 }
            return scores.reduce(0, +) / scores.count
        }()
        let avgFoirPct: Int = {
            let values: [Double] = apps.map { app in
                let raw = app.financials.foir
                if raw > 0 { return raw }
                return app.financials.dtiRatio * 100.0
            }
            guard !values.isEmpty else { return 0 }
            let sum = values.reduce(0, +)
            return Int((sum / Double(values.count)).rounded())
        }()
        let highRisk = apps.filter { ($0.financials.cibilScore > 0 && $0.financials.cibilScore < 650) || $0.financials.dtiRatio > 0.45 }.count
        let slaOverdue = apps.filter { $0.slaStatus == .overdue }.count
        let slaOnTimePct = total == 0 ? 0 : Int(((Double(total - slaOverdue) / Double(total)) * 100.0).rounded())

        switch reportId {
        case "RPT-01":
            return [
                ReportRow(id: "r1", label: "Total Applications", value: "\(total)", change: "—", isPositive: true),
                ReportRow(id: "r2", label: "Approved", value: "\(approved)", change: "—", isPositive: true),
                ReportRow(id: "r3", label: "Pending Review", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r4", label: "Rejected", value: "\(rejected)", change: "—", isPositive: rejected == 0)
            ]
        case "RPT-02":
            let overdue = apps.filter { $0.slaStatus == .overdue }.count
            return [
                ReportRow(id: "r1", label: "Overdue (SLA)", value: "\(overdue)", change: "—", isPositive: overdue == 0),
                ReportRow(id: "r2", label: "On-time SLA", value: "\(slaOnTimePct)%", change: "—", isPositive: slaOnTimePct >= 95),
                ReportRow(id: "r3", label: "Under Review", value: "\(apps.filter { $0.status == .underReview }.count)", change: "—", isPositive: true),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        case "RPT-03":
            // Disbursement not exposed on applications yet; proxy via approvals.
            return [
                ReportRow(id: "r1", label: "Approved (Proxy)", value: "\(approved)", change: "—", isPositive: true),
                ReportRow(id: "r2", label: "Pending", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r3", label: "Rejected", value: "\(rejected)", change: "—", isPositive: rejected == 0),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        case "RPT-04":
            return [
                ReportRow(id: "r1", label: "Avg CIBIL Score", value: "\(avgCibil)", change: "—", isPositive: avgCibil >= 700),
                ReportRow(id: "r2", label: "High Risk Apps", value: "\(highRisk)", change: "—", isPositive: highRisk == 0),
                ReportRow(id: "r3", label: "CIBIL < 650", value: "\(apps.filter { $0.financials.cibilScore > 0 && $0.financials.cibilScore < 650 }.count)", change: "—", isPositive: true),
                ReportRow(id: "r4", label: "Avg FOIR", value: "\(avgFoirPct)%", change: "—", isPositive: avgFoirPct <= 50)
            ]
        case "RPT-05":
            return [
                ReportRow(id: "r1", label: "On-Time SLA", value: "\(slaOnTimePct)%", change: "—", isPositive: slaOnTimePct >= 95),
                ReportRow(id: "r2", label: "SLA Breaches", value: "\(slaOverdue)", change: "—", isPositive: slaOverdue == 0),
                ReportRow(id: "r3", label: "Pending", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        default:
            return []
        }
    }

    // MARK: - Preview + Export payloads

    func previewTable(for reportId: String) -> (columns: [String], rows: [[String]]) {
        let id = normalizedReportID(reportId)

        // Try backend data first
        switch id {
        case "RPT-01":
            if let r = portfolioReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Portfolio Value", r.kpis.totalPortfolioValue.lakhsFormatted],
                    ["Active Loans", "\(r.kpis.totalActiveLoans)"],
                    ["Disbursed Amount", r.kpis.totalDisbursedAmount.lakhsFormatted],
                    ["Avg Loan Size", r.kpis.avgLoanSize.lakhsFormatted],
                    ["NPA Amount", r.kpis.npaAmount.lakhsFormatted],
                    ["NPA %", String(format: "%.2f%%", r.kpis.npaPercentage)],
                    ["Approval Rate", String(format: "%.1f%%", r.kpis.approvalRate)]
                ]
                return (columns, rows)
            }
        case "RPT-02":
            if let r = collectionReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["EMI Collected", r.kpis.totalEmiCollected.currencyFormatted],
                    ["Collection Efficiency", String(format: "%.1f%%", r.kpis.collectionEfficiencyPercentage)],
                    ["Pending", r.kpis.pendingAmount.currencyFormatted],
                    ["Overdue", r.kpis.overdueAmount.currencyFormatted]
                ]
                return (columns, rows)
            }
        case "RPT-03":
            if let r = disbursementReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Total Disbursed", r.kpis.totalDisbursedAmount.currencyFormatted],
                    ["Avg Size", r.kpis.avgDisbursementSize.currencyFormatted],
                    ["Growth", String(format: "%.1f%%", r.kpis.disbursementGrowthPercentage)],
                    ["Count", "\(r.kpis.totalDisbursementCount)"]
                ]
                return (columns, rows)
            }
        case "RPT-04":
            if let r = riskCreditReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Avg CIBIL", "\(r.kpis.avgCibilScore)"],
                    ["High Risk %", String(format: "%.1f%%", r.kpis.highRiskPercentage)],
                    ["Fraud Flags", "\(r.kpis.fraudFlagsCount)"],
                    ["Avg FOIR", String(format: "%.0f%%", r.kpis.avgFoir)]
                ]
                return (columns, rows)
            }
        case "RPT-NPA":
            if let r = npaReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Total NPA", r.kpis.totalNpaAmount.currencyFormatted],
                    ["NPA %", String(format: "%.2f%%", r.kpis.npaPercentage)],
                    ["NPA Count", "\(r.kpis.totalNpaCount)"]
                ]
                return (columns, rows)
            }
        default:
            break
        }

        return localPreviewTable(for: id)
    }

    func exportContent(for reportId: String, format: String) -> String {
        let rows = Self.liveReportRows(for: normalizedReportID(reportId), from: applications)
        let header = ["Label", "Value", "Change", "Positive"].joined(separator: ",")
        let body = rows.map { "\($0.label),\($0.value),\($0.change),\($0.isPositive)" }.joined(separator: "\n")
        return "\(header)\n\(body)\n"
    }

    // MARK: - Generate Report Data (used by ReportExportService)

    func generateReportData() -> (rows: [AppReportRow], summary: AppReportSummary) {
        let rows: [AppReportRow] = applications.map { app in
            let risk: String = {
                let cibil = app.financials.cibilScore
                let dti   = app.financials.dtiRatio
                if (cibil > 0 && cibil < 650) || dti > 0.45 { return "High" }
                if (cibil > 0 && cibil < 700) || dti > 0.35 { return "Medium" }
                return "Low"
            }()
            return AppReportRow(
                applicationId: app.id,
                borrowerName: app.borrower.name,
                loanType: app.loan.type.displayName,
                amount: app.loan.amount,
                status: app.status.displayName,
                risk: risk,
                date: app.createdAt
            )
        }

        let total    = applications.count
        let approved = applications.filter { $0.status == .approved || $0.status == .managerApproved }.count
        let pending  = applications.filter { $0.status == .pending  || $0.status == .underReview }.count
        let rejected = applications.filter {
            $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected
        }.count
        let totalValue = applications.reduce(0) { $0 + $1.loan.amount }
        let avgLoanSize = total > 0 ? totalValue / Double(total) : 0
        let npaRate = total > 0 ? (Double(rejected) / Double(total)) * 100.0 : 0

        let summary = AppReportSummary(
            total: total,
            approved: approved,
            pending: pending,
            rejected: rejected,
            totalValue: totalValue,
            avgLoanSize: avgLoanSize,
            npaRate: npaRate
        )
        return (rows, summary)
    }

    // MARK: - Report-Specific CSV Generation

    func generateReportCSV(
        reportId: String,
        dateRange: String? = nil,
        loanType: String? = nil,
        region: String? = nil,
        status: String? = nil
    ) -> String {
        let id = normalizedReportID(reportId)
        let bundle = buildLocalReportBundle(
            dateRange: dateRange ?? activeDateRange,
            loanType: loanType ?? activeLoanType,
            region: region ?? activeRegion,
            status: status ?? activeStatus
        )
        var lines: [String] = []

        switch id {
        case "RPT-01":
            let r = bundle.portfolio
            lines += ["Metric,Value",
                      "Portfolio Value,\(r.kpis.totalPortfolioValue)",
                      "Active Loans,\(r.kpis.totalActiveLoans)",
                      "Disbursed Amount,\(r.kpis.totalDisbursedAmount)",
                      "Avg Loan Size,\(r.kpis.avgLoanSize)",
                      "NPA Amount,\(r.kpis.npaAmount)",
                      "NPA %,\(r.kpis.npaPercentage)",
                      "Approval Rate,\(r.kpis.approvalRate)", ""]
            lines.append("Period,Portfolio Value,Disbursement,Loan Count")
            let pv = r.trends.portfolioValueTrend
            let dv = r.trends.disbursementTrend
            let lc = r.trends.loanCountTrend
            for i in pv.indices {
                lines.append("\(pv[i].period),\(pv[i].value),\(i < dv.count ? dv[i].value : 0),\(i < lc.count ? lc[i].value : 0)")
            }
            lines.append("")
            lines.append("Loan Type,Value,Percentage")
            for item in r.distributions.byLoanType {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.percentage ?? 0)")
            }
            lines.append("")
            lines.append("Region,Value,Percentage")
            for item in r.distributions.byRegion {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.percentage ?? 0)")
            }
            lines.append("")
            lines.append("NPA Aging Bucket,Amount,Count")
            for b in r.npaSummary.agingBuckets { lines.append("\(b.bucket),\(b.amount),\(b.count)") }

        case "RPT-02":
            let r = bundle.collection
            lines += ["Metric,Value",
                      "Total EMI Collected,\(r.kpis.totalEmiCollected)",
                      "Collection Efficiency %,\(r.kpis.collectionEfficiencyPercentage)",
                      "Pending Amount,\(r.kpis.pendingAmount)",
                      "Overdue Amount,\(r.kpis.overdueAmount)", ""]
            lines.append("Period,Collection Amount")
            for p in r.trends.collectionTrend { lines.append("\(p.period),\(p.value)") }
            lines.append("")
            lines.append("DPD Bucket,Amount,Count")
            for b in r.summaries.dpdBuckets { lines.append("\(b.bucket),\(b.amount),\(b.count)") }
            lines.append("")
            lines.append("Category,Value,Percentage")
            for item in r.summaries.paidVsPending {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.percentage ?? 0)")
            }

        case "RPT-03":
            let r = bundle.disbursement
            lines += ["Metric,Value",
                      "Total Disbursed,\(r.kpis.totalDisbursedAmount)",
                      "Avg Disbursement Size,\(r.kpis.avgDisbursementSize)",
                      "Growth %,\(r.kpis.disbursementGrowthPercentage)",
                      "Count,\(r.kpis.totalDisbursementCount)", ""]
            lines.append("Period,Disbursed Amount")
            for p in r.trends.disbursementTrend { lines.append("\(p.period),\(p.value)") }
            lines.append("")
            lines.append("Loan Type,Value,Percentage")
            for item in r.distributions.byLoanType {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.percentage ?? 0)")
            }
            lines.append("")
            lines.append("Region,Value,Count")
            for item in r.distributions.byRegion {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.count ?? 0)")
            }

        case "RPT-NPA":
            let r = bundle.npa
            lines += ["Metric,Value",
                      "Total NPA Amount,\(r.kpis.totalNpaAmount)",
                      "NPA %,\(r.kpis.npaPercentage)",
                      "Total NPA Count,\(r.kpis.totalNpaCount)", ""]
            lines.append("Aging Bucket,Amount,Count")
            for b in r.summaries.agingBuckets { lines.append("\(b.bucket),\(b.amount),\(b.count)") }
            lines.append("")
            lines.append("Category,Value,Percentage")
            for item in r.summaries.npaVsHealthy {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.percentage ?? 0)")
            }
            lines.append("")
            lines.append("Region,NPA Amount,Count")
            for item in r.summaries.topRegions {
                lines.append("\(csvEscape(item.name)),\(item.value),\(item.count ?? 0)")
            }

        case "RPT-04":
            let r = bundle.risk
            lines += ["Metric,Value",
                      "Avg CIBIL Score,\(r.kpis.avgCibilScore)",
                      "High Risk %,\(r.kpis.highRiskPercentage)",
                      "Fraud Flags,\(r.kpis.fraudFlagsCount)",
                      "Avg FOIR,\(r.kpis.avgFoir)", ""]
            lines.append("CIBIL Bucket,Count")
            for b in r.distributions.cibilScoreDistribution { lines.append("\(b.bucket),\(b.count)") }
            lines.append("")
            lines.append("Risk Category,Value,Percentage")
            for item in r.distributions.riskCategories {
                lines.append("\(csvEscape(item.name)),\(Int(item.value)),\(item.percentage ?? 0)")
            }
            lines.append("")
            lines.append("FOIR Bucket,Count")
            for b in r.distributions.foirDistribution { lines.append("\(b.bucket),\(b.count)") }

        default: break
        }

        if lines.isEmpty {
            let table = localPreviewTable(
                for: id,
                dateRange: dateRange ?? activeDateRange,
                loanType: loanType ?? activeLoanType,
                region: region ?? activeRegion,
                status: status ?? activeStatus
            )
            if !table.columns.isEmpty {
                lines.append(table.columns.map(csvEscape).joined(separator: ","))
                for row in table.rows {
                    lines.append(row.map(csvEscape).joined(separator: ","))
                }
            } else {
                let (rows, _) = generateReportData()
                lines.append("ApplicationID,Borrower,LoanType,Amount,Status,Risk,Date")
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                for row in rows {
                    lines.append([csvEscape(row.applicationId), csvEscape(row.borrowerName),
                                  csvEscape(row.loanType), String(format: "%.2f", row.amount),
                                  csvEscape(row.status), csvEscape(row.risk), df.string(from: row.date)
                                 ].joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func localPreviewTable(
        for reportId: String,
        dateRange: String? = nil,
        loanType: String? = nil,
        region: String? = nil,
        status: String? = nil
    ) -> (columns: [String], rows: [[String]]) {
        let apps = filteredApplications(
            dateRange: dateRange ?? activeDateRange,
            loanType: loanType ?? activeLoanType,
            region: region ?? activeRegion,
            status: status ?? activeStatus
        )

        switch reportId {
        case "RPT-01":
            let totalValue = apps.reduce(0) { $0 + $1.loan.amount }
            let avgLoanSize = apps.isEmpty ? 0 : totalValue / Double(apps.count)
            let highRisk = apps.filter { riskLabel(for: $0) == "High" }.count
            let overdue = apps.filter { $0.slaStatus == .overdue }.count
            return (
                ["Metric", "Value"],
                [
                    ["Total Applications", "\(apps.count)"],
                    ["Approved", "\(apps.filter { $0.status == .approved || $0.status == .managerApproved }.count)"],
                    ["Pending", "\(apps.filter { $0.status == .pending || $0.status == .underReview }.count)"],
                    ["Rejected", "\(apps.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count)"],
                    ["Portfolio Value", totalValue.currencyFormatted],
                    ["Avg Loan Size", avgLoanSize.currencyFormatted],
                    ["High Risk Apps", "\(highRisk)"],
                    ["SLA Overdue", "\(overdue)"]
                ]
            )
        case "RPT-02":
            let overdueApps = apps.filter { $0.slaStatus == .overdue }
            let overdueAmount = overdueApps.reduce(0) { $0 + $1.loan.amount }
            let activeAmount = apps.filter { $0.status == .approved || $0.status == .managerApproved || $0.status == .underReview }.reduce(0) { $0 + $1.loan.amount }
            let recoveryRate = apps.isEmpty ? 0 : (Double(apps.count - overdueApps.count) / Double(apps.count)) * 100
            return (
                ["Metric", "Value"],
                [
                    ["Overdue Accounts", "\(overdueApps.count)"],
                    ["Overdue Exposure", overdueAmount.currencyFormatted],
                    ["Active Exposure", activeAmount.currencyFormatted],
                    ["On-Time SLA Rate", String(format: "%.1f%%", recoveryRate)],
                    ["Under Review", "\(apps.filter { $0.status == .underReview }.count)"]
                ]
            )
        case "RPT-03":
            let approvedApps = apps.filter { $0.status == .approved || $0.status == .managerApproved }
            let totalDisbursed = approvedApps.reduce(0) { $0 + $1.loan.amount }
            let avgSize = approvedApps.isEmpty ? 0 : totalDisbursed / Double(approvedApps.count)
            return (
                ["Metric", "Value"],
                [
                    ["Approved Loans", "\(approvedApps.count)"],
                    ["Disbursed Proxy Amount", totalDisbursed.currencyFormatted],
                    ["Avg Approved Ticket", avgSize.currencyFormatted],
                    ["Pending Pipeline", "\(apps.filter { $0.status == .pending || $0.status == .underReview }.count)"],
                    ["Rejected", "\(apps.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count)"]
                ]
            )
        case "RPT-NPA":
            let npaApps = apps.filter { $0.slaStatus == .overdue || riskLabel(for: $0) == "High" }
            let npaAmount = npaApps.reduce(0) { $0 + $1.loan.amount }
            let ratio = apps.isEmpty ? 0 : (Double(npaApps.count) / Double(apps.count)) * 100
            return (
                ["Metric", "Value"],
                [
                    ["NPA Proxy Accounts", "\(npaApps.count)"],
                    ["NPA Proxy Exposure", npaAmount.currencyFormatted],
                    ["NPA Proxy %", String(format: "%.2f%%", ratio)],
                    ["Overdue > 0", "\(apps.filter { $0.slaStatus == .overdue }.count)"],
                    ["High Risk", "\(apps.filter { riskLabel(for: $0) == "High" }.count)"]
                ]
            )
        case "RPT-04":
            let scores = apps.map(\.financials.cibilScore).filter { $0 > 0 }
            let avgCibil = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
            let highRisk = apps.filter { riskLabel(for: $0) == "High" }.count
            let avgFoir: Double = {
                let values = apps.map { app -> Double in
                    let raw = app.financials.foir
                    return raw > 0 ? raw : app.financials.dtiRatio * 100
                }
                guard !values.isEmpty else { return 0 }
                return values.reduce(0, +) / Double(values.count)
            }()
            return (
                ["Metric", "Value"],
                [
                    ["Avg CIBIL", "\(avgCibil)"],
                    ["High Risk Apps", "\(highRisk)"],
                    ["High Risk %", apps.isEmpty ? "0.0%" : String(format: "%.1f%%", (Double(highRisk) / Double(apps.count)) * 100)],
                    ["Avg FOIR", String(format: "%.0f%%", avgFoir)],
                    ["CIBIL < 650", "\(apps.filter { $0.financials.cibilScore > 0 && $0.financials.cibilScore < 650 }.count)"]
                ]
            )
        default:
            let columns = ["Application ID", "Borrower", "Amount", "Status", "Risk"]
            let rows = apps.prefix(25).map { app in
                [app.id, app.borrower.name, app.loan.amount > 0 ? app.loan.amount.currencyFormatted : "—", app.status.displayName, riskLabel(for: app)]
            }
            return (columns, rows)
        }
    }

    private func filteredApplications() -> [LoanApplication] {
        filteredApplications(
            dateRange: activeDateRange,
            loanType: activeLoanType,
            region: activeRegion,
            status: activeStatus
        )
    }

    private func filteredApplications(
        dateRange: String,
        loanType: String,
        region: String,
        status: String
    ) -> [LoanApplication] {
        applications.filter { app in
            matches(dateRange: dateRange, createdAt: app.createdAt)
                && matches(loanType: loanType, app: app)
                && matches(region: region, app: app)
                && matches(status: status, app: app)
        }
    }

    private func filteredApplications(
        from: Date,
        to: Date,
        loanType: String,
        region: String,
        status: String
    ) -> [LoanApplication] {
        applications.filter { app in
            app.createdAt >= from
                && app.createdAt <= to
                && matches(loanType: loanType, app: app)
                && matches(region: region, app: app)
                && matches(status: status, app: app)
        }
    }

    func activeFilterDescription(reportTitle: String) -> String {
        [selectedBranch, selectedLoanType, dateRangeLabel]
            .filter { $0 != "All Branches" && $0 != "All Types" }
            .joined(separator: ", ")
    }

    func generatePDFReportData(
        reportTitle: String,
        dateRange: String,
        loanType: String,
        region: String,
        status: String
    ) -> AdminPDFReportPayload {
        let filteredApplications = filteredApplications(
            dateRange: dateRange,
            loanType: loanType,
            region: region,
            status: status
        )
        let bundle = buildLocalReportBundle(
            dateRange: dateRange,
            loanType: loanType,
            region: region,
            status: status
        )

        let rows = filteredApplications.map { app in
            AdminPDFReportRow(
                applicationId: app.id,
                borrowerName: app.borrower.name,
                borrowerPhone: app.borrower.phone,
                borrowerEmail: app.borrower.email,
                branch: app.branch,
                loanType: app.loan.type.displayName,
                amount: app.loan.amount,
                tenureMonths: app.loan.tenure,
                interestRate: app.loan.interestRate,
                emi: app.loan.emi,
                status: app.status.displayName,
                risk: riskLabel(for: app),
                slaStatus: app.slaStatus.displayName,
                createdAt: app.createdAt
            )
        }

        // Use backend summary data when available
        let total: Int
        let approved: Int
        let pending: Int
        let rejected: Int
        let totalValue: Double
        let avgLoanSize: Double
        let highRisk: Int

        let reportId = normalizedReportID(
            reportTitle == "Portfolio Performance" ? "RPT-PERF" :
            reportTitle == "Disbursement Report"   ? "RPT-DISB" :
            reportTitle == "Collection Report"     ? "RPT-COLL" :
            reportTitle == "NPA Report"            ? "RPT-NPA"  :
            reportTitle == "Risk & Credit Report"  ? "RPT-RISK" : ""
        )

        switch reportId {
        case "RPT-01":
            let k = bundle.portfolio.kpis
            total = k.totalActiveLoans
            approved = Int(Double(filteredApplications.count) * k.approvalRate / 100.0)
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = max(filteredApplications.count - approved - pending, 0)
            totalValue = k.totalPortfolioValue
            avgLoanSize = k.avgLoanSize
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        case "RPT-03":
            let k = bundle.disbursement.kpis
            total = k.totalDisbursementCount
            approved = filteredApplications.filter { $0.status == .approved || $0.status == .managerApproved }.count
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = filteredApplications.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count
            totalValue = k.totalDisbursedAmount
            avgLoanSize = k.avgDisbursementSize
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        default:
            total = filteredApplications.count
            approved = filteredApplications.filter { $0.status == .approved || $0.status == .managerApproved }.count
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = filteredApplications.filter {
                $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected
            }.count
            totalValue = filteredApplications.reduce(0) { $0 + $1.loan.amount }
            avgLoanSize = total > 0 ? totalValue / Double(total) : 0
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        }

        let filterText = [
            "Date Range: \(dateRange)",
            "Loan Type: \(loanType)",
            "Region: \(region)",
            "Status: \(status)"
        ].joined(separator: " | ")

        return AdminPDFReportPayload(
            reportName: reportTitle,
            filters: filterText,
            rows: rows,
            summary: AdminPDFReportSummary(
                total: total,
                approved: approved,
                pending: pending,
                rejected: rejected,
                totalValue: totalValue,
                avgLoanSize: avgLoanSize,
                highRisk: highRisk
            ),
            portfolioResponse: bundle.portfolio,
            disbursementResponse: bundle.disbursement,
            collectionResponse: bundle.collection,
            npaResponse: bundle.npa,
            riskCreditResponse: bundle.risk
        )
    }

    private func buildLocalReportBundle(
        dateRange: String,
        loanType: String,
        region: String,
        status: String
    ) -> LocalReportBundle {
        let apps = filteredApplications(dateRange: dateRange, loanType: loanType, region: region, status: status)
        let (from, to) = dateRangeToISO(dateRange)
        let metaFilters = ReportFilters(
            loanType: mapLoanType(loanType),
            region: region == "All Regions" ? "ALL" : region,
            status: mapStatus(status)
        )

        return LocalReportBundle(
            portfolio: makePortfolioReport(apps: apps, from: from, to: to, filters: metaFilters),
            disbursement: makeDisbursementReport(apps: apps, from: from, to: to, filters: metaFilters),
            collection: makeCollectionReport(apps: apps, from: from, to: to, filters: metaFilters),
            npa: makeNPAReport(apps: apps, from: from, to: to, filters: metaFilters),
            risk: makeRiskCreditReport(apps: apps, from: from, to: to, filters: metaFilters)
        )
    }

    private func makePortfolioReport(apps: [LoanApplication], from: String, to: String, filters: ReportFilters) -> PortfolioPerformanceResponse {
        let activeApps = activeLoanApps(from: apps)
        let disbursedApps = disbursedLoanApps(from: apps)
        let npaApps = npaLoanApps(from: activeApps)
        let totalPortfolioValue = activeApps.reduce(0) { $0 + outstandingAmount(for: $1) }
        let totalDisbursedAmount = disbursedApps.reduce(0) { $0 + $1.loan.amount }
        let avgLoanSize = disbursedApps.isEmpty ? (activeApps.isEmpty ? 0 : totalPortfolioValue / Double(activeApps.count)) : totalDisbursedAmount / Double(disbursedApps.count)
        let npaAmount = npaApps.reduce(0) { $0 + outstandingAmount(for: $1) }
        let approvalRate = apps.isEmpty ? 0 : (Double(disbursedApps.count) / Double(apps.count)) * 100
        let bucketRanges = makeTrendBuckets(from: from, to: to)

        let portfolioTrend = bucketRanges.map { bucket in
            let cumulative = activeApps.filter { $0.createdAt <= bucket.end }.reduce(0) { $0 + outstandingAmount(for: $1) }
            return TrendPoint(period: bucket.label, value: cumulative)
        }
        let disbursementTrend = bucketRanges.map { bucket in
            TrendPoint(period: bucket.label, value: disbursedApps.filter { bucket.contains($0.createdAt) }.reduce(0) { $0 + $1.loan.amount })
        }
        let loanCountTrend = bucketRanges.map { bucket in
            TrendPoint(period: bucket.label, value: Double(activeApps.filter { $0.createdAt <= bucket.end }.count))
        }

        let byLoanType = aggregateDistribution(
            apps: activeApps,
            key: { $0.loan.type.displayName },
            value: { outstandingAmount(for: $0) }
        )
        let byRegion = aggregateDistribution(
            apps: activeApps,
            key: { normalizedRegionName($0.branch) },
            value: { outstandingAmount(for: $0) }
        )
        let agingBuckets = makeAgingBuckets(from: npaApps)

        return PortfolioPerformanceResponse(
            reportMeta: reportMeta(name: "Portfolio Performance Report", from: from, to: to, filters: filters),
            kpis: PortfolioKPIs(
                totalPortfolioValue: totalPortfolioValue,
                totalActiveLoans: activeApps.count,
                totalDisbursedAmount: totalDisbursedAmount,
                avgLoanSize: avgLoanSize,
                npaAmount: npaAmount,
                npaPercentage: safePercentage(numerator: npaAmount, denominator: totalPortfolioValue),
                approvalRate: approvalRate
            ),
            trends: PortfolioTrends(
                portfolioValueTrend: portfolioTrend,
                disbursementTrend: disbursementTrend,
                loanCountTrend: loanCountTrend
            ),
            distributions: PortfolioDistributions(
                byLoanType: byLoanType,
                byRegion: byRegion
            ),
            npaSummary: NPASummary(
                totalNpaAmount: npaAmount,
                npaPercentage: safePercentage(numerator: npaAmount, denominator: totalPortfolioValue),
                npaCount: npaApps.count,
                agingBuckets: agingBuckets
            ),
            insights: portfolioInsights(totalPortfolioValue: totalPortfolioValue, byLoanType: byLoanType, agingBuckets: agingBuckets)
        )
    }

    private func makeDisbursementReport(apps: [LoanApplication], from: String, to: String, filters: ReportFilters) -> DisbursementResponse {
        let disbursedApps = disbursedLoanApps(from: apps)
        let totalAmount = disbursedApps.reduce(0) { $0 + $1.loan.amount }
        let count = disbursedApps.count
        let avgSize = count == 0 ? 0 : totalAmount / Double(count)
        let previousApps = disbursedLoanApps(
            from: previousPeriodApps(
                from: from,
                to: to,
                loanType: reverseMapLoanType(filters.loanType),
                region: reverseMapRegion(filters.region),
                status: "Closed"
            )
        )
        let previousTotal = previousApps.reduce(0) { $0 + $1.loan.amount }
        let growth = previousTotal == 0 ? (totalAmount > 0 ? 100 : 0) : ((totalAmount - previousTotal) / previousTotal) * 100
        let buckets = makeTrendBuckets(from: from, to: to)

        return DisbursementResponse(
            reportMeta: reportMeta(name: "Disbursement Report", from: from, to: to, filters: ReportFilters(loanType: filters.loanType, region: filters.region, status: "DISBURSED")),
            kpis: DisbursementKPIs(
                totalDisbursedAmount: totalAmount,
                avgDisbursementSize: avgSize,
                disbursementGrowthPercentage: growth,
                totalDisbursementCount: count
            ),
            trends: DisbursementTrends(
                disbursementTrend: buckets.map { bucket in
                    TrendPoint(period: bucket.label, value: disbursedApps.filter { bucket.contains($0.createdAt) }.reduce(0) { $0 + $1.loan.amount })
                }
            ),
            distributions: DisbursementDistributions(
                byLoanType: aggregateDistribution(apps: disbursedApps, key: { $0.loan.type.displayName }, value: { $0.loan.amount }),
                byRegion: aggregateDistributionWithCount(apps: disbursedApps, key: { normalizedRegionName($0.branch) }, value: { $0.loan.amount })
            ),
            insights: disbursementInsights(totalAmount: totalAmount, growth: growth, byLoanType: aggregateDistribution(apps: disbursedApps, key: { $0.loan.type.displayName }, value: { $0.loan.amount }), byRegion: aggregateDistributionWithCount(apps: disbursedApps, key: { normalizedRegionName($0.branch) }, value: { $0.loan.amount }))
        )
    }

    private func makeCollectionReport(apps: [LoanApplication], from: String, to: String, filters: ReportFilters) -> CollectionResponse {
        let activeApps = activeLoanApps(from: apps)
        let scheduledAmount = activeApps.reduce(0) { $0 + emiAmount(for: $1) }
        let overdueApps = activeApps.filter { $0.slaStatus == .overdue }
        let pendingApps = activeApps.filter { $0.slaStatus != .overdue && $0.status != .approved && $0.status != .managerApproved }
        let overdueAmount = overdueApps.reduce(0) { $0 + emiAmount(for: $1) }
        let pendingAmount = pendingApps.reduce(0) { $0 + emiAmount(for: $1) }
        let totalCollected = max(0, scheduledAmount - pendingAmount - overdueAmount)
        let buckets = makeTrendBuckets(from: from, to: to)
        let collectionTrend = buckets.map { bucket -> TrendPoint in
            let bucketApps = activeApps.filter { bucket.contains($0.createdAt) }
            let scheduled = bucketApps.reduce(0) { $0 + emiAmount(for: $1) }
            let bucketOverdue = bucketApps.filter { $0.slaStatus == .overdue }.reduce(0) { $0 + emiAmount(for: $1) }
            let bucketPending = bucketApps.filter { $0.slaStatus != .overdue && $0.status != .approved && $0.status != .managerApproved }.reduce(0) { $0 + emiAmount(for: $1) }
            return TrendPoint(period: bucket.label, value: max(0, scheduled - bucketOverdue - bucketPending))
        }
        let dpdBuckets = makeAgingBuckets(from: overdueApps, amountProvider: { self.emiAmount(for: $0) })
        let totalScheduled = max(scheduledAmount, 1)
        let paidVsPending = [
            DistributionItem(name: "Paid", value: totalCollected, percentage: safePercentage(numerator: totalCollected, denominator: totalScheduled)),
            DistributionItem(name: "Pending", value: pendingAmount, percentage: safePercentage(numerator: pendingAmount, denominator: totalScheduled)),
            DistributionItem(name: "Overdue", value: overdueAmount, percentage: safePercentage(numerator: overdueAmount, denominator: totalScheduled))
        ]

        return CollectionResponse(
            reportMeta: reportMeta(name: "Collection Report", from: from, to: to, filters: filters),
            kpis: CollectionKPIs(
                totalEmiCollected: totalCollected,
                collectionEfficiencyPercentage: safePercentage(numerator: totalCollected, denominator: totalScheduled),
                pendingAmount: pendingAmount,
                overdueAmount: overdueAmount
            ),
            trends: CollectionTrends(collectionTrend: collectionTrend),
            summaries: CollectionSummaries(dpdBuckets: dpdBuckets, paidVsPending: paidVsPending),
            insights: collectionInsights(efficiency: safePercentage(numerator: totalCollected, denominator: totalScheduled), dpdBuckets: dpdBuckets)
        )
    }

    private func makeNPAReport(apps: [LoanApplication], from: String, to: String, filters: ReportFilters) -> NPAResponse {
        let activeApps = activeLoanApps(from: apps)
        let npaApps = npaLoanApps(from: activeApps)
        let totalPortfolioValue = activeApps.reduce(0) { $0 + outstandingAmount(for: $1) }
        let npaAmount = npaApps.reduce(0) { $0 + outstandingAmount(for: $1) }
        let agingBuckets = makeAgingBuckets(from: npaApps)
        let healthyAmount = max(0, totalPortfolioValue - npaAmount)
        let npaPercentage = safePercentage(numerator: npaAmount, denominator: totalPortfolioValue)
        let topRegions = aggregateDistributionWithCount(apps: npaApps, key: { normalizedRegionName($0.branch) }, value: { outstandingAmount(for: $0) })

        return NPAResponse(
            reportMeta: reportMeta(name: "NPA Report", from: from, to: to, filters: ReportFilters(loanType: filters.loanType, region: filters.region, status: "NPA")),
            kpis: NPAKPIs(
                totalNpaAmount: npaAmount,
                npaPercentage: npaPercentage,
                totalNpaCount: npaApps.count
            ),
            summaries: NPASummaries(
                agingBuckets: agingBuckets,
                npaVsHealthy: [
                    DistributionItem(name: "Healthy", value: healthyAmount, percentage: safePercentage(numerator: healthyAmount, denominator: totalPortfolioValue)),
                    DistributionItem(name: "NPA", value: npaAmount, percentage: npaPercentage)
                ],
                topRegions: topRegions
            ),
            insights: npaInsights(agingBuckets: agingBuckets, topRegions: topRegions)
        )
    }

    private func makeRiskCreditReport(apps: [LoanApplication], from: String, to: String, filters: ReportFilters) -> RiskCreditResponse {
        let validScores = apps.map(\.financials.cibilScore).filter { $0 > 0 }
        let avgCibil = validScores.isEmpty ? 0 : validScores.reduce(0, +) / validScores.count
        let highRiskApps = apps.filter { riskLabel(for: $0) == "High" }
        let fraudFlags = AdminRiskViewModel.deriveFraudFlags(from: apps)
        let avgFoir = averageFoir(from: apps)
        let total = max(apps.count, 1)

        return RiskCreditResponse(
            reportMeta: reportMeta(name: "Risk & Credit Report", from: from, to: to, filters: filters),
            kpis: RiskCreditKPIs(
                avgCibilScore: avgCibil,
                highRiskPercentage: safePercentage(numerator: Double(highRiskApps.count), denominator: Double(total)),
                fraudFlagsCount: fraudFlags.count,
                avgFoir: avgFoir
            ),
            distributions: RiskCreditDistributions(
                cibilScoreDistribution: [
                    CountBucket(bucket: "300-600", count: apps.filter { $0.financials.cibilScore > 0 && $0.financials.cibilScore < 600 }.count),
                    CountBucket(bucket: "600-750", count: apps.filter { $0.financials.cibilScore >= 600 && $0.financials.cibilScore < 750 }.count),
                    CountBucket(bucket: "750+", count: apps.filter { $0.financials.cibilScore >= 750 }.count)
                ],
                riskCategories: [
                    DistributionItem(name: "Low", value: Double(apps.filter { riskLabel(for: $0) == "Low" }.count), percentage: safePercentage(numerator: Double(apps.filter { riskLabel(for: $0) == "Low" }.count), denominator: Double(total))),
                    DistributionItem(name: "Medium", value: Double(apps.filter { riskLabel(for: $0) == "Medium" }.count), percentage: safePercentage(numerator: Double(apps.filter { riskLabel(for: $0) == "Medium" }.count), denominator: Double(total))),
                    DistributionItem(name: "High", value: Double(highRiskApps.count), percentage: safePercentage(numerator: Double(highRiskApps.count), denominator: Double(total)))
                ],
                foirDistribution: [
                    CountBucket(bucket: "<35%", count: apps.filter { effectiveFoir(for: $0) < 35 }.count),
                    CountBucket(bucket: "35-50%", count: apps.filter { effectiveFoir(for: $0) >= 35 && effectiveFoir(for: $0) < 50 }.count),
                    CountBucket(bucket: "50%+", count: apps.filter { effectiveFoir(for: $0) >= 50 }.count)
                ]
            ),
            insights: riskInsights(highRiskPercentage: safePercentage(numerator: Double(highRiskApps.count), denominator: Double(total)), fraudFlags: fraudFlags.count, avgFoir: avgFoir)
        )
    }

    private func reportMeta(name: String, from: String, to: String, filters: ReportFilters) -> ReportMeta {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return ReportMeta(
            reportName: name,
            generatedAt: formatter.string(from: Date()),
            dateRange: DateRangeFilter(from: from, to: to),
            filters: filters,
            currency: "INR"
        )
    }

    private func activeLoanApps(from apps: [LoanApplication]) -> [LoanApplication] {
        apps.filter { $0.status != .rejected && $0.status != .managerRejected && $0.status != .officerRejected }
    }

    private func disbursedLoanApps(from apps: [LoanApplication]) -> [LoanApplication] {
        apps.filter { $0.status == .approved || $0.status == .managerApproved }
    }

    private func npaLoanApps(from apps: [LoanApplication]) -> [LoanApplication] {
        apps.filter { daysPastDue(for: $0) > 0 || riskLabel(for: $0) == "High" }
    }

    private func outstandingAmount(for app: LoanApplication) -> Double {
        max(app.loan.amount - (emiAmount(for: app) * Double(max(monthsElapsed(for: app), 0))), app.loan.amount * 0.35)
    }

    private func emiAmount(for app: LoanApplication) -> Double {
        if app.loan.emi > 0 { return app.loan.emi }
        guard app.loan.tenure > 0 else { return app.loan.amount }
        return app.loan.amount / Double(app.loan.tenure)
    }

    private func monthsElapsed(for app: LoanApplication) -> Int {
        Calendar.current.dateComponents([.month], from: app.createdAt, to: Date()).month ?? 0
    }

    private func daysPastDue(for app: LoanApplication) -> Int {
        max(-app.slaDeadline.daysRemaining, 0)
    }

    private func effectiveFoir(for app: LoanApplication) -> Double {
        app.financials.foir > 0 ? app.financials.foir : (app.financials.dtiRatio * 100)
    }

    private func averageFoir(from apps: [LoanApplication]) -> Double {
        guard !apps.isEmpty else { return 0 }
        return apps.map { effectiveFoir(for: $0) }.reduce(0, +) / Double(apps.count)
    }

    private func normalizedRegionName(_ branch: String) -> String {
        let value = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.localizedCaseInsensitiveContains("mumbai") { return "Mumbai" }
        if value.localizedCaseInsensitiveContains("delhi") { return "Delhi NCR" }
        if value.localizedCaseInsensitiveContains("bangalore") || value.localizedCaseInsensitiveContains("bengaluru") { return "Bangalore" }
        if value.localizedCaseInsensitiveContains("chennai") { return "Chennai" }
        return value.isEmpty ? "Unknown" : value
    }

    private func safePercentage(numerator: Double, denominator: Double) -> Double {
        guard denominator > 0 else { return 0 }
        return (numerator / denominator) * 100
    }

    private func aggregateDistribution(
        apps: [LoanApplication],
        key: (LoanApplication) -> String,
        value: (LoanApplication) -> Double
    ) -> [DistributionItem] {
        let total = apps.reduce(0) { $0 + value($1) }
        let grouped = Dictionary(grouping: apps, by: key)
        return grouped.map { name, group in
            let totalValue = group.reduce(0) { $0 + value($1) }
            return DistributionItem(name: name, value: totalValue, percentage: safePercentage(numerator: totalValue, denominator: total))
        }
        .sorted { $0.value > $1.value }
    }

    private func aggregateDistributionWithCount(
        apps: [LoanApplication],
        key: (LoanApplication) -> String,
        value: (LoanApplication) -> Double
    ) -> [DistributionWithCount] {
        let grouped = Dictionary(grouping: apps, by: key)
        return grouped.map { name, group in
            DistributionWithCount(
                name: name,
                value: group.reduce(0) { $0 + value($1) },
                count: group.count,
                percentage: nil
            )
        }
        .sorted { $0.value > $1.value }
    }

    private func makeAgingBuckets(
        from apps: [LoanApplication],
        amountProvider: ((LoanApplication) -> Double)? = nil
    ) -> [AgingBucket] {
        let buckets: [(String, ClosedRange<Int>)] = [
            ("0-30", 0...30),
            ("31-60", 31...60),
            ("61-90", 61...90),
            ("90+", 91...10_000)
        ]

        return buckets.map { label, range in
            let bucketApps = apps.filter { range.contains(daysPastDue(for: $0)) }
            return AgingBucket(
                bucket: label,
                amount: bucketApps.reduce(0) { $0 + (amountProvider?($1) ?? outstandingAmount(for: $1)) },
                count: bucketApps.count
            )
        }
    }

    private struct TrendBucket {
        let label: String
        let start: Date
        let end: Date

        func contains(_ date: Date) -> Bool {
            date >= start && date <= end
        }
    }

    private func makeTrendBuckets(from fromISO: String, to toISO: String) -> [TrendBucket] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let from = formatter.date(from: fromISO), let to = formatter.date(from: toISO) else { return [] }
        let calendar = Calendar.current
        let daySpan = max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 1)

        if daySpan <= 10 {
            return strideBuckets(from: from, to: to, component: .day, step: 1, labelFormat: "dd MMM")
        } else if daySpan <= 45 {
            return strideBuckets(from: from, to: to, component: .day, step: 7, labelPrefix: "Week")
        } else {
            return strideBuckets(from: from, to: to, component: .month, step: 1, labelFormat: "MMM yyyy")
        }
    }

    private func strideBuckets(
        from start: Date,
        to end: Date,
        component: Calendar.Component,
        step: Int,
        labelFormat: String? = nil,
        labelPrefix: String? = nil
    ) -> [TrendBucket] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = labelFormat ?? "dd MMM"
        var buckets: [TrendBucket] = []
        var cursor = start
        var index = 1

        while cursor <= end {
            guard let next = calendar.date(byAdding: component, value: step, to: cursor) else { break }
            let bucketEnd = min(calendar.date(byAdding: .day, value: -1, to: next) ?? end, end)
            let label = labelPrefix.map { "\($0) \(index)" } ?? formatter.string(from: cursor)
            buckets.append(TrendBucket(label: label, start: cursor, end: bucketEnd))
            cursor = next
            index += 1
        }

        return buckets
    }

    private func previousPeriodApps(from: String, to: String, loanType: String, region: String, status: String) -> [LoanApplication] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard
            let fromDate = formatter.date(from: from),
            let toDate = formatter.date(from: to)
        else { return [] }
        let daySpan = (Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0) + 1
        let prevTo = Calendar.current.date(byAdding: .day, value: -1, to: fromDate) ?? fromDate
        let prevFrom = Calendar.current.date(byAdding: .day, value: -daySpan, to: fromDate) ?? fromDate
        return filteredApplications(from: prevFrom, to: prevTo, loanType: loanType, region: region, status: status)
    }

    private func reverseMapLoanType(_ code: String) -> String {
        switch code {
        case "HOME": return "Home Loan"
        case "PERSONAL": return "Personal Loan"
        case "BUSINESS": return "Business Loan"
        case "VEHICLE": return "Vehicle Loan"
        default: return "All Types"
        }
    }

    private func reverseMapRegion(_ value: String) -> String {
        value == "ALL" ? "All Regions" : value
    }

    private func portfolioInsights(totalPortfolioValue: Double, byLoanType: [DistributionItem], agingBuckets: [AgingBucket]) -> [String] {
        var insights: [String] = []
        insights.append(totalPortfolioValue > 0 ? "Portfolio value remained active across the selected period." : "No active portfolio value was found for the selected filters.")
        if let topLoanType = byLoanType.first {
            insights.append("\(topLoanType.name) represents the largest share of the current portfolio.")
        }
        if let topBucket = agingBuckets.max(by: { $0.amount < $1.amount }), topBucket.amount > 0 {
            insights.append("The \(topBucket.bucket) aging bucket carries the highest delinquency exposure.")
        }
        return insights
    }

    private func disbursementInsights(totalAmount: Double, growth: Double, byLoanType: [DistributionItem], byRegion: [DistributionWithCount]) -> [String] {
        var insights: [String] = []
        insights.append("Disbursement \(growth >= 0 ? "grew" : "declined") by \(String(format: "%.1f", abs(growth)))% versus the previous comparison period.")
        if let topLoanType = byLoanType.first {
            insights.append("\(topLoanType.name) contributed the largest share of disbursement value.")
        }
        if byRegion.count >= 2 {
            insights.append("\(byRegion[0].name) and \(byRegion[1].name) together contributed the strongest regional disbursement volume.")
        } else if let first = byRegion.first {
            insights.append("\(first.name) contributed the strongest regional disbursement volume.")
        }
        if totalAmount == 0 {
            insights[0] = "No disbursement activity matched the selected filters."
        }
        return insights
    }

    private func collectionInsights(efficiency: Double, dpdBuckets: [AgingBucket]) -> [String] {
        var insights = ["Collection efficiency reached \(String(format: "%.1f", efficiency))% for the selected period."]
        if let topBucket = dpdBuckets.max(by: { $0.count < $1.count }), topBucket.count > 0 {
            insights.append("Most delinquency is concentrated in the \(topBucket.bucket) DPD bucket.")
        }
        if let highRiskBucket = dpdBuckets.max(by: { $0.amount < $1.amount }), highRiskBucket.amount > 0 {
            insights.append("The \(highRiskBucket.bucket) bucket carries the highest recovery exposure by amount.")
        }
        return insights
    }

    private func npaInsights(agingBuckets: [AgingBucket], topRegions: [DistributionWithCount]) -> [String] {
        var insights: [String] = []
        if let topBucket = agingBuckets.max(by: { $0.amount < $1.amount }), topBucket.amount > 0 {
            insights.append("The \(topBucket.bucket) aging bucket has the highest NPA exposure.")
        }
        if topRegions.count >= 2 {
            insights.append("\(topRegions[0].name) and \(topRegions[1].name) account for the largest NPA value concentration.")
        } else if let topRegion = topRegions.first {
            insights.append("\(topRegion.name) accounts for the largest NPA value concentration.")
        }
        insights.append("Early-stage delinquency should be addressed quickly to limit migration into deeper buckets.")
        return insights
    }

    private func riskInsights(highRiskPercentage: Double, fraudFlags: Int, avgFoir: Double) -> [String] {
        [
            highRiskPercentage < 20 ? "Credit quality is relatively healthy overall, with most borrowers outside the high-risk bucket." : "High-risk applications form a meaningful part of the portfolio and should be watched closely.",
            fraudFlags > 0 ? "\(fraudFlags) applications triggered fraud or policy risk signals and should remain under manual review." : "No strong fraud or policy risk signals were detected in the selected set.",
            avgFoir >= 50 ? "FOIR above 50% should be monitored before expanding approvals." : "Average FOIR remains within a manageable range for the selected population."
        ]
    }

    private func riskLabel(for app: LoanApplication) -> String {
        let cibil = app.financials.cibilScore
        let dti = app.financials.dtiRatio
        if (cibil > 0 && cibil < 650) || dti > 0.45 { return "High" }
        if (cibil > 0 && cibil < 700) || dti > 0.35 { return "Medium" }
        return "Low"
    }

    private func matches(dateRange: String, createdAt: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case "Last 7 Days":
            guard let start = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return createdAt >= start
        case "Last 30 Days":
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return createdAt >= start
        case "Last 90 Days":
            guard let start = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return createdAt >= start
        case "This FY":
            let year = calendar.component(.month, from: now) >= 4
                ? calendar.component(.year, from: now)
                : calendar.component(.year, from: now) - 1
            let start = calendar.date(from: DateComponents(year: year, month: 4, day: 1))
            return start.map { createdAt >= $0 } ?? true
        default:
            return true
        }
    }

    private func matches(loanType: String, app: LoanApplication) -> Bool {
        loanType == "All Types" || app.loan.type.displayName == loanType
    }

    private func matches(region: String, app: LoanApplication) -> Bool {
        region == "All Regions" || app.branch.localizedCaseInsensitiveContains(region)
    }

    private func matches(status: String, app: LoanApplication) -> Bool {
        switch status {
        case "All":
            return true
        case "Active":
            return app.status == .pending || app.status == .underReview || app.status == .managerApproved
        case "Closed":
            return app.status == .approved
        case "NPA":
            return app.slaStatus == .overdue || riskLabel(for: app) == "High"
        default:
            return app.status.displayName == status
        }
    }

    // MARK: - Mock Data

    static func mockScheduledReports() -> [ScheduledReport] {
        [
            ScheduledReport(id: "SR-001", reportName: "Portfolio Overview",
                            frequency: "Weekly", nextRun: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                            recipients: "admin@gmail.com", isActive: true),
            ScheduledReport(id: "SR-002", reportName: "SLA Compliance",
                            frequency: "Daily",  nextRun: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                            recipients: "admin@gmail.com, manager@gmail.com", isActive: true)
        ]
    }

    static func mockReportRows(for reportId: String) -> [ReportRow] {
        switch reportId {
        case "RPT-01":
            return [
                ReportRow(id: "r1", label: "Total Portfolio",     value: "₹3.95 Cr", change: "+12%",  isPositive: true),
                ReportRow(id: "r2", label: "Disbursed (MTD)",     value: "₹72 L",    change: "+8%",   isPositive: true),
                ReportRow(id: "r3", label: "NPA Ratio",           value: "2.4%",     change: "-0.3%", isPositive: true),
                ReportRow(id: "r4", label: "Pending Approval",    value: "5",        change: "+2",    isPositive: false)
            ]
        case "RPT-02":
            return [
                ReportRow(id: "r1", label: "EMI Collected (MTD)", value: "₹14.2 L",  change: "+5%",   isPositive: true),
                ReportRow(id: "r2", label: "Overdue Loans",       value: "4",        change: "+1",    isPositive: false),
                ReportRow(id: "r3", label: "Total Outstanding",   value: "₹1.71 Cr", change: "-3%",   isPositive: true),
                ReportRow(id: "r4", label: "Recovery Rate",       value: "78%",      change: "+2%",   isPositive: true)
            ]
        case "RPT-03":
            return [
                ReportRow(id: "r1", label: "Home Loans",          value: "₹2.1 Cr",  change: "+15%",  isPositive: true),
                ReportRow(id: "r2", label: "Personal Loans",      value: "₹32 L",    change: "+3%",   isPositive: true),
                ReportRow(id: "r3", label: "Business Loans",      value: "₹50 L",    change: "-8%",   isPositive: false),
                ReportRow(id: "r4", label: "Vehicle Loans",       value: "₹15 L",    change: "+2%",   isPositive: true)
            ]
        case "RPT-04":
            return [
                ReportRow(id: "r1", label: "Avg CIBIL Score",     value: "728",      change: "+12",   isPositive: true),
                ReportRow(id: "r2", label: "High Risk Apps",      value: "3",        change: "+1",    isPositive: false),
                ReportRow(id: "r3", label: "Fraud Flags",         value: "2",        change: "0",     isPositive: true),
                ReportRow(id: "r4", label: "Avg FOIR",            value: "28%",      change: "-2%",   isPositive: true)
            ]
        case "RPT-05":
            return [
                ReportRow(id: "r1", label: "On-Time SLA",         value: "83%",      change: "+5%",   isPositive: true),
                ReportRow(id: "r2", label: "Overdue SLA",         value: "2",        change: "-1",    isPositive: true),
                ReportRow(id: "r3", label: "Avg TAT (days)",      value: "4.2",      change: "-0.8",  isPositive: true),
                ReportRow(id: "r4", label: "Escalations",         value: "1",        change: "0",     isPositive: true)
            ]
        default:
            return []
        }
    }
}
