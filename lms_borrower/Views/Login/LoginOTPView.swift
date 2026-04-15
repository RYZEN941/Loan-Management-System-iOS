// Views/Login/LoginOTPView.swift
// LoanOS — Borrower App
// Login Step 2 — OTP verification screen.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login OTP View
// ═══════════════════════════════════════════════════════════════

struct LoginOTPView: View {
    @Binding var path: NavigationPath

    @State private var otp      = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            StepBar(current: 2, total: 4).padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 26) {
                ScreenBadge(badge: "OTP VERIFICATION", color: DS.warning,
                            title: "Verify your\nidentity",
                            subtitle: "Enter the 6-digit OTP sent to your registered contact.")

                // OTP status banner
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(DS.warning).font(.system(size: 18))
                        .frame(width: 42, height: 42)
                        .background(DS.warning.opacity(0.12)).cornerRadius(12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OTP Sent")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                        Text("Check your inbox or SMS")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                    }
                    Spacer()
                    Text("Expires in 5:00")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(DS.warning)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(DS.warning.opacity(0.1)).cornerRadius(10)
                }
                .padding(14).background(DS.card).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.border, lineWidth: 1))

                OTPBoxRow(otp: $otp, focused: $focused)

                PrimaryBtn(title: "Verify OTP", icon: "checkmark.circle.fill",
                           disabled: otp.count < 6) {
                    path.append(LoginRoute.passkey)
                }

                Button {} label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13))
                        Text("Resend OTP")
                    }.font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(DS.primary)
                }.frame(maxWidth: .infinity)

                InfoCard(icon: "info.circle.fill", color: DS.primary,
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
