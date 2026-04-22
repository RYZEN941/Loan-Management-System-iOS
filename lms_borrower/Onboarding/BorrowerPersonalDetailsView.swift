import SwiftUI

struct BorrowerPersonalDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dateOfBirth = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 20)) ?? Date()

    private var isFormValid: Bool {
        !viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.normalizedPAN.count == 10
    }

    var body: some View {
        List {
            Section {
                headerContent
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                TextField("Full name (as per PAN)", text: $viewModel.fullName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)

                TextField("PAN Number", text: $viewModel.panNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.next)

                DatePicker(
                    "Date of birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
            } header: {
                Text("Personal")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Step 1 of 3")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "person.crop.circle")
            }
            .foregroundStyle(DS.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Match your borrower profile")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Text("These details are used to match the Aadhaar and PAN verification responses from the backend KYC APIs.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Save & Continue", isLoading: viewModel.isLoading, disabled: !isFormValid) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                viewModel.dateOfBirth = formatter.string(from: dateOfBirth)
                
                Task {
                    if await viewModel.submitPersonalDetails() {
                        path.append(KYCRoute.verifyIdentity)
                    }
                }
            }

            if !isFormValid {
                Text("Enter your full name, PAN, and date of birth to continue.")
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DS.warning)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}
