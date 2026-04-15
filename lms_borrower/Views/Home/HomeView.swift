// Views/Home/HomeView.swift
// LoanOS — Borrower App
// Minimal signed-in screen.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 44)

            headerSection

            Spacer(minLength: 28)

            statusCard
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
        .navigationBarBackButtonHidden(true)
    }

    private var headerSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EAF8F0"))
                    .frame(width: 104, height: 104)

                Circle()
                    .fill(Color(hex: "#CFF1DD"))
                    .frame(width: 76, height: 76)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(Color(hex: "#34C759"))
            }

            VStack(spacing: 8) {
                Text("You’re signed in")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text("Your account is ready to use.")
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 0) {
            HomeStatusRow(
                icon: "person.crop.circle.fill",
                label: "Account",
                value: "Verified",
                valueColor: Color(hex: "#34C759"),
                isLast: false
            )

            HomeStatusRow(
                icon: "faceid",
                label: "Passkey",
                value: "Enabled",
                valueColor: DS.textPrimary,
                isLast: false
            )

            HomeStatusRow(
                icon: "checkmark.shield.fill",
                label: "Authenticator",
                value: "Active",
                valueColor: DS.textPrimary,
                isLast: true
            )
        }
        .background(.white.opacity(0.84))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            PrimaryBtn(title: "Continue") {
                // Keep user signed in and stay on the authenticated area.
            }

            Button {
                session.logout()
            } label: {
                Text("Sign out")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }
}

private struct HomeStatusRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.primaryLight)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.primary)
            }
            .frame(width: 34, height: 34)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(DS.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 64)
            }
        }
    }
}
