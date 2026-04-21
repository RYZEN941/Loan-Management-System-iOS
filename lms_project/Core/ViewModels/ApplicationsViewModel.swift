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
    
    private let dataService = MockDataService.shared
    private let xmlService = XMLParserService.shared
    
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
}

// MARK: - Uploaded Doc File

struct UploadedDocFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    let isImage: Bool
    let uploadedAt: Date
}
