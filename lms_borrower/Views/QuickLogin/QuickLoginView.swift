// Views/QuickLogin/QuickLoginView.swift
// LoanOS — Borrower App
// Quick-login screen for returning users.
// Offers Face ID fast-auth OR TOTP code entry.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Quick Login View
// ═══════════════════════════════════════════════════════════════

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var goHome: Bool

    @State private var isAuthBio  = false
    @State private var bioError   = ""
    @State private var showTOTP   = false
    @State private var totpCode   = ""
    @State private var appeared   = false
    @FocusState private var totpFocused: Bool

    var body: some View {
        ZStack {
            DS.surface.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Brand header
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(DS.gradient).frame(width: 72, height: 72)
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.white).font(.system(size: 34))
                    }
                    Text("LoanOS")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Text("Welcome back\(session.userName.isEmpty ? "" : ", \(session.userName)")")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)

                if !showTOTP {
                    faceIDPanel
                } else {
                    totpPanel
                }

                Spacer()

                Button { session.logout() } label: {
                    Text("Sign in with a different account")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(DS.textSecondary).underline()
                }
                .opacity(appeared ? 1 : 0).padding(.bottom, 36)
            }
        }
        .navigationBarHidden(true)
        .onAppear { withAnimation(.spring(response: 0.5)) { appeared = true } }
    }

    // MARK: - Subviews

    private var faceIDPanel: some View {
        VStack(spacing: 16) {
            Button { triggerFaceID() } label: {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isAuthBio ? DS.primary.opacity(0.15) : DS.primaryLight)
                            .frame(width: 80, height: 80)
                        if isAuthBio {
                            Circle()
                                .stroke(DS.primary.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 94, height: 94)
                                .scaleEffect(isAuthBio ? 1.1 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                           value: isAuthBio)
                        }
                        Image(systemName: "faceid")
                            .font(.system(size: 38)).foregroundColor(DS.primary)
                    }
                    Text(isAuthBio ? "Verifying…" : "Use Face ID")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.primary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
                .background(DS.card).cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.border, lineWidth: 1))
            }
            .buttonStyle(TapScale()).disabled(isAuthBio)

            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(DS.danger).multilineTextAlignment(.center)
            }

            HStack {
                Rectangle().fill(DS.border).frame(height: 1)
                Text("or")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(DS.textSecondary).padding(.horizontal, 10)
                Rectangle().fill(DS.border).frame(height: 1)
            }

            SecondaryBtn(title: "Use TOTP Code Instead", icon: "shield.fill") {
                withAnimation { showTOTP = true }
            }
        }
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
        .transition(.opacity.animation(.easeInOut))
    }

    private var totpPanel: some View {
        VStack(spacing: 20) {
            ScreenBadge(badge: "TOTP VERIFICATION", color: DS.purple,
                        title: "Enter your\nTOTP code",
                        subtitle: "Open your authenticator app and enter the 6-digit code.")

            OTPBoxRow(otp: $totpCode, focused: $totpFocused)

            PrimaryBtn(title: "Open App", icon: "checkmark.shield.fill",
                       style: .success, disabled: totpCode.count < 6) {
                goHome = true
            }

            Button {
                withAnimation { showTOTP = false; totpCode = "" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left").font(.system(size: 13))
                    Text("Back to Face ID")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(DS.primary)
            }.frame(maxWidth: .infinity)

            InfoCard(icon: "info.circle.fill", color: DS.purple,
                     text: "Demo mode: enter any 6 digits.")
        }
        .padding(.horizontal, 24)
        .transition(.opacity.animation(.easeInOut))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { totpFocused = true }
        }
    }

    // MARK: - Actions

    private func triggerFaceID() {
        bioError = ""; isAuthBio = true
        BiometricAuth.authenticate(reason: "Verify your identity to open LoanOS") { ok, err in
            isAuthBio = false
            if ok { goHome = true }
            else  { bioError = BiometricAuth.humanMessage(for: err) }
        }
    }
}
