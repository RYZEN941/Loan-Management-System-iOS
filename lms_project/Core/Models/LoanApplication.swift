//
//  LoanApplication.swift
//  lms_project
//

import Foundation

// MARK: - Loan Application

struct LoanApplication: Identifiable, Codable, Hashable {
    let id: String
    var borrower: Borrower
    var loan: LoanDetails
    var financials: Financials
    var documents: [LoanDocument]
    var verification: [VerificationItem]
    var notes: [Note]
    var internalRemarks: [InternalRemark]
    var status: ApplicationStatus
    var assignedTo: String
    var assignedToName: String = ""
    var primaryBorrowerProfileID: String = ""
    var createdByUserID: String = ""
    var createdByName: String = ""
    var branchID: String = ""
    var branch: String
    var riskLevel: RiskLevel
    var createdAt: Date
    var slaDeadline: Date
    /// Populated when manager rejects — saved with the application
    var rejectionRemarks: String?
    
    /// Sanction letter tracking
    var sanctionLetter: SanctionLetter?
    
    var isHighRisk: Bool {
        financials.cibilScore >= 0 && financials.cibilScore < 600
        || financials.foir >= 0 && financials.foir > 60
        || slaStatus == .overdue
        || riskLevel == .high
    }

    var borrowerUserID: String = ""
    var borrowerHistoryThisBank: [BorrowerLoanHistoryEntry] = []
    var borrowerHistoryOtherLenders: [BorrowerLoanHistoryEntry] = []
    var repaymentSummary: RepaymentSummary = .na
    var repaymentHistory: [RepaymentHistoryItem] = []
    var isDisbursed: Bool = false

    var slaStatus: SLAStatus {
        let days = slaDeadline.daysRemaining
        if days < 0 { return .overdue }
        if days <= 2 { return .urgent }
        return .onTrack
    }
}

// MARK: - Sanction Letter

struct SanctionLetter: Codable, Hashable {
    var versions: [SanctionLetterVersion]
    var currentVersion: Int
    
    var activeVersion: SanctionLetterVersion? {
        versions.first { $0.version == currentVersion }
    }
}

struct SanctionLetterVersion: Identifiable, Codable, Hashable {
    var id: String { "\(version)" }
    let version: Int
    let generatedAt: Date
    var status: SanctionLetterStatus
    let fileUrl: String
}


// MARK: - Internal Remark

struct InternalRemark: Identifiable, Codable, Hashable {
    let id: String
    var author: String
    var text: String
    var timestamp: Date
}

struct BorrowerLoanHistoryEntry: Identifiable, Codable, Hashable {
    let id: String
    let loanType: String
    let institution: String
    let amount: String
    let status: String
    let statusStyle: HistoryStatusStyle
}

enum HistoryStatusStyle: String, Codable, Hashable {
    case primary
    case success
    case warning
    case critical
    case neutral
}

struct RepaymentSummary: Codable, Hashable {
    let outstanding: String
    let paidToDate: String
    let nextEmi: String

    static let na = RepaymentSummary(
        outstanding: "N/A",
        paidToDate: "N/A",
        nextEmi: "N/A"
    )
}

struct RepaymentHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let period: String
    let dueDateText: String
    let amount: String
    let status: String
    let isPaid: Bool
}


// MARK: - Borrower

struct Borrower: Codable, Hashable {
    var name: String
    var dob: Date
    var address: String
    var employer: String
    var employmentType: String
    var phone: String
    var email: String
}

// MARK: - Loan Details

struct LoanDetails: Codable, Hashable {
    var amount: Double
    var type: LoanType
    var tenure: Int          // months
    var interestRate: Double  // percentage
    var emi: Double
}

// MARK: - Financials

struct Financials: Codable, Hashable {
    var monthlyIncome: Double
    var annualIncome: Double
    var existingEMI: Double
    var dtiRatio: Double
    var cibilScore: Int
    var bankBalance: Double
    var foir: Double           // percentage
    var ltvRatio: Double       // percentage
    var proposedEMI: Double    // amount
}

// MARK: - Loan Document

struct LoanDocument: Identifiable, Codable, Hashable {
    let id: String
    var backendDocumentID: String? = nil
    var requiredDocID: String? = nil
    var type: DocumentType
    var label: String
    var status: DocumentStatus
    var uploadedAt: Date?
    var mediaFileID: String? = nil
    var fileName: String? = nil
    var contentType: String? = nil
    var fileURL: URL? = nil
}

// MARK: - Verification Item

struct VerificationItem: Identifiable, Codable, Hashable {
    let id: String
    var field: String
    var declaredValue: String
    var extractedValue: String
    var isMatch: Bool
}

// MARK: - Note

struct Note: Identifiable, Codable, Hashable {
    let id: String
    var author: String
    var text: String
    var timestamp: Date
}

// MARK: - SLA Status

enum SLAStatus {
    case onTrack
    case urgent
    case overdue
    
    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .urgent: return "Urgent"
        case .overdue: return "Overdue"
        }
    }
    
    var icon: String {
        switch self {
        case .onTrack: return "clock"
        case .urgent: return "exclamationmark.clock"
        case .overdue: return "clock.badge.exclamationmark"
        }
    }
}
