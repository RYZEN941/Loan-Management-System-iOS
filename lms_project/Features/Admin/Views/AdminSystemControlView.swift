//
//  AdminSystemControlView.swift
//  lms_project
//
//  TAB 5 — System Control with 7 sidebar sections
//

import SwiftUI

struct AdminSystemControlView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var selectedSection: SystemSection = .userManagement
    @State private var showCreateUser = false
    @State private var editingUser: User? = nil
    @State private var configSaved = false
    @State private var sidebarCollapsed = false

    // Policy config state
    @State private var foirLimit = 50.0
    @State private var cibilThreshold = 600
    @State private var ltvLimit = 80.0
    @State private var baseInterestRate = 8.5
    @State private var maxLoanAmountMil = 50.0

    // Workflow state
    @State private var managerApprovalThreshold = 10.0
    @State private var autoApprovalEnabled = false
    @State private var autoApprovalCIBIL = 800

    // Verification state
    @State private var panOCR = true
    @State private var aadhaarKYC = true
    @State private var faceMatch = true
    @State private var faceMatchThreshold = 85.0
    @State private var videoKYC = false

    // Notification state
    @State private var npaEmailAlert = true
    @State private var smsDocRequest = true
    @State private var dailySummary = true
    @State private var slaBreachAlert = true

    enum SystemSection: String, CaseIterable, Identifiable {
        case userManagement = "User Management"
        case policyConfig = "Policy Config"
        case workflowConfig = "Workflow"
        case verificationSettings = "Verification"
        case notifications = "Notifications"
        case auditCompliance = "Audit & Compliance"
        case integrations = "Integrations"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .userManagement: return "person.3.fill"
            case .policyConfig: return "shield.righthalf.filled"
            case .workflowConfig: return "arrow.triangle.branch"
            case .verificationSettings: return "checkmark.seal"
            case .notifications: return "bell.badge"
            case .auditCompliance: return "list.bullet.rectangle.portrait"
            case .integrations: return "network"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if !sidebarCollapsed {
                            sidebar.frame(width: geo.size.width * 0.28)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }
                        contentPanel.frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("System Control").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { sidebarCollapsed.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileNavButton(showProfile: $showProfile) }
            }
            .onAppear { adminVM.loadData() }
            .sheet(isPresented: $showCreateUser) { CreateUserSheet(adminVM: adminVM) }
            .sheet(item: $editingUser) { user in EditUserSheet(adminVM: adminVM, user: user) }
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SystemSection.allCases) { section in
                    let isSelected = selectedSection == section
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: section.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(isSelected ? Theme.Colors.primary : .secondary)
                                .frame(width: 22)
                            Text(section.rawValue)
                                .font(Theme.Typography.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 14)
                        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.15 : 0.8) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Spacing.md)
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - Content Panel
    private var contentPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                requestBanner
                Text(selectedSection.rawValue).font(Theme.Typography.titleLarge)
                switch selectedSection {
                case .userManagement: userManagementContent
                case .policyConfig: policyConfigContent
                case .workflowConfig: workflowConfigContent
                case .verificationSettings: verificationContent
                case .notifications: notificationsContent
                case .auditCompliance: auditContent
                case .integrations: integrationsContent
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
    }

    @ViewBuilder
    private var requestBanner: some View {
        if let error = adminVM.requestError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.critical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.critical.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        } else if let success = adminVM.requestSuccess {
            Label(success, systemImage: "checkmark.circle.fill")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.success.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    // MARK: - 1. User Management
    private var userManagementContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("\(adminVM.activeUsersCount) active · \(adminVM.users.count) total")
                    .font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showCreateUser = true } label: {
                    Label("Add User", systemImage: "plus.circle.fill")
                        .font(Theme.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.Colors.primary)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)
            }

            // Role summary
            HStack(spacing: Theme.Spacing.md) {
                ForEach(UserRole.allCases) { role in
                    let count = adminVM.usersByRole[role] ?? 0
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: role.icon).font(.system(size: 18)).foregroundStyle(Theme.Colors.primary)
                        Text("\(count)").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(role.displayName).font(Theme.Typography.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(Theme.Spacing.sm).cardStyle(colorScheme: colorScheme)
                }
            }

            // User list
            VStack(spacing: 0) {
                ForEach(adminVM.filteredUsers) { user in
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle().fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12)).frame(width: 36, height: 36)
                            Text(user.initials).font(Theme.Typography.caption2).foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).font(Theme.Typography.subheadline).fontWeight(.medium)
                            Text("\(user.role.displayName) · \(user.branch)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Actions
                        Button { editingUser = user } label: {
                            Image(systemName: "pencil").font(.system(size: 16)).foregroundStyle(Theme.Colors.primary)
                        }.buttonStyle(.plain)

                        Button { adminVM.toggleUserStatus(user) } label: {
                            Image(systemName: user.isActive ? "person.slash" : "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundStyle(user.isActive ? Theme.Colors.critical : Theme.Colors.success)
                        }.buttonStyle(.plain)

                        GenericBadge(text: user.isActive ? "Active" : "Inactive", color: user.isActive ? Theme.Colors.success : Theme.Colors.neutral)
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
                    if user.id != adminVM.filteredUsers.last?.id { Divider().padding(.leading, 56) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 2. Policy Configuration
    private var policyConfigContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                editRow("FOIR Limit") { stepper(value: $foirLimit, range: 20...70, step: 5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Min CIBIL Threshold") { stepper(value: Binding(get:{Double(cibilThreshold)},set:{cibilThreshold=Int($0)}), range: 500...800, step: 10, suffix: "") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("LTV Limit") { stepper(value: $ltvLimit, range: 50...95, step: 5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Base Interest Rate") { stepper(value: $baseInterestRate, range: 5...20, step: 0.5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Max Loan Amount") { stepper(value: $maxLoanAmountMil, range: 10...200, step: 10, suffix: "L") }
            }.cardStyle(colorScheme: colorScheme)

            saveButton("Save Policy Config") {
                adminVM.minCIBILScore = cibilThreshold
                adminVM.maxDTIRatio = foirLimit / 100.0
            }

            // Eligibility rules
            SectionHeader(title: "Loan Eligibility Rules", icon: "checklist")
            VStack(spacing: 0) {
                ruleInfoRow("Min income ₹25,000/month for Personal Loan")
                Divider().padding(.leading, Theme.Spacing.md)
                ruleInfoRow("Co-applicant required for loans > ₹15L")
                Divider().padding(.leading, Theme.Spacing.md)
                ruleInfoRow("Max 3 active loans per borrower")
                Divider().padding(.leading, Theme.Spacing.md)
                ruleInfoRow("Employment tenure ≥ 1 year")
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 3. Workflow Configuration
    private var workflowConfigContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Approval Flow", icon: "arrow.right.arrow.left")
            VStack(spacing: 0) {
                flowStepRow(step: "1", title: "Loan Officer", desc: "Initial review & document collection", icon: "person.text.rectangle")
                Divider().padding(.leading, Theme.Spacing.md)
                flowStepRow(step: "2", title: "Manager", desc: "Credit assessment & approval/rejection", icon: "person.badge.shield.checkmark")
                Divider().padding(.leading, Theme.Spacing.md)
                flowStepRow(step: "3", title: "Admin", desc: "Final override & escalation handling", icon: "gearshape.2")
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Escalation Rules", icon: "exclamationmark.arrow.triangle.2.circlepath")
            VStack(spacing: 0) {
                escRow(trigger: "Loan > ₹50L", to: "Branch Manager", priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "CIBIL < 600", to: "Risk Committee", priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "SLA Breach > 7 days", to: "Admin", priority: "Medium")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "3 consecutive rejects", to: "Fraud Team", priority: "Critical")
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Auto-Approval", icon: "bolt.circle")
            VStack(spacing: 0) {
                editRow("Enable Auto-Approval") { Toggle("", isOn: $autoApprovalEnabled).labelsHidden().tint(Theme.Colors.primary) }
                if autoApprovalEnabled {
                    Divider().padding(.leading, Theme.Spacing.md)
                    editRow("Min CIBIL for Auto") { stepper(value: Binding(get:{Double(autoApprovalCIBIL)},set:{autoApprovalCIBIL=Int($0)}), range: 750...900, step: 10, suffix: "") }
                    Divider().padding(.leading, Theme.Spacing.md)
                    editRow("Manager Threshold (₹L)") { stepper(value: $managerApprovalThreshold, range: 5...100, step: 5, suffix: "L") }
                }
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 4. Verification Settings
    private var verificationContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "KYC Requirements", icon: "person.badge.shield.checkmark.fill")
            VStack(spacing: 0) {
                toggleConfigRow("PAN Card OCR Verification", isOn: $panOCR)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Aadhaar eKYC Integration", isOn: $aadhaarKYC)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Face Liveness Check", isOn: $faceMatch)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Video KYC (High Value)", isOn: $videoKYC)
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Document Checklist", icon: "doc.badge.gearshape")
            VStack(spacing: 0) {
                ForEach(DocumentType.allCases) { docType in
                    HStack {
                        Image(systemName: docType.icon).font(.system(size: 16)).foregroundStyle(Theme.Colors.primary).frame(width: 24)
                        Text(docType.displayName).font(Theme.Typography.subheadline)
                        Spacer()
                        GenericBadge(text: "Required", color: Theme.Colors.primary)
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if docType != DocumentType.allCases.last { Divider().padding(.leading, 48) }
                }
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Face Match Threshold", icon: "face.smiling")
            VStack(spacing: 0) {
                editRow("Match Confidence") { stepper(value: $faceMatchThreshold, range: 70...99, step: 1, suffix: "%") }
            }.cardStyle(colorScheme: colorScheme)

            saveButton("Save Verification Settings") {}
        }
    }

    // MARK: - 5. Notifications
    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Alert Configuration", icon: "bell.badge")
            VStack(spacing: 0) {
                toggleConfigRow("Email alerts for NPA accounts", isOn: $npaEmailAlert)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("SMS for document requests", isOn: $smsDocRequest)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Daily summary report emails", isOn: $dailySummary)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("SLA breach notifications", isOn: $slaBreachAlert)
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Email/SMS Templates", icon: "envelope.badge")
            VStack(spacing: 0) {
                templateRow(name: "Loan Approved", channel: "Email + SMS", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "Document Request", channel: "Email", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "EMI Reminder", channel: "SMS", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "NPA Notice", channel: "Email", status: "Draft")
            }.cardStyle(colorScheme: colorScheme)

            saveButton("Save Notification Settings") {}
        }
    }

    private func templateRow(name: String, channel: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Typography.subheadline)
                Text(channel).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            GenericBadge(text: status, color: status == "Active" ? Theme.Colors.success : Theme.Colors.warning)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13)
    }

    // MARK: - 6. Audit & Compliance
    private var auditContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Audit Logs", icon: "list.bullet.rectangle")
                Spacer()
                Button {} label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.primary)
                }.buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                ForEach(adminVM.auditLogs) { log in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: "clock").font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.action).font(Theme.Typography.subheadline).fontWeight(.medium)
                                Spacer()
                                Text(log.timestamp.relativeFormatted).font(Theme.Typography.caption).foregroundStyle(.tertiary)
                            }
                            Text(log.detail).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                            Text("by \(log.user)").font(Theme.Typography.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if log.id != adminVM.auditLogs.last?.id { Divider().padding(.leading, 48) }
                }
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Data Access Logs", icon: "lock.doc")
            VStack(spacing: 0) {
                accessLogRow(user: "Sunita Patel", action: "Viewed loan APP-2024-006", time: "2 min ago")
                Divider().padding(.leading, Theme.Spacing.md)
                accessLogRow(user: "Deepak Mehta", action: "Exported Portfolio Report", time: "15 min ago")
                Divider().padding(.leading, Theme.Spacing.md)
                accessLogRow(user: "Neha Kapoor", action: "Accessed borrower PII data", time: "1 hr ago")
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    private func accessLogRow(user: String, action: String, time: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(action).font(Theme.Typography.subheadline)
                Text("by \(user)").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(time).font(Theme.Typography.caption).foregroundStyle(.tertiary)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    // MARK: - 7. Integrations
    private var integrationsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "API Configuration", icon: "antenna.radiowaves.left.and.right")
            VStack(spacing: Theme.Spacing.sm) {
                apiCard(name: "CIBIL API", endpoint: "api.cibil.com", status: .healthy, latency: "180ms")
                apiCard(name: "UIDAI (Aadhaar)", endpoint: "uidai.gov.in/api", status: .healthy, latency: "95ms")
                apiCard(name: "GSTN API", endpoint: "api.gst.gov.in", status: .healthy, latency: "120ms")
                apiCard(name: "Core Banking", endpoint: "cbs.bank.internal", status: .healthy, latency: "42ms")
                apiCard(name: "Notification Service", endpoint: "notify.bank.internal", status: .degraded, latency: "820ms")
            }

            SectionHeader(title: "Failed API Calls", icon: "exclamationmark.arrow.circlepath")
            VStack(spacing: 0) {
                failedCallRow(api: "Notification Service", error: "Timeout after 5000ms", time: "12 min ago", retryable: true)
                Divider().padding(.leading, Theme.Spacing.md)
                failedCallRow(api: "GSTN API", error: "Rate limit exceeded", time: "2 hr ago", retryable: false)
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    private func apiCard(name: String, endpoint: String, status: SystemHealth, latency: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle().fill(status.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Typography.subheadline)
                Text(endpoint).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(status.displayName).font(Theme.Typography.caption2).foregroundStyle(status.color).fontWeight(.semibold)
                Text(latency).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13).cardStyle(colorScheme: colorScheme)
    }

    private func failedCallRow(api: String, error: String, time: String, retryable: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(api).font(Theme.Typography.subheadline).fontWeight(.medium)
                Text(error).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.critical)
                Text(time).font(Theme.Typography.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            if retryable {
                Button {  } label: {
                    Label("Retry", systemImage: "arrow.clockwise").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.primary)
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    // MARK: - Shared Helpers
    private func editRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); value() }
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func toggleConfigRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); Toggle("", isOn: isOn).labelsHidden().tint(Theme.Colors.primary) }
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
    }

    private func stepper(value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        HStack {
            Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= step } } label: {
                Image(systemName: "minus.circle").foregroundStyle(Theme.Colors.primary)
            }.buttonStyle(.plain)
            Text(step >= 1 ? "\(Int(value.wrappedValue))\(suffix)" : String(format: "%.1f\(suffix)", value.wrappedValue))
                .font(Theme.Typography.mono).foregroundStyle(Theme.Colors.primary).frame(minWidth: 48)
            Button { if value.wrappedValue < range.upperBound { value.wrappedValue += step } } label: {
                Image(systemName: "plus.circle").foregroundStyle(Theme.Colors.primary)
            }.buttonStyle(.plain)
        }
    }

    private func saveButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation { configSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { configSaved = false }
        } label: {
            HStack {
                Image(systemName: configSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(configSaved ? "Saved!" : label).fontWeight(.medium)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: Theme.Layout.buttonHeight)
            .background(configSaved ? Theme.Colors.success : Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }.buttonStyle(.plain)
    }

    private func ruleInfoRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.Colors.success)
            Text(text).font(Theme.Typography.subheadline)
            Spacer()
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func flowStepRow(step: String, title: String, desc: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 32, height: 32)
                Text(step).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.subheadline).fontWeight(.medium)
                Text(desc).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func escRow(trigger: String, to: String, priority: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger).font(Theme.Typography.subheadline)
                Text("→ \(to)").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let c: Color = priority == "Critical" ? Theme.Colors.critical : priority == "High" ? Theme.Colors.warning : Theme.Colors.primary
            GenericBadge(text: priority, color: c)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13)
    }
}

