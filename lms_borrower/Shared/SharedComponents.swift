// Shared/SharedComponents.swift
// LoanOS — Borrower App
// All shared design tokens, reusable views, and UI components used
// across both the Login and Signup flows.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Design System Tokens
// ═══════════════════════════════════════════════════════════════

enum DS {
    static let primary       = Color(hex: "#1A56E8")
    static let primaryLight  = Color(hex: "#EEF2FD")
    static let surface       = Color(hex: "#F8F9FC")
    static let card          = Color.white
    static let textPrimary   = Color(hex: "#0F1B3D")
    static let textSecondary = Color(hex: "#6B7A99")
    static let border        = Color(hex: "#E2E6F0")
    static let success       = Color(hex: "#0ECB7A")
    static let warning       = Color(hex: "#F59E0B")
    static let purple        = Color(hex: "#7C3AED")
    static let danger        = Color(hex: "#EF4444")

    static let gradient = LinearGradient(
        colors: [Color(hex: "#1A56E8"), Color(hex: "#0E3BB5")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let successGradient = LinearGradient(
        colors: [Color(hex: "#0ECB7A"), Color(hex: "#059A5C")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Form Components
// ═══════════════════════════════════════════════════════════════

struct AppTextField: View {
    let icon: String; let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(focused ? DS.primary : DS.textSecondary).frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: focused)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 16, design: .rounded)).foregroundColor(DS.textPrimary)
                .autocapitalization(.none).autocorrectionDisabled().focused($focused)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(DS.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(focused ? DS.primary : DS.border, lineWidth: focused ? 1.8 : 1)
            .animation(.easeInOut(duration: 0.2), value: focused))
        .shadow(color: focused ? DS.primary.opacity(0.1) : .black.opacity(0.03),
                radius: focused ? 8 : 4, x: 0, y: 2)
    }
}

struct AppSecureField: View {
    let icon: String; let placeholder: String
    @Binding var text: String
    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(focused ? DS.primary : DS.textSecondary).frame(width: 20)
            Group {
                if revealed {
                    TextField(placeholder, text: $text).autocapitalization(.none).autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16, design: .rounded)).foregroundColor(DS.textPrimary).focused($focused)
            Spacer()
            Button { revealed.toggle() } label: {
                Image(systemName: revealed ? "eye.slash" : "eye").foregroundColor(DS.textSecondary).frame(width: 20)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(DS.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(focused ? DS.primary : DS.border, lineWidth: focused ? 1.8 : 1)
            .animation(.easeInOut(duration: 0.2), value: focused))
        .shadow(color: focused ? DS.primary.opacity(0.1) : .black.opacity(0.03),
                radius: focused ? 8 : 4, x: 0, y: 2)
    }
}

// MARK: OTP 6-box

struct OTPBoxRow: View {
    @Binding var otp: String
    @FocusState.Binding var focused: Bool
    var body: some View {
        ZStack {
            TextField("", text: $otp)
                .keyboardType(.numberPad).focused($focused)
                .frame(width: 0, height: 0).opacity(0)
                .onChange(of: otp) { _, v in otp = String(v.filter(\.isNumber).prefix(6)) }
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    let ch: String = otp.count > i ? String(otp[otp.index(otp.startIndex, offsetBy: i)]) : ""
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(ch.isEmpty ? DS.card : DS.primaryLight)
                        RoundedRectangle(cornerRadius: 12).stroke(ch.isEmpty ? DS.border : DS.primary,
                                                                   lineWidth: ch.isEmpty ? 1.2 : 2)
                        if ch.isEmpty && i == otp.count && focused {
                            Rectangle().fill(DS.primary).frame(width: 2, height: 22).opacity(0.8)
                        } else {
                            Text(ch).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(DS.primary)
                        }
                    }
                    .frame(height: 56).animation(.spring(response: 0.2), value: ch)
                }
            }
        }
        .onTapGesture { focused = true }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Buttons
// ═══════════════════════════════════════════════════════════════

struct PrimaryBtn: View {
    let title: String
    var icon: String? = nil
    var style: BStyle = .blue
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void
    enum BStyle { case blue, success, danger }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                    Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).opacity(0.7)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(bg).cornerRadius(16)
            .shadow(color: shadowColor.opacity(disabled ? 0 : 0.3), radius: 12, x: 0, y: 6)
            .opacity(disabled ? 0.5 : 1)
        }
        .disabled(isLoading || disabled)
        .buttonStyle(TapScale())
    }

    @ViewBuilder private var bg: some View {
        switch style {
        case .blue:    DS.gradient
        case .success: DS.successGradient
        case .danger:  DS.dangerGradient
        }
    }
    private var shadowColor: Color {
        switch style { case .blue: DS.primary; case .success: DS.success; case .danger: DS.danger }
    }
}

