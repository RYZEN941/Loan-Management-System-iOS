import SwiftUI

enum ForgotPasswordStep {
    case methodSelection
    case input
    case otp
    case reset
    case success
}

struct ForgotPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentStep: ForgotPasswordStep = .methodSelection
    @State private var selectedMethod: MFAMethod = .email
    @State private var inputValue: String = ""
    @State private var otp: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    
    // For input focus
    @FocusState private var isInputFocused: Bool
    @FocusState private var isOtpFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Button {
                        if currentStep == .methodSelection || currentStep == .success {
                            withAnimation(.easeInOut(duration: 0.32)) {
                                authVM.authStep = .credentials
                            }
                        } else {
                            goBack()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            Text(currentStep == .methodSelection ? "Cancel" : "Back").font(.system(size: 15))
                        }
                        .foregroundStyle(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 48)
                .padding(.top, 32)
                
                Spacer().frame(height: 40)
                
                ZStack {
                    switch currentStep {
                    case .methodSelection:
                        methodSelectionContent
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .input:
                        inputContent
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .otp:
                        otpContent
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .reset:
                        resetContent
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .success:
                        successContent
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
                .id(currentStep)
                
                Spacer().frame(height: 60)
            }
        }
    }
    
    private func goBack() {
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.35)) {
            switch currentStep {
            case .input: currentStep = .methodSelection
            case .otp: currentStep = .input
            case .reset: currentStep = .otp
            default: break
            }
        }
    }
    
    // MARK: - Method Selection
    private var methodSelectionContent: some View {
        VStack(spacing: 0) {
            headerView(icon: "key.fill", title: "Reset Password", subtitle: "Choose how you want to reset your password")
            
            VStack(spacing: 12) {
                methodCard(method: .email, icon: "envelope.fill", title: "Email", description: "Send reset link to your email")
                methodCard(method: .sms, icon: "message.fill", title: "Phone Number", description: "Send OTP to your phone")
            }
            .padding(.top, 32)
            
            Button {
                errorMessage = nil
                withAnimation(.easeInOut(duration: 0.35)) { currentStep = .input }
            } label: {
                primaryButtonLabel("Continue")
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 48)
    }
    
    private func methodCard(method: MFAMethod, icon: String, title: String, description: String) -> some View {
        Button {
            withAnimation { selectedMethod = method }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selectedMethod == method ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(selectedMethod == method ? Theme.Colors.primary : Color.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(selectedMethod == method ? Theme.Colors.primary : Color.primary)
                    Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .strokeBorder(selectedMethod == method ? Theme.Colors.primary : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selectedMethod == method {
                        Circle().fill(Theme.Colors.primary).frame(width: 11, height: 11)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.adaptiveSurface(colorScheme)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selectedMethod == method ? Theme.Colors.primary.opacity(0.55) : Theme.Colors.adaptiveBorder(colorScheme), lineWidth: selectedMethod == method ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Input View
    private var inputContent: some View {
        VStack(spacing: 0) {
            headerView(icon: selectedMethod == .email ? "envelope.fill" : "phone.fill", title: selectedMethod == .email ? "Enter Email" : "Enter Phone", subtitle: selectedMethod == .email ? "We will send an OTP to your email" : "We will send an OTP to your phone")
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: selectedMethod == .email ? "envelope" : "phone")
                        .font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 22).padding(.leading, 16)
                    TextField(selectedMethod == .email ? "Email address" : "Phone number", text: $inputValue)
                        .keyboardType(selectedMethod == .email ? .emailAddress : .phonePad)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).font(.system(size: 16)).padding(.vertical, 16)
                        .focused($isInputFocused)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.adaptiveSurface(colorScheme)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1))
            .padding(.top, 32)
            
            errorView
            
            Button {
                if inputValue.isEmpty {
                    errorMessage = "Please enter your \(selectedMethod == .email ? "email" : "phone number")"
                    return
                }
                
                if selectedMethod == .sms {
                    let digitsOnly = inputValue.filter { $0.isNumber }
                    if digitsOnly.count != inputValue.count {
                        errorMessage = "Invalid phone number. Only numbers allowed."
                        return
                    }
                }
                
                errorMessage = nil
                otp = "" // Reset OTP
                withAnimation(.easeInOut(duration: 0.35)) { currentStep = .otp }
            } label: {
                primaryButtonLabel("Send OTP")
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: 480).padding(.horizontal, 48)
        .onAppear { isInputFocused = true }
    }
    
    // MARK: - OTP View
    private var otpContent: some View {
        VStack(spacing: 0) {
            headerView(icon: "shield.fill", title: "Enter OTP", subtitle: "Enter the 6-digit code sent to \(inputValue)")
            
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.adaptiveSurface(colorScheme)))
                            .frame(width: 45, height: 55)
                        
                        Text(getOtpDigit(at: index))
                            .font(.system(size: 24, weight: .semibold))
                    }
                }
            }
            .padding(.top, 32)
            .background(
                TextField("", text: $otp)
                    .keyboardType(.numberPad)
                    .focused($isOtpFocused)
                    .opacity(0)
            )
            .onTapGesture { isOtpFocused = true }
            
            errorView
            
            Button {
                if otp == "123456" {
                    errorMessage = nil
                    withAnimation { currentStep = .reset }
                } else {
                    errorMessage = "Invalid OTP. Please try 123456."
                }
            } label: {
                primaryButtonLabel("Verify OTP")
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .disabled(otp.count < 6)
            
            Button {
                otp = ""
                errorMessage = nil
                // Simulate resend
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                Text("Didn't receive a code? **Resend**")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .frame(maxWidth: 480).padding(.horizontal, 48)
        .onAppear { isOtpFocused = true }
        .onChange(of: otp) { _, newValue in
            if newValue.count > 6 {
                otp = String(newValue.prefix(6))
            }
            
            if otp.count == 6 {
                if otp == "123456" {
                    errorMessage = nil
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .reset
                    }
                } else {
                    errorMessage = "Invalid OTP. Please try 123456."
                }
            } else {
                errorMessage = nil
            }
        }
    }
    
    private func getOtpDigit(at index: Int) -> String {
        guard index < otp.count else { return "" }
        let charIndex = otp.index(otp.startIndex, offsetBy: index)
        return String(otp[charIndex])
    }
    
    // MARK: - Reset Password View
    private var resetContent: some View {
        VStack(spacing: 0) {
            headerView(icon: "lock.rotation", title: "New Password", subtitle: "Set a new password for your account")
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "lock").font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 22).padding(.leading, 16)
                    SecureField("New password", text: $newPassword)
                        .font(.system(size: 16)).padding(.vertical, 16)
                }
                Divider().padding(.leading, 52)
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield").font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 22).padding(.leading, 16)
                    SecureField("Confirm password", text: $confirmPassword)
                        .font(.system(size: 16)).padding(.vertical, 16)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.adaptiveSurface(colorScheme)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1))
            .padding(.top, 32)
            
            errorView
            
            Button {
                if newPassword.count < 6 {
                    errorMessage = "Password must be at least 6 characters"
                } else if newPassword != confirmPassword {
                    errorMessage = "Passwords do not match"
                } else {
                    errorMessage = nil
                    withAnimation(.easeInOut(duration: 0.35)) { currentStep = .success }
                }
            } label: {
                primaryButtonLabel("Reset Password")
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: 480).padding(.horizontal, 48)
    }
    
    // MARK: - Success View
    private var successContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Theme.Colors.success.opacity(0.14)).frame(width: 80, height: 80)
                Image(systemName: "checkmark").font(.system(size: 36, weight: .bold)).foregroundStyle(Theme.Colors.success)
            }
            .padding(.bottom, 24)
            
            Text("Password Reset")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .padding(.bottom, 10)
            
            Text("Your password has been successfully reset. You can now sign in with your new password.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
            
            Button {
                withAnimation(.easeInOut(duration: 0.32)) {
                    authVM.authStep = .credentials
                }
            } label: {
                primaryButtonLabel("Back to Sign In")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 480).padding(.horizontal, 48)
    }
    
    // MARK: - Helpers
    private func headerView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.Colors.primary.opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(Theme.Colors.primary)
            }
            Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(colorScheme == .dark ? .white : .primary).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    
    private func primaryButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 280, height: 50)
            .background(colorScheme == .dark ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    @ViewBuilder
    private var errorView: some View {
        if let err = errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                Text(err).font(.system(size: 13))
            }
            .foregroundStyle(Theme.Colors.critical)
            .padding(.top, 10)
            .transition(.opacity)
        }
    }
}
