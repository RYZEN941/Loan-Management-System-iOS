//
//  AdminProfileSettingsView.swift
//  lms_project
//

import SwiftUI

struct AdminProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var adminVM: AdminViewModel

    @State private var selectedSection: SettingsSection = .profile

    enum SettingsSection: String, CaseIterable, Identifiable {
        case profile = "Profile"
        case userManagement = "User Management"
        case policies = "Policy Configs"
        case workflows = "Workflow Setup"
        case verifications = "Verification Settings"
        case integrations = "Integrations"
        case notifications = "Notifications"
        case audit = "Audit & Compliance"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .profile: return "person.crop.circle"
            case .userManagement: return "person.3.sequence"
            case .policies: return "shield.righthalf.filled"
            case .workflows: return "arrow.triangle.branch"
            case .verifications: return "checkmark.seal"
            case .integrations: return "network"
            case .notifications: return "bell.badge"
            case .audit: return "list.bullet.rectangle.portrait"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        sidebar
                            .frame(width: geo.size.width * 0.3)
                        Divider()
                        content
                            .frame(width: geo.size.width * 0.7 - 1)
                    }
                }
            }
            .navigationTitle("Admin Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout", role: .destructive) {
                        dismiss()
                        authVM.logout()
                    }
                    .foregroundStyle(Theme.Colors.critical)
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header profile snippet
                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 64, height: 64)
                        Text(authVM.currentUser?.initials ?? "AD")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    Text(authVM.currentUser?.name ?? "Admin")
                        .font(Theme.Typography.headline)
                    GenericBadge(text: "System Administrator", color: Theme.Colors.primary)
                }
                .padding(.vertical, Theme.Spacing.md)

                Divider().padding(.horizontal, Theme.Spacing.md)

                // Menu items
                VStack(spacing: 0) {
                    ForEach(SettingsSection.allCases) { section in
                        let isSelected = selectedSection == section
                        Button {
                            withAnimation { selectedSection = section }
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? Theme.Colors.primary : .secondary)
                                    .frame(width: 24)
                                Text(section.rawValue)
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 14)
                            .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.1 : 0.8) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(selectedSection.rawValue)
                    .font(Theme.Typography.titleLarge)

                switch selectedSection {
                case .profile:
                    profileContent
                case .userManagement:
                    userMgmtContent
                case .policies:
                    policiesContent
                case .workflows:
                    workflowsContent
                case .verifications:
                    verificationsContent
                case .integrations:
                    integrationsContent
                case .notifications:
                    notificationsContent
                case .audit:
                    auditContent
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
    }

    // MARK: - Content Sections (Mockups / Reusing existing concepts)

    private var profileContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let user = authVM.currentUser {
                VStack(spacing: 0) {
                    infoRow("Name", user.name)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Email", user.email)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Phone", user.phone)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Branch", user.branch)
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }

    private var userMgmtContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Go to the main 'Users' tab for full management capabilities.")
                .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
            HStack {
                miniStat("Active Users", "\(adminVM.activeUsersCount)", Theme.Colors.success)
                miniStat("Total Users", "\(adminVM.users.count)", Theme.Colors.primary)
            }
        }
    }

    private var policiesContent: some View {
        VStack(spacing: 0) {
            toggleRow("Enforce strict FOIR limits", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("Auto-reject CIBIL < 600", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            infoRow("Max LTV Ratio", "80%")
        }
        .cardStyle(colorScheme: colorScheme)
    }

    private var workflowsContent: some View {
        VStack(spacing: 0) {
            toggleRow("Require Manager Approval > ₹10L", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("Enable Auto-Assignment to LOs", isOn: Binding(get: { adminVM.autoAssignEnabled }, set: { _ in }))
        }
        .cardStyle(colorScheme: colorScheme)
    }

    private var verificationsContent: some View {
        VStack(spacing: 0) {
            toggleRow("Enable PAN OCR verification", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("Aadhaar e-KYC integration", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("Bank statement analysis (Third-party)", isOn: .constant(false))
        }
        .cardStyle(colorScheme: colorScheme)
    }

    private var integrationsContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            integrationCard("CIBIL API", status: "Connected", color: Theme.Colors.success)
            integrationCard("Equifax API", status: "Disconnected", color: Theme.Colors.neutral)
            integrationCard("DigiLocker", status: "Connected", color: Theme.Colors.success)
        }
    }

    private var notificationsContent: some View {
        VStack(spacing: 0) {
            toggleRow("Email alerts for NPA accounts", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("SMS alerts for borrower document requests", isOn: .constant(true))
            Divider().padding(.leading, Theme.Spacing.md)
            toggleRow("Daily summary report emails", isOn: .constant(true))
        }
        .cardStyle(colorScheme: colorScheme)
    }

    private var auditContent: some View {
        VStack(spacing: 0) {
            ForEach(adminVM.auditLogs.prefix(10)) { log in
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: "clock").font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(log.action).font(Theme.Typography.subheadline).fontWeight(.medium)
                            Spacer()
                            Text(log.timestamp.shortFormatted).font(Theme.Typography.caption).foregroundStyle(.tertiary)
                        }
                        Text(log.detail).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        Text("by \(log.user)").font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                if log.id != adminVM.auditLogs.prefix(10).last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typography.subheadline)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 14)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.Colors.primary)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md).cardStyle(colorScheme: colorScheme)
    }

    private func integrationCard(_ name: String, status: String, color: Color) -> some View {
        HStack {
            Image(systemName: "network").font(.system(size: 20)).foregroundStyle(Theme.Colors.primary)
            Text(name).font(Theme.Typography.subheadline).padding(.leading, 8)
            Spacer()
            GenericBadge(text: status, color: color)
        }
        .padding(Theme.Spacing.md).cardStyle(colorScheme: colorScheme)
    }
}
