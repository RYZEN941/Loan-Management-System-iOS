// Core/Services/NotificationStore.swift
// LoanOS Borrower App
// Local, UserDefaults-backed in-app notification system.

import SwiftUI
import Combine

// MARK: - AppNotificationType

enum AppNotificationType: String, Codable, CaseIterable {
    case statusChange
    case kycReminder
    case kycCompleted
    case emiDue
    case paymentSuccess

    var icon: String {
        switch self {
        case .statusChange:   return "doc.badge.clock.fill"
        case .kycReminder:    return "person.badge.shield.checkmark.fill"
        case .kycCompleted:   return "checkmark.seal.fill"
        case .emiDue:         return "calendar.badge.exclamationmark"
        case .paymentSuccess: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .statusChange:   return .orange
        case .kycReminder:    return DS.danger
        case .kycCompleted:   return DS.success
        case .emiDue:         return DS.danger
        case .paymentSuccess: return DS.success
        }
    }

    var displayName: String {
        switch self {
        case .statusChange:   return "Status Update"
        case .kycReminder:    return "KYC Reminder"
        case .kycCompleted:   return "KYC Verified"
        case .emiDue:         return "EMI Due"
        case .paymentSuccess: return "Payment"
        }
    }
}

// MARK: - AppNotification

struct AppNotification: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    var type: AppNotificationType
    var isRead: Bool
    var createdAt: Date
    var applicationId: String?
    var loanId: String?
    var emiScheduleId: String?
    var emiAmount: Double?
    var transactionID: String?
    var applicationStatus: String?
}

// MARK: - NotificationStore

@MainActor
final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published private(set) var notifications: [AppNotification] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    var hasUnread: Bool { unreadCount > 0 }

    private let storageKey = "loanOS_appNotifications"
    private let dedupStorageKey = "loanOS_notifDedup"
    private let maxNotifications = 100

    private init() { load() }

    // MARK: - Public API

    func add(_ notification: AppNotification) {
        if notifications.contains(where: { $0.id == notification.id }) { return }
        notifications.append(notification)
        notifications.sort { $0.createdAt > $1.createdAt }
        trimIfNeeded()
        save()
    }

    func markRead(id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[idx].isRead = true
        save()
    }

    func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        save()
    }

    func delete(id: UUID) {
        notifications.removeAll(where: { $0.id == id })
        save()
    }

    func clearAll() {
        notifications.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: dedupStorageKey)
    }

    // MARK: - Deduplication Helpers

    func hasAlreadyFired(dedupKey: String) -> Bool {
        let dict = UserDefaults.standard.dictionary(forKey: dedupStorageKey) as? [String: Bool] ?? [:]
        return dict[dedupKey] == true
    }

    func markFired(dedupKey: String) {
        var dict = UserDefaults.standard.dictionary(forKey: dedupStorageKey) as? [String: Bool] ?? [:]
        dict[dedupKey] = true
        UserDefaults.standard.set(dict, forKey: dedupStorageKey)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(notifications)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Silently fail — notifications are non-critical UI state
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([AppNotification].self, from: data)
            notifications = decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            notifications = []
        }
    }

    private func trimIfNeeded() {
        guard notifications.count > maxNotifications else { return }
        // Remove oldest read notifications first; if all unread, remove oldest
        if let oldestReadIdx = notifications.lastIndex(where: { $0.isRead }) {
            notifications.remove(at: oldestReadIdx)
        } else {
            notifications.removeLast()
        }
    }
}
