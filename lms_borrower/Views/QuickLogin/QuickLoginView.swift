// Views/QuickLogin/QuickLoginView.swift
// LoanOS — Borrower App
// Minimal quick-login screen for returning users.

import SwiftUI

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var goHome: Bool

    @State private var isAuthenticating = false
    @State private var bioError = ""
    @State private var showTOTP = false
    @State private var totpCode = ""
    @FocusState private var totpFocused: Bool

    private var welcomeText: String {
        session.userName.isEmpty ? "Welcome back" : "Welcome back, \(session.userName)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            headerSection

            Spacer(minLength: 28)

            Group {
                if showTOTP {
                    totpSection
                } else {
                    biometricSection
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            footerSection
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
        }
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.gradient)
                    .frame(width: 72, height: 72)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("LoanOS")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text(welcomeText)
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    private var biometricSection: some View {
        VStack(spacing: 16) {
            Button {
                triggerFaceID()
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.82))
                            .background(.ultraThinMaterial, in: Circle())
                            .frame(width: 112, height: 112)

                        Image(systemName: "faceid")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundColor(DS.primary)
                    }

                    VStack(spacing: 6) {
                        Text(isAuthenticating ? "Checking Face ID" : "Use Face ID")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DS.textPrimary)

                        Text("Sign in securely with your saved passkey.")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.82))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(TapScale())
            .disabled(isAuthenticating)

            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                showTOTP = true
                totpCode = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    totpFocused = true
                }
            } label: {
                Text("Use verification code instead")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DS.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.primary.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(TapScale())
        }
    }

    private var totpSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter verification code")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text("Open your authenticator app and enter the 6-digit code.")
                    .font(.system(size: 15))
                    .foregroundColor(DS.textSecondary)
                    .lineSpacing(2)
            }

            VStack(spacing: 18) {
                OTPBoxRow(otp: $totpCode, focused: $totpFocused)

                PrimaryBtn(
                    title: "Continue",
                    disabled: totpCode.count < 6
                ) {
                    goHome = true
                }

                Button {
                    showTOTP = false
                    totpCode = ""
                } label: {
                    Text("Back to Face ID")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.primary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(.white.opacity(0.82))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                totpFocused = true
            }
        }
    }

    private var footerSection: some View {
        Button {
            session.logout()
        } label: {
            Text("Sign in with a different account")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
        }
    }

    private func triggerFaceID() {
        bioError = ""
        isAuthenticating = true

        BiometricAuth.authenticate(reason: "Verify your identity to open LoanOS") { ok, err in
            isAuthenticating = false
            if ok {
                goHome = true
            } else {
                bioError = BiometricAuth.humanMessage(for: err)
            }
        }
    }
}
