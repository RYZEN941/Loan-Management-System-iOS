//
//  ManagerDstView.swift
//  lms_project
//

import SwiftUI

struct ManagerDstView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var showAddDst = false
    @State private var editingAgent: User? = nil
    @State private var searchText = ""
    @State private var agentToDelete: User? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                ManagerTheme.Colors.background(colorScheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            dstStatsStrip
                            searchBar
                            dstList
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("DST Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .tint(ManagerTheme.Colors.primary(colorScheme))
            .sheet(isPresented: $showAddDst) {
                AddDstSheet(adminVM: adminVM, authVM: authVM)
            }
            .sheet(item: $editingAgent) { agent in
                EditDstSheet(agent: agent, adminVM: adminVM, authVM: authVM)
            }
            .alert("Delete Agent", isPresented: Binding(
                get: { agentToDelete != nil },
                set: { if !$0 { agentToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let agent = agentToDelete {
                        adminVM.removeDstLocally(agent)
                    }
                }
            } message: {
                Text("Remove \(agentToDelete?.name ?? "this agent") from this list? This is a frontend-only action.")
            }
            .overlay(alignment: .top) {
                feedbackBanner
                    .padding(.top, 8)
            }
            .onAppear {
                adminVM.loadData()
                Task {
                    await adminVM.loadDstDataForManagerScope()
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Direct Sales Team")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Manage and monitor your branch's field agents")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Button {
                showAddDst = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add Agent")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ManagerTheme.Colors.primary(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
    }
    
    private var dstStatsStrip: some View {
        HStack(spacing: Theme.Spacing.lg) {
            let branchDst = adminVM.dstUsers
            
            DstKPICard(title: "Total Agents", 
                        value: "\(branchDst.count)", 
                        icon: "person.2.fill", 
                        color: ManagerTheme.Colors.primary(colorScheme))
            
            DstKPICard(title: "Active Portfolio", 
                        value: "₹\((branchDst.count * 14))L",
                        icon: "indianrupeesign.circle.fill", 
                        color: ManagerTheme.Colors.secondary(colorScheme))
            
            DstKPICard(title: "Active Ratio", 
                        value: branchDst.isEmpty ? "0%" : "\(Int(Double(branchDst.filter { $0.isActive }.count) / Double(branchDst.count) * 100))%", 
                        icon: "chart.bar.fill", 
                        color: Theme.Colors.adaptiveSuccess(colorScheme))
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            TextField("Search agents by name, email or ID...", text: $searchText)
                .font(.system(size: 15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ManagerTheme.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
        )
    }
    
    private var dstList: some View {
        VStack(spacing: Theme.Spacing.lg) {
            let branchDst = adminVM.dstUsers
            let filteredDst = branchDst.filter {
                searchText.isEmpty || 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
            
            if filteredDst.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("No agents found in this branch")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: Theme.Spacing.lg)], spacing: Theme.Spacing.lg) {
                    ForEach(filteredDst) { agent in
                        DstCard(agent: agent) {
                            editingAgent = agent
                        } onToggle: {
                            adminVM.toggleUserStatus(agent)
                        } onDelete: {
                            agentToDelete = agent
                        }
                    }
                }
            }
        }
    }
    
    private var feedbackBanner: some View {
        Group {
            if let error = adminVM.requestError, !error.isEmpty {
                banner(text: error, color: Theme.Colors.adaptiveCritical(colorScheme))
            } else if let success = adminVM.requestSuccess, !success.isEmpty {
                banner(text: success, color: Theme.Colors.adaptiveSuccess(colorScheme))
            }
        }
    }
    
    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .padding(.horizontal, Theme.Spacing.lg)
    }
}

// MARK: - Local Components for DST View

private struct DstKPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ManagerTheme.Colors.surface(colorScheme))
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
        )
    }
}

private struct DstCard: View {
    let agent: User
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ManagerTheme.Colors.primary(colorScheme).opacity(0.1))
                        .frame(width: 52, height: 52)
                    Text(agent.initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text(agent.email)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                DstStatusBadge(isActive: agent.isActive)
            }
            .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contact")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(agent.phone)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(16)
                
                Spacer()
                
                HStack(spacing: 8) {
                    actionButton(icon: agent.isActive ? "person.fill.xmark" : "person.fill.checkmark", color: agent.isActive ? .orange : Theme.Colors.adaptiveSuccess(colorScheme), action: onToggle)
                    actionButton(icon: "pencil", color: ManagerTheme.Colors.primary(colorScheme), action: onEdit)
                    actionButton(icon: "trash", color: Theme.Colors.adaptiveCritical(colorScheme), action: onDelete)
                }
                .padding(.trailing, 16)
            }
            .background(ManagerTheme.Colors.surfaceSecondary(colorScheme).opacity(0.3))
        }
        .background(ManagerTheme.Colors.surface(colorScheme))
        .cornerRadius(Theme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
    }
    
    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(ManagerTheme.Colors.surface(colorScheme))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct DstStatusBadge: View {
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Theme.Colors.adaptiveSuccess(colorScheme) : Color.gray)
                .frame(width: 6, height: 6)
            Text(isActive ? "Active" : "Inactive")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(isActive ? Theme.Colors.adaptiveSuccess(colorScheme) : .gray)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isActive ? Theme.Colors.adaptiveSuccess(colorScheme) : Color.gray).opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct AddDstSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adminVM: AdminViewModel
    @ObservedObject var authVM: AuthViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Personal Details")
                }
                
                Section {
                    SecureField("Assign Password", text: $password)
                } header: {
                    Text("Login Credentials")
                } footer: {
                    Text("Agents will use their email and this password to sign in.")
                }
            }
            .navigationTitle("New DST Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating..." : "Create Account") {
                        saveAgent()
                    }
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty || isSaving)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func saveAgent() {
        isSaving = true
        Task {
            let success = await adminVM.createDstAccount(
                name: name,
                email: email,
                phone: phone,
                password: password
            )
            
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

private struct EditDstSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adminVM: AdminViewModel
    @ObservedObject var authVM: AuthViewModel
    
    let agent: User
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false
    
    init(agent: User, adminVM: AdminViewModel, authVM: AuthViewModel) {
        self.agent = agent
        self.adminVM = adminVM
        self.authVM = authVM
        _name = State(initialValue: agent.name)
        _email = State(initialValue: agent.email)
        _phone = State(initialValue: agent.phone)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Update Agent Details")
                }
                
                Section {
                    HStack {
                        Text("Branch")
                        Spacer()
                        Text(agent.branch)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Account ID")
                        Spacer()
                        Text(agent.id)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Text("Account Info")
                }
            }
            .navigationTitle("Edit Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Update") {
                        updateAgent()
                    }
                    .disabled(name.isEmpty || email.isEmpty || isSaving)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func updateAgent() {
        isSaving = true
        Task {
            let success = await adminVM.updateDstAccount(
                userID: agent.id,
                name: name,
                email: email,
                phone: phone
            )
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
