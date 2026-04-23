//
//  ApplicationsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class ApplicationsViewModel: ObservableObject {
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var filterStatus: ApplicationStatus? = .underReview   // default: Under Review
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showXMLUploadResult = false
    @Published var xmlParseResult: XMLParseResult? = nil
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    // Uploaded file URLs per document id (in-memory for session)
    @Published var uploadedFiles: [String: [UploadedDocFile]] = [:]
    
    // Manager rejection remarks sheet
    @Published var showRejectionRemarksSheet = false
    @Published var pendingRejectionApp: LoanApplication? = nil
    @Published var rejectionRemarksText = ""
    
    // Manager send back sheet
    @Published var showSendBackSheet = false
    @Published var pendingSendBackApp: LoanApplication? = nil
    @Published var sendBackReason = ""
    @Published var sendBackCustomRemark = ""
    @Published var availableLoanProducts: [LoanProduct] = []
    
    private let dataService = MockDataService.shared
    private let xmlService = XMLParserService.shared
    private let loanAPI = LoanAPI()
    private let authAPI = AuthAPI()
    
    // MARK: - Filtered Applications
    
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
    
    // MARK: - Load Data
    
    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.applications = self.dataService.fetchApplications()
            if self.selectedApplication == nil {
                self.selectedApplication = self.applications.first
            }
            self.isLoading = false
        }
        Task {
            await loadAvailableLoanProducts()
        }
    }

    @MainActor
    func loadAvailableLoanProducts() async {
        do {
            let products = try await loanAPI.listLoanProducts(limit: 200, offset: 0, includeDeleted: false, authorized: true)
                .map(LoanProduct.init(proto:))
                .filter { $0.isActive && !$0.isDeleted }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            availableLoanProducts = products
        } catch {
            // Keep existing value; create flow will still show API error on submit.
        }
    }
    
    func selectApplication(_ app: LoanApplication) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedApplication = app
        }
    }
    
    // MARK: - LO Actions
    
    /// Loan Officer sends application to manager (Under Review)
    func sendToManager(_ app: LoanApplication) {
        updateStatus(app, to: .underReview, message: "Application sent to Manager for review")
    }
    
    /// Kept for backward-compat — same as sendToManager
    func recommendApplication(_ app: LoanApplication) {
        sendToManager(app)
    }
    
    func rejectApplication(_ app: LoanApplication) {
        updateStatus(app, to: .rejected, message: "Application rejected")
    }
    
    func approveApplication(_ app: LoanApplication) {
        updateStatus(app, to: .approved, message: "Application approved ✓")
    }
    
    func beginSendBack(_ app: LoanApplication) {
        pendingSendBackApp = app
        sendBackReason = "Incomplete documentation"
        sendBackCustomRemark = ""
        showSendBackSheet = true
    }
    
    func confirmSendBack() {
        guard let app = pendingSendBackApp else { return }
        
        let finalRemark = sendBackReason == "Other" 
            ? sendBackCustomRemark 
            : (sendBackCustomRemark.isEmpty ? sendBackReason : "\(sendBackReason): \(sendBackCustomRemark)")
            
        // Record the send back remark as a manager remark message
        sendApplicationMessage(
            applicationId: app.id,
            senderName: "Deepak Mehta",
            senderRole: "Manager",
            text: finalRemark,
            isManagerRemark: true
        )
        
        updateStatus(app, to: .pending, message: "Application returned to Loan Officer")
        showSendBackSheet = false
        pendingSendBackApp = nil
    }
    
    func requestDocuments(_ app: LoanApplication) {
        actionMessage = "Document request sent to borrower"
        showActionAlert = true
    }
    
    private func updateStatus(_ app: LoanApplication, to status: ApplicationStatus, message: String) {
        if let index = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[index].status = status
                selectedApplication = applications[index]
            }
        }
        actionMessage = message
        showActionAlert = true
    }
    
    // MARK: - Manager Rejection With Remarks
    
    /// Call this to begin the rejection flow (shows the remarks sheet)
    func beginRejectWithRemarks(_ app: LoanApplication) {
        pendingRejectionApp = app
        rejectionRemarksText = ""
        showRejectionRemarksSheet = true
    }
    
    /// Confirmed rejection: saves remarks then updates status
    func confirmRejectWithRemarks() {
        guard let app = pendingRejectionApp else { return }
        let remarks = rejectionRemarksText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[index].status = .rejected
                applications[index].rejectionRemarks = remarks.isEmpty ? nil : remarks
                selectedApplication = applications[index]
            }
        }
        actionMessage = "Application rejected"
        showActionAlert = true
        showRejectionRemarksSheet = false
        pendingRejectionApp = nil
        rejectionRemarksText = ""
    }
    
    // MARK: - XML Upload
    
    func simulateXMLUpload() {
        xmlParseResult = xmlService.simulateXMLUpload()
        showXMLUploadResult = true
    }
    
    /// Parse XML silently (no result sheet) — used by CreateApplicationSheet for autofill
    func parseXMLFile(_ data: Data) {
        xmlParseResult = xmlService.parseXMLData(data)
        showXMLUploadResult = true
    }
    
    // MARK: - Per-Application Conversation
    
    @Published var applicationMessages: [String: [ApplicationMessage]] = [:]
    @Published var chatText = ""
    
    func loadApplicationMessages(for applicationId: String) {
        if applicationMessages[applicationId] == nil {
            applicationMessages[applicationId] = dataService.fetchApplicationMessages(applicationId: applicationId)
        }
    }
    
    func messagesForApplication(_ applicationId: String) -> [ApplicationMessage] {
        return applicationMessages[applicationId] ?? []
    }
    
    // MARK: - Internal Remarks
    
    func addInternalRemark(applicationId: String, text: String, author: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let remark = InternalRemark(
            id: UUID().uuidString,
            author: author,
            text: text,
            timestamp: Date()
        )
        if let idx = applications.firstIndex(where: { $0.id == applicationId }) {
            withAnimation {
                applications[idx].internalRemarks.append(remark)
                selectedApplication = applications[idx]
            }
        }
    }
    
    // MARK: - Document Upload
    
    func addOtherDocument(to app: LoanApplication, label: String) {
        let newDoc = LoanDocument(
            id: "DOC-OTHER-\(UUID().uuidString.prefix(6))",
            type: .other,
            label: label,
            status: .pending,
            uploadedAt: nil
        )
        if let idx = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[idx].documents.append(newDoc)
                selectedApplication = applications[idx]
            }
        }
    }
    
    func recordUploadedFile(_ file: UploadedDocFile, forDocumentId docId: String) {
        withAnimation {
            if uploadedFiles[docId] != nil {
                uploadedFiles[docId]!.append(file)
            } else {
                uploadedFiles[docId] = [file]
            }
        }
        // Mark document as uploaded in the application
        if let appIdx = applications.firstIndex(where: { app in
            app.documents.contains(where: { $0.id == docId })
        }) {
            if let docIdx = applications[appIdx].documents.firstIndex(where: { $0.id == docId }) {
                withAnimation {
                    applications[appIdx].documents[docIdx].status = .uploaded
                    applications[appIdx].documents[docIdx].uploadedAt = Date()
                    selectedApplication = applications[appIdx]
                }
            }
        }
    }
    
    func sendApplicationMessage(applicationId: String, senderName: String, senderRole: String, text: String? = nil, isManagerRemark: Bool = false) {
        let textToSend = text ?? chatText
        guard !textToSend.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let msg = ApplicationMessage(
            id: "\(applicationId)-AM-\(UUID().uuidString.prefix(6))",
            applicationId: applicationId,
            senderId: isManagerRemark ? "MGR-001" : "LO-001",
            senderName: senderName,
            senderRole: senderRole,
            text: textToSend,
            timestamp: Date(),
            type: isManagerRemark ? .managerRemark : .message,
            isFromCurrentUser: true
        )
        withAnimation {
            if applicationMessages[applicationId] != nil {
                applicationMessages[applicationId]!.append(msg)
            } else {
                applicationMessages[applicationId] = [msg]
            }
        }
        if text == nil {
            chatText = ""
        }
    }

    // MARK: - Backend Creation (Loan Officer)

    @MainActor
    func createBackendApplication(
        borrowerProfileID: String,
        borrowerName: String,
        borrowerPhone: String,
        borrowerEmail: String,
        borrowerAddress: String,
        selectedLoanProduct: LoanProduct,
        requestedAmount: Double,
        tenureMonths: Int,
        monthlyIncome: Double,
        existingEMI: Double,
        documents: [LoanDocument]
    ) async throws {
        let cleanBorrowerProfileID = borrowerProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBorrowerProfileID.isEmpty else {
            throw APIError.invalidArgument("Borrower profile ID is required.")
        }
        guard requestedAmount > 0 else {
            throw APIError.invalidArgument("Requested loan amount must be greater than 0.")
        }
        guard tenureMonths > 0 else {
            throw APIError.invalidArgument("Tenure must be greater than 0.")
        }

        let profile = try await authAPI.getMyProfile()
        guard case .officerProfile(let officerProfile) = profile.profile else {
            throw APIError.permissionDenied("Only Officer profile can create applications from this screen.")
        }
        let branchID = officerProfile.branch.branchID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branchID.isEmpty else {
            throw APIError.failedPrecondition("Officer is not assigned to a branch.")
        }

        let created = try await loanAPI.createLoanApplication(
            primaryBorrowerProfileID: cleanBorrowerProfileID,
            loanProductID: selectedLoanProduct.id,
            branchID: branchID,
            requestedAmount: String(Int(requestedAmount)),
            tenureMonths: Int32(tenureMonths),
            status: .submitted
        )

        let localApp = LoanApplication(
            id: created.id,
            borrower: Borrower(
                name: borrowerName.isEmpty ? "Borrower" : borrowerName,
                dob: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
                address: borrowerAddress.isEmpty ? "Address TBD" : borrowerAddress,
                employer: "To be verified",
                employmentType: "To be verified",
                phone: borrowerPhone,
                email: borrowerEmail
            ),
            loan: LoanDetails(
                amount: requestedAmount,
                type: selectedLoanProduct.loanTypeForUI,
                tenure: tenureMonths,
                interestRate: Double(created.offeredInterestRate) ?? 0,
                emi: 0
            ),
            financials: Financials(
                monthlyIncome: monthlyIncome,
                annualIncome: monthlyIncome * 12,
                existingEMI: existingEMI,
                dtiRatio: monthlyIncome > 0 ? (existingEMI / monthlyIncome) : 0,
                cibilScore: 0,
                bankBalance: 0
            ),
            documents: documents,
            verification: [],
            notes: [],
            internalRemarks: [],
            status: created.status.employeeStatus,
            assignedTo: "LO-001",
            branch: created.branchName.isEmpty ? officerProfile.branch.name : created.branchName,
            riskLevel: .medium,
            createdAt: Date(),
            slaDeadline: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )

        withAnimation {
            applications.insert(localApp, at: 0)
            selectedApplication = localApp
        }
    }

    @MainActor
    func resolveBorrowerProfileID(email: String, phone: String) async throws -> String? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        func exactMatch(from items: [BorrowerSignupStatusSearchItem]) -> BorrowerSignupStatusSearchItem? {
            let direct = items.first { item in
                let emailMatch = !cleanEmail.isEmpty && item.email.lowercased() == cleanEmail
                let phoneMatch = !cleanPhone.isEmpty && item.phone == cleanPhone
                return emailMatch || phoneMatch
            }
            if let direct { return direct }
            return items.first
        }

        if !cleanEmail.isEmpty {
            let emailResults = try await authAPI.searchBorrowerSignupStatus(query: cleanEmail, limit: 20, offset: 0)
            if let found = exactMatch(from: emailResults), !found.borrowerProfileID.isEmpty {
                return found.borrowerProfileID
            }
        }

        if !cleanPhone.isEmpty {
            let phoneResults = try await authAPI.searchBorrowerSignupStatus(query: cleanPhone, limit: 20, offset: 0)
            if let found = exactMatch(from: phoneResults), !found.borrowerProfileID.isEmpty {
                return found.borrowerProfileID
            }
        }

        return nil
    }
}

// MARK: - Uploaded Doc File

struct UploadedDocFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    let isImage: Bool
    let uploadedAt: Date
}

private extension Loan_V1_LoanApplicationStatus {
    var employeeStatus: ApplicationStatus {
        switch self {
        case .draft, .submitted:
            return .pending
        case .underReview:
            return .underReview
        case .approved:
            return .approved
        case .rejected:
            return .rejected
        case .disbursed, .cancelled, .officerReview, .officerApproved, .officerRejected, .managerReview, .managerApproved, .managerRejected, .unspecified, .UNRECOGNIZED:
            return .underReview
        }
    }
}

private extension LoanProduct {
    var loanTypeForUI: LoanType {
        switch category {
        case .home:
            return .homeLoan
        case .vehicle:
            return .vehicleLoan
        case .education:
            return .educationLoan
        case .personal:
            return .personalLoan
        case .unspecified, .UNRECOGNIZED:
            return .businessLoan
        }
    }
}
