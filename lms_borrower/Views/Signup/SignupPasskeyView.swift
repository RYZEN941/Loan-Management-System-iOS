// Views/Signup/SignupPasskeyView.swift
// LoanOS — Borrower App
// Signup Step 3 — Passkey setup screen using real Face ID / Touch ID.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup Passkey View
// ═══════════════════════════════════════════════════════════════

struct SignupPasskeyView: View {
    @Binding var path: NavigationPath

    @State private var isAuthenticating = false
    @State private var success  = false
    @State private var failed   = false
    @State private var message  = ""
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            StepBar(current: 3, total: 4).padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 26) {
                ScreenBadge(badge: "BIOMETRICS", color: DS.primary,
                            title: "Secure your\naccount with Passkey",
                            subtitle: "Use Face ID or Touch ID to sign in instantly — no passwords needed.")

                BiometricCard(isAuthenticating: isAuthenticating,
                              success: success, failed: failed, errorMessage: message)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "bolt.fill",  text: "Sign in 3× faster than passwords")
                    FeatureRow(icon: "lock.fill",  text: "Private key never leaves your device")
                    FeatureRow(icon: "iphone",     text: "Works with Face ID, Touch ID, and PIN")
                }

                if success {
                    PrimaryBtn(title: "Continue to 2FA Setup", icon: "shield.checkered") {
                        path.append(SignupRoute.totp)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 12) {
                        PrimaryBtn(title: failed ? "Try Again" : "Enable Passkey",
                                   icon: "faceid", isLoading: isAuthenticating) { trigger() }
                        if failed {
                            SecondaryBtn(title: "Skip Biometrics (Demo)", icon: "arrow.right") {
                                withAnimation { success = true }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.4), value: success)

            Spacer()
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationTitle("")
        .offset(y: appeared ? 0 : 24).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.45)) { appeared = true } }
    }

    // MARK: - Actions

    private func trigger() {
        failed = false; message = ""; isAuthenticating = true
        BiometricAuth.authenticate(reason: "Set up Face ID for your LoanOS account") { ok, err in
            isAuthenticating = false
            if ok { withAnimation { success = true } }
            else  { withAnimation { failed = true }; message = BiometricAuth.humanMessage(for: err) }
        }
    }
}