// MARK: - Edit User Sheet (Local to System Control)
struct EditUserSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var selectedRole: UserRole
    @State private var branch: String
    @State private var newBranchName = ""
    
    init(adminVM: AdminViewModel, user: User) {
        self.adminVM = adminVM
        self.user = user
        _name = State(initialValue: user.name)
        _selectedRole = State(initialValue: user.role)
        _branch = State(initialValue: user.branch)
    }
    
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
                    Picker("Branch", selection: $branch) {
                        ForEach(adminVM.branches, id: \.self) { b in
                            Text(b).tag(b)
                        }
                        Text("+ Create New Branch").tag("+ Create New Branch")
                    }
                    if branch == "+ Create New Branch" {
                        TextField("New Branch Name", text: $newBranchName)
                    }
                }
                
                Section("Account (Read-only)") {
                    HStack {
                        Text("Email").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.email).foregroundStyle(.primary)
                    }
                    HStack {
                        Text("Employee ID").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.id).foregroundStyle(.primary)
                    }
                    HStack {
                        Text("Phone").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.phone).foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Edit: \(user.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var finalBranch = branch
                        if branch == "+ Create New Branch" {
                            adminVM.createBranch(newBranchName)
                            finalBranch = newBranchName
                        }
                        adminVM.updateUser(userId: user.id, name: name, role: selectedRole, branch: finalBranch)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
