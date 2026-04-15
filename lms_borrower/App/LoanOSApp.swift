// App/LoanOSApp.swift
// LoanOS — Borrower App
// App entry point and root view coordinator.
//
// ── App flow ─────────────────────────────────────────────────
// FIRST LAUNCH  ─ Login screen with "Sign Up" link
// SIGNUP        ─ details → OTP → Passkey (FaceID) → TOTP setup → Home
// LOGIN         ─ email+password → OTP → Passkey (FaceID) → TOTP → Home
// RETURNING     ─ Quick-login: Face ID  OR  TOTP code  →  Home
// ─────────────────────────────────────────────────────────────

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - App Entry
// ═══════════════════════════════════════════════════════════════

@main
struct LoanOSApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Root View
// ═══════════════════════════════════════════════════════════════

/// Top-level coordinator: routes between QuickLoginGate (returning user)
/// and OnboardingRoot (new / logged-out user).
struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        if session.isLoggedIn {
            QuickLoginGate()
        } else {
            OnboardingRoot()
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Onboarding Root
// ═══════════════════════════════════════════════════════════════

/// Coordinator for first-time / logged-out users.
/// Switches between LoginRoot and SignupRoot.
struct OnboardingRoot: View {
    @State private var showSignup = true

    var body: some View {
        if showSignup {
            SignupRoot(onBackToLogin: { showSignup = false })
        } else {
            LoginRoot(onGoToSignup: { showSignup = true })
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════════════

#Preview("First launch") {
    let s = SessionStore(); s.logout()
    return RootView().environmentObject(s)
}

#Preview("Returning user") {
    let s = SessionStore(); s.completeSession(name: "Ravi")
    return RootView().environmentObject(s)
}
