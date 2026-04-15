// Views/Login/LoginTOTPView.swift
// LoanOS — Borrower App
// Login Step 4 — TOTP (Time-based One-Time Password) entry screen.
// Completing this step calls session.completeSession() to mark the user
// as fully authenticated and navigates to HomeView.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login TOTP View
// ═══════════════════════════════════════════════════════════════

struct LoginTOTPView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var session: SessionStore

    @State private var code     = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            StepBar(current: 4, total: 4).padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 26) {
                ScreenBadge(badge: "2-FACTOR AUTH", color: DS.purple,
                            title: "Enter your\nauthenticator code",
                            subtitle: "Enter the 6-digit code from your TOTP app.")

                // TOTP input card
                VStack(spacing: 14) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(DS.purple.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(DS.purple).font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LoanOS Authenticator")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(DS.textPrimary)
                            Text("Refreshes every 30 seconds")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "clock.fill").foregroundColor(DS.purple).font(.system(size: 14))
                    }
                    OTPBoxRow(otp: $code, focused: $focused)
                }
                .padding(16).background(DS.card).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.border, lineWidth: 1))

                PrimaryBtn(title: "Verify & Sign In", icon: "checkmark.shield.fill",
                           style: .success, disabled: code.count < 6) {
                    session.completeSession()
                    path.append(LoginRoute.home)
                }

                InfoCard(icon: "info.circle.fill", color: DS.purple,
                         text: "Demo mode: enter any 6 digits.")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationTitle("")
        .offset(y: appeared ? 0 : 22).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}
