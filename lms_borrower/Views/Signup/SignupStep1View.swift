// Views/Signup/SignupStep1View.swift
// LoanOS — Borrower App
// Signup Step 1 — Full name, email/mobile, and password entry screen.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Signup Step 1 View
// ═══════════════════════════════════════════════════════════════

struct SignupStep1View: View {
    @Binding var path: NavigationPath
    let onBackToLogin: () -> Void

    @State private var fullName  = ""
    @State private var contact   = ""
    @State private var password  = ""
    @State private var appeared  = false

    var canProceed: Bool { !fullName.isEmpty && !contact.isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BrandBar()
                StepBar(current: 1, total: 4).padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 26) {
                    ScreenBadge(badge: "NEW ACCOUNT", color: DS.primary,
                                title: "Create your\nborrower account",
                                subtitle: "Apply for loans, track repayments, and manage your finances.")
                    .slide(appeared, delay: 0)

                    VStack(spacing: 14) {
                        AppTextField(icon: "person.fill", placeholder: "Full Name", text: $fullName)
                        AppTextField(icon: "envelope.fill", placeholder: "Email or Mobile Number",
                                     text: $contact, keyboardType: .emailAddress)
                        AppSecureField(icon: "lock.fill", placeholder: "Create Password", text: $password)
                    }
                    .slide(appeared, delay: 0.08)

                    VStack(spacing: 14) {
                        PrimaryBtn(title: "Create Account", icon: "checkmark.shield.fill",
                                   disabled: !canProceed) {
                            path.append(SignupRoute.otp)
                        }
                        Button { onBackToLogin() } label: {
                            HStack(spacing: 4) {
                                Text("Already have an account?").foregroundColor(DS.textSecondary)
                                Text("Sign In").foregroundColor(DS.primary).fontWeight(.semibold)
                            }.font(.system(size: 15, design: .rounded))
                        }.frame(maxWidth: .infinity)
                    }
                    .slide(appeared, delay: 0.16)

                    // Trust indicators
                    HStack(spacing: 18) {
                        TrustBadge(icon: "lock.shield",    label: "256-bit SSL")
                        TrustBadge(icon: "checkmark.seal", label: "RBI Compliant")
                        TrustBadge(icon: "hand.raised",    label: "No Spam")
                    }
                    .frame(maxWidth: .infinity).padding(.top, 4)
                    .opacity(appeared ? 0.6 : 0).offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5).delay(0.3), value: appeared)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { withAnimation(.spring(response: 0.5)) { appeared = true } }
    }
}
