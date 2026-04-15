// Views/Login/LoginStep1View.swift
// LoanOS — Borrower App
// Login Step 1 — Email / Mobile + Password entry screen.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Step 1 View
// ═══════════════════════════════════════════════════════════════

struct LoginStep1View: View {
    @Binding var path: NavigationPath
    let onGoToSignup: () -> Void

    @State private var contact  = ""
    @State private var password = ""
    @State private var appeared = false

    var canProceed: Bool { !contact.isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BrandBar()
                StepBar(current: 1, total: 4).padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 26) {
                    ScreenBadge(badge: "SECURE LOGIN", color: DS.primary,
                                title: "Welcome back",
                                subtitle: "Enter your credentials to continue.")
                    .slide(appeared, delay: 0)

                    VStack(spacing: 14) {
                        AppTextField(icon: "at", placeholder: "Email or Mobile Number",
                                     text: $contact, keyboardType: .emailAddress)
                        AppSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                    }
                    .slide(appeared, delay: 0.08)

                    VStack(spacing: 12) {
                        PrimaryBtn(title: "Continue", icon: "arrow.right.circle.fill",
                                   disabled: !canProceed) {
                            path.append(LoginRoute.otp)
                        }
                        Button { onGoToSignup() } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?").foregroundColor(DS.textSecondary)
                                Text("Sign Up").foregroundColor(DS.primary).fontWeight(.semibold)
                            }.font(.system(size: 14, design: .rounded))
                        }.frame(maxWidth: .infinity)
                    }
                    .slide(appeared, delay: 0.16)

                    InfoCard(icon: "info.circle.fill", color: DS.primary,
                             text: "Demo mode: enter anything to continue.")
                }
                .padding(.horizontal, 24)
            }
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { withAnimation(.spring(response: 0.5)) { appeared = true } }
    }
}
