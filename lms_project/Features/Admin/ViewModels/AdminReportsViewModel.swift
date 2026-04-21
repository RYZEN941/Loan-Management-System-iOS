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

// MARK: - Admin Reports View Model

class AdminReportsViewModel: ObservableObject {

    @Published var selectedReportType: ReportType? = nil
    @Published var selectedBranch = "All Branches"
    @Published var selectedLoanType = "All Types"
    @Published var dateRangeLabel = "Last 30 Days"
    @Published var scheduledReports: [ScheduledReport] = []
    @Published var reportRows: [ReportRow] = []
    @Published var showExportAlert = false
    @Published var exportFormat = "PDF"
    @Published var isLoading = false

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.scheduledReports = Self.mockScheduledReports()
            self.selectedReportType = self.reportTypes.first
            self.refreshReportData()
            self.isLoading = false
        }
    }

    func refreshReportData() {
        guard let type = selectedReportType else { return }
        reportRows = Self.mockReportRows(for: type.id)
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
