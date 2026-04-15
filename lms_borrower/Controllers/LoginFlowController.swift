// Controllers/LoginFlowController.swift
// LoanOS — Borrower App
// Manages the Login navigation stack and route definitions.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Routes
// ═══════════════════════════════════════════════════════════════

enum LoginRoute: Hashable { case otp, passkey, totp, home }

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Flow Controller
// ═══════════════════════════════════════════════════════════════

/// Owns the NavigationStack for the entire login flow.
/// Routes: Email+Password → OTP → Passkey (Face ID) → TOTP → Home
struct LoginRoot: View {
    @State private var path = NavigationPath()
    let onGoToSignup: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LoginStep1View(path: $path, onGoToSignup: onGoToSignup)
                .navigationDestination(for: LoginRoute.self) { route in
                    switch route {
                    case .otp:     LoginOTPView(path: $path)
                    case .passkey: LoginPasskeyView(path: $path)
                    case .totp:    LoginTOTPView(path: $path)
                    case .home:    HomeView()
                    }
                }
        }
        .tint(DS.primary)
    }
}
