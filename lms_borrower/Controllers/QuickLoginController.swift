// Controllers/QuickLoginController.swift
// LoanOS — Borrower App
// Controller for returning users — wraps QuickLoginView in a
// NavigationStack so HomeView can be pushed onto the stack.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Quick Login Controller
// ═══════════════════════════════════════════════════════════════

/// Entry point for returning (already-authenticated) users.
/// Presents Face ID or TOTP quick-login, then pushes HomeView.
struct QuickLoginGate: View {
    @State private var goHome = false

    var body: some View {
        NavigationStack {
            QuickLoginView(goHome: $goHome)
                .navigationDestination(isPresented: $goHome) { HomeView() }
        }
        .tint(DS.primary)
    }
}
