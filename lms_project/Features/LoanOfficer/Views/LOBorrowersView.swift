//
//  LOBorrowersView.swift
//  lms_project
//

import SwiftUI

struct LOBorrowersView: View {
    @EnvironmentObject private var applicationsVM: ApplicationsViewModel
    @EnvironmentObject private var borrowerVM: BorrowerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: Int
    @Binding var showProfile: Bool

    var body: some View {
        NavigationSplitView {
            borrowerList
                .navigationTitle("Borrowers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileNavButton(showProfile: $showProfile)
                    }
                }
        } detail: {
            if let borrower = borrowerVM.selectedBorrower {
                BorrowerProfileView(
                    borrowerRecord: borrower,
                    notes: borrowerVM.notes(for: borrower.id),
                    showsInternalNotes: true,
                    onAddNote: { borrowerVM.addNote(text: $0, borrowerID: borrower.id) },
                    onSelectApplication: { application in
                        applicationsVM.selectApplication(application)
                        selectedTab = 1
                    }
                )
                .navigationTitle(borrower.borrower.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "No Borrowers",
                    systemImage: "person.text.rectangle",
                    description: Text("Borrowers you’ve handled will appear here once applications are loaded.")
                )
            }
        }
        .onAppear {
            if applicationsVM.applications.isEmpty {
                applicationsVM.loadData(autoSelectFirst: false)
            }
            borrowerVM.refresh(from: applicationsVM.applications)
        }
        .onChange(of: applicationsVM.applications) { _, newValue in
            borrowerVM.refresh(from: newValue)
        }
        .tint(Theme.Colors.adaptivePrimary(colorScheme))
    }

    private var borrowerList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.primary)
                TextField("Search name, phone, email, employer", text: $borrowerVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BorrowerDirectoryFilter.allCases) { filter in
                        AppFilterChip(label: filter.rawValue, isSelected: borrowerVM.filter == filter) {
                            withAnimation(.spring(response: 0.3)) {
                                borrowerVM.filter = filter
                                borrowerVM.selectedBorrowerID = borrowerVM.filteredBorrowers.first?.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            List(selection: $borrowerVM.selectedBorrowerID) {
                ForEach(borrowerVM.filteredBorrowers) { borrower in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(borrower.riskLevel.color.opacity(0.16))
                                .frame(width: 42, height: 42)
                            Text(initials(for: borrower.borrower.name))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(borrower.riskLevel.color)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(borrower.borrower.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text(borrower.borrower.phone)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(borrower.recentApplicationSubtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                    .tag(borrower.id)
                }
            }
            .listStyle(.plain)
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
}
