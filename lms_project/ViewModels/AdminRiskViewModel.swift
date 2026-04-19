//
//  AdminRiskViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Risk Analytics Models

struct FraudFlag: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let borrowerName: String
    let reason: String
    let severity: RiskLevel
    let flaggedAt: Date
}

struct DecisionRecord: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let borrowerName: String
    let decision: String    // "Approved" / "Rejected" / "Escalated"
    let reason: String
    let score: Int          // 0–100
    let decidedAt: Date
}

struct RiskBucket: Identifiable {
    let id = UUID()
    let label: String       // "CIBIL < 650", "650-749", "750+"
    let count: Int
    let color: Color
}

// MARK: - Admin Risk View Model

class AdminRiskViewModel: ObservableObject {

    @Published var applications: [LoanApplication] = []
    @Published var fraudFlags: [FraudFlag] = []
    @Published var decisions: [DecisionRecord] = []
    @Published var stressTestEnabled = false
    @Published var isLoading = false

    private let dataService = MockDataService.shared

    // MARK: - KPIs

    var avgCIBIL: Int {
        guard !applications.isEmpty else { return 0 }
        return applications.map { $0.financials.cibilScore }.reduce(0, +) / applications.count
    }

    var avgFOIR: Double {
        guard !applications.isEmpty else { return 0 }
        return applications.map { $0.financials.dtiRatio }.reduce(0, +) / Double(applications.count)
    }

    var approvalRate: Double {
        guard !applications.isEmpty else { return 0 }
        let approved = applications.filter { $0.status == .approved }.count
        return Double(approved) / Double(applications.count)
    }

    var fraudFlagCount: Int { fraudFlags.count }

    // MARK: - CIBIL Buckets

    var cibilBuckets: [RiskBucket] {
        let low   = applications.filter { $0.financials.cibilScore >= 750 }.count
        let mid   = applications.filter { $0.financials.cibilScore >= 650 && $0.financials.cibilScore < 750 }.count
        let poor  = applications.filter { $0.financials.cibilScore < 650 }.count
        return [
            RiskBucket(label: "750+",     count: low,  color: Theme.Colors.success),
            RiskBucket(label: "650–749",  count: mid,  color: Theme.Colors.warning),
            RiskBucket(label: "< 650",    count: poor, color: Theme.Colors.critical)
        ]
    }

    // MARK: - Income Discrepancy

    var incomeDiscrepancies: [LoanApplication] {
        applications.filter { $0.financials.dtiRatio > 0.40 }
    }

    // MARK: - Load

    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.applications = self.dataService.fetchApplications()
            self.fraudFlags = Self.mockFraudFlags()
            self.decisions   = Self.mockDecisions(from: self.applications)
            self.isLoading   = false
        }
    }

    // MARK: - Mock Data

    static func mockFraudFlags() -> [FraudFlag] {
        [
            FraudFlag(id: "FF-001", applicationId: "APP-2024-005",
                      borrowerName: "Suresh Nair",
                      reason: "Declared income 15% higher than bank statement",
                      severity: .high,
                      flaggedAt: Date().addingTimeInterval(-86400)),
            FraudFlag(id: "FF-002", applicationId: "APP-2024-010",
                      borrowerName: "Divya Krishnan",
                      reason: "PAN name mismatch with Aadhaar",
                      severity: .high,
                      flaggedAt: Date().addingTimeInterval(-172800))
        ]
    }

    static func mockDecisions(from apps: [LoanApplication]) -> [DecisionRecord] {
        [
            DecisionRecord(id: "DEC-001", applicationId: "APP-2024-006",
                           borrowerName: "Meera Joshi", decision: "Approved",
                           reason: "CIBIL 800, DTI 12%, all docs verified",
                           score: 92, decidedAt: Date().addingTimeInterval(-172800)),
            DecisionRecord(id: "DEC-002", applicationId: "APP-2024-007",
                           borrowerName: "Karan Malhotra", decision: "Rejected",
                           reason: "CIBIL 660, DTI 40% exceeds policy threshold",
                           score: 41, decidedAt: Date().addingTimeInterval(-259200)),
            DecisionRecord(id: "DEC-003", applicationId: "APP-2024-010",
                           borrowerName: "Divya Krishnan", decision: "Rejected",
                           reason: "CIBIL 580, income insufficient",
                           score: 28, decidedAt: Date().addingTimeInterval(-432000))
        ]
    }
}
