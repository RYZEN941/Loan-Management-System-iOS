import Foundation

@available(iOS 18.0, *)
extension ApplicationStatus {
    init(proto value: Loan_V1_LoanApplicationStatus) {
        switch value {
        case .approved, .disbursed:
            self = .approved
        case .managerApproved:
            self = .managerApproved
        case .managerRejected:
            self = .managerRejected
        case .officerRejected:
            self = .officerRejected
        case .rejected, .cancelled:
            self = .rejected
        case .managerReview, .underReview:
            self = value == .underReview ? .underReview : .managerReview
        case .officerApproved:
            self = .officerApproved
        case .officerReview:
            self = .officerReview
        case .submitted:
            self = .officerReview
        case .draft, .unspecified, .UNRECOGNIZED:
            self = .pending
        }
    }
}

@available(iOS 18.0, *)
struct LoanApplicationEnrichment {
    var borrowerProfile: Auth_V1_BorrowerProfile? = nil
    var borrowerUser: Auth_V1_UserPublicProfile? = nil
    var bureauScores: [Loan_V1_BureauScore] = []
    var borrowerCibilScore: Int? = nil
    var internalRemarks: [InternalRemark] = []
    var requiredDocuments: [LoanProduct.RequiredDocument] = []
    var existingEMI: Double = -1
    var assignedToName: String = ""
    var createdByName: String = ""
    var borrowerHistoryThisBank: [BorrowerLoanHistoryEntry] = []
    var borrowerHistoryOtherLenders: [BorrowerLoanHistoryEntry] = []
    var repaymentSummary: RepaymentSummary = .na
    var repaymentHistory: [RepaymentHistoryItem] = []
    var isDisbursed: Bool = false
}

@available(iOS 18.0, *)
extension LoanApplication {
    static func from(
        proto value: Loan_V1_LoanApplication,
        documents protoDocuments: [Loan_V1_ApplicationDocument] = [],
        enrichment: LoanApplicationEnrichment = LoanApplicationEnrichment()
    ) -> LoanApplication {
        let createdAt = Date.fromBackendTimestamp(value.createdAt) ?? Date()
        let updatedAt = Date.fromBackendTimestamp(value.updatedAt) ?? createdAt
        let borrowerProfile = enrichment.borrowerProfile
        let borrowerUser = enrichment.borrowerUser
        let borrowerName = borrowerProfile?.fullName.nonEmpty
            ?? borrowerUser?.email.nonEmpty
            ?? "N/A"
        let borrowerDOB = Date.fromBackendDateOnly(borrowerProfile?.dateOfBirth ?? "")
            ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())
            ?? Date()
        let monthlyIncome = Double(borrowerProfile?.monthlyIncome ?? "") ?? -1
        let existingEMI = enrichment.existingEMI
        let cibilScore = enrichment.bureauScores.latestScore ?? enrichment.borrowerCibilScore ?? -1
        let proposedEMI = estimatedEMI(
            principal: Double(value.requestedAmount) ?? 0,
            annualRatePercent: Double(value.offeredInterestRate) ?? 0,
            tenureMonths: Int(value.tenureMonths)
        )
        let totalDebtObligation = max(existingEMI, 0) + max(proposedEMI, 0)
        let dtiRatio = monthlyIncome > 0 ? (totalDebtObligation / monthlyIncome) : -1
        let foir = monthlyIncome > 0 && proposedEMI >= 0
            ? ((totalDebtObligation / monthlyIncome) * 100)
            : -1

