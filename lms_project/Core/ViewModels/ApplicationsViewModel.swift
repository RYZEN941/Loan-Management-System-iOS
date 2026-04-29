//
//  ApplicationsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

struct OfficerDirectoryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let branchName: String
}

struct CachedMediaPreview: Sendable {
    let mediaFileID: String
    let fileName: String
    let contentType: String
    let fileURL: URL?
}

@MainActor
class ApplicationsViewModel: ObservableObject {
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var filterStatuses: [ApplicationStatus]? = nil
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showXMLUploadResult = false
    @Published var xmlParseResult: XMLParseResult? = nil
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    // Uploaded file URLs per document id (in-memory for session)
    @Published var uploadedFiles: [String: [UploadedDocFile]] = [:]

    // MARK: - Services
    // Use the shared mock data service to satisfy existing calls in this view model
    private let dataService: LMSDataService = MockDataService.shared
    // Note: XML parsing service is provided by XMLParserService
    // This view model expects an xmlService; map it to the shared parser service below.
    private var defaultBranchID: String? { nil }

    // New Filters for Manager Navigation
    @Published var filterRisk: RiskLevel? = nil
    @Published var filterSLA: SLAStatus? = nil
    @Published var filterHighValue: Bool = false
    @Published var filterLoanType: LoanType? = nil

    // Manager rejection remarks sheet
    @Published var showRejectionRemarksSheet = false
    @Published var pendingRejectionApp: LoanApplication? = nil
    @Published var rejectionRemarksText = ""

    @Published var availableLoanProducts: [LoanProduct] = []
    @Published var availableBranchOfficers: [OfficerDirectoryItem] = []
    @Published var officerDirectoryUnavailableMessage: String? = nil
    @Published var isLoadingBranchOfficers = false
    @Published private(set) var mediaPreviewCache: [String: CachedMediaPreview] = [:]

    /// Tracks whether initial data has been loaded after login to avoid redundant fetches.
    private(set) var hasLoaded = false
    private var lastLoadTime: Date = .distantPast
    private var activeLoadTask: Task<Void, Never>? = nil

    // Auth API for fetching profile
    private let authAPI = AuthAPI()
    private let adminAPI = AdminAPI()
    private let dstAPI = DstAPI()
    private var cachedBranchID: String? = nil
    private var borrowerUserIDsByProfileID: [String: String] = [:]
    private var borrowerProfileCache: [String: Auth_V1_BorrowerProfile] = [:]
    private var borrowerCibilScoreCache: [String: Int] = [:]
    private var userCache: [String: Auth_V1_UserPublicProfile] = [:]
    private var employeeNamesByUserID: [String: String] = [:]
    private var dstNamesByUserID: [String: String] = [:]
    private var localRemarksByApplicationID: [String: [InternalRemark]] = [:]
    private var loanProductCache: [String: LoanProduct] = [:]
    private let borrowerUserDefaultsKey = "ApplicationsViewModel.borrowerUserIDsByProfileID"
    private var realtimeRefreshTask: Task<Void, Never>? = nil
    private var inFlightDetailRefreshes: Set<String> = []
    private let realtimeRefreshIntervalNanoseconds: UInt64 = 15_000_000_000
    private var loadedOfficerDirectoryBranchName: String = ""
    private var loadedOfficerDirectoryBranchID: String = ""

    // Manager send back sheet
    @Published var showSendBackSheet = false
    @Published var pendingSendBackApp: LoanApplication? = nil
    @Published var sendBackReason = ""
    @Published var sendBackCustomRemark = ""
    
    @Published var minAmount: Double = 0
    @Published var maxAmount: Double = 100_000_000 // 10 Cr
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    
    // MARK: - Dashboard Context State
    enum DashboardFilterType {
        case none, pending, nearSLA, risky, overdue
    }

    @Published var activeDashboardFilter: DashboardFilterType = .none
    
    // MARK: - Sorting State
    @Published var currentSort: SortOption = .newestFirst

        enum SortOption {
            case newestFirst
            case longestInQueue // FIFO
            case highestAmount
        }
    // MARK: - Filtered Applications

    var filteredApplications: [LoanApplication] {
        var result = applications

        switch activeDashboardFilter {
        case .pending:
            result = result.filter { dashboardPendingStatuses.contains($0.status) }
        case .risky:
            result = result.filter { $0.riskLevel == .high }
        case .nearSLA:
            result = result.filter { $0.slaStatus == .urgent }
        case .overdue:
            result = result.filter { $0.slaStatus == .overdue }
        case .none:
            if let statuses = filterStatuses {
                result = result.filter { statuses.contains($0.status) }
            }
            if let risk = filterRisk {
                result = result.filter { $0.riskLevel == risk }
            }
            if let sla = filterSLA {
                result = result.filter { $0.slaStatus == sla }
            }
            if filterHighValue {
                result = result.filter { $0.loan.amount >= highValueLoanThreshold }
            }
            if let loanType = filterLoanType {
                result = result.filter { $0.loan.type == loanType }
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.borrower.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                $0.borrower.employer.localizedCaseInsensitiveContains(searchText)
            }
        }

        result = result.filter { $0.loan.amount >= minAmount && $0.loan.amount <= maxAmount }
        result = result.filter { $0.createdAt >= startDate }

        return result.sorted(by: compareApplications)
    }

    let dashboardPendingStatuses: Set<ApplicationStatus> = [
        .pending,
        .officerReview,
        .officerApproved,
        .managerReview,
        .underReview
    ]
    let loanOfficerNewStatuses: [ApplicationStatus] = [.pending]
    let loanOfficerMyReviewStatuses: [ApplicationStatus] = [.officerReview, .underReview]
    let loanOfficerSentToManagerStatuses: [ApplicationStatus] = [.officerApproved, .managerReview]
    let managerPendingReviewStatuses: [ApplicationStatus] = [.officerApproved, .managerReview, .underReview]
    let approvedStatuses: [ApplicationStatus] = [.approved, .managerApproved]
    let rejectedStatuses: [ApplicationStatus] = [.rejected, .officerRejected, .managerRejected]
    let highValueLoanThreshold: Double = 5_000_000

    func resetFiltersToAll() {
        filterStatuses = nil
        filterRisk = nil
        filterSLA = nil
        filterHighValue = false
        filterLoanType = nil
        minAmount = 0
        maxAmount = 100_000_000
        startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }
    
    func updateSort(_ option: SortOption) {
        withAnimation {
            currentSort = option
        }
    }

