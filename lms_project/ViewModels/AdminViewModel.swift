//
//  AdminViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

@MainActor
class AdminViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var selectedUser: User? = nil
    @Published var isLoading = false
    @Published var requestError: String? = nil
    @Published var requestSuccess: String? = nil
    @Published var searchText = ""
    
    // System Control
    @Published var maxLoanAmount: Double = 50_000_000
    @Published var minCIBILScore: Int = 600
    @Published var maxDTIRatio: Double = 0.50
    @Published var requireDocVerification: Bool = true
    @Published var autoAssignEnabled: Bool = true
    
    // Branches
    @Published var branches: [String] = ["Mumbai Central", "Delhi NCR", "Bangalore Tech Park"]
    
    // Audit Logs
    @Published var auditLogs: [AuditLog] = []
    
    private let dataService = MockDataService.shared
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
        requestError = nil
        requestSuccess = nil

        guard role == .loanOfficer || role == .manager else {
            requestError = "Only Manager and Officer accounts can be created from this screen."
            return
        }

        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmail = resolvedEmail.isEmpty ? "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@bank.com" : resolvedEmail
        let finalPhone = resolvedPhone.isEmpty ? "+91-0000000000" : resolvedPhone

        isLoading = true
        Task {
            do {
                let response = try await adminAPI.createEmployeeAccount(
                    name: name,
                    email: finalEmail,
                    phoneNumber: finalPhone,
                    password: password,
                    role: role,
                    branchID: nil
                )

                let newUser = User(
                    id: response.userID.isEmpty ? employeeId : response.userID,
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
            } catch {
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create user"
            }
            isLoading = false
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
        // Persist to published properties
    }
    
    func createBranch(_ branchName: String) {
        let trimmed = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        requestError = nil
        requestSuccess = nil
        isLoading = true

        Task {
            do {
                _ = try await adminAPI.createBankBranch(name: trimmed, region: "Unknown", city: "Unknown")
                if !branches.contains(trimmed) {
                    withAnimation {
                        branches.append(trimmed)
                    }
                }
                requestSuccess = "Branch created successfully."
            } catch {
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create branch"
            }
            isLoading = false
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
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create DST account"
            return false
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
