//
//  AdminViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

enum RiskSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case actionRequired = "Action Required"
    case collections = "Collections"
    case npa = "NPA"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .actionRequired: return "exclamationmark.triangle.fill"
        case .collections: return "tray.full.fill"
        case .npa: return "exclamationmark.octagon.fill"
        }
    }
}

enum ActionRequiredFilter: String, CaseIterable, Identifiable {
    case slaBreach = "SLA Breaches"
    case fraudAlert = "Fraud Alerts"
    case policyViolation = "Policy Violations"
    case stuckApplication = "Stuck Applications"
    var id: String { rawValue }
}

@MainActor
class AdminViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var selectedUser: User? = nil
    @Published var isLoading = false
    @Published var requestError: String? = nil
    @Published var requestSuccess: String? = nil
    @Published var searchText = ""
    
    // Risk Navigation
    @Published var selectedRiskSection: RiskSection = .overview
    @Published var selectedRiskFilter: ActionRequiredFilter = .slaBreach
    
    // System Control Navigation
    @Published var selectedSystemSection: String = "User Management"
    
    // System Control
    @Published var maxLoanAmount: Double = 50_000_000
    @Published var minCIBILScore: Int = 600
    @Published var maxDTIRatio: Double = 0.50
    @Published var requireDocVerification: Bool = true
    @Published var autoAssignEnabled: Bool = true
    
    // Branches
    @Published var branches: [BranchModel] = [
        BranchModel(name: "Mumbai Central", location: "Mumbai"),
        BranchModel(name: "Delhi NCR", location: "Delhi"),
        BranchModel(name: "Bangalore Tech Park", location: "Bangalore")
    ]
    
    // Audit Logs
    @Published var auditLogs: [AuditLog] = []
    
    // Editable Policies
    @Published var eligibilityRules: [String] = [
        "Min income ₹25,000/month for Personal Loan",
        "Co-applicant required for loans > ₹15L",
        "Max 3 active loans per borrower",
        "Employment tenure ≥ 1 year"
    ]
    
    func deleteEligibilityRule(at index: Int) {
        if eligibilityRules.indices.contains(index) {
            eligibilityRules.remove(at: index)
        }
    }
    
    @Published var documentChecklist: [DocumentChecklistItem] = [
        DocumentChecklistItem(name: "PAN Card", isRequired: true),
        DocumentChecklistItem(name: "Aadhaar Card", isRequired: true),
        DocumentChecklistItem(name: "Bank Statements (6 months)", isRequired: true),
        DocumentChecklistItem(name: "Salary Slips (3 months)", isRequired: true),
        DocumentChecklistItem(name: "Address Proof", isRequired: false)
    ]
    
    // Notifications for Profile
    @Published var notifications: [AdminNotification] = [
        AdminNotification(title: "System Maintenance", message: "Scheduled for Sunday 2 AM", time: "2h ago", icon: "wrench.and.screwdriver", color: .orange),
        AdminNotification(title: "New Policy Update", message: "CIBIL threshold updated to 600", time: "5h ago", icon: "shield", color: .blue),
        AdminNotification(title: "Critical Alert", message: "SLA breach spike detected in Mumbai", time: "1d ago", icon: "exclamationmark.triangle", color: .red)
    ]
    
    // Performance Trends
    @Published var slaBreachTrendData: [Double] = [8, 5, 12, 7, 4, 9, 3]
    @Published var slaBreachTrendLabels: [String] = [] 
    
    private let adminAPI = AdminAPI()
    
    var filteredUsers: [User] {
        if searchText.isEmpty { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.role.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var activeUsersCount: Int {
        users.filter { $0.isActive }.count
    }
    
    var usersByRole: [UserRole: Int] {
        Dictionary(grouping: users.filter { $0.isActive }, by: { $0.role })
            .mapValues { $0.count }
    }
    
    func loadData() {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        Task {
            do {
                let employees = try await adminAPI.listEmployeeAccounts(limit: 200, offset: 0)
                let mappedUsers = employees.compactMap(Self.mapEmployeeAccount)
                withAnimation {
                    users = mappedUsers
                    if let selectedID = selectedUser?.id {
                        selectedUser = mappedUsers.first(where: { $0.id == selectedID })
                    }
                }
                let branchNames = Set(mappedUsers.map(\.branch).filter { !$0.isEmpty })
                if !branchNames.isEmpty {
                    var updatedBranches = branches
                    for name in branchNames {
                        if !updatedBranches.contains(where: { $0.name == name }) {
                            updatedBranches.append(BranchModel(name: name, location: ""))
                        }
                    }
                    branches = updatedBranches.sorted(by: { $0.name < $1.name })
                }
                auditLogs = Self.mockAuditLogs()
                slaBreachTrendLabels = Self.generateDayLabels()
            } catch {
                users = []
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to load users"
                auditLogs = Self.mockAuditLogs()
                slaBreachTrendLabels = Self.generateDayLabels()
            }
            isLoading = false
        }
    }
    
    func toggleUserStatus(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            withAnimation {
                users[index].isActive.toggle()
                selectedUser = users[index]
            }
        }
    }
    
    // Notification Actions
    func markNotificationRead(_ id: UUID) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
        }
    }
    
    func markAllNotificationsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }
    
    func deleteNotification(_ id: UUID) {
        notifications.removeAll(where: { $0.id == id })
    }

    func createUser(name: String, email: String, password: String, phone: String, role: UserRole, branch: String, employeeId: String) {
        requestError = nil
        requestSuccess = nil

        guard role == .loanOfficer || role == .manager || role == .dst else {
            requestError = "Only Manager, Officer and DST accounts can be created from this screen."
            return
        }

        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmail = resolvedEmail.isEmpty ? "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@bank.com" : resolvedEmail
        let finalPhone = resolvedPhone.isEmpty ? "+91-0000000000" : resolvedPhone

        isLoading = true
        Task {
            do {
                var userId = employeeId
                if role == .dst {
                    _ = try await adminAPI.createDstAccount(
                        name: name,
                        email: finalEmail,
                        phoneNumber: finalPhone,
                        password: password
                    )
                } else {
                    let response = try await adminAPI.createEmployeeAccount(
                        name: name,
                        email: finalEmail,
                        phoneNumber: finalPhone,
                        password: password,
                        role: role,
                        branchID: nil
                    )
                    if !response.userID.isEmpty {
                        userId = response.userID
                    }
                }

                let newUser = User(
                    id: userId,
                    name: name,
                    email: finalEmail,
                    role: role,
                    branch: branch,
                    phone: finalPhone,
                    isActive: true,
                    joinedAt: Date()
                )

                withAnimation {
                    users.append(newUser)
                }
                requestSuccess = "User created successfully."
                loadData()
            } catch {
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create user"
            }
            isLoading = false
        }
    }
    
    func updateUser(userId: String, name: String, email: String, phone: String, role: UserRole, branch: String) {
        if let index = users.firstIndex(where: { $0.id == userId }) {
            withAnimation {
                users[index].name = name
                users[index].email = email
                users[index].phone = phone
                users[index].role = role
                users[index].branch = branch
                selectedUser = users[index]
            }
        }
    }
    
    func deleteUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            withAnimation {
                users.remove(at: index)
                if selectedUser?.id == user.id {
                    selectedUser = nil
                }
            }
        }
    }
    
    func saveConfig(baseRate: Double, maxTenure: Int, slaDays: Int) {
        // Persist to published properties
    }
    
    func createBranch(_ branchName: String, location: String = "") {
        let trimmed = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        requestError = nil
        requestSuccess = nil
        isLoading = true

        Task {
            do {
                _ = try await adminAPI.createBankBranch(name: trimmed, region: location, city: location)
                requestSuccess = "Branch created successfully."
            } catch {
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create branch"
            }
            // For UI prototype: Optimistically add the branch regardless of API success
            if !branches.contains(where: { $0.name == trimmed }) {
                withAnimation {
                    branches.append(BranchModel(name: trimmed, location: location))
                    branches.sort(by: { $0.name < $1.name })
                }
            }
            isLoading = false
        }
    }

    func updateBranch(oldName: String, newName: String, location: String) {
        if let index = branches.firstIndex(where: { $0.name == oldName }) {
            withAnimation {
                branches[index].name = newName
                branches[index].location = location
                branches.sort(by: { $0.name < $1.name })
            }
        }
    }
    
    func deleteBranch(name: String) {
        if let index = branches.firstIndex(where: { $0.name == name }) {
            withAnimation {
                branches.remove(at: index)
            }
        }
    }

    func createDstAccount(name: String, email: String, phone: String, password: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        do {
            _ = try await adminAPI.createDstAccount(name: name, email: email, phoneNumber: phone, password: password)
            requestSuccess = "DST account created successfully."
            return true
        } catch {
            // For prototyping: allow success even if API fails, but set error for info
            requestError = (error as? LocalizedError)?.errorDescription ?? "API Error (Mocking success for demo)"
            requestSuccess = "DST account created (Demo Mode)"
            return true 
        }
    }

    func addDstLocally(name: String, email: String, phone: String, branch: String) {
        let newUser = User(
            id: "DST-\(UUID().uuidString.prefix(4))",
            name: name,
            email: email,
            role: .dst,
            branch: branch,
            phone: phone,
            isActive: true,
            joinedAt: Date()
        )
        withAnimation {
            users.insert(newUser, at: 0)
        }
    }

    func updateDstCommission(branchID: String, commission: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        do {
            _ = try await adminAPI.updateBranchDstCommission(branchID: branchID, dstCommission: commission)
            requestSuccess = "DST commission updated successfully."
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to update commission"
            return false
        }
    }
    
    // MARK: - Mock Audit Logs
    
    static func mockAuditLogs() -> [AuditLog] {
        [
            AuditLog(id: "AUD-001", action: "APP-2024-006 approved", user: "Deepak Mehta", detail: "Loan approved after credit verification",
                     timestamp: Date().addingTimeInterval(-720)), // 12m ago
            AuditLog(id: "AUD-002", action: "Policy Update: Min CIBIL Score matched", user: "System Rule", detail: "Automated policy check passed",
                     timestamp: Date().addingTimeInterval(-3600)), // 1h ago
            AuditLog(id: "AUD-003", action: "APP-2024-009 escalated to Admin", user: "Sunita Patel", detail: "Manual review required for high-value asset",
                     timestamp: Date().addingTimeInterval(-7200)), // 2h ago
            AuditLog(id: "AUD-004", action: "Suspicious Application detected", user: "Fraud Engine", detail: "Fraud flag raised for loan APP-2024-021",
                     timestamp: Date().addingTimeInterval(-10800)), // 3h ago
            AuditLog(id: "AUD-005", action: "Config Updated", user: "Sunita Patel", detail: "Max DTI ratio changed to 0.50",
                     timestamp: Date().addingTimeInterval(-86400))
        ]
    }

    private static func mapEmployeeAccount(_ account: Admin_V1_EmployeeAccount) -> User? {
        guard let role = mapStaffRole(account.role) else {
            return nil
        }

        let joinedAt: Date = {
            guard !account.createdAt.isEmpty else { return Date() }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: account.createdAt) ?? Date()
        }()

        let resolvedName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = resolvedName.isEmpty
            ? account.email.components(separatedBy: "@").first?.replacingOccurrences(of: ".", with: " ").capitalized ?? "Unknown"
            : resolvedName

        let branchName = account.branchName.isEmpty ? "Unassigned" : account.branchName

        return User(
            id: account.userID,
            name: name,
            email: account.email,
            role: role,
            branch: branchName,
            phone: account.phoneNumber,
            isActive: account.isActive,
            joinedAt: joinedAt
        )
    }

    private static func mapStaffRole(_ role: Admin_V1_StaffRole) -> UserRole? {
        switch role {
        case .admin:
            return .admin
        case .manager:
            return .manager
        case .officer:
            return .loanOfficer
        default:
            return nil
        }
    }

    private static func generateDayLabels() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // e.g., MON, TUE
        let calendar = Calendar.current
        return (0..<7).reversed().map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            return formatter.string(from: date).uppercased()
        }
    }
}

// MARK: - Audit Log

struct AuditLog: Identifiable, Hashable {
    let id: String
    let action: String
    let user: String
    let detail: String
    let timestamp: Date
}

// MARK: - Branch Model

struct BranchModel: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var location: String
}

// MARK: - Document Checklist Item

struct DocumentChecklistItem: Identifiable {
    let id = UUID()
    var name: String
    var isRequired: Bool
}

// MARK: - Admin Notification

struct AdminNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let time: String
    let icon: String
    let color: Color
    var isRead: Bool = false
}
