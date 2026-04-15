// Views/Login/LoginPasskeyView.swift
// LoanOS — Borrower App
// Login Step 3 — Passkey / Face ID / Touch ID authentication screen.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Passkey View
// ═══════════════════════════════════════════════════════════════

struct LoginPasskeyView: View {
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
                ScreenBadge(badge: "BIOMETRIC AUTH", color: DS.primary,
                            title: "Authenticate\nwith Face ID",
                            subtitle: "Verify your identity using Face ID or Touch ID.")

                BiometricCard(isAuthenticating: isAuthenticating,
                              success: success, failed: failed, errorMessage: message)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "bolt.fill",        text: "Instant login — no typing required")
                    FeatureRow(icon: "lock.fill",        text: "Private key never leaves your device")
                    FeatureRow(icon: "checkmark.shield", text: "Phishing-resistant by design")
                }

                if success {
                    PrimaryBtn(title: "Continue to TOTP", icon: "shield.checkered", style: .success) {
                        path.append(LoginRoute.totp)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 12) {
                        PrimaryBtn(title: failed ? "Try Again" : "Continue",
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
        .offset(y: appeared ? 0 : 22).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.45)) { appeared = true } }
    }

    // MARK: - Actions

    private func trigger() {
        failed = false; message = ""; isAuthenticating = true
        BiometricAuth.authenticate(reason: "Verify your identity to log in to LoanOS") { ok, err in
            isAuthenticating = false
            if ok { withAnimation { success = true } }
            else  { withAnimation { failed = true }; message = BiometricAuth.humanMessage(for: err) }
        }
    }
}
