// Models/SessionStore.swift
// LoanOS — Borrower App
// Manages and persists the user's login session.

import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════
// MARK: - Session Store  (persists login state to UserDefaults)
// ═══════════════════════════════════════════════════════════════

final class SessionStore: ObservableObject {

    @Published var isLoggedIn: Bool
    @Published var userName: String

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "loanOS_loggedIn")
        userName   = UserDefaults.standard.string(forKey: "loanOS_userName") ?? ""
    }

    func completeSession(name: String = "User") {
        userName   = name
        isLoggedIn = true
        UserDefaults.standard.set(true, forKey: "loanOS_loggedIn")
        UserDefaults.standard.set(name,  forKey: "loanOS_userName")
    }

    func logout() {
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: "loanOS_loggedIn")
    }
}