        return LoanApplication(
            id: value.id,
            borrower: Borrower(
                name: borrowerName,
                dob: borrowerDOB,
                address: borrowerProfile?.formattedAddress ?? "N/A",
                employer: "N/A",
                employmentType: borrowerProfile?.employmentType.nonEmpty ?? "N/A",
                phone: borrowerUser?.phone.nonEmpty ?? "N/A",
                email: borrowerUser?.email.nonEmpty ?? "N/A"
            ),
            loan: LoanDetails(
                amount: Double(value.requestedAmount) ?? 0,
                type: LoanType.fromProductName(value.loanProductName),
                tenure: Int(value.tenureMonths),
                interestRate: Double(value.offeredInterestRate) ?? 0,
                emi: proposedEMI
            ),
            financials: Financials(
                monthlyIncome: monthlyIncome,
                annualIncome: monthlyIncome > 0 ? (monthlyIncome * 12) : -1,
                existingEMI: existingEMI,
                dtiRatio: dtiRatio,
                cibilScore: cibilScore,
                bankBalance: -1,
                foir: foir,
                ltvRatio: -1,
                proposedEMI: proposedEMI
            ),
            documents: mergedDocuments(
                protoDocuments: protoDocuments,
                requiredDocuments: enrichment.requiredDocuments
            ),
            verification: [],
            notes: [],
            internalRemarks: enrichment.internalRemarks,
            status: ApplicationStatus(proto: value.status),
            assignedTo: value.assignedOfficerUserID,
            assignedToName: enrichment.assignedToName,
            primaryBorrowerProfileID: value.primaryBorrowerProfileID,
            createdByUserID: value.createdByUserID,
            createdByName: enrichment.createdByName,
            branchID: value.branchID,
            branch: value.branchName.isEmpty ? value.branchID : value.branchName,
            riskLevel: RiskLevel.from(
                cibilScore: cibilScore,
                dtiRatio: dtiRatio,
                documentStatuses: protoDocuments.map(\.verificationStatus)
            ),
            createdAt: createdAt,
            slaDeadline: Calendar.current.date(byAdding: .day, value: 7, to: updatedAt) ?? updatedAt,
            rejectionRemarks: value.escalationReason.nonEmpty,
            sanctionLetter: nil,
            borrowerUserID: borrowerUser?.userID ?? "",
            borrowerHistoryThisBank: enrichment.borrowerHistoryThisBank,
            borrowerHistoryOtherLenders: enrichment.borrowerHistoryOtherLenders,
            repaymentSummary: enrichment.repaymentSummary,
            repaymentHistory: enrichment.repaymentHistory,
            isDisbursed: enrichment.isDisbursed
        )
    }
}

@available(iOS 18.0, *)
private extension LoanDocument {
    static func from(
        proto value: Loan_V1_ApplicationDocument,
        requiredDocument: LoanProduct.RequiredDocument? = nil
    ) -> LoanDocument {
        let requiredDocID = value.requiredDocID.isEmpty ? nil : value.requiredDocID
        let fallbackType = DocumentType.fromRequiredDocID(value.requiredDocID)
        let mappedType = requiredDocument.map { document in
            DocumentType.fromRequirementType(document.requirementType)
        } ?? fallbackType
        return LoanDocument(
            id: requiredDocID ?? value.id,
            backendDocumentID: value.id.isEmpty ? nil : value.id,
            requiredDocID: requiredDocID,
            type: mappedType,
            label: requiredDocument?.label ?? fallbackType.displayName,
            status: DocumentStatus.from(verificationStatus: value.verificationStatus),
            uploadedAt: Date.fromBackendTimestamp(value.createdAt),
            mediaFileID: value.mediaFileID.isEmpty ? nil : value.mediaFileID,
            fileName: nil,
            contentType: nil,
            fileURL: nil
        )
    }
}

@available(iOS 18.0, *)
private extension DocumentStatus {
    static func from(verificationStatus: Loan_V1_DocumentVerificationStatus) -> DocumentStatus {
        switch verificationStatus {
        case .pass:
            return .verified
        case .fail:
            return .rejected
        case .pending:
            return .uploaded
        case .unspecified, .UNRECOGNIZED:
            return .pending
        }
    }
}

private extension DocumentType {
    static func fromRequirementType(_ value: Loan_V1_DocumentRequirementType) -> DocumentType {
        switch value {
        case .identity:
            return .aadhaar
        case .address:
            return .bankStatement
        case .income:
            return .salarySlip
        case .collateral:
            return .other
        case .unspecified, .UNRECOGNIZED:
            return .other
        }
    }

    static func fromRequiredDocID(_ value: String) -> DocumentType {
        let normalized = value.lowercased()
        if normalized.contains("pan") { return .panCard }
        if normalized.contains("aadhaar") || normalized.contains("aadhar") { return .aadhaar }
        if normalized.contains("bank") { return .bankStatement }
        if normalized.contains("salary") { return .salarySlip }
        if normalized.contains("itr") { return .itr }
        return .other
    }
}

private extension LoanType {
    static func fromProductName(_ value: String) -> LoanType {
        let normalized = value.lowercased()
        if normalized.contains("home") { return .homeLoan }
        if normalized.contains("personal") { return .personalLoan }
        if normalized.contains("business") { return .businessLoan }
        if normalized.contains("vehicle") || normalized.contains("car") { return .vehicleLoan }
        if normalized.contains("education") { return .educationLoan }
        return .personalLoan
    }
}

