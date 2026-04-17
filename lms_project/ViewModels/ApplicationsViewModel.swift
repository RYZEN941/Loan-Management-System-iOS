//
//  ApplicationsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class ApplicationsViewModel: ObservableObject {
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var filterStatus: ApplicationStatus? = nil
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showXMLUploadResult = false
    @Published var xmlParseResult: XMLParseResult? = nil
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    
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
    
    // MARK: - Actions
    
    func recommendApplication(_ app: LoanApplication) {
        updateStatus(app, to: .recommended, message: "Application recommended to Manager")
    }
    
    func rejectApplication(_ app: LoanApplication) {
        updateStatus(app, to: .rejected, message: "Application rejected")
    }
    
    func approveApplication(_ app: LoanApplication) {
        updateStatus(app, to: .approved, message: "Application approved")
    }
    
    func sendBackApplication(_ app: LoanApplication) {
        updateStatus(app, to: .sentBack, message: "Application sent back to Loan Officer")
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
    
    // MARK: - XML Upload
    
    func simulateXMLUpload() {
        xmlParseResult = xmlService.simulateXMLUpload()
        showXMLUploadResult = true
    }
    
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
    
    func sendApplicationMessage(applicationId: String, senderName: String, senderRole: String, isManagerRemark: Bool = false) {
        guard !chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let msg = ApplicationMessage(
            id: "\(applicationId)-AM-\(UUID().uuidString.prefix(6))",
            applicationId: applicationId,
            senderId: isManagerRemark ? "MGR-001" : "LO-001",
            senderName: senderName,
            senderRole: senderRole,
            text: chatText,
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
        chatText = ""
    }
}