    func syncSelectedApplicationWithFilters(preferredApplicationID: String? = nil) {
        let filtered = filteredApplications

        if filtered.isEmpty {
            selectedApplication = nil
            return
        }

        if let preferredApplicationID,
           let preferred = filtered.first(where: { $0.id == preferredApplicationID }) {
            selectedApplication = preferred
            return
        }

        if let selectedID = selectedApplication?.id,
           let selected = filtered.first(where: { $0.id == selectedID }) {
            selectedApplication = selected
            return
        }

        selectedApplication = filtered.first
    }

    func canManagerReassign(application: LoanApplication) -> Bool {
        !application.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func canManagerTakeDecision(on application: LoanApplication) -> Bool {
        !approvedStatuses.contains(application.status) && !rejectedStatuses.contains(application.status)
    }

    func managerFilterChip(for dashboardFilter: DashboardFilterType) -> String {
        switch dashboardFilter {
        case .pending:
            return "Pending Review"
        case .risky:
            return "High Risk"
        default:
            return "All"
        }
    }

    func loanOfficerFilterChip(for dashboardFilter: DashboardFilterType) -> String {
        switch dashboardFilter {
        case .pending:
            return "New"
        default:
            return "All"
        }
    }

    private func compareApplications(_ lhs: LoanApplication, _ rhs: LoanApplication) -> Bool {
        let lhsPriority = priorityRank(for: lhs)
        let rhsPriority = priorityRank(for: rhs)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        switch currentSort {
        case .newestFirst:
            return lhs.createdAt > rhs.createdAt
        case .longestInQueue:
            return lhs.createdAt < rhs.createdAt
        case .highestAmount:
            return lhs.loan.amount > rhs.loan.amount
        }
    }

    private func priorityRank(for application: LoanApplication) -> Int {
        switch activeDashboardFilter {
        case .overdue:
            if application.slaStatus == .overdue { return 0 }
        case .nearSLA:
            if application.slaStatus == .urgent { return 0 }
        case .pending, .risky, .none:
            break
        }

        if application.slaStatus == .overdue { return 1 }
        return 2
    }

    // MARK: - Load Data

    func loadAvailableLoanProducts() async {
        guard #available(iOS 18.0, *) else { return }
        do {
            let products = try await LoanAPI().listLoanProducts(limit: 100, offset: 0, includeDeleted: false, authorized: true)
            let mapped = products.map { LoanProduct(proto: $0) }
            self.availableLoanProducts = mapped
            self.loanProductCache = Dictionary(uniqueKeysWithValues: mapped.map { ($0.id, $0) })
        } catch {
            print("Failed to load loan products: \(error)")
        }
    }

    func loadData(autoSelectFirst: Bool = true, force: Bool = false) {
        // Deduplicate: skip if already loaded within last 2 seconds (unless forced)
        let now = Date()
        if !force && hasLoaded && now.timeIntervalSince(lastLoadTime) < 2.0 {
            return
        }
        // If there's already an active load task running, don't stack another one
        if !force && activeLoadTask != nil {
            return
        }
        isLoading = true
        activeLoadTask = Task {
            do {
                try await refreshApplications(
                    selectApplicationID: selectedApplication?.id,
                    autoSelectFirst: autoSelectFirst
                )
                hasLoaded = true
                lastLoadTime = Date()
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load applications from server"
                showActionAlert = true
            }
            isLoading = false
            activeLoadTask = nil
        }
    }

    /// Called right after successful authentication to eagerly load data.
    /// This ensures data is ready before the user even sees the main UI.
    func preloadAfterLogin() {
        guard !hasLoaded else { return }
        loadData(autoSelectFirst: true, force: true)
    }

    /// Force a fresh reload, ignoring dedup. Use for pull-to-refresh or explicit user actions.
    func forceReload(autoSelectFirst: Bool = true) {
        loadData(autoSelectFirst: autoSelectFirst, force: true)
    }

    /// Reset state on logout so fresh data is loaded on next login.
    func resetOnLogout() {
        hasLoaded = false
        lastLoadTime = .distantPast
        activeLoadTask?.cancel()
        activeLoadTask = nil
        stopRealtimeSync()
        applications = []
        selectedApplication = nil
    }

    func selectApplication(_ app: LoanApplication) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedApplication = app
        }
        if !app.branchID.isEmpty || !app.branch.isEmpty {
            loadBranchOfficers(branchID: app.branchID, branchName: app.branch)
        }
        Task { await refreshSelectedApplicationDetail(applicationID: app.id) }
    }

    func selectApplication(applicationID: String) {
        guard let match = applications.first(where: { $0.id == applicationID }) else { return }
        selectApplication(match)
    }

    func refreshDocumentPreview(documentID: String, applicationID: String) async -> LoanDocument? {
        let selectedDoc = selectedApplication?.documents.first(where: { $0.id == documentID })
        let hasInMemoryUpload = !((uploadedFiles[documentID] ?? []).isEmpty)

        if var selectedDoc {
            if selectedDoc.fileURL == nil {
                selectedDoc = applyCachedPreview(to: selectedDoc)
            }
            if selectedDoc.fileURL != nil || hasInMemoryUpload {
                return selectedDoc
            }
        }

        await refreshSelectedApplicationDetail(applicationID: applicationID)

        if var refreshedSelectedDoc = selectedApplication?.documents.first(where: { $0.id == documentID }) {
            refreshedSelectedDoc = applyCachedPreview(to: refreshedSelectedDoc)
            if refreshedSelectedDoc.fileURL == nil {
                refreshedSelectedDoc = await resolveDocumentPreview(refreshedSelectedDoc)
            }
            return refreshedSelectedDoc
        }

        return applications
            .first(where: { $0.id == applicationID })?
            .documents
            .first(where: { $0.id == documentID })
            .map(applyCachedPreview)
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
                successMessage: "Application rejected",
                internalRemarkAuthor: "Loan Officer"
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

        Task {
            await sendBackToOfficer(applicationID: app.id, remark: finalRemark)
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
            await rejectFromManager(applicationID: app.id, remark: remarks)
        }
        showRejectionRemarksSheet = false
        pendingRejectionApp = nil
        rejectionRemarksText = ""
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
    ) async throws -> String {
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

        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }

        // Use cached branchID if available to avoid redundant profile fetch
        let branchID: String
        if let cached = cachedBranchID, !cached.isEmpty {
            branchID = cached
        } else {
            let profile = try await authAPI.getMyProfile()
            guard case .officerProfile(let officerProfile) = profile.profile else {
                throw APIError.permissionDenied("Only Officer profile can create applications from this screen.")
            }
            branchID = officerProfile.branch.branchID.trimmingCharacters(in: .whitespacesAndNewlines)
            cachedBranchID = branchID
        }
        guard !branchID.isEmpty else {
            throw APIError.failedPrecondition("Officer is not assigned to a branch.")
        }

        let created = try await LoanAPI().createLoanApplication(
            primaryBorrowerProfileID: cleanBorrowerProfileID,
            loanProductID: selectedLoanProduct.id,
            branchID: branchID,
            requestedAmount: String(Int(requestedAmount)),
            tenureMonths: Int32(tenureMonths),
            status: .submitted
        )

        // Refresh list in background — don't block the dismiss
        Task {
            try? await refreshApplications(selectApplicationID: created.id, autoSelectFirst: true)
        }
        return created.id
    }

    // MARK: - Document Verification

    func verifyDocument(document: LoanDocument, applicationId: String, approved: Bool, rejectionReason: String? = nil) {
        Task {
            await verifyDocumentInternal(document: document, applicationId: applicationId, approved: approved, rejectionReason: rejectionReason)
        }
    }

    private func verifyDocumentInternal(document: LoanDocument, applicationId: String, approved: Bool, rejectionReason: String?) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Document verification requires iOS 18 or later"
            showActionAlert = true
            return
        }
        guard let backendDocumentID = document.backendDocumentID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !backendDocumentID.isEmpty else {
            actionMessage = "Upload the document to the backend first before verifying it."
            showActionAlert = true
            return
        }
        do {
            // Proto uses .pass / .fail — NOT .verified / .rejected
            let status: Loan_V1_DocumentVerificationStatus = approved ? .pass : .fail
            _ = try await LoanAPI().updateApplicationDocumentVerification(
                documentID: backendDocumentID,
                verificationStatus: status,
                rejectionReason: rejectionReason
            )
            // Update locally immediately — no need to re-fetch from backend
            if let appIdx = applications.firstIndex(where: { $0.id == applicationId }) {
                if let docIdx = applications[appIdx].documents.firstIndex(where: { $0.id == document.id }) {
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
                applyAssignedOfficerLocally(applicationID: applicationId, officerUserID: officerUserId)
                await refreshSelectedApplicationDetail(applicationID: applicationId)
                actionMessage = "Loan Officer assigned successfully"
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to assign officer"
                showActionAlert = true
            }
        }
    }

    func loadBranchOfficers(branchID: String = "", branchName: String = "") {
        Task {
            isLoadingBranchOfficers = true
            defer { isLoadingBranchOfficers = false }
            do {
                let normalizedBranchID = branchID.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if loadedOfficerDirectoryBranchID == normalizedBranchID,
                   loadedOfficerDirectoryBranchName == normalizedBranch,
                   !availableBranchOfficers.isEmpty {
                    return
                }
                let employees: [Admin_V1_EmployeeAccount]
                if !normalizedBranchID.isEmpty {
                    employees = try await adminAPI.listBranchOfficers(branchID: normalizedBranchID, limit: 500, offset: 0)
                } else {
                    employees = try await adminAPI.listEmployeeAccounts(limit: 500, offset: 0)
                }
                cacheEmployeeNames(from: employees)
                let officers = employees.compactMap { account -> OfficerDirectoryItem? in
                    guard account.role == .officer, account.isActive else { return nil }
                    let candidateBranch = account.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return OfficerDirectoryItem(
                        id: account.userID,
                        name: resolvedName.isEmpty ? account.email : resolvedName,
                        branchName: candidateBranch
                    )
                }
                let branchMatches = officers.filter { officer in
                    guard !normalizedBranch.isEmpty else { return true }
                    let candidate = officer.branchName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !candidate.isEmpty else { return false }
                    return candidate == normalizedBranch
                        || candidate.contains(normalizedBranch)
                        || normalizedBranch.contains(candidate)
                }
                let mapped = branchMatches.isEmpty ? officers : branchMatches
                availableBranchOfficers = mapped.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
                loadedOfficerDirectoryBranchID = normalizedBranchID
                loadedOfficerDirectoryBranchName = normalizedBranch
                officerDirectoryUnavailableMessage = mapped.isEmpty
                    ? "Officer directory is currently unavailable for this branch. Reassignment options will appear once officer data is available."
                    : nil
            } catch {
                availableBranchOfficers = []
                officerDirectoryUnavailableMessage = "Officer directory is currently unavailable. Manager can view Reassign, but reassignment options are temporarily unavailable."
            }
        }
    }

    func officerDisplayName(for userID: String) -> String {
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Unassigned" }
        if let cached = employeeNamesByUserID[userID] {
            return cached
        }
        if let match = availableBranchOfficers.first(where: { $0.id == userID }) {
            return match.name
        }
        // Return truncated userID as placeholder instead of generic label
        let shortID = String(userID.prefix(8))
        return "Officer (\(shortID)…)"
    }

    // MARK: - Update Loan Terms

    func updateLoanTerms(applicationId: String, tenureMonths: Int, offeredInterestRate: Double) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            do {
                _ = try await LoanAPI().updateLoanApplicationTerms(
                    applicationID: applicationId,
                    tenureMonths: Int32(tenureMonths),
                    offeredInterestRate: String(format: "%.2f", offeredInterestRate)
                )
                applyLoanTermsLocally(
                    applicationID: applicationId,
                    tenureMonths: tenureMonths,
                    offeredInterestRate: offeredInterestRate
                )
                await refreshSelectedApplicationDetail(applicationID: applicationId)
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
        xmlParseResult = XMLParserService.shared.simulateXMLUpload()
        showXMLUploadResult = true
    }

    /// Parse XML silently (no result sheet) — used by CreateApplicationSheet for autofill
    func parseXMLFile(_ data: Data) {
        xmlParseResult = XMLParserService.shared.parseXMLData(data)
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
        appendInternalRemark(
            applicationID: applicationId,
            author: author,
            text: text,
            timestamp: Date()
        )
        actionMessage = "Internal remark added"
        showActionAlert = true
    }

    // MARK: - Document Upload

    func addOtherDocument(to app: LoanApplication, label: String) {
        let newDoc = LoanDocument(
            id: "DOC-OTHER-\(UUID().uuidString.prefix(6))",
            backendDocumentID: nil,
            requiredDocID: nil,
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

    func uploadApplicationDocument(
        file: UploadedDocFile,
        document: LoanDocument,
        applicationID: String,
        borrowerProfileID: String
    ) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            guard let data = file.data,
                  let contentType = file.contentType,
                  let requiredDocID = {
                      let candidate = (document.requiredDocID ?? document.id).trimmingCharacters(in: .whitespacesAndNewlines)
                      return candidate.isEmpty ? nil : candidate
                  }() else {
                actionMessage = "This document slot is not linked to a backend requirement yet."
                showActionAlert = true
                return
            }
            do {
                let uploadedMedia = try await MediaAPI().uploadFile(data: data, fileName: file.name, contentType: contentType)
                cacheMediaPreview(uploadedMedia)
                _ = try await LoanAPI().addApplicationDocument(
                    applicationID: applicationID,
                    borrowerProfileID: borrowerProfileID,
                    requiredDocID: requiredDocID,
                    mediaFileID: uploadedMedia.mediaID
                )
                await MainActor.run {
                    recordUploadedFile(file, forDocumentId: document.id)
                }
                await refreshSelectedApplicationDetail(applicationID: applicationID)
                actionMessage = "Document uploaded successfully."
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to upload document."
                showActionAlert = true
            }
        }
    }

    func uploadSanctionLetter(application: LoanApplication, data: Data, fileName: String, contentType: String) {
        Task {
            guard #available(iOS 18.0, *) else {
                actionMessage = "Sanction letter upload requires iOS 18 or later."
                showActionAlert = true
                return
            }

            let borrowerProfileID = application.primaryBorrowerProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !borrowerProfileID.isEmpty else {
                actionMessage = "Borrower profile details are unavailable for this application. Please refresh and try again."
                showActionAlert = true
                return
            }

            do {
                let uploadedMedia = try await MediaAPI().uploadFile(data: data, fileName: fileName, contentType: contentType)
                cacheMediaPreview(uploadedMedia)
                _ = try await LoanAPI().addApplicationDocument(
                    applicationID: application.id,
                    borrowerProfileID: borrowerProfileID,
                    requiredDocID: "sanction_letter_manual",
                    mediaFileID: uploadedMedia.mediaID
                )
                try await refreshApplications(selectApplicationID: application.id, autoSelectFirst: true)
                actionMessage = "Sanction letter uploaded successfully."
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to upload sanction letter."
                showActionAlert = true
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

    // MARK: - Borrower Profile Resolution

    @MainActor
    func resolveBorrowerProfileID(email: String, phone: String) async throws -> String? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard #available(iOS 18.0, *) else { return nil }

        func exactMatch(from items: [Auth_V1_BorrowerSignupStatusItem]) -> Auth_V1_BorrowerSignupStatusItem? {
            let direct = items.first { item in
                let emailMatch = !cleanEmail.isEmpty && item.email.lowercased() == cleanEmail
                let phoneMatch = !cleanPhone.isEmpty && item.phone == cleanPhone
                return emailMatch || phoneMatch
            }
            if let direct { return direct }
            return items.first
        }

        if !cleanEmail.isEmpty {
            let emailResults: Auth_V1_SearchBorrowerSignupStatusResponse = try await authAPI.searchBorrowerSignupStatus(query: cleanEmail, limit: 20, offset: 0)
            if let found = exactMatch(from: emailResults.items), !found.borrowerProfileId.isEmpty {
                if !found.userId.isEmpty {
                    cacheBorrowerUserID(found.userId, forProfileID: found.borrowerProfileId)
                }
                return found.borrowerProfileId
            }
        }

        if !cleanPhone.isEmpty {
            let phoneResults: Auth_V1_SearchBorrowerSignupStatusResponse = try await authAPI.searchBorrowerSignupStatus(query: cleanPhone, limit: 20, offset: 0)
            if let found = exactMatch(from: phoneResults.items), !found.borrowerProfileId.isEmpty {
                if !found.userId.isEmpty {
                    cacheBorrowerUserID(found.userId, forProfileID: found.borrowerProfileId)
                }
                return found.borrowerProfileId
            }
        }

        return nil
    }

    // MARK: - Private Backend Helpers

    /// Manager approval: updates status to MANAGER_APPROVED and leaves final disbursal pending borrower acceptance.
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
            applyStatusUpdateLocally(applicationID: app.id, status: .managerApproved, escalationReason: nil)
            await refreshSelectedApplicationDetail(applicationID: app.id)
            actionMessage = "Application approved. Borrower must accept the sanction letter before disbursal."
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
        successMessage: String,
        internalRemarkAuthor: String? = nil
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
            applyStatusUpdateLocally(
                applicationID: applicationID,
                status: ApplicationStatus(proto: status),
                escalationReason: escalationReason,
                internalRemarkAuthor: internalRemarkAuthor
            )
            await refreshSelectedApplicationDetail(applicationID: applicationID)
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
                // If officerReview succeeded, silently chain officerApproved immediately
                // so both backend steps happen in a single user action.
                if nextStatus == .officerReview {
                    try? await LoanAPI().updateLoanApplicationStatus(
                        applicationID: applicationID,
                        status: .officerApproved,
                        escalationReason: nil
                    )
                }
                let finalStatus: Loan_V1_LoanApplicationStatus = nextStatus == .officerReview ? .officerApproved : nextStatus
                applyStatusUpdateLocally(
                    applicationID: applicationID,
                    status: ApplicationStatus(proto: finalStatus),
                    escalationReason: nil
                )
                await refreshSelectedApplicationDetail(applicationID: applicationID)
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

    private func sendBackToOfficer(applicationID: String, remark: String) async {
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusAttempts: [(Loan_V1_LoanApplicationStatus, String)] = [
            (.officerReview, "Application sent back to Loan Officer"),
            (.underReview, "Application sent back to Loan Officer")
        ]

        await updateApplicationStatusWithFallback(
            applicationID: applicationID,
            attempts: statusAttempts,
            escalationReason: trimmedRemark.isEmpty ? nil : trimmedRemark,
            internalRemarkAuthor: "Manager"
        )
    }

    private func rejectFromManager(applicationID: String, remark: String) async {
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusAttempts: [(Loan_V1_LoanApplicationStatus, String)] = [
            (.managerRejected, "Application rejected"),
            (.rejected, "Application rejected")
        ]

        await updateApplicationStatusWithFallback(
            applicationID: applicationID,
            attempts: statusAttempts,
            escalationReason: trimmedRemark.isEmpty ? nil : trimmedRemark,
            internalRemarkAuthor: "Manager"
        )
    }

    private func updateApplicationStatusWithFallback(
        applicationID: String,
        attempts: [(Loan_V1_LoanApplicationStatus, String)],
        escalationReason: String?,
        internalRemarkAuthor: String
    ) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Status update requires iOS 18 or later"
            showActionAlert = true
            return
        }

        var lastError: Error?
        for (nextStatus, successMessage) in attempts {
            do {
                _ = try await LoanAPI().updateLoanApplicationStatus(
                    applicationID: applicationID,
                    status: nextStatus,
                    escalationReason: escalationReason
                )
                applyStatusUpdateLocally(
                    applicationID: applicationID,
                    status: ApplicationStatus(proto: nextStatus),
                    escalationReason: escalationReason,
                    internalRemarkAuthor: internalRemarkAuthor
                )
                await refreshSelectedApplicationDetail(applicationID: applicationID)
                actionMessage = successMessage
                showActionAlert = true
                return
            } catch {
                lastError = error
            }
        }

        actionMessage = (lastError as? LocalizedError)?.errorDescription ?? "Unable to update application status"
        showActionAlert = true
    }

    private func refreshApplications(selectApplicationID: String?, autoSelectFirst: Bool) async throws {
        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }

        // Fire list + context prefetch concurrently where possible
        let loanAPI = LoanAPI()
        async let listLoad = loanAPI.listLoanApplications(limit: 100, offset: 0, branchID: defaultBranchID)
        let list = try await listLoad

        Task { await self.loadEmployeeNamesIfNeeded() }
        if availableLoanProducts.isEmpty {
            Task { await self.loadAvailableLoanProducts() }
        }

        let previousApplicationsByID = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        let mapped = list.map { application in
            let base = LoanApplication.from(
                proto: application,
                enrichment: cachedEnrichment(for: application)
            )
            if let existing = previousApplicationsByID[base.id] {
                return mergeListApplication(base: base, existing: existing)
            }
            return base
        }
        withAnimation {
            applications = mapped
            let preferredID = selectApplicationID ?? selectedApplication?.id
            if autoSelectFirst {
                selectedApplication = mapped.first(where: { $0.id == preferredID }) ?? mapped.first
            } else if let preferredID,
                      let selected = mapped.first(where: { $0.id == preferredID }) {
                selectedApplication = selected
            }
        }
        syncSelectedApplicationWithFilters(preferredApplicationID: selectApplicationID)
        if let selectedID = selectedApplication?.id {
            Task { await self.refreshSelectedApplicationDetail(applicationID: selectedID) }
        }
    }

    private func refreshSelectedApplicationDetail(applicationID: String) async {
        guard #available(iOS 18.0, *) else { return }
        guard !inFlightDetailRefreshes.contains(applicationID) else { return }
        inFlightDetailRefreshes.insert(applicationID)
        defer { inFlightDetailRefreshes.remove(applicationID) }
        do {
            let detail = try await LoanAPI().getLoanApplication(applicationID: applicationID)
            let borrowerUserID = resolveBorrowerUserID(for: detail.application)

            // Fire ALL enrichment fetches in parallel
            async let productTask = loanProduct(forID: detail.application.loanProductID)
            async let existingEMITask = existingEMI(
                for: detail.application.primaryBorrowerProfileID,
                excluding: detail.application.id
            )

            // Borrower-related fetches (all parallel)
            let hasBorrower = !borrowerUserID.isEmpty
            async let borrowerProfileTask: Auth_V1_BorrowerProfile? = hasBorrower ? (try? fetchBorrowerProfile(userID: borrowerUserID)) : nil
            async let borrowerUserTask: Auth_V1_UserPublicProfile? = hasBorrower ? (try? fetchUser(userID: borrowerUserID)) : nil
            async let borrowerCibilTask: Int? = hasBorrower ? (try? fetchBorrowerCibilScore(userID: borrowerUserID)) : nil

            // DST name fetch (parallel with everything above)
            let isDst = detail.application.createdByRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "dst"
            let dstUserID = detail.application.createdByUserID.trimmingCharacters(in: .whitespacesAndNewlines)
            let needsDstFetch = isDst && !dstUserID.isEmpty && dstNamesByUserID[dstUserID] == nil
            async let dstNameTask: String? = needsDstFetch ? (try? fetchDstName(userID: dstUserID)) : nil

            // Officer name fetch
            let officerUserID = detail.application.assignedOfficerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
            let needsOfficerFetch = !officerUserID.isEmpty && employeeNamesByUserID[officerUserID] == nil
            async let officerNameTask: String? = needsOfficerFetch ? (try? fetchOfficerName(userID: officerUserID)) : nil

            // Await all results simultaneously
            let product = try? await productTask
            let resolvedExistingEMI = await existingEMITask
            let borrowerProfile = await borrowerProfileTask
            let borrowerUser = await borrowerUserTask
            let borrowerCibil = await borrowerCibilTask
            _ = await dstNameTask  // Side-effect: caches the name
            _ = await officerNameTask // Caches the officer name

            // Build enrichment from all parallel results
            var enrichment = cachedEnrichment(for: detail.application, bureauScores: detail.bureauScores)
            enrichment.requiredDocuments = product?.requiredDocuments ?? []
            enrichment.existingEMI = resolvedExistingEMI
            enrichment.borrowerProfile = borrowerProfile
            enrichment.borrowerUser = borrowerUser
            enrichment.borrowerCibilScore = borrowerCibil

            enrichment.createdByName = displayName(
                for: detail.application.createdByUserID,
                role: detail.application.createdByRole,
                borrowerProfile: enrichment.borrowerProfile
            )
            enrichment.assignedToName = displayName(for: detail.application.assignedOfficerUserID)
            enrichment.borrowerHistoryThisBank = borrowerHistory(for: detail.application)
            enrichment.isDisbursed = detail.application.status == .disbursed
            if enrichment.isDisbursed, let repayment = try? await repaymentData(for: detail.application) {
                enrichment.repaymentSummary = repayment.summary
                enrichment.repaymentHistory = repayment.history
            }

            var enriched = LoanApplication.from(
                proto: detail.application,
                documents: detail.documents,
                enrichment: enrichment
            )
            enriched.documents = enriched.documents.map(applyCachedPreview)
            if let index = applications.firstIndex(where: { $0.id == applicationID }) {
                applications[index] = enriched
            }
            if selectedApplication?.id == applicationID {
                selectedApplication = enriched
            }
            syncSelectedApplicationWithFilters(preferredApplicationID: applicationID)
        } catch {
            // Keep list data if detail fetch fails.
        }
    }

    func startRealtimeSync() {
        guard realtimeRefreshTask == nil || realtimeRefreshTask?.isCancelled == true else { return }
        realtimeRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self.realtimeRefreshIntervalNanoseconds)
                if Task.isCancelled { break }
                do {
                    try await self.refreshApplications(
                        selectApplicationID: self.selectedApplication?.id,
                        autoSelectFirst: self.selectedApplication == nil
                    )
                } catch {
                    continue
                }
            }
        }
    }

    func stopRealtimeSync() {
        realtimeRefreshTask?.cancel()
        realtimeRefreshTask = nil
    }

    private func resolveDocumentPreview(_ document: LoanDocument) async -> LoanDocument {
        guard let mediaFileID = document.mediaFileID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !mediaFileID.isEmpty else {
            return document
        }
        if mediaPreviewCache[mediaFileID] != nil {
            return applyCachedPreview(to: document)
        }

        do {
            var offset: Int32 = 0
            let pageSize: Int32 = 100
            let maxPages = 20

            for _ in 0..<maxPages {
                let page = try await MediaAPI().listMedia(limit: pageSize, offset: offset)
                if page.isEmpty { break }

                if let media = page.first(where: { $0.mediaID == mediaFileID }) {
                    mediaPreviewCache[mediaFileID] = CachedMediaPreview(
                        mediaFileID: media.mediaID,
                        fileName: media.fileName,
                        contentType: media.contentType,
                        fileURL: media.fileUrl.isEmpty ? nil : URL(string: media.fileUrl)
                    )
                    return applyCachedPreview(to: document)
                }

                if page.count < Int(pageSize) {
                    break
                }
                offset += pageSize
            }
        } catch {
            return document
        }

        return document
    }

    func cacheMediaPreview(_ uploadedMedia: UploadedMedia) {
        mediaPreviewCache[uploadedMedia.mediaID] = CachedMediaPreview(
            mediaFileID: uploadedMedia.mediaID,
            fileName: uploadedMedia.fileName,
            contentType: uploadedMedia.contentType,
            fileURL: uploadedMedia.fileURL
        )
    }

    private func applyCachedPreview(to document: LoanDocument) -> LoanDocument {
        guard let mediaFileID = document.mediaFileID,
              let cachedPreview = mediaPreviewCache[mediaFileID] else {
            return document
        }

        var updated = document
        if updated.fileName?.isEmpty != false {
            updated.fileName = cachedPreview.fileName
        }
        if updated.contentType?.isEmpty != false {
            updated.contentType = cachedPreview.contentType
        }
        if updated.fileURL == nil {
            updated.fileURL = cachedPreview.fileURL
        }
        return updated
    }

    private func cachedEnrichment(
        for application: Loan_V1_LoanApplication,
        bureauScores: [Loan_V1_BureauScore] = []
    ) -> LoanApplicationEnrichment {
        let borrowerUserID = resolveBorrowerUserID(for: application)
        return LoanApplicationEnrichment(
            borrowerProfile: borrowerProfileCache[borrowerUserID],
            borrowerUser: userCache[borrowerUserID],
            bureauScores: bureauScores,
            borrowerCibilScore: borrowerCibilScoreCache[borrowerUserID],
            internalRemarks: backendInternalRemarks(for: application),
            assignedToName: displayName(for: application.assignedOfficerUserID),
            createdByName: displayName(
                for: application.createdByUserID,
                role: application.createdByRole,
                borrowerProfile: borrowerProfileCache[borrowerUserID]
            ),
            isDisbursed: application.status == .disbursed
        )
    }

    private func resolveBorrowerUserID(for application: Loan_V1_LoanApplication) -> String {
        if (application.createdByRole == "borrower" || application.createdByChannel == .self_), !application.createdByUserID.isEmpty {
            cacheBorrowerUserID(application.createdByUserID, forProfileID: application.primaryBorrowerProfileID)
            return application.createdByUserID
        }
        return borrowerUserID(forProfileID: application.primaryBorrowerProfileID)
    }

    private func fetchBorrowerProfile(userID: String) async throws -> Auth_V1_BorrowerProfile {
        if let cached = borrowerProfileCache[userID] {
            return cached
        }
        let profile = try await authAPI.getBorrowerProfile(userID: userID)
        borrowerProfileCache[userID] = profile
        return profile
    }

    private func fetchUser(userID: String) async throws -> Auth_V1_UserPublicProfile {
        if let cached = userCache[userID] {
            return cached
        }
        let response = try await authAPI.getUser(userID: userID)
        let user = response.user
        userCache[userID] = user
        return user
    }

    private func fetchBorrowerCibilScore(userID: String) async throws -> Int {
        if let cached = borrowerCibilScoreCache[userID] {
            return cached
        }
        let snapshot = try await authAPI.getBorrowerProfileSnapshot(userID: userID)
        let score = Int(snapshot.cibilScore)
        borrowerCibilScoreCache[userID] = score
        return score
    }

    private func backendInternalRemarks(for application: Loan_V1_LoanApplication) -> [InternalRemark] {
        var remarks: [InternalRemark] = []
        let trimmed = application.escalationReason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            remarks.append(
                InternalRemark(
                    id: "\(application.id)-backend-escalation",
                    author: application.createdByRole.isEmpty ? "System" : application.createdByRole.capitalized,
                    text: trimmed,
                    timestamp: Date.fromBackendTimestamp(application.updatedAt) ?? Date.fromBackendTimestamp(application.createdAt) ?? Date()
                )
            )
        }
        remarks.append(contentsOf: localRemarksByApplicationID[application.id] ?? [])
        return deduplicatedRemarks(remarks)
    }

    private func borrowerHistory(for application: Loan_V1_LoanApplication) -> [BorrowerLoanHistoryEntry] {
        applications
            .filter {
                $0.primaryBorrowerProfileID == application.primaryBorrowerProfileID &&
                $0.id != application.id
            }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { item in
                BorrowerLoanHistoryEntry(
                    id: item.id,
                    loanType: item.loan.type.displayName,
                    institution: item.branch.isEmpty ? "Our Bank" : item.branch,
                    amount: item.loan.amount.currencyFormatted,
                    status: item.status.displayName,
                    statusStyle: historyStatusStyle(for: item.status)
                )
            }
    }

    private func historyStatusStyle(for status: ApplicationStatus) -> HistoryStatusStyle {
        switch status {
        case .approved, .managerApproved:
            return .success
        case .rejected, .managerRejected, .officerRejected:
            return .critical
        case .pending:
            return .warning
        case .officerReview, .officerApproved, .managerReview, .underReview:
            return .primary
        }
    }

    private func borrowerUserID(forProfileID profileID: String) -> String {
        if let cached = borrowerUserIDsByProfileID[profileID] {
            return cached
        }
        let persisted = (UserDefaults.standard.dictionary(forKey: borrowerUserDefaultsKey) as? [String: String]) ?? [:]
        if let resolved = persisted[profileID] {
            borrowerUserIDsByProfileID[profileID] = resolved
            return resolved
        }
        return ""
    }

    private func cacheBorrowerUserID(_ userID: String, forProfileID profileID: String) {
        guard !userID.isEmpty, !profileID.isEmpty else { return }
        borrowerUserIDsByProfileID[profileID] = userID
        var persisted = (UserDefaults.standard.dictionary(forKey: borrowerUserDefaultsKey) as? [String: String]) ?? [:]
        persisted[profileID] = userID
        UserDefaults.standard.set(persisted, forKey: borrowerUserDefaultsKey)
    }

    private func repaymentData(for application: Loan_V1_LoanApplication) async throws -> (summary: RepaymentSummary, history: [RepaymentHistoryItem]) {
        let loan = try await LoanAPI().getLoan(applicationID: application.id)
        let schedule = (try? await LoanAPI().listEmiSchedule(loanID: loan.id)) ?? []
        let payments = (try? await LoanAPI().listPayments(loanID: loan.id)) ?? []

        let totalPaid = payments
            .filter { $0.status == .success }
            .compactMap { Double($0.amount) }
            .reduce(0, +)
        let nextDue = schedule
            .filter { $0.status == .upcoming || $0.status == .overdue }
            .sorted { $0.installmentNumber < $1.installmentNumber }
            .first

        let history = schedule
            .sorted { $0.installmentNumber < $1.installmentNumber }
            .map { item in
                let dueDate = Date.fromBackendTimestamp(item.dueDate) ?? Date.fromBackendDateOnly(item.dueDate)
                return RepaymentHistoryItem(
                    id: item.id,
                    period: "Installment \(item.installmentNumber)",
                    dueDateText: dueDate?.shortFormatted ?? "N/A",
                    amount: (Double(item.emiAmount) ?? -1).currencyFormatted,
                    status: item.emiStatusText,
                    isPaid: item.status == .paid
                )
            }

        return (
            summary: RepaymentSummary(
                outstanding: (Double(loan.outstandingBalance) ?? -1).currencyFormatted,
                paidToDate: totalPaid > 0 ? totalPaid.currencyFormatted : "N/A",
                nextEmi: nextDue.flatMap { Date.fromBackendTimestamp($0.dueDate) ?? Date.fromBackendDateOnly($0.dueDate) }?.shortFormatted ?? "N/A"
            ),
            history: history
        )
    }

    private func loanProduct(forID productID: String) async throws -> LoanProduct? {
        let trimmed = productID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let cached = loanProductCache[trimmed] {
            return cached
        }
        if let cached = availableLoanProducts.first(where: { $0.id == trimmed }) {
            loanProductCache[trimmed] = cached
            return cached
        }
        let product = try await LoanAPI().getLoanProduct(productID: trimmed)
        let mapped = LoanProduct(proto: product)
        loanProductCache[trimmed] = mapped
        if !availableLoanProducts.contains(where: { $0.id == mapped.id }) {
            availableLoanProducts.append(mapped)
        }
        return mapped
    }

    private func loadEmployeeNamesIfNeeded() async {
        guard employeeNamesByUserID.isEmpty else { return }
        do {
            let employees = try await adminAPI.listEmployeeAccounts(limit: 500, offset: 0)
            cacheEmployeeNames(from: employees)
        } catch {
            // Fall back to raw IDs if employee directory is unavailable.
        }
    }

    private func cacheEmployeeNames(from employees: [Admin_V1_EmployeeAccount]) {
        for employee in employees {
            let trimmedID = employee.userID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { continue }
            let trimmedName = employee.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = employee.email.trimmingCharacters(in: .whitespacesAndNewlines)
            employeeNamesByUserID[trimmedID] = trimmedName.isEmpty ? fallback : trimmedName
        }
    }

    private func fetchOfficerName(userID: String) async throws -> String {
        if let cached = employeeNamesByUserID[userID] {
            return cached
        }
        do {
            let response = try await authAPI.getUser(userID: userID)
            let resolved = [response.user.email, response.user.phone]
                .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? "Officer"
            employeeNamesByUserID[userID] = resolved
            return resolved
        } catch {
            return "Officer"
        }
    }

    private func displayName(
        for userID: String,
        role: String = "",
        borrowerProfile: Auth_V1_BorrowerProfile? = nil
    ) -> String {
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedRole == "borrower" {
            let borrowerName = [borrowerProfile?.firstName ?? "", borrowerProfile?.lastName ?? ""]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return borrowerName.isEmpty ? "Borrower" : borrowerName
        }
        if trimmedRole == "dst" {
            return dstNamesByUserID[userID] ?? "DST"
        }
        if trimmedRole == "manager" {
            return employeeNamesByUserID[userID] ?? "Manager"
        }
        if trimmedRole == "officer" {
            return employeeNamesByUserID[userID] ?? "Loan Officer"
        }
        if trimmedRole == "admin" {
            return employeeNamesByUserID[userID] ?? "Admin"
        }
        return officerDisplayName(for: userID)
    }

    // prefetchListContext is now inlined into refreshApplications for parallel execution.
    // Keeping this stub for backward compatibility if called elsewhere.
    private func prefetchListContext(for _: [Loan_V1_LoanApplication]) async {
        await loadEmployeeNamesIfNeeded()

        if availableLoanProducts.isEmpty {
            await loadAvailableLoanProducts()
        }
    }

    private func fetchDstName(userID: String) async throws -> String {
        if let cached = dstNamesByUserID[userID] {
            return cached
        }
        let account = try await dstAPI.getDstAccount(userID: userID)
        let resolved = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = account.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = resolved.isEmpty ? (fallback.isEmpty ? "DST" : fallback) : resolved
        dstNamesByUserID[userID] = finalName
        return finalName
    }

    private func mergeListApplication(base: LoanApplication, existing: LoanApplication) -> LoanApplication {
        var merged = base

        if merged.assignedToName.isEmpty {
            merged.assignedToName = existing.assignedToName
        }
        if merged.createdByName.isEmpty {
            merged.createdByName = existing.createdByName
        }
        if merged.borrower.name == "N/A", existing.borrower.name != "N/A" {
            merged.borrower = existing.borrower
        }
        if merged.financials.monthlyIncome < 0, existing.financials.monthlyIncome >= 0 {
            merged.financials = existing.financials
        }
        if !existing.documents.isEmpty {
            merged.documents = existing.documents
        }
        if !existing.internalRemarks.isEmpty {
            merged.internalRemarks = deduplicatedRemarks(merged.internalRemarks + existing.internalRemarks)
        }
        if !existing.borrowerHistoryThisBank.isEmpty {
            merged.borrowerHistoryThisBank = existing.borrowerHistoryThisBank
        }
        if !existing.borrowerHistoryOtherLenders.isEmpty {
            merged.borrowerHistoryOtherLenders = existing.borrowerHistoryOtherLenders
        }
        if existing.repaymentSummary != .na {
            merged.repaymentSummary = existing.repaymentSummary
        }
        if !existing.repaymentHistory.isEmpty {
            merged.repaymentHistory = existing.repaymentHistory
        }
        if existing.sanctionLetter != nil {
            merged.sanctionLetter = existing.sanctionLetter
        }
        merged.isDisbursed = base.isDisbursed || existing.isDisbursed
        return merged
    }

    private func existingEMI(for borrowerProfileID: String, excluding applicationID: String) async -> Double {
        let relatedApplications = applications.filter {
            $0.primaryBorrowerProfileID == borrowerProfileID && $0.id != applicationID
        }

        var totalEMI = 0.0
        for relatedApplication in relatedApplications {
            do {
                let loan = try await LoanAPI().getLoan(applicationID: relatedApplication.id)
                guard loan.status == .active, let emiAmount = Double(loan.emiAmount) else { continue }
                totalEMI += emiAmount
            } catch {
                continue
            }
        }
        return totalEMI > 0 ? totalEMI : -1
    }

    private func applyStatusUpdateLocally(
        applicationID: String,
        status: ApplicationStatus,
        escalationReason: String?,
        internalRemarkAuthor: String? = nil
    ) {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }) else { return }
        applications[index].status = status
        if let escalationReason {
            let trimmedReason = escalationReason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedReason.isEmpty {
                applications[index].rejectionRemarks = trimmedReason
                appendInternalRemark(
                    applicationID: applicationID,
                    author: internalRemarkAuthor ?? status.remarkAuthorLabel,
                    text: trimmedReason,
                    timestamp: Date()
                )
            }
        }
        if selectedApplication?.id == applicationID {
            selectedApplication = applications[index]
        }
        syncSelectedApplicationWithFilters(preferredApplicationID: applicationID)
    }

    private func applyAssignedOfficerLocally(applicationID: String, officerUserID: String) {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }) else { return }
        applications[index].assignedTo = officerUserID
        applications[index].assignedToName = officerDisplayName(for: officerUserID)
        appendInternalRemark(
            applicationID: applicationID,
            author: "Manager",
            text: "Reassigned application to \(applications[index].assignedToName).",
            timestamp: Date()
        )
        if selectedApplication?.id == applicationID {
            selectedApplication = applications[index]
        }
        syncSelectedApplicationWithFilters(preferredApplicationID: applicationID)
    }

    private func applyLoanTermsLocally(
        applicationID: String,
        tenureMonths: Int,
        offeredInterestRate: Double
    ) {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }) else { return }
        let currentAmount = applications[index].loan.amount
        let updatedEMI = estimatedEMI(
            principal: currentAmount,
            annualRatePercent: offeredInterestRate,
            tenureMonths: tenureMonths
        )
        applications[index].loan.tenure = tenureMonths
        applications[index].loan.interestRate = offeredInterestRate
        applications[index].loan.emi = updatedEMI
        applications[index].financials.proposedEMI = updatedEMI
        if applications[index].financials.monthlyIncome > 0 {
            let totalDebt = max(applications[index].financials.existingEMI, 0) + max(updatedEMI, 0)
            applications[index].financials.dtiRatio = totalDebt / applications[index].financials.monthlyIncome
            applications[index].financials.foir = (totalDebt / applications[index].financials.monthlyIncome) * 100
        }
        if selectedApplication?.id == applicationID {
            selectedApplication = applications[index]
        }
        syncSelectedApplicationWithFilters(preferredApplicationID: applicationID)
    }

    private func appendInternalRemark(
        applicationID: String,
        author: String,
        text: String,
        timestamp: Date
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let normalizedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let remark = InternalRemark(
            id: "\(applicationID)-remark-\(UUID().uuidString)",
            author: normalizedAuthor.isEmpty ? "Staff" : normalizedAuthor,
            text: trimmedText,
            timestamp: timestamp
        )

        localRemarksByApplicationID[applicationID, default: []].append(remark)
        localRemarksByApplicationID[applicationID] = deduplicatedRemarks(localRemarksByApplicationID[applicationID] ?? [])

        if let index = applications.firstIndex(where: { $0.id == applicationID }) {
            applications[index].internalRemarks = deduplicatedRemarks(applications[index].internalRemarks + [remark])
            if selectedApplication?.id == applicationID {
                selectedApplication = applications[index]
            }
        }
    }

    private func deduplicatedRemarks(_ remarks: [InternalRemark]) -> [InternalRemark] {
        var seen = Set<String>()
        return remarks
            .sorted(by: { $0.timestamp > $1.timestamp })
            .filter { remark in
                let key = "\(remark.author)|\(remark.text)|\(remark.timestamp.timeIntervalSince1970)"
                return seen.insert(key).inserted
            }
    }
}

