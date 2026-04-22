//
//  ManagerApprovalsView.swift
//  lms_project
//

import SwiftUI

struct ManagerApprovalsView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { sidebarCollapsed.toggle() }
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
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.primary).font(.system(size: 14, weight: .bold))
                TextField("Search applications...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // List Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Approval Queue")
                        .font(.system(size: 17, weight: .bold))
                    Text("Review applications pending your final decision.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(applicationsVM.filteredApplications.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AppFilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        withAnimation { applicationsVM.filterStatus = nil }
                    }
                    AppFilterChip(label: "Pending", isSelected: applicationsVM.filterStatus == .underReview) {
                        withAnimation { applicationsVM.filterStatus = .underReview }
                    }
                    AppFilterChip(label: "Approved", isSelected: applicationsVM.filterStatus == .approved) {
                        withAnimation { applicationsVM.filterStatus = .approved }
                    }
                    AppFilterChip(label: "Rejected", isSelected: applicationsVM.filterStatus == .rejected) {
                        withAnimation { applicationsVM.filterStatus = .rejected }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            Divider()

            if applicationsVM.filteredApplications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 32, weight: .thin)).foregroundStyle(Theme.Colors.primary.opacity(0.3))
                    Text("No applications found").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(applicationsVM.filteredApplications) { app in
                            ApplicationRow(
                                application: app,
                                isSelected: applicationsVM.selectedApplication?.id == app.id,
                                useMinimalStyle: true
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    applicationsVM.selectApplication(app)
                                }
                            }
                            Divider().padding(.leading, 72)
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
                    VStack(alignment: .leading, spacing: 24) {
                        detailHeader(app)
                        financialSection(app)
                        borrowerInfoSection(app)
                        documentsSummarySection(app)
                        verificationSection(app)
                        conversationSection(app)
                    }
                    .padding(20)
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
                        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.badge.questionmark").font(.system(size: 48, weight: .thin)).foregroundStyle(Theme.Colors.primary.opacity(0.4))
                    Text("Select an application to review").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Detail Header
    private func detailHeader(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 56, height: 56)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(app.borrower.name).font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    Text(app.loan.amount.currencyFormatted + " · " + app.loan.type.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.primary)
                    Text("ID: \(app.id)").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
            
            HStack(spacing: 20) {
                metaLabel(app.borrower.employer, systemImage: "building.2.fill")
                metaLabel(app.borrower.employmentType, systemImage: "person.text.rectangle.fill")
                metaLabel(app.borrower.phone, systemImage: "phone.fill")
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)

            HStack {
                Label("Loan Officer Assessed", systemImage: "person.badge.shield.checkered.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                Spacer()
                Text("Due: \(app.slaDeadline.shortFormatted)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Theme.Colors.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
    
    private func metaLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 11))
            Text(text)
        }
    }

    // MARK: - Borrower Info
    private func borrowerInfoSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Borrower Profile", icon: "person.crop.square.fill")
                .description("Detailed personal and employment information for background check.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private func infoCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).textCase(.uppercase)
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    // MARK: - Financials
    private func financialSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Risk & Credit Analysis", icon: "gauge.with.needle.fill")
                .description("Key financial indicators, CIBIL score, and DTI ratios for risk mitigation.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                finCard("Monthly Income",  app.financials.monthlyIncome.currencyFormatted, "dollarsign.circle.fill", Theme.Colors.primary)
                finCard("CIBIL Score",     "\(app.financials.cibilScore)", "bolt.fill", cibilColor(app.financials.cibilScore))
                finCard("DTI Ratio",       app.financials.dtiRatio.percentFormatted, "chart.pie.fill", dtiColor(app.financials.dtiRatio))
                finCard("Annual Income",   app.financials.annualIncome.currencyFormatted, "calendar.badge.clock", Theme.Colors.primary)
                finCard("Bank Balance",    app.financials.bankBalance.currencyFormatted, "building.columns.fill", Theme.Colors.primary)
                finCard("Risk Assessment", app.riskLevel.displayName, "shield.lefthalf.filled", app.riskLevel.color)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private func finCard(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint)
                Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).textCase(.uppercase)
            }
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    private func cibilColor(_ s: Int) -> Color { s >= 750 ? Theme.Colors.success : s >= 650 ? Theme.Colors.warning : Theme.Colors.critical }
    private func dtiColor(_ r: Double) -> Color { r <= 0.30 ? Theme.Colors.success : r <= 0.40 ? Theme.Colors.warning : Theme.Colors.critical }

    // MARK: - Documents
    private func documentsSummarySection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Document Verification", icon: "doc.on.doc.fill")
                .description("Final checklist of all verified documents submitted by the borrower.")
            VStack(spacing: 0) {
                ForEach(app.documents) { doc in
                    HStack {
                        Image(systemName: doc.type.icon).font(.system(size: 14)).foregroundStyle(Theme.Colors.primary).frame(width: 24)
                        Text(doc.label).font(Theme.Typography.subheadline).foregroundStyle(.primary)
                        Spacer()
                        DocStatusBadge(status: doc.status)
                    }
                    .padding(.vertical, 12)
                    if doc.id != app.documents.last?.id { Divider() }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Verification
    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Identity & Fraud Checks", icon: "checkmark.shield.fill")
                .description("AI-powered verification results for identity and financial documents.")
            ForEach(app.verification) { item in VerificationRow(item: item) }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Conversation
    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Activity & Remarks", icon: "bubble.left.and.exclamationmark.bubble.right.fill")
            let messages = applicationsVM.messagesForApplication(app.id)
            VStack(spacing: 12) {
                ForEach(messages) { msg in messageBubble(msg) }
            }
            HStack(spacing: 12) {
                TextField("Add remark for Loan Officer...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id, senderName: "Deepak Mehta",
                        senderRole: "Manager", isManagerRemark: true)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                        .foregroundStyle(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Color.secondary.opacity(0.3) : Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .onAppear { applicationsVM.loadApplicationMessages(for: app.id) }
    }

    private func messageBubble(_ msg: ApplicationMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isFromCurrentUser || msg.type == .managerRemark { Spacer(minLength: 80) }
            VStack(alignment: (msg.isFromCurrentUser || msg.type == .managerRemark) ? .trailing : .leading, spacing: 4) {
                if msg.type == .managerRemark {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill").font(.system(size: 10))
                        Text("MANAGER REMARK").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.primary)
                } else {
                    Text("\(msg.senderName)").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                }
                Text(msg.text)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(msg.type == .managerRemark ? .white : (msg.isFromCurrentUser ? .white : .primary))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        msg.type == .managerRemark ? Theme.Colors.primary
                        : (msg.isFromCurrentUser ? Theme.Colors.primary.opacity(0.8) : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(msg.timestamp.timeFormatted).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            if !(msg.isFromCurrentUser || msg.type == .managerRemark) { Spacer(minLength: 80) }
        }
    }

    // MARK: - Section Label
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.Colors.primary)
            Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(1.0)
        }
    }

    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill").font(.system(size: 48)).foregroundStyle(Theme.Colors.critical)
                    Text("Rejection Remarks").font(Theme.Typography.title)
                }
                .padding(.top)
                
                Text("Explain why this application is being rejected.")
                    .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                
                TextEditor(text: $applicationsVM.rejectionRemarksText)
                    .padding(12)
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1))
                    .frame(height: 180).padding(.horizontal)
                
                Button { applicationsVM.confirmRejectWithRemarks() } label: {
                    Text("Confirm Rejection").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Theme.Colors.critical)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(applicationsVM.rejectionRemarksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
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
                Section {
                    Picker("Reason", selection: $applicationsVM.sendBackReason) {
                        Text("Incomplete documentation").tag("Incomplete documentation")
                        Text("Income mismatch detected").tag("Income mismatch detected")
                        Text("Property documents unclear").tag("Property documents unclear")
                        Text("Other").tag("Other")
                    }
                    if applicationsVM.sendBackReason == "Other" {
                        TextField("Enter reason...", text: $applicationsVM.sendBackCustomRemark)
                    } else {
                        TextField("Additional notes...", text: $applicationsVM.sendBackCustomRemark)
                    }
                } header: {
                    Text("Send Back to Loan Officer")
                }
                
                Section {
                    Button { applicationsVM.confirmSendBack() } label: {
                        Text("Send Back").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .listRowBackground(Theme.Colors.warning)
                    .disabled(applicationsVM.sendBackReason == "Other" &&
                              applicationsVM.sendBackCustomRemark.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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
