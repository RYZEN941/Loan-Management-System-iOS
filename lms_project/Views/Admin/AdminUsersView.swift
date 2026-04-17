//
//  AdminUsersView.swift
//  lms_project
//

import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var showCreateUser = false
    @State private var showEditUser = false
    @State private var editingUser: User? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    HStack(spacing: 1) {
                        userListPanel
                            .frame(width: geometry.size.width * Theme.Layout.splitLeftRatio)
                        Divider()
                        userDetailPanel
                            .frame(width: geometry.size.width * Theme.Layout.splitRightRatio - 1)
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateUser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                adminVM.loadData()
            }
            .sheet(isPresented: $showCreateUser) {
                CreateUserSheet(adminVM: adminVM)
            }
            .sheet(isPresented: $showEditUser) {
                if let user = editingUser {
                    EditUserSheet(adminVM: adminVM, user: user)
                }
            }
        }
    }
    
    // MARK: - User List Panel
    
    private var userListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search users...", text: $adminVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            
            HStack {
                Text("\(adminVM.activeUsersCount) active")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(adminVM.users.count) total")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(adminVM.filteredUsers) { user in
                        UserRow(user: user, isSelected: adminVM.selectedUser?.id == user.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    adminVM.selectedUser = user
                                }
                            }
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }
    
    // MARK: - User Detail Panel
    
    private var userDetailPanel: some View {
        Group {
            if let user = adminVM.selectedUser {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        VStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Text(user.initials)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
                            }
                            
                            Text(user.name)
                                .font(Theme.Typography.title)
                            
                            HStack(spacing: Theme.Spacing.sm) {
                                GenericBadge(text: user.role.displayName, color: Theme.Colors.primary)
                                GenericBadge(text: user.isActive ? "Active" : "Inactive",
                                             color: user.isActive ? Theme.Colors.success : Theme.Colors.neutral)
                            }
                        }
                        
                        VStack(spacing: 0) {
                            detailRow(icon: "envelope", label: "Email", value: user.email)
                            Divider().padding(.leading, 48)
                            detailRow(icon: "phone", label: "Phone", value: user.phone)
                            Divider().padding(.leading, 48)
                            detailRow(icon: "building.2", label: "Branch", value: user.branch)
                            Divider().padding(.leading, 48)
                            detailRow(icon: "calendar", label: "Joined", value: user.joinedAt.shortFormatted)
                        }
                        .cardStyle(colorScheme: colorScheme)
                        
                        HStack(spacing: Theme.Spacing.md) {
                            Button {
                                adminVM.toggleUserStatus(user)
                            } label: {
                                Label(
                                    user.isActive ? "Deactivate" : "Activate",
                                    systemImage: user.isActive ? "person.slash" : "person.badge.plus"
                                )
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(user.isActive ? Theme.Colors.critical : Theme.Colors.success)
                                .frame(maxWidth: .infinity)
                                .frame(height: Theme.Layout.buttonHeight)
                                .background((user.isActive ? Theme.Colors.critical : Theme.Colors.success).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                editingUser = user
                                showEditUser = true
                            } label: {
                                Label("Edit User", systemImage: "pencil")
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Theme.Layout.buttonHeight)
                                    .background(Theme.Colors.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select a user to view details")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: User
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(user.initials)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(user.isActive ? .primary : .secondary)
                    Spacer()
                    GenericBadge(text: user.role.displayName, color: Theme.Colors.primary)
                }
                HStack {
                    Text(user.branch)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !user.isActive {
                        Text("Inactive")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.neutral)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Create User Sheet

struct CreateUserSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var selectedRole: UserRole = .loanOfficer
    @State private var branch = ""
    @State private var employeeId = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    TextField("Full Name", text: $name)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    TextField("Branch", text: $branch)
                    TextField("Employee ID", text: $employeeId)
                }
            }
            .navigationTitle("Create User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        adminVM.createUser(name: name, role: selectedRole, branch: branch, employeeId: employeeId)
                        dismiss()
                    }
                    .disabled(name.isEmpty || branch.isEmpty || employeeId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit User Sheet

struct EditUserSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedRole: UserRole = .loanOfficer
    @State private var branch: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Information") {
                    TextField("Full Name", text: $name)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    TextField("Branch", text: $branch)
                }
                
                Section("Account") {
                    HStack {
                        Text("Email")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(user.email)
                    }
                    HStack {
                        Text("Employee ID")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(user.id)
                    }
                }
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        adminVM.updateUser(userId: user.id, name: name, role: selectedRole, branch: branch)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = user.name
                selectedRole = user.role
                branch = user.branch
            }
        }
    }
}
