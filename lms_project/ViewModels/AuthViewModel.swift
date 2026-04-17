//
//  AuthViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - MFA Method

enum MFAMethod: String, CaseIterable, Identifiable {
    case email = "email"
    case sms   = "sms"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .email: return "Email OTP"
        case .sms:   return "SMS OTP"
        }
    }

    var icon: String {
        switch self {
        case .email: return "envelope.badge.shield.half.filled"
        case .sms:   return "iphone.and.arrow.forward"
        }
    }

    var description: String {
        switch self {
        case .email: return "Enter your email to receive a code"
        case .sms:   return "Enter your phone number to receive a code"
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .email: return "Your email address"
        case .sms:   return "Your phone number"
        }
    }

    var inputKeyboardType: UIKeyboardType {
        switch self {
        case .email: return .emailAddress
        case .sms:   return .phonePad
        }
    }
}

// MARK: - Auth Step

enum AuthStep {
    case credentials       // email + password screen
    case mfaSelection      // choose MFA method + enter contact
    case mfaVerification   // enter OTP (any input accepted)
    case authenticated     // logged in
}

// MARK: - AuthViewModel

class AuthViewModel: ObservableObject {

    // Published session state
    @Published var currentRole: UserRole? = nil
    @Published var currentUser: User?     = nil

    // Auth flow state
    @Published var authStep: AuthStep = .credentials
    @Published var loginError: String? = nil
    @Published var selectedMFAMethod: MFAMethod = .email
    @Published var mfaContact: String = ""   // email or phone entered by user
    @Published var otpError: String? = nil

    private let dataService = MockDataService.shared
    private let userStore   = UserStore.shared

    private var pendingCredential: StoredCredential? = nil

    var isLoggedIn: Bool { currentRole != nil }

    // MARK: - Step 1: Validate Credentials

    func submitCredentials(email: String, password: String) {
        loginError = nil

        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Please enter your email and password."
            return
        }

        if let credential = userStore.authenticate(email: email, password: password) {
            pendingCredential = credential
            authStep = .mfaSelection
        } else {
            loginError = "Invalid email or password."
        }
    }

    // MARK: - Step 2: Select MFA + Enter Contact

    /// contact: the email or phone number typed by the user on the MFA selection screen
    func selectMFA(_ method: MFAMethod, contact: String) {
        selectedMFAMethod = method
        mfaContact = contact
        // Production: call backend to send OTP to `contact`.
        // For now, any code entered on the next screen will be accepted.
        authStep = .mfaVerification
    }

    // MARK: - Step 3: Verify OTP (dummy — any input accepted)

    func verifyOTP(_ entered: String) {
        otpError = nil

        // Accept any non-empty input — real backend OTP check added later
        guard !entered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            otpError = "Please enter the verification code."
            return
        }

        guard let credential = pendingCredential else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            currentRole = credential.role
            currentUser = resolveUser(credential: credential)
            authStep    = .authenticated
        }
    }

    // MARK: - Resend OTP

    func resendOTP() {
        otpError = nil
        // Production: re-trigger send.
    }

    // MARK: - Back Navigation

    func backToCredentials() {
        pendingCredential = nil
        mfaContact  = ""
        loginError  = nil
        otpError    = nil
        authStep    = .credentials
    }

    func backToMFASelection() {
        otpError = nil
        authStep = .mfaSelection
    }

    // MARK: - Logout

    func logout() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRole       = nil
            currentUser       = nil
            pendingCredential = nil
            mfaContact        = ""
            loginError        = nil
            otpError          = nil
            authStep          = .credentials
        }
    }

    // MARK: - Legacy shim

    func login(as role: UserRole) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRole = role
            currentUser = dataService.currentUser(role: role)
        }
    }

    // MARK: - Private Helpers

    private func resolveUser(credential: StoredCredential) -> User {
        let allUsers = dataService.fetchUsers()
        if let match = allUsers.first(where: { $0.id == credential.id }) {
            return match
        }
        return User(
            id: credential.id,
            name: nameFromEmail(credential.email),
            email: credential.email,
            role: credential.role,
            branch: "Head Office",
            phone: credential.phone,
            isActive: true,
            joinedAt: Date()
        )
    }

    private func nameFromEmail(_ email: String) -> String {
        let base = email.components(separatedBy: "@").first ?? email
        return base.replacingOccurrences(of: ".", with: " ").capitalized
    }
}
