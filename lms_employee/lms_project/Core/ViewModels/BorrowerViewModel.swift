//
//  BorrowerViewModel.swift
//  lms_project
//

import Foundation
import Combine
import SwiftUI

struct BorrowerNote: Identifiable, Codable, Hashable {
    let id: String
    let borrowerID: String
    let author: String
    let text: String
    let createdAt: Date
}

enum BorrowerDirectoryFilter: String, CaseIterable, Identifiable {
    case all = "All Borrowers"
    case activeLoan = "Has Active Loan"
    case pending = "Application Pending"
    case approvedHistory = "Previously Approved"
    case rejectedHistory = "Rejected History"

    var id: String { rawValue }
}

struct BorrowerRecord: Identifiable, Hashable {
    let id: String
    let borrower: Borrower
    let branch: String
    let applications: [LoanApplication]

    var latestApplication: LoanApplication {
        applications.sorted { $0.createdAt > $1.createdAt }.first ?? applications[0]
    }

    var riskLevel: RiskLevel {
        latestApplication.riskLevel
    }

    var activeLoanApplication: LoanApplication? {
        applications.first { [.approved, .managerApproved].contains($0.status) }
    }

    var pendingApplication: LoanApplication? {
        applications.first { $0.status.isPendingBorrowerWorkload }
    }

    var hasRejectedHistory: Bool {
        applications.contains { $0.status.isRejectedState }
    }

    var approvalHistoryCount: Int {
        applications.filter { $0.status.isApprovedState }.count
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: borrower.dob, to: Date()).year ?? 0
    }

    var latestKYCStatuses: [(title: String, status: DocumentStatus)] {
        let latestDocs = latestApplication.documents
        return [
            ("PAN Card", latestDocs.first(where: { $0.type == .panCard })?.status ?? .pending),
            ("Aadhaar", latestDocs.first(where: { $0.type == .aadhaar })?.status ?? .pending),
            ("Income Proof", latestDocs.first(where: { $0.type == .salarySlip || $0.type == .itr || $0.type == .bankStatement })?.status ?? .pending)
        ]
    }

    var recentApplicationSubtitle: String {
        "\(latestApplication.loan.type.displayName) • \(latestApplication.status.displayName)"
    }
}

@MainActor
final class BorrowerViewModel: ObservableObject {
    @Published private(set) var borrowers: [BorrowerRecord] = []
    @Published var selectedBorrowerID: String?
    @Published var searchText = ""
    @Published var filter: BorrowerDirectoryFilter = .all

    private let notesKey = "dst.employee.borrower.notes.v1"
    private let defaults = UserDefaults.standard
    private var persistedNotes: [String: [BorrowerNote]] = [:]

    init() {
        loadPersistedNotes()
    }

    var filteredBorrowers: [BorrowerRecord] {
        var result = borrowers
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter {
                $0.borrower.name.localizedCaseInsensitiveContains(query) ||
                $0.borrower.phone.localizedCaseInsensitiveContains(query) ||
                $0.borrower.email.localizedCaseInsensitiveContains(query) ||
                $0.borrower.employer.localizedCaseInsensitiveContains(query)
            }
        }

        switch filter {
        case .all:
            break
        case .activeLoan:
            result = result.filter { $0.activeLoanApplication != nil }
        case .pending:
            result = result.filter { $0.pendingApplication != nil }
        case .approvedHistory:
            result = result.filter { $0.approvalHistoryCount > 0 }
        case .rejectedHistory:
            result = result.filter { $0.hasRejectedHistory }
        }

        return result.sorted {
            $0.borrower.name.localizedCaseInsensitiveCompare($1.borrower.name) == .orderedAscending
        }
    }

    var selectedBorrower: BorrowerRecord? {
        guard let selectedBorrowerID else { return filteredBorrowers.first ?? borrowers.first }
        return borrowers.first(where: { $0.id == selectedBorrowerID })
    }

    func refresh(from applications: [LoanApplication]) {
        let previousSelection = selectedBorrowerID
        let grouped = Dictionary(grouping: applications, by: borrowerKey(for:))

        borrowers = grouped.compactMap { borrowerID, borrowerApplications in
            guard let newest = borrowerApplications.sorted(by: { $0.createdAt > $1.createdAt }).first else {
                return nil
            }
            return BorrowerRecord(
                id: borrowerID,
                borrower: newest.borrower,
                branch: newest.branch,
                applications: borrowerApplications.sorted(by: { $0.createdAt > $1.createdAt })
            )
        }
        .sorted { $0.borrower.name.localizedCaseInsensitiveCompare($1.borrower.name) == .orderedAscending }

        if let previousSelection, borrowers.contains(where: { $0.id == previousSelection }) {
            selectedBorrowerID = previousSelection
        } else {
            selectedBorrowerID = borrowers.first?.id
        }
    }

    func focus(on borrowerID: String?, from applications: [LoanApplication]) {
        refresh(from: applications)
        guard let borrowerID else { return }
        selectedBorrowerID = borrowers.first(where: { $0.id == borrowerID })?.id
            ?? borrowers.first(where: { $0.applications.contains(where: { $0.id == borrowerID }) })?.id
    }

    func notes(for borrowerID: String) -> [BorrowerNote] {
        (persistedNotes[borrowerID] ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    func addNote(text: String, borrowerID: String, author: String = "Loan Officer") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = BorrowerNote(
            id: UUID().uuidString,
            borrowerID: borrowerID,
            author: author,
            text: trimmed,
            createdAt: Date()
        )

        persistedNotes[borrowerID, default: []].append(note)
        persistNotes()
        objectWillChange.send()
    }

    private func borrowerKey(for application: LoanApplication) -> String {
        if !application.primaryBorrowerProfileID.isEmpty {
            return application.primaryBorrowerProfileID
        }

        let normalizedEmail = application.borrower.email.lowercased()
        if !normalizedEmail.isEmpty {
            return normalizedEmail
        }

        let normalizedPhone = application.borrower.phone.replacingOccurrences(of: " ", with: "")
        if !normalizedPhone.isEmpty {
            return normalizedPhone
        }

        return application.borrower.name.lowercased()
    }

    private func loadPersistedNotes() {
        guard let data = defaults.data(forKey: notesKey) else { return }
        persistedNotes = (try? JSONDecoder().decode([String: [BorrowerNote]].self, from: data)) ?? [:]
    }

    private func persistNotes() {
        guard let data = try? JSONEncoder().encode(persistedNotes) else { return }
        defaults.set(data, forKey: notesKey)
    }
}

private extension ApplicationStatus {
    var isApprovedState: Bool {
        self == .approved || self == .managerApproved || self == .officerApproved
    }

    var isRejectedState: Bool {
        self == .rejected || self == .managerRejected || self == .officerRejected
    }

    var isPendingBorrowerWorkload: Bool {
        self == .pending || self == .officerReview || self == .managerReview || self == .underReview
    }
}
