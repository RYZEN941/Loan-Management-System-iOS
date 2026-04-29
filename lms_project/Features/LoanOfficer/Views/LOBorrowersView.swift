//
//  LOBorrowersView.swift
//  lms_project
//
//  Borrowers directory for Loan Officer.
//  Matches the UI/UX of LOApplicationsView for consistency.
//

import SwiftUI

struct LOBorrowersView: View {
    @EnvironmentObject private var applicationsVM: ApplicationsViewModel
    @EnvironmentObject private var borrowerVM: BorrowerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: Int
    @Binding var showProfile: Bool

    @State private var sidebarCollapsed = false
    private let sidebarWidth: CGFloat = 320

    // MARK: - Theme Helpers
    private var primary: Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var surface: Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var bg:      Color { Theme.Colors.adaptiveBackground(colorScheme) }
    private var border:  Color { Theme.Colors.adaptiveBorder(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                GeometryReader { _ in
                    HStack(spacing: 0) {
                        // ── Collapsable sidebar ──────────────────────────
                        if !sidebarCollapsed {
                            borrowerListPanel
                                .frame(width: sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))

                            Divider()
                        }

                        // ── Detail panel ─────────────────────────────────
                        borrowerDetailPanel
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Borrowers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Sidebar toggle
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .symbolVariant(sidebarCollapsed ? .none : .fill)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
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
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sidebarCollapsed)
        .tint(primary)
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Sidebar: Borrower List
    // ────────────────────────────────────────────────────────────────

    private var borrowerListPanel: some View {
        VStack(spacing: 0) {
            // List Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Borrowers")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("\(borrowerVM.filteredBorrowers.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(primary)
                    .font(.system(size: 14, weight: .bold))
                TextField("Search name, phone, email...", text: $borrowerVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(border, lineWidth: 1)
            )
            .padding(.horizontal, 16)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BorrowerDirectoryFilter.allCases) { filter in
                        AppFilterChip(label: filter.rawValue, isSelected: borrowerVM.filter == filter) {
                            withAnimation(.spring(response: 0.3)) {
                                borrowerVM.filter = filter
                                // Auto-select first in filter if any
                                if let first = borrowerVM.filteredBorrowers.first {
                                    borrowerVM.selectedBorrowerID = first.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            Divider()

            // List
            if borrowerVM.filteredBorrowers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(primary.opacity(0.3))
                    Text("No borrowers found")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(borrowerVM.filteredBorrowers) { borrower in
                            borrowerRow(borrower)
                                .padding(.horizontal, 8)
                                .background(borrowerVM.selectedBorrowerID == borrower.id ? primary.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        borrowerVM.selectedBorrowerID = borrower.id
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(surface)
    }

    private func borrowerRow(_ borrower: BorrowerRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text(initials(for: borrower.borrower.name))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(primary)
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Detail Panel
    // ────────────────────────────────────────────────────────────────

    private var borrowerDetailPanel: some View {
        Group {
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(primary.opacity(0.2))
                    Text("Select a borrower to view profile")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bg)
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
}