extension Date {
    static func fromBackendTimestamp(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return Date.iso8601WithFractional.date(from: value)
            ?? Date.iso8601.date(from: value)
    }

    static func fromBackendDateOnly(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: value)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Auth_V1_BorrowerProfile {
    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var formattedAddress: String {
        let parts = [addressLine1, city, state, pincode]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "N/A" : parts.joined(separator: ", ")
    }
}

private extension Array where Element == Loan_V1_BureauScore {
    var latestScore: Int? {
        guard !isEmpty else { return nil }
        var latest: Loan_V1_BureauScore?
        var latestDate = Date.distantPast
        for item in self {
            let fetchedDate = Date.fromBackendTimestamp(item.fetchedAt) ?? .distantPast
            if fetchedDate > latestDate {
                latestDate = fetchedDate
                latest = item
            }
        }
        if let latest {
            return Int(latest.score)
        }
        return nil
    }
}

private extension RiskLevel {
    static func from(
        cibilScore: Int,
        dtiRatio: Double,
        documentStatuses: [Loan_V1_DocumentVerificationStatus]
    ) -> RiskLevel {
        if documentStatuses.contains(.fail) {
            return .high
        }
        if cibilScore > 0 && cibilScore < 650 {
            return .high
        }
        if dtiRatio >= 0.45 {
            return .high
        }
        if cibilScore >= 750 && (dtiRatio < 0 || dtiRatio <= 0.30) {
            return .low
        }
        return .medium
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self else { return nil }
        return self.nonEmpty
    }
}

@available(iOS 18.0, *)
private func mergedDocuments(
    protoDocuments: [Loan_V1_ApplicationDocument],
    requiredDocuments: [LoanProduct.RequiredDocument]
) -> [LoanDocument] {
    guard !requiredDocuments.isEmpty else {
        return protoDocuments.map { document in
            LoanDocument.from(proto: document)
        }
    }

    let requiredByID = Dictionary(uniqueKeysWithValues: requiredDocuments.map { ($0.id, $0) })
    var seenRequiredDocIDs = Set<String>()
    var merged: [LoanDocument] = []
    
    // First pass: Match explicitly by requiredDocID
    var unassignedProtoDocs: [Loan_V1_ApplicationDocument] = []
    
    for document in protoDocuments {
        let reqID = document.requiredDocID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reqID.isEmpty, requiredByID[reqID] != nil {
            let mapped = LoanDocument.from(proto: document, requiredDocument: requiredByID[reqID])
            merged.append(mapped)
            seenRequiredDocIDs.insert(reqID)
        } else {
            unassignedProtoDocs.append(document)
        }
    }

    // Second pass: Match unassigned proto docs to remaining requirements sequentially
    var remainingRequired = requiredDocuments.filter { !seenRequiredDocIDs.contains($0.id) }
    
    for document in unassignedProtoDocs {
        if !remainingRequired.isEmpty {
            let matchedRequirement = remainingRequired.removeFirst()
            let mapped = LoanDocument.from(proto: document, requiredDocument: matchedRequirement)
            merged.append(mapped)
            seenRequiredDocIDs.insert(matchedRequirement.id)
        } else {
            merged.append(LoanDocument.from(proto: document))
        }
    }

    // Only add placeholder rows for required documents that have NO uploaded proto doc
    for requiredDocument in remainingRequired {
        merged.append(
            LoanDocument(
                id: requiredDocument.id,
                backendDocumentID: nil,
                requiredDocID: requiredDocument.id,
                type: .fromRequirementType(requiredDocument.requirementType),
                label: requiredDocument.label,
                status: .pending,
                uploadedAt: nil
            )
        )
    }
    return merged
}

func estimatedEMI(principal: Double, annualRatePercent: Double, tenureMonths: Int) -> Double {
    guard principal > 0, tenureMonths > 0 else { return -1 }
    let monthlyRate = annualRatePercent / 1200
    guard monthlyRate > 0 else { return principal / Double(tenureMonths) }
    let factor = pow(1 + monthlyRate, Double(tenureMonths))
    let emi = principal * monthlyRate * factor / (factor - 1)
    return emi.isFinite ? emi : -1
}
