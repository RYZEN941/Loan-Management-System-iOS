import Foundation
import Combine

enum ActionItemType: String {
    case sla
    case fraud
    case policy
    case stuck
}

enum ActionItemStatus: String {
    case open
    case resolved
    case escalated
}

enum ActionItemSeverity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct ActionItemModel: Identifiable, Equatable {
    let id: String
    let type: ActionItemType
    let title: String
    let description: String
    let severity: ActionItemSeverity
    let timestamp: Date
    var assignedOfficer: String
    var status: ActionItemStatus
}

class ActionRequiredMockService: ObservableObject {
    static let shared = ActionRequiredMockService()
    
    @Published var items: [ActionItemModel] = []
    
    init() {
        generateMockData()
    }
    
    private func generateMockData() {
        let now = Date()
        items = [
            // SLA
            ActionItemModel(id: "SLA-001", type: .sla, title: "SLA Breach", description: "Application under review for 4 days", severity: .high, timestamp: now.addingTimeInterval(-86400 * 4), assignedOfficer: "Deepak Mehta", status: .open),
            ActionItemModel(id: "SLA-002", type: .sla, title: "SLA Breach", description: "Application pending manager approval", severity: .medium, timestamp: now.addingTimeInterval(-86400 * 2), assignedOfficer: "Sunita Patel", status: .open),
            
            // Fraud
            ActionItemModel(id: "FRAUD-001", type: .fraud, title: "Risk Signal", description: "Identity verification failed", severity: .high, timestamp: now.addingTimeInterval(-3600 * 2), assignedOfficer: "System", status: .open),
            ActionItemModel(id: "FRAUD-002", type: .fraud, title: "Risk Signal", description: "Bank statement mismatch", severity: .high, timestamp: now.addingTimeInterval(-3600 * 5), assignedOfficer: "System", status: .open),
            
            // Policy
            ActionItemModel(id: "POL-001", type: .policy, title: "LTV Exceeded", description: "LTV is 85% (Max allowed: 80%)", severity: .medium, timestamp: now.addingTimeInterval(-3600 * 12), assignedOfficer: "Kavitha Nair", status: .open),
            ActionItemModel(id: "POL-002", type: .policy, title: "FOIR High", description: "FOIR is 55% (Limit: 50%)", severity: .medium, timestamp: now.addingTimeInterval(-3600 * 24), assignedOfficer: "Ravi Kumar", status: .open),
            
            // Stuck
            ActionItemModel(id: "STUCK-001", type: .stuck, title: "Stuck in Verification", description: "Waiting for physical verification", severity: .low, timestamp: now.addingTimeInterval(-86400 * 5), assignedOfficer: "Unassigned", status: .open),
            ActionItemModel(id: "STUCK-002", type: .stuck, title: "Stuck in Verification", description: "Borrower unresponsive", severity: .low, timestamp: now.addingTimeInterval(-86400 * 6), assignedOfficer: "Unassigned", status: .open)
        ]
    }
    
    func resolveItem(id: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = .resolved
        }
    }
    
    func escalateItem(id: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = .escalated
        }
    }
    
    func assignItem(id: String, to officer: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].assignedOfficer = officer
        }
    }
    
    var openItems: [ActionItemModel] {
        items.filter { $0.status == .open }
    }
    
    var slaBreaches: [ActionItemModel] { openItems.filter { $0.type == .sla } }
    var fraudAlerts: [ActionItemModel] { openItems.filter { $0.type == .fraud } }
    var policyViolations: [ActionItemModel] { openItems.filter { $0.type == .policy } }
    var stuckApps: [ActionItemModel] { openItems.filter { $0.type == .stuck } }
}
