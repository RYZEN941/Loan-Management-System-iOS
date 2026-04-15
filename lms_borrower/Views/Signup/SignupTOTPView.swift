// Views/Signup/SignupTOTPView.swift
// LoanOS — Borrower App
// Signup Step 5 — Minimal authenticator setup screen.

import SwiftUI

struct SignupTOTPView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var session: SessionStore

    @State private var appeared = false
    @State private var copied = false

    private let totpURI = "otpauth://totp/LoanOS:user@example.com?secret=ABC123XYZ&issuer=LoanOS"
    private let manualKey = "ABC123XYZ"

    var body: some View {
        VStack(spacing: 0) {
            topBar

            StepBar(current: 5, total: 5)
                .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.35), value: appeared)

                    qrCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

                    manualKeySection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.48).delay(0.08), value: appeared)

                    actionSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.easeOut(duration: 0.54).delay(0.12), value: appeared)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
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
            appeared = true
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if !path.isEmpty {
                    path.removeLast()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set up authenticator")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Scan this code in your authenticator app to finish securing your account.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var qrCard: some View {
        VStack(spacing: 18) {
            if let qr = QRGen.make(totpURI) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 196, height: 196)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Text("Open Google Authenticator, 1Password, or another compatible app and scan the code.")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var manualKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manual key")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.textSecondary)

            Button {
                UIPasteboard.general.string = manualKey
                copied = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    copied = false
                }
            } label: {
                HStack(spacing: 12) {
                    Text(formattedManualKey)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.primary)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(.white.opacity(0.82))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
            }
            .buttonStyle(TapScale())
        }
    }

    private var actionSection: some View {
        PrimaryBtn(
            title: "Finish Setup"
        ) {
            session.completeSession()
            path.append(SignupRoute.home)
        }
    }

    private var formattedManualKey: String {
        stride(from: 0, to: manualKey.count, by: 3).map { index in
            let start = manualKey.index(manualKey.startIndex, offsetBy: index)
            let end = manualKey.index(start, offsetBy: min(3, manualKey.count - index))
            return String(manualKey[start..<end])
        }
        .joined(separator: " ")
    }
}
