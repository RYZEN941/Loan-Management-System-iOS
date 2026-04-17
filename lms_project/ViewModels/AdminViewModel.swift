//
//  AdminViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class AdminViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var selectedUser: User? = nil
    @Published var isLoading = false
    @Published var searchText = ""
    
    // System Control
    @Published var maxLoanAmount: Double = 50_000_000
    @Published var minCIBILScore: Int = 600
    @Published var maxDTIRatio: Double = 0.50
    @Published var requireDocVerification: Bool = true
    @Published var autoAssignEnabled: Bool = true
    
    // Audit Logs
    @Published var auditLogs: [AuditLog] = []
    
    private let dataService = MockDataService.shared
    
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
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.users = self.dataService.fetchUsers()
            self.auditLogs = Self.mockAuditLogs()
            self.isLoading = false
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
    
    func createUser(name: String, email: String, password: String, phone: String, role: UserRole, branch: String, employeeId: String) {
        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let newUser = User(
            id: employeeId,
            name: name,
            email: resolvedEmail.isEmpty ? "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@bank.com" : resolvedEmail,
            role: role,
            branch: branch,
            phone: resolvedPhone.isEmpty ? "+91-0000000000" : resolvedPhone,
            isActive: true,
            joinedAt: Date()
        )
        // Save login credential so the user can sign in from the login screen
        UserStore.shared.addCredential(
            StoredCredential(id: employeeId, email: resolvedEmail, password: password, phone: resolvedPhone, role: role)
        )
        withAnimation {
            users.append(newUser)
        }
    }
    
    func updateUser(userId: String, name: String, role: UserRole, branch: String) {
        if let index = users.firstIndex(where: { $0.id == userId }) {
            withAnimation {
                users[index].name = name
                users[index].role = role
                users[index].branch = branch
                selectedUser = users[index]
            }
        }
    }
    
    func saveConfig(baseRate: Double, maxTenure: Int, slaDays: Int) {
        // Persist to published properties for future API integration
        // In production, this would write to persistent store
        _ = baseRate   // stored in view state
        _ = maxTenure
        _ = slaDays
    }
    
    // MARK: - Mock Audit Logs
    
    static func mockAuditLogs() -> [AuditLog] {
        [
            AuditLog(id: "AUD-001", action: "User Created", user: "Sunita Patel", detail: "Created user Ravi Shankar (LO)",
                     timestamp: Date().addingTimeInterval(-3600)),
            AuditLog(id: "AUD-002", action: "Config Updated", user: "Sunita Patel", detail: "Max DTI ratio changed to 0.50",
                     timestamp: Date().addingTimeInterval(-7200)),
            AuditLog(id: "AUD-003", action: "User Deactivated", user: "Sunita Patel", detail: "Deactivated user Prakash Jha",
                     timestamp: Date().addingTimeInterval(-86400)),
            AuditLog(id: "AUD-004", action: "Application Override", user: "Deepak Mehta", detail: "Overrode risk score for APP-2024-003",
                     timestamp: Date().addingTimeInterval(-172800)),
            AuditLog(id: "AUD-005", action: "Rule Modified", user: "Sunita Patel", detail: "Min CIBIL score changed from 650 to 600",
                     timestamp: Date().addingTimeInterval(-259200))
        ]
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
