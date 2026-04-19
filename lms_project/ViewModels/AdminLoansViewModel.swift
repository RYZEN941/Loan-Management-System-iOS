//
//  AdminLoansViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Admin Loans View Model

class AdminLoansViewModel: ObservableObject {

    // MARK: Published State
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var filterStatus: ApplicationStatus? = nil   // nil = All
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    @Published var showReassignSheet = false
    @Published var showEscalateSheet = false
    @Published var escalateNote = ""
    @Published var reassignTargetId = ""

    private let dataService = MockDataService.shared

    // MARK: - Derived

    var filteredApplications: [LoanApplication] {
        var result = applications
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.borrower.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                $0.borrower.employer.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var totalCount: Int { applications.count }
    var pendingCount: Int { applications.filter { $0.status == .pending }.count }
    var underReviewCount: Int { applications.filter { $0.status == .underReview }.count }
    var approvedCount: Int { applications.filter { $0.status == .approved }.count }
    var rejectedCount: Int { applications.filter { $0.status == .rejected }.count }

    // MARK: - Load

    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.applications = self.dataService.fetchApplications()
            if self.selectedApplication == nil {
                self.selectedApplication = self.applications.first
            }
            self.isLoading = false
        }
    }

    // MARK: - Actions

    func approve(_ app: LoanApplication) {
        updateStatus(app, to: .approved, message: "Application \(app.id) approved ✓")
    }

    func reject(_ app: LoanApplication) {
        updateStatus(app, to: .rejected, message: "Application \(app.id) rejected")
    }

    func beginEscalate(_ app: LoanApplication) {
        selectedApplication = app
        escalateNote = ""
        showEscalateSheet = true
    }

    func confirmEscalate() {
        guard let app = selectedApplication else { return }
        updateStatus(app, to: .underReview, message: "Application \(app.id) escalated to senior manager")
        showEscalateSheet = false
    }

    func beginReassign(_ app: LoanApplication) {
        selectedApplication = app
        reassignTargetId = ""
        showReassignSheet = true
    }

    func confirmReassign(to officerId: String) {
        guard let app = selectedApplication else { return }
        if let idx = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[idx].assignedTo = officerId
                selectedApplication = applications[idx]
            }
        }
        actionMessage = "Application reassigned to \(officerId)"
        showActionAlert = true
        showReassignSheet = false
    }

    private func updateStatus(_ app: LoanApplication, to status: ApplicationStatus, message: String) {
        if let idx = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[idx].status = status
                selectedApplication = applications[idx]
            }
        }
        actionMessage = message
        showActionAlert = true
    }

    // MARK: - Officers (for reassign picker)

    let loanOfficers: [(id: String, name: String)] = [
        ("LO-001", "Amit Singh"),
        ("LO-002", "Neha Kapoor"),
        ("LO-003", "Ravi Shankar")
    ]
}
