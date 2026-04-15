// Views/Signup/SignupPasskeyView.swift
// LoanOS — Borrower App
// Signup Step 4 — Minimal passkey setup screen.

import SwiftUI

struct SignupPasskeyView: View {
    @Binding var path: NavigationPath

    @State private var isAuthenticating = false
    @State private var success = false
    @State private var failed = false
    @State private var message = ""
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            StepBar(current: 4, total: 5)
                .padding(.bottom, 22)

            VStack(spacing: 28) {
                Spacer(minLength: 8)

                heroSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.35), value: appeared)

                contentCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
        .onAppear {
            appeared = true
        }
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

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.75))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 112, height: 112)

                Image(systemName: success ? "checkmark.circle.fill" : "faceid")
                    .font(.system(size: success ? 42 : 44, weight: .medium))
                    .foregroundColor(success ? DS.success : DS.primary)
            }
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)

            VStack(spacing: 8) {
                Text(success ? "Passkey is ready" : "Set up Passkey")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text(success
                     ? "You can now sign in securely with Face ID or Touch ID."
                     : "Use Face ID or Touch ID for faster, more secure sign in.")
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: 18) {
            if failed && !message.isEmpty {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 8) {
                Text(success ? "Authentication completed." : "Authentication is required once to enable passkey on this device.")
                    .font(.system(size: 15))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                if !success {
                    Text("You’ll see the native Face ID or Touch ID prompt next.")
                        .font(.system(size: 13))
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            PrimaryBtn(
                title: success ? "Continue" : "Set Up Passkey",
                isLoading: isAuthenticating
            ) {
                success ? continueFlow() : trigger()
            }
        }
        .padding(22)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private func continueFlow() {
        path.append(SignupRoute.totp)
    }

    private func trigger() {
        failed = false
        message = ""
        isAuthenticating = true

        BiometricAuth.authenticate(reason: "Set up Face ID for your LoanOS account") { ok, err in
            isAuthenticating = false

            if ok {
                withAnimation(.spring(response: 0.35)) {
                    success = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    failed = true
                }
                message = BiometricAuth.humanMessage(for: err)
            }
        }
    }
}
