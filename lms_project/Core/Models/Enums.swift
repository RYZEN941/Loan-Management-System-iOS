//
//  Enums.swift
//  lms_project
//

import SwiftUI

// MARK: - User Role

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case loanOfficer = "loan_officer"
    case manager = "manager"
    case admin = "admin"
    case dst = "dst"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .loanOfficer: return "Loan Officer"
        case .manager: return "Manager"
        case .admin: return "Admin"
        case .dst: return "DST"
        }
    }
    
    var icon: String {
        switch self {
        case .loanOfficer: return "person.text.rectangle"
        case .manager: return "person.badge.shield.checkmark"
        case .admin: return "gearshape.2"
        case .dst: return "person.badge.plus"
        }
    }
}

// MARK: - Application Status
// STRICT: Only these four statuses are allowed across the entire app.

enum ApplicationStatus: String, CaseIterable, Identifiable, Codable {
    case pending     = "pending"       // New / not yet reviewed
    case underReview = "under_review"  // Sent to manager
    case approved    = "approved"
    case rejected    = "rejected"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:     return "Pending"
        case .underReview: return "Under Review"
        case .approved:    return "Approved"
        case .rejected:    return "Rejected"
        }
    }

    var color: Color {
        switch self {
        case .pending, .underReview: return Theme.Colors.primary
        case .approved:              return Theme.Colors.secondary
        case .rejected:              return Theme.Colors.critical
        }
    }

    var backgroundColor: Color {
        switch self {
        case .pending, .underReview: return Theme.Colors.primaryLight
        case .approved:              return Theme.Colors.primaryLight
        case .rejected:              return Theme.Colors.critical.opacity(0.12)
        }
    }
}

// MARK: - Document Status

enum DocumentStatus: String, CaseIterable, Identifiable, Codable {
    case pending = "pending"
    case uploaded = "uploaded"
    case verified = "verified"
    case rejected = "rejected"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .uploaded: return "Uploaded"
        case .verified: return "Verified"
        case .rejected: return "Rejected"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .uploaded: return "arrow.up.circle"
        case .verified: return "checkmark.shield.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return Theme.Colors.neutral
        case .uploaded: return Theme.Colors.primary
        case .verified: return Theme.Colors.success
        case .rejected: return Theme.Colors.critical
        }
    }
}

// MARK: - Sanction Letter Status

enum SanctionLetterStatus: String, CaseIterable, Identifiable, Codable {
    case sent = "sent"
    case revoked = "revoked"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sent: return "Sent to Borrower"
        case .revoked: return "Revoked"
        }
    }
}

// MARK: - Document Type

enum DocumentType: String, CaseIterable, Identifiable, Codable {
    case panCard = "pan_card"
    case aadhaar = "aadhaar"
    case bankStatement = "bank_statement"
    case salarySlip = "salary_slip"
    case itr = "itr"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .panCard: return "PAN Card"
        case .aadhaar: return "Aadhaar Card"
        case .bankStatement: return "Bank Statement"
        case .salarySlip: return "Salary Slip"
        case .itr: return "ITR"
        case .other: return "Other Document"
        }
    }
    
    var icon: String {
        switch self {
        case .panCard: return "creditcard"
        case .aadhaar: return "person.crop.rectangle"
        case .bankStatement: return "building.columns"
        case .salarySlip: return "indianrupeesign.circle"
        case .itr: return "doc.text"
        case .other: return "paperclip"
        }
    }
}

// MARK: - Risk Level

enum RiskLevel: String, CaseIterable, Identifiable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low:    return Theme.Colors.secondary
        case .medium: return Theme.Colors.primary
        case .high:   return Theme.Colors.critical
        }
    }

    func adaptiveColor(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .low:    return Theme.Colors.adaptiveSecondary(colorScheme)
        case .medium: return Theme.Colors.adaptivePrimary(colorScheme)
        case .high:   return Theme.Colors.adaptiveCritical(colorScheme)
        }
    }
}

// MARK: - Loan Type

enum LoanType: String, CaseIterable, Identifiable, Codable {
    case homeLoan = "home_loan"
    case personalLoan = "personal_loan"
    case businessLoan = "business_loan"
    case vehicleLoan = "vehicle_loan"
    case educationLoan = "education_loan"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .homeLoan: return "Home Loan"
        case .personalLoan: return "Personal Loan"
        case .businessLoan: return "Business Loan"
        case .vehicleLoan: return "Vehicle Loan"
        case .educationLoan: return "Education Loan"
        }
    }
}

// MARK: - Application Action

enum ApplicationAction: String, Codable {
    case sendToManager = "send_to_manager"
    case reject = "reject"
    case requestDocs = "request_docs"
    case approve = "approve"
    case sendBack = "send_back"
}

// MARK: - System Health

enum SystemHealth: String, Codable {
    case healthy = "healthy"
    case degraded = "degraded"
    case down = "down"
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .down: return "Down"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy: return Theme.Colors.success
        case .degraded: return Theme.Colors.warning
        case .down: return Theme.Colors.critical
        }
    }
}
