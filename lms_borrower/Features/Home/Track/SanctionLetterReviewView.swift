import SwiftUI

@available(iOS 18.0, *)
struct SanctionLetterReviewView: View {
    let application: BorrowerLoanApplication
    let acceptAction: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var content: BorrowerSanctionLetterContent {
        BorrowerSanctionLetterSupport.makeLetter(
            for: application,
            borrowerName: session.userName,
            mobileNumber: session.userPhone
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    letterHeader
                    introCopy
                    identityTable
                    termsTable
                    conditionsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task {
                            isSubmitting = true
                            errorMessage = nil
                            do {
                                try await acceptAction()
                                dismiss()
                            } catch {
                                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to accept sanction letter."
                            }
                            isSubmitting = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Accepting..." : "Accept Sanction Letter")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSubmitting)

                    Text("Acceptance will create the real loan record and update the application to disbursed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sanction Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var letterHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date: \(content.sanctionDate)")
                .font(.headline)

            Text("Dear \(content.applicantName),")
                .font(.title3.weight(.semibold))

            Text("Thank you for choosing ABC Bank. Based on your application and the information provided, we are pleased to extend a loan offer on the preliminary terms and conditions below.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var introCopy: some View {
        VStack(spacing: 0) {
            tableRow("Application No.", content.applicationNumber)
            tableRow("Sanctioned Date", content.sanctionDate)
            tableRow("Applicant Name", content.applicantName)
            tableRow("Mobile No.", content.mobileNumber, isLast: true)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var identityTable: some View {
        VStack(spacing: 0) {
            tableRow("Loan Type", content.loanType)
            tableRow("Loan Amount Sanctioned", content.sanctionedAmount)
            tableRow("Reference Interest Rate", content.referenceInterestRate)
            tableRow("Floating Interest Rate", content.floatingInterestRate)
            tableRow("Loan Tenor", content.loanTenor)
            tableRow("Total Processing Charges", content.processingCharges)
            tableRow("Origination Fee (Inclusive of GST)", content.originationFee)
            tableRow("Sanction Letter Validity", content.validity)
            tableRow("Amount of EMI (INR)", content.emiAmount)
            tableRow("Property Address", content.propertyAddress, isLast: true)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var termsTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acceptance Summary")
                .font(.headline)

            HStack(spacing: 12) {
                summaryPill(title: "Status", value: "Pending Acceptance")
                summaryPill(title: "Version", value: "v1")
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional conditions to comply prior to loan disbursal:")
                .font(.headline)

            ForEach(Array(content.conditions.enumerated()), id: \.offset) { index, condition in
                Text("\(index + 1). \(condition)")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func tableRow(_ label: String, _ value: String, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.mainBlue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
