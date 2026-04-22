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

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            headerSection

            Spacer(minLength: 28)

            methodPicker
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

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
        Picker("Quick login method", selection: $quickMethod) {
            ForEach(QuickMethod.allCases) { method in
                Text(method.rawValue).tag(method)
            }
        }
        .pickerStyle(.segmented)
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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authenticator code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.textSecondary)

                    Text("Enter the 6-digit code from your app.")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                }

                OTPBoxRow(otp: $totpCode, focused: $codeFocused)
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
                bioError = "" // Re-using bioError as a generic alert if needed
                
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
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("One-time code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.textSecondary)

                if let target = otpChallengeTarget, !target.isEmpty {
                    Text("Code sent to \(target).")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                } else {
                    Text("Tap Send code, then enter the 6-digit OTP.")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                }
            }

            OTPBoxRow(otp: $otpCode, focused: $codeFocused)
                .padding(.vertical, 6)

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
