// Views/Login/LoginPasskeyView.swift
// LoanOS — Borrower App
// Login Step 3 — Minimal Face ID verification screen.

import SwiftUI

struct LoginPasskeyView: View {
    @Binding var path: NavigationPath

    @State private var isAuthenticating = false
    @State private var errorMessage = ""
    @State private var isVerified = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            StepBar(current: 3, total: 4)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                verificationCard
                actionSection

                Spacer()
            }
            .padding(.horizontal, 20)
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

    private var topBar: some View {
        HStack {
            Button {
                if !path.isEmpty {
                    path.removeLast()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verify with Face ID")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Confirm your identity to continue signing in.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var verificationCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.82))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 112, height: 112)

                Image(systemName: isVerified ? "checkmark.circle.fill" : "faceid")
                    .font(.system(size: isVerified ? 40 : 42, weight: .medium))
                    .foregroundColor(isVerified ? DS.success : DS.primary)
            }

            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DS.textPrimary)

                Text(statusSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white.opacity(0.84))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var actionSection: some View {
        PrimaryBtn(
            title: isVerified ? "Continue" : "Use Face ID",
            isLoading: isAuthenticating
        ) {
            if isVerified {
                path.append(LoginRoute.totp)
            } else {
                triggerFaceID()
            }
        }
    }

    private var statusTitle: String {
        if isVerified {
            return "Verified"
        }
        if isAuthenticating {
            return "Checking Face ID"
        }
        return "Ready to verify"
    }

    private var statusSubtitle: String {
        if isVerified {
            return "Your identity has been confirmed."
        }
        if isAuthenticating {
            return "Complete the native Face ID prompt on your device."
        }
        return "Use Face ID or Touch ID to continue securely."
    }

    private func triggerFaceID() {
        errorMessage = ""
        isAuthenticating = true

        BiometricAuth.authenticate(reason: "Verify your identity to log in to LoanOS") { ok, err in
            isAuthenticating = false

            if ok {
                isVerified = true
            } else {
                errorMessage = BiometricAuth.humanMessage(for: err)
            }
        }
    }
}