private extension ApplicationStatus {
    var remarkAuthorLabel: String {
        switch self {
        case .managerRejected, .managerApproved, .managerReview:
            return "Manager"
        case .officerRejected, .officerApproved, .officerReview:
            return "Loan Officer"
        case .pending, .underReview, .approved, .rejected:
            return "System"
        }
    }
}

// MARK: - Uploaded Doc File

struct UploadedDocFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    var data: Data? = nil
    let contentType: String?
    let isImage: Bool
    let uploadedAt: Date
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

@available(iOS 18.0, *)
private extension Loan_V1_EmiScheduleItem {
    var emiStatusText: String {
        switch status {
        case .paid:
            return "Paid"
        case .overdue:
            return "Overdue"
        case .upcoming:
            return "Upcoming"
        case .unspecified, .UNRECOGNIZED:
            return "N/A"
        }
    }
}

struct NPADataPoint: Identifiable {
    let id = UUID()
    let category: String
    let npaCount: Int
    let totalCount: Int
    let npaRatio: Double
}

extension ApplicationsViewModel {
    var npaLoans: [LoanApplication] {
        guard let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) else {
            return []
        }
        return applications.filter { $0.slaDeadline < ninetyDaysAgo }
    }

    var npaByLoanType: [NPADataPoint] {
        npaDataPoints(grouping: applications, by: { $0.loan.type.displayName })
    }

    var npaByTenure: [NPADataPoint] {
        npaDataPoints(grouping: applications, by: tenureBucket(for:))
    }

    private func tenureBucket(for application: LoanApplication) -> String {
        switch application.loan.tenure {
        case ..<13:
            return "0-1 yr"
        case ..<37:
            return "1-3 yr"
        default:
            return "3+ yr"
        }
    }

    private func npaDataPoints(
        grouping source: [LoanApplication],
        by category: (LoanApplication) -> String
    ) -> [NPADataPoint] {
        let npaIDs = Set(npaLoans.map(\.id))

        return Dictionary(grouping: source, by: category)
            .map { key, apps in
                let npaCount = apps.filter { npaIDs.contains($0.id) }.count
                let totalCount = apps.count
                return NPADataPoint(
                    category: key,
                    npaCount: npaCount,
                    totalCount: totalCount,
                    npaRatio: totalCount > 0 ? (Double(npaCount) / Double(totalCount)) * 100 : 0
                )
            }
            .sorted {
                if $0.npaCount != $1.npaCount {
                    return $0.npaCount > $1.npaCount
                }
                return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
            }
    }
}
