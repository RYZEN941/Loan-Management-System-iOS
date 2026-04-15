// Controllers/SignupFlowController.swift
// LoanOS — Borrower App
// Manages the Signup navigation stack and route definitions.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup Routes
// ═══════════════════════════════════════════════════════════════

enum SignupRoute: Hashable { case otp, passkey, totp, home }

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup Flow Controller
// ═══════════════════════════════════════════════════════════════

/// Owns the NavigationStack for the entire signup flow.
/// Routes: Details → OTP → Passkey (Face ID) → TOTP Setup → Home
struct SignupRoot: View {
    @State private var path = NavigationPath()
    let onBackToLogin: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            SignupStep1View(path: $path, onBackToLogin: onBackToLogin)
                .navigationDestination(for: SignupRoute.self) { route in
                    switch route {
                    case .otp:     SignupOTPView(path: $path)
                    case .passkey: SignupPasskeyView(path: $path)
                    case .totp:    SignupTOTPView(path: $path)
                    case .home:    HomeView()
                    }
                }
        }
        .tint(DS.primary)
    }
}
