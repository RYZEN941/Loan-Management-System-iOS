// Views/Signup/SignupTOTPView.swift
// LoanOS — Borrower App
// Signup Step 4 — TOTP (authenticator app) setup screen.
// Displays a QR code and manual key. Completing this step
// calls session.completeSession() and navigates to Home.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup TOTP Setup View
// ═══════════════════════════════════════════════════════════════

struct SignupTOTPView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var session: SessionStore

    @State private var appeared = false

    /// In production, generate a per-user secret on the server.
    private let totpURI = "otpauth://totp/LoanOS:user@example.com?secret=ABC123XYZ&issuer=LoanOS"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                StepBar(current: 4, total: 4).padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 28) {
                    ScreenBadge(badge: "TWO-FACTOR AUTH", color: DS.purple,
                                title: "Set up your\nauthenticator",
                                subtitle: "Scan this QR with Google Authenticator, Authy, or any TOTP app.")

                    // QR code card
                    VStack(spacing: 16) {
                        if let qr = QRGen.make(totpURI) {
                            Image(uiImage: qr)
                                .interpolation(.none).resizable().scaledToFit()
                                .frame(width: 190, height: 190).padding(12)
                                .background(Color.white).cornerRadius(16)
                                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        }
                        VStack(spacing: 4) {
                            Text("LoanOS Authenticator")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(DS.textPrimary)
                            Text("user@example.com")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(DS.card).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.border, lineWidth: 1))

                    // Manual key entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAN'T SCAN? USE MANUAL KEY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                        HStack {
                            Text("ABC 123 XYZ")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(DS.primary).tracking(3)
                            Spacer()
                            Button { UIPasteboard.general.string = "ABC123XYZ" } label: {
                                Image(systemName: "doc.on.doc").foregroundColor(DS.primary)
                            }
                        }
                        .padding(14).background(DS.primaryLight).cornerRadius(12)
                    }

                    PrimaryBtn(title: "Done — Complete Setup", icon: "checkmark.seal.fill",
                               style: .success) {
                        session.completeSession()
                        path.append(SignupRoute.home)
                    }

                    InfoCard(icon: "exclamationmark.triangle.fill", color: DS.warning,
                             text: "Demo QR. In production a real TOTP secret is generated per user.")
                }
                .padding(.horizontal, 24)
            }
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationTitle("")
        .offset(y: appeared ? 0 : 24).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.45)) { appeared = true } }
    }
}