struct SecondaryBtn: View {
    let title: String; var icon: String? = nil; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium)) }
                Text(title).font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(DS.primary).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(DS.primaryLight).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.primary.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(TapScale())
    }
}

struct TapScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Layout / Decoration Components
// ═══════════════════════════════════════════════════════════════

struct ScreenBadge: View {
    let badge: String; let color: Color; let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(badge).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(color)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(color.opacity(0.12)).cornerRadius(20)
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary).lineSpacing(2)
            Text(subtitle).font(.system(size: 15, design: .rounded))
                .foregroundColor(DS.textSecondary).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoCard: View {
    let icon: String; let color: Color; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            Text(text).font(.system(size: 13, design: .rounded)).foregroundColor(DS.textSecondary).lineSpacing(3)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.18), lineWidth: 1))
    }
}

struct BrandBar: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(DS.gradient).frame(width: 38, height: 38)
                Image(systemName: "building.columns.fill").foregroundColor(.white).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("LoanOS").font(.system(size: 19, weight: .bold, design: .rounded)).foregroundColor(DS.textPrimary)
                Text("Borrower Portal").font(.system(size: 11, design: .rounded)).foregroundColor(DS.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
    }
}

struct StepBar: View {
    let current: Int; let total: Int
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { s in
                    Capsule().fill(s <= current ? DS.primary : DS.border).frame(height: 4)
                        .animation(.spring(response: 0.4), value: current)
                }
            }
            HStack {
                Text("Step \(current) of \(total)").font(.caption).foregroundColor(DS.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 24).padding(.top, 8)
    }
}

struct TrustBadge: View {
    let icon: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(DS.primary)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(DS.textSecondary)
        }
    }
}

struct FeatureRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(DS.primary)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30).background(DS.primaryLight).cornerRadius(8)
            Text(text).font(.system(size: 14, design: .rounded)).foregroundColor(DS.textSecondary)
        }
    }
}

struct ConfettiView: View {
    let trigger: Bool
    let items = (0..<24).map { _ in (
        x: CGFloat.random(in: 0.04...0.96), y: CGFloat.random(in: 0.0...0.5),
        size: CGFloat.random(in: 7...15),
        color: [Color(hex: "#1A56E8"), Color(hex: "#0ECB7A"),
                Color(hex: "#FFB800"), Color(hex: "#FF4F8B")].randomElement()!,
        rot: Double.random(in: 0...360)
    )}
    var body: some View {
        GeometryReader { geo in
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                RoundedRectangle(cornerRadius: 3).fill(it.color)
                    .frame(width: it.size, height: it.size * 0.5)
                    .rotationEffect(.degrees(it.rot))
                    .position(x: it.x * geo.size.width, y: trigger ? it.y * geo.size.height : -20)
                    .opacity(trigger ? 0.75 : 0)
                    .animation(.spring(response: 0.9, dampingFraction: 0.6).delay(Double(i) * 0.035), value: trigger)
            }
        }
        .allowsHitTesting(false)
    }
}

struct BiometricCard: View {
    let isAuthenticating: Bool; let success: Bool; let failed: Bool; let errorMessage: String
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            success ? DS.success.opacity(0.2 - Double(i)*0.06)
                                    : failed  ? DS.danger.opacity(0.2  - Double(i)*0.06)
                                    :           DS.primary.opacity(0.15 - Double(i)*0.04),
                            lineWidth: 1.5)
                        .frame(width: CGFloat(80 + i * 28), height: CGFloat(80 + i * 28))
                        .scaleEffect(isAuthenticating ? 1.08 : 1)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2), value: isAuthenticating)
                }
                Circle().fill(success ? DS.success.opacity(0.15) : failed ? DS.danger.opacity(0.1) : DS.primaryLight)
                    .frame(width: 90, height: 90)
                Image(systemName: success ? "checkmark.circle.fill" : failed ? "xmark.circle.fill" : "faceid")
                    .font(.system(size: success || failed ? 46 : 44))
                    .foregroundColor(success ? DS.success : failed ? DS.danger : DS.primary)
                    .scaleEffect(success || failed ? 1.1 : 1)
                    .animation(.spring(response: 0.4), value: success)
            }
            .frame(height: 145)
            VStack(spacing: 4) {
                Text(success ? "Identity Verified!"
                     : failed  ? "Authentication Failed"
                     : isAuthenticating ? "Verifying…" : "Ready to authenticate")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(success ? DS.success : failed ? DS.danger : DS.textPrimary)
                Text(success ? "Proceeding to next step"
                     : failed && !errorMessage.isEmpty ? errorMessage
                     : "Tap Continue to trigger Face ID / Touch ID")
                    .font(.system(size: 13, design: .rounded)).foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .animation(.easeInOut(duration: 0.25), value: success)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        .background(DS.card).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.border, lineWidth: 1))
    }
}
