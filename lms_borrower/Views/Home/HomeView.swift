// Views/Home/HomeView.swift
// LoanOS — Borrower App
// Home screen shown after successful authentication.
// Displays account status summary and a Logout button.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Home View
// ═══════════════════════════════════════════════════════════════

struct HomeView: View {
    @EnvironmentObject var session: SessionStore
    @State private var appeared = false

    var body: some View {
        ZStack {
            DS.surface.ignoresSafeArea()
            ConfettiView(trigger: appeared)

            VStack(spacing: 32) {
                Spacer()

                // Success checkmark with animated rings
                ZStack {
                    Circle().fill(DS.success.opacity(0.1)).frame(width: 150, height: 150)
                    Circle().fill(DS.success.opacity(0.2)).frame(width: 110, height: 110)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 58)).foregroundColor(DS.success)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.15),
                                   value: appeared)
                }

                VStack(spacing: 10) {
                    Text("Login Completed")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Text("You're securely signed in to LoanOS.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 16)

                // Account summary card
                VStack(spacing: 0) {
                    HomeRow(icon: "person.fill",      label: "Account",   value: "Verified",   last: false)
                    HomeRow(icon: "faceid",           label: "Biometric", value: "Enabled",    last: false)
                    HomeRow(icon: "shield.checkered", label: "2FA",       value: "Configured", last: true)
                }
                .background(DS.card).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.border, lineWidth: 1))
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5).delay(0.3), value: appeared)

                Spacer()

                PrimaryBtn(title: "Logout",
                           icon: "rectangle.portrait.and.arrow.right",
                           style: .danger) {
                    session.logout()
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(0.1)) { appeared = true }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Home Row
// ═══════════════════════════════════════════════════════════════

struct HomeRow: View {
    let icon: String
    let label: String
    let value: String
    let last: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(DS.primary)
                .frame(width: 30, height: 30).background(DS.primaryLight).cornerRadius(8)
            Text(label)
                .font(.system(size: 13, design: .rounded)).foregroundColor(DS.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(DS.textPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !last { Divider().padding(.leading, 58) }
        }
    }
}
