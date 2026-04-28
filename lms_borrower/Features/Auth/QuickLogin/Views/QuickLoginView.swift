// Views/QuickLogin/QuickLoginView.swift
// LoanOS — Borrower App
// Minimal quick-login screen for returning users.

import SwiftUI

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isAuthenticating = false
    @State private var bioError = ""
    @State private var totpCode = ""
    @State private var otpCode = ""
    @FocusState private var codeFocused: Bool
    @State private var retryCount = 0
    @State private var quickMethod: QuickMethod = .totp
    @Namespace private var animation
    @State private var otpMFASessionID: String?
    @State private var otpChallengeTarget: String?

    private let maxFailedAttempts = 3

    private enum QuickMethod: String, CaseIterable, Identifiable {
        case totp = "Authenticator"
        case phoneOTP = "Phone OTP"
        case emailOTP = "Email OTP"

        var id: String { rawValue }

        var factor: String {
            switch self {
            case .totp: return "totp"
            case .phoneOTP: return "phone_otp"
            case .emailOTP: return "email_otp"
            }
        }
    }

    private var welcomeText: String {
        session.userName.isEmpty ? "Welcome back" : "Welcome back, \(session.userName)"
    }

    private var availableMethods: [QuickMethod] {
        var methods: [QuickMethod] = []
        if session.hasTotp {
            methods.append(.totp)
        }
        methods.append(.phoneOTP)
        methods.append(.emailOTP)
        return methods
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            headerSection

            Spacer(minLength: 28)

            methodPicker
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            quickLoginSection
                .padding(.horizontal, 20)

            Spacer()

            footerSection
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: quickMethod)
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
            if !availableMethods.contains(quickMethod), let first = availableMethods.first {
                quickMethod = first
            }
        }
        .onChange(of: session.hasTotp) { _, _ in
            if !availableMethods.contains(quickMethod), let first = availableMethods.first {
                quickMethod = first
            }
        }
        .onChange(of: quickMethod) { _, _ in
            bioError = ""
            totpCode = ""
            otpCode = ""
            otpMFASessionID = nil
            otpChallengeTarget = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                codeFocused = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.gradient)
                    .frame(width: 72, height: 72)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("Karz")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text(welcomeText)
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    private var methodPicker: some View {
        VStack(spacing: 10) {
            ForEach(availableMethods) { method in
                let isSelected = quickMethod == method
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        quickMethod = method
                    }
                } label: {
                    HStack {
                        Text(method.rawValue)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? DS.primary : DS.textPrimary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DS.primary)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? DS.primary.opacity(0.06) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? DS.primary : DS.border, lineWidth: isSelected ? 1.5 : 1)
                    )
                }
            }
        }
    }

    private var quickLoginSection: some View {
        switch quickMethod {
        case .totp:
            return AnyView(totpSection)
        case .phoneOTP, .emailOTP:
            return AnyView(otpSection)
        }
    }

    private var totpSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Enter 6-digit \(quickMethod.rawValue) Code")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(DS.textPrimary)

                    Text("Check your authenticator app for the verification code.")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }

                OTPBoxRow(otp: $totpCode, focused: $codeFocused, isSecure: true)
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
            
            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, -12)
            }

            PrimaryBtn(
                title: isAuthenticating ? "Verifying..." : "Verify",
                disabled: totpCode.count != 6 || isAuthenticating
            ) {
                codeFocused = false
                isAuthenticating = true
                bioError = "" 
                
                Task {
                    guard #available(iOS 18, *) else {
                        bioError = "This feature requires iOS 18 or later."
                        isAuthenticating = false
                        return
                    }
                    do {
                        let success = try await session.verifyQuickReopenMFA(factor: quickMethod.factor, code: totpCode)
                        
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        
                        if !success {
                            if registerFailedAttempt() {
                                bioError = "Invalid authenticator code."
                            }
                        }
                    } catch let error as AuthError {
                        if registerFailedAttempt() {
                            switch error {
                            case .sessionExpired:
                                bioError = "Your session has fully expired. Please sign in again."
                            default:
                                bioError = error.localizedDescription
                            }
                        }
                    } catch {
                        if registerFailedAttempt() {
                            bioError = "Invalid authenticator code or connection error."
                        }
                    }
                    isAuthenticating = false
                }
            }
        }
    }

    private var otpSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Enter 6-digit \(quickMethod.rawValue) Code")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(DS.textPrimary)

                    if let target = otpChallengeTarget, !target.isEmpty {
                        Text("Check your registered \(quickMethod == .phoneOTP ? "phone" : "email") for the verification code sent to \(target).")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Tap Send code, then enter the 6-digit OTP.")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                OTPBoxRow(otp: $otpCode, focused: $codeFocused, isSecure: true)
                    .padding(.vertical, 6)
                    .disabled(otpMFASessionID == nil)
                    .opacity(otpMFASessionID == nil ? 0.5 : 1)
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

            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 12) {
                SecondaryBtn(
                    title: isAuthenticating ? "Sending..." : "Send code"
                ) {
                    codeFocused = false
                    isAuthenticating = true
                    bioError = ""
                    Task {
                        do {
                            let result = try await session.beginQuickReopenOTP(factor: quickMethod.factor)
                            otpMFASessionID = result.mfaSessionID
                            otpChallengeTarget = result.challengeTarget
                            otpCode = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                codeFocused = true
                            }
                        } catch {
                            bioError = error.localizedDescription
                        }
                        isAuthenticating = false
                    }
                }
                .disabled(isAuthenticating)

                PrimaryBtn(
                    title: isAuthenticating ? "Verifying..." : "Verify",
                    disabled: otpCode.count != 6 || isAuthenticating || otpMFASessionID == nil
                ) {
                    codeFocused = false
                    isAuthenticating = true
                    bioError = ""
                    Task {
                        do {
                            guard let mfaSessionID = otpMFASessionID else { return }
                            let success = try await session.verifyQuickReopenOTP(
                                mfaSessionID: mfaSessionID,
                                factor: quickMethod.factor,
                                code: otpCode
                            )

                            if !success, registerFailedAttempt() {
                                bioError = "Invalid OTP code."
                            }
                        } catch let error as AuthError {
                            if registerFailedAttempt() {
                                switch error {
                                case .sessionExpired:
                                    bioError = "Your session has fully expired. Please sign in again."
                                default:
                                    bioError = error.localizedDescription
                                }
                            }
                        } catch {
                            if registerFailedAttempt() {
                                bioError = "Invalid OTP code or connection error."
                            }
                        }
                        isAuthenticating = false
                    }
                }
            }
        }
    }

    private var passwordFallbackSection: some View {
        VStack(spacing: 18) {
            Text("Quick login is turned off for this account on this device.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)

            Text("Use your password to continue.")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)

            PrimaryBtn(title: "Use Password") {
                session.logout()
            }
        }
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

    private var footerSection: some View {
        Button {
            session.logout()
        } label: {
            Text("Back to login")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
        }
    }

    @discardableResult
    private func registerFailedAttempt() -> Bool {
        retryCount += 1
        if retryCount >= maxFailedAttempts {
            session.logout(reason: "Too many failed quick-login attempts. Please sign in again.")
            return false
        }
        return true
    }
}
