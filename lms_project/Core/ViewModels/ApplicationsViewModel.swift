//
//  ApplicationsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

@MainActor
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
    
    private let dataService = MockDataService.shared
    private let xmlService = XMLParserService.shared
    // TODO: Replace with UserStore.shared.branchID once auth session exposes it
    private let defaultBranchID = ""
    // TODO: Replace with the actual borrower profile ID resolved from KYC/auth session
    private let defaultBorrowerProfileID = "BORROWER-PROFILE-PLACEHOLDER"
    // TODO: Replace with a real product ID from LoanAPI.listLoanProducts() via a product picker
    private let defaultLoanProductID = "LOAN-PRODUCT-PLACEHOLDER"
    
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
        Task {
            do {
                try await refreshApplications(selectApplicationID: selectedApplication?.id)
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load applications from server"
                showActionAlert = true
            }
            isLoading = false
        }
    }
    
    func selectApplication(_ app: LoanApplication) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedApplication = app
        }
        Task { await refreshSelectedApplicationDetail(applicationID: app.id) }
    }
    
    // MARK: - LO Actions
    
    /// Loan Officer sends application to manager (Under Review)
    func sendToManager(_ app: LoanApplication) {
        Task {
            await sendToManagerWithFallback(applicationID: app.id)
        }
    }
    
    /// Kept for backward-compat — same as sendToManager
    func recommendApplication(_ app: LoanApplication) {
        sendToManager(app)
    }
    
    func rejectApplication(_ app: LoanApplication) {
        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .officerRejected,
                escalationReason: nil,
                successMessage: "Application rejected"
            )
        }
    }
    
    func approveApplication(_ app: LoanApplication) {
        Task {
            await approveAndCreateLoan(app)
        }
    }
    
    func regenerateSanctionLetter(_ app: LoanApplication) {
        // No backend RPC exists for sanction letter generation.
        actionMessage = "Sanction letter generation is not implemented in the backend yet."
        showActionAlert = true
    }
    
    func revokeSanctionLetter(_ app: LoanApplication) {
        // No backend RPC exists for sanction letter revocation.
        actionMessage = "Sanction letter revocation is not implemented in the backend yet."
        showActionAlert = true
    }
    
    func beginSendBack(_ app: LoanApplication) {
        pendingSendBackApp = app
        sendBackReason = "Select a reason"
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
        
        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .officerReview,
                escalationReason: finalRemark,
                successMessage: "Application returned to Loan Officer"
            )
        }
        showSendBackSheet = false
        pendingSendBackApp = nil
    }
    
    func requestDocuments(_ app: LoanApplication) {
        // No backend RPC exists for automated document requests yet.
        actionMessage = "Automated document requests are not implemented in the backend yet. Please contact the borrower directly."
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
        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .managerRejected,
                escalationReason: remarks.isEmpty ? nil : remarks,
                successMessage: "Application rejected"
            )
        }
        showRejectionRemarksSheet = false
        pendingRejectionApp = nil
        rejectionRemarksText = ""
    }

    func createApplication(
        borrowerName: String,
        loanType: LoanType,
        amount: Double,
        tenureMonths: Int,
        branchID: String? = nil
    ) async throws -> LoanApplication {
        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }
        let created = try await LoanAPI().createLoanApplication(
            primaryBorrowerProfileID: defaultBorrowerProfileID,
            loanProductID: defaultLoanProductID,
            branchID: branchID ?? defaultBranchID,
            requestedAmount: String(format: "%.0f", amount),
            tenureMonths: Int32(max(1, tenureMonths)),
            status: .officerReview
        )
        let mapped = LoanApplication.from(proto: created)
        withAnimation {
            selectedApplication = mapped
        }
        try await refreshApplications(selectApplicationID: mapped.id)
        return mapped
    }

    // MARK: - Document Verification

    func verifyDocument(documentId: String, applicationId: String, approved: Bool, rejectionReason: String? = nil) {
        Task {
            await verifyDocumentInternal(documentId: documentId, applicationId: applicationId, approved: approved, rejectionReason: rejectionReason)
        }
    }

    private func verifyDocumentInternal(documentId: String, applicationId: String, approved: Bool, rejectionReason: String?) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Document verification requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            // Proto uses .pass / .fail — NOT .verified / .rejected
            let status: Loan_V1_DocumentVerificationStatus = approved ? .pass : .fail
            _ = try await LoanAPI().updateApplicationDocumentVerification(
                documentID: documentId,
                verificationStatus: status,
                rejectionReason: rejectionReason
            )
            if let appIdx = applications.firstIndex(where: { $0.id == applicationId }) {
                if let docIdx = applications[appIdx].documents.firstIndex(where: { $0.id == documentId }) {
                    withAnimation {
                        applications[appIdx].documents[docIdx].status = approved ? .verified : .rejected
                        if selectedApplication?.id == applicationId {
                            selectedApplication = applications[appIdx]
                        }
                    }
                }
            }
            actionMessage = approved ? "Document verified successfully" : "Document marked as rejected"
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update document verification"
            showActionAlert = true
        }
    }

    // MARK: - Assign Officer

    func assignOfficer(applicationId: String, officerUserId: String) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            do {
                _ = try await LoanAPI().assignLoanApplicationOfficer(
                    applicationID: applicationId,
                    officerUserID: officerUserId
                )
                try await refreshApplications(selectApplicationID: applicationId)
                actionMessage = "Loan Officer assigned successfully"
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to assign officer"
                showActionAlert = true
            }
        }
    }

    // MARK: - Update Loan Terms

    func updateLoanTerms(applicationId: String, tenureMonths: Int, offeredInterestRate: Double) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            do {
                let updatedApp = try await LoanAPI().updateLoanApplicationTerms(
                    applicationID: applicationId,
                    tenureMonths: Int32(tenureMonths),
                    offeredInterestRate: String(format: "%.2f", offeredInterestRate)
                )
                let mapped = LoanApplication.from(proto: updatedApp)
                if let idx = applications.firstIndex(where: { $0.id == applicationId }) {
                    withAnimation {
                        applications[idx] = mapped
                        if selectedApplication?.id == applicationId {
                            selectedApplication = mapped
                        }
                    }
                }
                actionMessage = "Loan terms updated successfully"
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update loan terms"
                showActionAlert = true
            }
        }
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

    /// Manager approval: updates status to MANAGER_APPROVED then creates the loan ledger via CreateLoan.
    private func approveAndCreateLoan(_ app: LoanApplication) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Approval requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            _ = try await LoanAPI().updateLoanApplicationStatus(
                applicationID: app.id,
                status: .managerApproved,
                escalationReason: nil
            )
            // Create the loan ledger so repayment/EMI schedule is generated
            let principalAmount = String(format: "%.0f", app.loan.amount)
            _ = try? await LoanAPI().createLoan(
                applicationID: app.id,
                principalAmount: principalAmount
            )
            try await refreshApplications(selectApplicationID: app.id)
            actionMessage = "Application approved and loan disbursement initiated"
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to approve application"
            showActionAlert = true
        }
    }

    private func updateApplicationStatus(
        applicationID: String,
        status: Loan_V1_LoanApplicationStatus,
        escalationReason: String?,
        successMessage: String
    ) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Status update requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            _ = try await LoanAPI().updateLoanApplicationStatus(
                applicationID: applicationID,
                status: status,
                escalationReason: escalationReason
            )
            try await refreshApplications(selectApplicationID: applicationID)
            actionMessage = successMessage
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update application status"
            showActionAlert = true
        }
    }

    private func sendToManagerWithFallback(applicationID: String) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Status update requires iOS 18 or later"
            showActionAlert = true
            return
        }

        // Different deployments can enforce slightly different officer transitions.
        // Try manager escalation first, then officer approval as fallback.
        let statusAttempts: [(Loan_V1_LoanApplicationStatus, String)] = [
            (.managerReview, "Application sent to Manager for review"),
            (.officerApproved, "Application sent to Manager for review"),
            (.officerReview, "Application moved to Officer Review. Send to Manager after approval.")
        ]
        var lastError: Error?

        for (nextStatus, successMessage) in statusAttempts {
            do {
                _ = try await LoanAPI().updateLoanApplicationStatus(
                    applicationID: applicationID,
                    status: nextStatus,
                    escalationReason: nil
                )
                try await refreshApplications(selectApplicationID: applicationID)
                actionMessage = successMessage
                showActionAlert = true
                return
            } catch {
                lastError = error
            }
        }

        actionMessage = (lastError as? LocalizedError)?.errorDescription ?? "Unable to send application to manager"
        showActionAlert = true
    }

    private func refreshApplications(selectApplicationID: String?) async throws {
        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }
        let list = try await LoanAPI().listLoanApplications(limit: 100, offset: 0, branchID: defaultBranchID)
        let mapped = list.map { LoanApplication.from(proto: $0) }
        withAnimation {
            applications = mapped
            if let selectedID = selectApplicationID,
               let selected = mapped.first(where: { $0.id == selectedID }) {
                selectedApplication = selected
            } else {
                selectedApplication = mapped.first
            }
        }

        if let selectedID = selectedApplication?.id {
            await refreshSelectedApplicationDetail(applicationID: selectedID)
        }
    }

    private func refreshSelectedApplicationDetail(applicationID: String) async {
        guard #available(iOS 18.0, *) else { return }
        do {
            let detail = try await LoanAPI().getLoanApplication(applicationID: applicationID)
            let enriched = LoanApplication.from(proto: detail.application, documents: detail.documents)
            if let index = applications.firstIndex(where: { $0.id == applicationID }) {
                applications[index] = enriched
            }
            if selectedApplication?.id == applicationID {
                selectedApplication = enriched
            }
        } catch {
            // Keep list data if detail fetch fails.
        }
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
