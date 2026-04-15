// Views/Signup/SignupOTPView.swift
// LoanOS — Borrower App
// Signup Step 2 — OTP verification screen to confirm contact details.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup OTP View
// ═══════════════════════════════════════════════════════════════

struct SignupOTPView: View {
    @Binding var path: NavigationPath

    @State private var otp      = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            StepBar(current: 2, total: 4).padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 26) {
                ScreenBadge(badge: "VERIFICATION", color: DS.primary,
                            title: "Enter the\nverification code",
                            subtitle: "We've sent a 6-digit OTP to your email or mobile number.")

                OTPBoxRow(otp: $otp, focused: $focused)

                PrimaryBtn(title: "Verify OTP", icon: "checkmark.circle.fill",
                           disabled: otp.count < 6) {
                    path.append(SignupRoute.passkey)
                }

                Button {} label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13))
                        Text("Resend OTP")
                    }.font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(DS.primary)
                }.frame(maxWidth: .infinity)

                InfoCard(icon: "info.circle.fill", color: DS.primary,
                         text: "For testing, enter any 6 digits to continue.")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationTitle("")
        .offset(y: appeared ? 0 : 24).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}
