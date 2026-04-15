// Controllers/SignupFlowController.swift
// LoanOS — Borrower App
// Manages the Signup navigation stack and route definitions.

import SwiftUI

enum SignupRoute: Hashable {
    case phoneOTP
    case emailOTP
    case passkey
    case totp
    case home
}

struct SignupRoot: View {
    @State private var path = NavigationPath()
    let onBackToLogin: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            SignupStep1View(path: $path, onBackToLogin: onBackToLogin)
                .navigationDestination(for: SignupRoute.self) { route in
                    switch route {
                    case .phoneOTP:
                        SignupOTPView(path: $path)

                    case .emailOTP:
                        SignupEmailOTPView(path: $path)

                    case .passkey:
                        SignupPasskeyView(path: $path)

                    case .totp:
                        SignupTOTPView(path: $path)

                    case .home:
                        HomeView()
                    }
                }
        }
        .tint(DS.primary)
    }
}
