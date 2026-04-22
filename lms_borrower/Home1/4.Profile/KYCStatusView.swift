import SwiftUI

struct KYCStatusView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showKYCFlow = false

    private let implementedFeatures = [
        "Record Aadhaar consent",
        "Initiate Aadhaar OTP",
        "Verify Aadhaar OTP",
        "Record PAN consent",
        "Verify PAN KYC",
        "Get borrower KYC status and history"
    ]

    private let remainingFeatures = [
        "Address proof",
        "Income details",
        "E-signature",
        "Manual document upload and review",
        "Other profile completion steps"
    ]

    private var bannerIcon: String {
        switch session.kycStatus {
        case .approved:
            return "checkmark.seal.fill"
        case .pending:
            return "clock.badge.checkmark.fill"
        case .rejected:
            return "xmark.octagon.fill"
        case .notStarted:
            return "shield.lefthalf.filled"
        }
    }

    private var bannerColor: Color {
        switch session.kycStatus {
        case .approved:
            return Color(hex: "#00C48C")
        case .pending:
            return .secondaryBlue
        case .rejected:
            return .alertRed
        case .notStarted:
            return .mainBlue
        }
    }

    private var bannerTitle: String {
        switch session.kycStatus {
        case .approved:
            return "Aadhaar & PAN Verified"
        case .pending:
            return "Backend KYC In Progress"
        case .rejected:
            return "Backend KYC Needs Attention"
        case .notStarted:
            return "Start Backend KYC"
        }
    }

    private var bannerMessage: String {
        switch session.kycStatus {
        case .approved:
            return "Your borrower profile reflects the completed Aadhaar and PAN verification steps available in the backend today."
        case .pending:
            return "We’re waiting on the backend-supported Aadhaar and PAN checks to finish."
        case .rejected:
            return "Aadhaar or PAN verification could not be completed. Reopen the flow and review the details."
        case .notStarted:
            return "Start with the KYC steps that are already implemented in the backend, then review the remaining onboarding items separately."
        }
    }

    private var actionTitle: String? {
        switch session.kycStatus {
        case .approved:
            return nil
        case .pending:
            return "Continue Aadhaar & PAN KYC"
        case .rejected:
            return "Retry Aadhaar & PAN KYC"
        case .notStarted:
            return "Start Aadhaar & PAN KYC"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                if session.kycStatus == .approved {
                    documentsSection
                }

                segmentSection(
                    title: "Implemented in backend",
                    subtitle: "This first segment is based directly on `docs/kyc.md`.",
                    items: implementedFeatures,
                    icon: "checkmark.circle.fill",
                    iconColor: DS.primary
                )
                .padding(.horizontal, 20)

                segmentSection(
                    title: "Remaining items",
                    subtitle: "These still sit outside the current backend KYC API scope.",
                    items: remainingFeatures,
                    icon: "clock.arrow.circlepath",
                    iconColor: DS.warning
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("KYC Status")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showKYCFlow) {
            KYCFlowController()
        }
    }

    private var statusBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: bannerIcon)
                .font(.system(size: 60))
                .foregroundColor(bannerColor)

            Text(bannerTitle)
                .font(.title2)
                .bold()

            Text(bannerMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if let actionTitle {
                Button {
                    showKYCFlow = true
                } label: {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(bannerColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verified Documents")
                .font(.headline)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                KYCDocRow(title: "PAN Card", docID: "Matched with borrower profile", date: "Verified via PAN KYC")
                Divider().padding(.leading, 20)
                KYCDocRow(title: "Aadhaar Card", docID: "OTP-based verification completed", date: "Verified via Aadhaar KYC")
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
    }

    private func segmentSection(
        title: String,
        subtitle: String,
        items: [String],
        icon: String,
        iconColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .padding(.top, 2)

                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(DS.textPrimary)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct KYCDocRow: View {
    let title: String
    let docID: String
    let date: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.title2)
                .foregroundColor(.mainBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(docID).font(.subheadline).foregroundColor(.secondary)
                Text(date).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#00C48C"))
                Text("Verified").font(.caption2).bold().foregroundColor(Color(hex: "#00C48C"))
            }
        }
        .padding(16)
    }
}
