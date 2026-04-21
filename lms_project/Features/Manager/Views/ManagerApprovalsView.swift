//
//  ManagerApprovalsView.swift
//  lms_project
//

import SwiftUI

struct ManagerApprovalsView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var sidebarCollapsed = false
    private let sidebarWidth: CGFloat = 320

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                GeometryReader { _ in
                    HStack(spacing: 0) {
                        if !sidebarCollapsed {
                            applicationListPanel
                                .frame(width: sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }
                        applicationDetailPanel
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) { sidebarCollapsed.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .symbolVariant(sidebarCollapsed ? .none : .fill)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear { applicationsVM.loadData() }
            .alert("Action", isPresented: $applicationsVM.showActionAlert) {
                Button("OK") {}
            } message: { Text(applicationsVM.actionMessage ?? "") }
            .sheet(isPresented: $applicationsVM.showRejectionRemarksSheet) { rejectionSheet }
            .sheet(isPresented: $applicationsVM.showSendBackSheet) { sendBackSheet }
        }
    }

    // MARK: - Sidebar
    private var applicationListPanel: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 14))
                TextField("Search applications...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AppFilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        applicationsVM.filterStatus = nil
                    }
                    AppFilterChip(label: "Under Review", isSelected: applicationsVM.filterStatus == .underReview) {
                        applicationsVM.filterStatus = .underReview
                    }
                    AppFilterChip(label: "Approved", isSelected: applicationsVM.filterStatus == .approved) {
                        applicationsVM.filterStatus = .approved
                    }
                    AppFilterChip(label: "Rejected", isSelected: applicationsVM.filterStatus == .rejected) {
                        applicationsVM.filterStatus = .rejected
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)

            HStack {
                Text("\(applicationsVM.filteredApplications.count) applications")
                    .font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.bottom, 4)

            Divider()

            if applicationsVM.filteredApplications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("No applications").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(applicationsVM.filteredApplications) { app in
                            ApplicationRow(application: app,
                                           isSelected: applicationsVM.selectedApplication?.id == app.id)
                                .onTapGesture { applicationsVM.selectApplication(app) }
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - Detail Panel
    private var applicationDetailPanel: some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailHeader(app)
                        financialSection(app)
                        borrowerInfoSection(app)
                        documentsSummarySection(app)
                        verificationSection(app)
                        conversationSection(app)
                    }
                    .padding(18)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    if app.status == .underReview {
                        ManagerActionPanel(
                            onApprove: { applicationsVM.approveApplication(app) },
                            onRejectWithRemarks: { applicationsVM.beginRejectWithRemarks(app) },
                            onSendBack: { applicationsVM.beginSendBack(app) }
                        )
                        .background(Theme.Colors.adaptiveSurface(colorScheme))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle").font(.system(size: 36)).foregroundStyle(.tertiary)
                    Text("Select an application to review").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Detail Header
    private func detailHeader(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(Theme.Colors.primary.opacity(0.1)).frame(width: 48, height: 48)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(app.borrower.name).font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    Text(app.loan.amount.currencyFormatted + " · " + app.loan.type.displayName)
                        .font(Theme.Typography.subheadline).foregroundStyle(Theme.Colors.primary)
                    Text("ID: \(app.id)").font(Theme.Typography.caption).foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 16) {
                Label(app.borrower.employer, systemImage: "building.2")
                Label(app.borrower.employmentType, systemImage: "person.fill")
                Label(app.borrower.phone, systemImage: "phone")
            }
            .font(.system(size: 12)).foregroundStyle(.secondary)

            // Submitted by row
            HStack(spacing: 6) {
                Image(systemName: "person.badge.clock").font(.system(size: 12)).foregroundStyle(Theme.Colors.primary)
                Text("Submitted by: Loan Officer").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.primary)
                Spacer()
                Text("SLA: \(app.slaDeadline.shortFormatted)").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Theme.Colors.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    // MARK: - Borrower Info
    private func borrowerInfoSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Borrower Details", icon: "person.text.rectangle")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoCard("Full Name", app.borrower.name)
                infoCard("Email", app.borrower.email)
                infoCard("Phone", app.borrower.phone)
                infoCard("Employer", app.borrower.employer)
                infoCard("Employment", app.borrower.employmentType)
                infoCard("Loan Tenure", "\(app.loan.tenure) months")
                infoCard("Interest Rate", String(format: "%.2f%%", app.loan.interestRate))
                infoCard("EMI", app.loan.emi.currencyFormatted)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    private func infoCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 14, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    // MARK: - Financials
    private func financialSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Financial Summary", icon: "indianrupeesign.circle")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                finCard("Monthly Income",  app.financials.monthlyIncome.currencyFormatted, "arrow.up.circle", Theme.Colors.primary)
                finCard("CIBIL Score",     "\(app.financials.cibilScore)", "chart.bar", cibilColor(app.financials.cibilScore))
                finCard("DTI Ratio",       app.financials.dtiRatio.percentFormatted, "percent", dtiColor(app.financials.dtiRatio))
                finCard("Annual Income",   app.financials.annualIncome.currencyFormatted, "calendar", Theme.Colors.primary)
                finCard("Bank Balance",    app.financials.bankBalance.currencyFormatted, "building.columns", Theme.Colors.primary)
                finCard("Risk Level",      app.riskLevel.displayName, "exclamationmark.shield", app.riskLevel.color)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    private func finCard(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(tint.opacity(0.7))
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private func cibilColor(_ s: Int) -> Color { s >= 750 ? Theme.Colors.success : s >= 650 ? Theme.Colors.neutral : Theme.Colors.critical }
    private func dtiColor(_ r: Double) -> Color { r <= 0.30 ? Theme.Colors.success : r <= 0.40 ? Theme.Colors.neutral : Theme.Colors.critical }

    // MARK: - Documents
    private func documentsSummarySection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Documents", icon: "doc.fill")
            ForEach(app.documents) { doc in
                HStack {
                    Image(systemName: doc.type.icon).font(.system(size: 14)).foregroundStyle(.secondary).frame(width: 20)
                    Text(doc.label).font(Theme.Typography.subheadline)
                    Spacer()
                    DocStatusBadge(status: doc.status)
                }
                .padding(.vertical, 4)
                if doc.id != app.documents.last?.id { Divider() }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    // MARK: - Verification
    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Verification", icon: "cpu")
            ForEach(app.verification) { item in VerificationRow(item: item) }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    // MARK: - Conversation
    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Conversation & Remarks", icon: "bubble.left.and.bubble.right")
            let messages = applicationsVM.messagesForApplication(app.id)
            VStack(spacing: 8) {
                ForEach(messages) { msg in messageBubble(msg) }
            }
            HStack(spacing: 10) {
                TextField("Add remark...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id, senderName: "Deepak Mehta",
                        senderRole: "Manager", isManagerRemark: true)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                        .foregroundStyle(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Color.secondary.opacity(0.35) : Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .onAppear { applicationsVM.loadApplicationMessages(for: app.id) }
    }

    private func messageBubble(_ msg: ApplicationMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isFromCurrentUser || msg.type == .managerRemark { Spacer(minLength: 60) }
            VStack(alignment: (msg.isFromCurrentUser || msg.type == .managerRemark) ? .trailing : .leading, spacing: 2) {
                if msg.type == .managerRemark {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered").font(.system(size: 11))
                        Text("Manager: \(msg.senderName)").font(Theme.Typography.caption2)
                    }
                    .foregroundStyle(Theme.Colors.secondary)
                } else {
                    Text("\(msg.senderName) (\(msg.senderRole))").font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
                Text(msg.text)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(msg.type == .managerRemark ? Theme.Colors.secondary : (msg.isFromCurrentUser ? .white : .primary))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        msg.type == .managerRemark ? Theme.Colors.secondary.opacity(0.1)
                        : (msg.isFromCurrentUser ? Theme.Colors.primary : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(msg.timestamp.timeFormatted).font(Theme.Typography.caption).foregroundStyle(.tertiary)
            }
            if !(msg.isFromCurrentUser || msg.type == .managerRemark) { Spacer(minLength: 60) }
        }
    }

    // MARK: - Section Label
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Theme.Colors.primary)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.4)
        }
    }

    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                Text("Rejection Remarks").font(Theme.Typography.headline).padding(.top)
                Text("Please provide a reason for rejecting this application.")
                    .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                TextEditor(text: $applicationsVM.rejectionRemarksText)
                    .font(Theme.Typography.body).padding()
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(height: 150).padding(.horizontal)
                Button { applicationsVM.confirmRejectWithRemarks() } label: {
                    Text("Reject Application").fontWeight(.semibold).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.Colors.critical)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .padding()
                .disabled(applicationsVM.rejectionRemarksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .navigationTitle("Reject").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { applicationsVM.showRejectionRemarksSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Send Back Sheet
    private var sendBackSheet: some View {
        NavigationStack {
            Form {
                Section("Reason for Sending Back") {
                    Picker("Select Reason", selection: $applicationsVM.sendBackReason) {
                        Text("Incomplete documentation").tag("Incomplete documentation")
                        Text("Income mismatch detected").tag("Income mismatch detected")
                        Text("Property documents unclear").tag("Property documents unclear")
                        Text("Re-evaluate eligibility").tag("Re-evaluate eligibility")
                        Text("Other").tag("Other")
                    }
                    .pickerStyle(.menu)
                    if applicationsVM.sendBackReason == "Other" {
                        TextField("Enter custom remark", text: $applicationsVM.sendBackCustomRemark)
                    } else {
                        TextField("Additional remarks (optional)", text: $applicationsVM.sendBackCustomRemark)
                    }
                }
                Button { applicationsVM.confirmSendBack() } label: {
                    Text("Send Back Application").fontWeight(.semibold).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.Colors.warning)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .listRowBackground(Color.clear)
                .disabled(applicationsVM.sendBackReason == "Other" &&
                          applicationsVM.sendBackCustomRemark.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Send Back").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { applicationsVM.showSendBackSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
