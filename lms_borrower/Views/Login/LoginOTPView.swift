// Views/Login/LoginOTPView.swift
// LoanOS — Borrower App
// Login Step 2 — Minimal OTP verification screen.

import SwiftUI

struct LoginOTPView: View {
    @Binding var path: NavigationPath

    @State private var otp = ""
    @FocusState private var focused: Bool

    private var canContinue: Bool {
        otp.count == 6
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            StepBar(current: 2, total: 4)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                otpCard
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focused = true
            }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter verification code")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Enter the 6-digit code sent to your registered contact.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var otpCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("One-time code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.textSecondary)

                Text("Code sent to your email or phone")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
            }

            OTPBoxRow(otp: $otp, focused: $focused)

            Button {
                otp = ""
                focused = true
            } label: {
                Text("Resend code")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.primary)
            }
        }
        .padding(20)
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
            title: "Continue",
            disabled: !canContinue
        ) {
            path.append(LoginRoute.passkey)
        }
    }
}
