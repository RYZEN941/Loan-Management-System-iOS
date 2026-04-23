//
//  LOApplicationsView.swift
//  lms_project
//
//  Applications tab for Loan Officer.
//  Features: collapsable sidebar, filter chips (default: Under Review),
//  financial details on top, documents with upload, internal remarks.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Main View

struct LOApplicationsView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var showNewApplication = false
    @State private var sidebarCollapsed   = false
    
    @State private var showAddDocumentAlert = false
    @State private var newDocumentName = ""

    private let sidebarWidth: CGFloat = 320

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // ── Collapsable sidebar ──────────────────────────
                        if !sidebarCollapsed {
                            applicationListPanel
                                .frame(width: sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))

                            Divider()
                        }

                        // ── Detail panel ─────────────────────────────────
                        applicationDetailPanel(collapsed: sidebarCollapsed)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Sidebar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.left")
                            .symbolVariant(sidebarCollapsed ? .none : .fill)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showNewApplication = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear { applicationsVM.loadData() }
            .alert("Action", isPresented: $applicationsVM.showActionAlert) {
                Button("OK") {}
            } message: {
                Text(applicationsVM.actionMessage ?? "")
            }
            .sheet(isPresented: $applicationsVM.showXMLUploadResult) { xmlResultSheet }
            .sheet(isPresented: $showNewApplication) {
                CreateApplicationSheet(applicationsVM: applicationsVM)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: sidebarCollapsed)
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Sidebar: Application List
    // ────────────────────────────────────────────────────────────────

    private var applicationListPanel: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.primary)
                    .font(.system(size: 14, weight: .bold))
                TextField("Search applications...", text: $applicationsVM.searchText)
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

            // List Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Applications")
                        .font(.system(size: 17, weight: .bold))
                    Text("Browse and manage your assigned loan cases.")
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

            // Filter chips — only key statuses
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AppFilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        withAnimation(.spring(response: 0.3)) { applicationsVM.filterStatus = nil }
                    }
                    AppFilterChip(label: "Pending", isSelected: applicationsVM.filterStatus == .pending) {
                        withAnimation(.spring(response: 0.3)) { applicationsVM.filterStatus = .pending }
                    }
                    AppFilterChip(label: "In Review", isSelected: applicationsVM.filterStatus == .underReview) {
                        withAnimation(.spring(response: 0.3)) { applicationsVM.filterStatus = .underReview }
                    }
                    AppFilterChip(label: "Approved", isSelected: applicationsVM.filterStatus == .approved) {
                        withAnimation(.spring(response: 0.3)) { applicationsVM.filterStatus = .approved }
                    }
                    AppFilterChip(label: "Rejected", isSelected: applicationsVM.filterStatus == .rejected) {
                        withAnimation(.spring(response: 0.3)) { applicationsVM.filterStatus = .rejected }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            Divider()

            // List
            if applicationsVM.filteredApplications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(Theme.Colors.primary.opacity(0.3))
                    Text("No applications found")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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

    // ────────────────────────────────────────────────────────────────
    // MARK: - Detail Panel
    // ────────────────────────────────────────────────────────────────

    private func applicationDetailPanel(collapsed: Bool) -> some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header row
                        detailHeader(app)

                        if collapsed {
                            // Wide layout: financials + docs side by side
                            HStack(alignment: .top, spacing: 20) {
                                VStack(alignment: .leading, spacing: 20) {
                                    financialSection(app)
                                    documentsSection(app)
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 20) {
                                    verificationSection(app)
                                    internalRemarksSection(app)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            conversationSection(app)
                        } else {
                            // Normal stacked layout
                            financialSection(app)
                            documentsSection(app)
                            verificationSection(app)
                            internalRemarksSection(app)
                            conversationSection(app)
                        }
                    }
                    .padding(18)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    LOActionPanel(
                        onSendToManager: { applicationsVM.sendToManager(app) },
                        onReject: { applicationsVM.rejectApplication(app) },
                        onRequestDocs: { applicationsVM.requestDocuments(app) }
                    )
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select an application")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Detail Header
    // ────────────────────────────────────────────────────────────────

    private func detailHeader(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Avatar with Gradient
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary)
                        .frame(width: 60, height: 60)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(app.borrower.name)
                            .font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    
                    HStack(spacing: 6) {
                        Text(app.loan.amount.currencyFormatted)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.primary)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(app.loan.type.displayName)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("ID: \(app.id)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            // Borrower meta row
            HStack(spacing: 20) {
                metaItem(icon: "building.2.fill", text: app.borrower.employer)
                metaItem(icon: "person.text.rectangle.fill", text: app.borrower.employmentType)
                metaItem(icon: "phone.fill", text: app.borrower.phone)
                Spacer()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.adaptiveSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12))
            Text(text)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Financial Section
    // ────────────────────────────────────────────────────────────────

    private func financialSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Financial Details", icon: "indianrupeesign.circle")
                .description("Verified income, expenses, and credit risk assessment data.")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                finCard("Monthly Income",  app.financials.monthlyIncome.currencyFormatted,  "arrow.up.circle",        .primary)
                finCard("Annual Income",   app.financials.annualIncome.currencyFormatted,   "calendar",               .primary)
                finCard("Existing EMI",    app.financials.existingEMI.currencyFormatted,    "arrow.down.circle",      .secondary)
                finCard("CIBIL Score",     "\(app.financials.cibilScore)",                  "chart.bar",              cibilColor(app.financials.cibilScore))
                finCard("DTI Ratio",       app.financials.dtiRatio.percentFormatted,        "percent",                dtiColor(app.financials.dtiRatio))
                finCard("Bank Balance",    app.financials.bankBalance.currencyFormatted,     "building.columns",       .primary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private func finCard(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(tint.opacity(0.7))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    private func cibilColor(_ s: Int)    -> Color { s >= 750 ? Theme.Colors.success : s >= 650 ? Theme.Colors.neutral : Theme.Colors.critical }
    private func dtiColor(_ r: Double)   -> Color { r <= 0.30 ? Theme.Colors.success : r <= 0.40 ? Theme.Colors.neutral : Theme.Colors.critical }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Documents Section
    // ────────────────────────────────────────────────────────────────

    private func documentsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Required Documents", icon: "doc.fill")
                .description("Upload and verify necessary documentation for loan eligibility.")
                .info { /* Info Action */ }

            ForEach(app.documents) { doc in
                DocumentUploadRow(
                    doc: doc,
                    uploadedFiles: applicationsVM.uploadedFiles[doc.id] ?? [],
                    onUpload: { file in
                        applicationsVM.recordUploadedFile(file, forDocumentId: doc.id)
                    }
                )
            }
            
            Button {
                newDocumentName = ""
                showAddDocumentAlert = true
            } label: {
                Label("Add Other Document", systemImage: "plus.circle")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.primary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
        )
        .alert("Add Document", isPresented: $showAddDocumentAlert) {
            TextField("Document Name", text: $newDocumentName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                if !newDocumentName.trimmingCharacters(in: .whitespaces).isEmpty {
                    applicationsVM.addOtherDocument(to: app, label: newDocumentName)
                }
            }
        } message: {
            Text("Enter a name for the new document.")
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Verification Section
    // ────────────────────────────────────────────────────────────────

    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "AI Verification", icon: "cpu.fill")
                .description("Automated data cross-referencing and authenticity checks.")
                .info { /* Info Action */ }

            let mismatches = app.verification.filter { !$0.isMatch }.count
            if mismatches > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.critical)
                    Text("\(mismatches) mismatch\(mismatches > 1 ? "es" : "") found")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.critical)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.Colors.critical.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            ForEach(app.verification) { item in
                VerificationRow(item: item)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Internal Remarks
    // ────────────────────────────────────────────────────────────────

    private func internalRemarksSection(_ app: LoanApplication) -> some View {
        InternalRemarksView(app: app, applicationsVM: applicationsVM)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.adaptiveSurface(colorScheme)))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Conversation Section
    // ────────────────────────────────────────────────────────────────

    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Conversation", icon: "bubble.left.and.bubble.right")

            let messages = applicationsVM.messagesForApplication(app.id)
            VStack(spacing: 8) {
                ForEach(messages) { msg in
                    appMessageBubble(msg)
                }
            }

            HStack(spacing: 10) {
                TextField("Type a message...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )

                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id,
                        senderName: "Amit Singh",
                        senderRole: "Loan Officer"
                    )
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.35)
                            : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .onAppear { applicationsVM.loadApplicationMessages(for: app.id) }
    }

    private func appMessageBubble(_ msg: ApplicationMessage) -> some View {
        Group {
            if msg.type == .managerRemark {
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered").font(.system(size: 11))
                        Text("Manager · \(msg.senderName)").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    Text(msg.text)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    if msg.isFromCurrentUser { Spacer(minLength: 60) }
                    VStack(alignment: msg.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                        if !msg.isFromCurrentUser {
                            Text(msg.senderName).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Text(msg.text)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(msg.isFromCurrentUser ? Color.white : Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(msg.isFromCurrentUser ? Theme.Colors.primary : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Text(msg.timestamp.timeFormatted)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if !msg.isFromCurrentUser { Spacer(minLength: 60) }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - XML Result Sheet
    // ────────────────────────────────────────────────────────────────

    private var xmlResultSheet: some View {
        NavigationStack {
            if let result = applicationsVM.xmlParseResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parsed Data").font(Theme.Typography.title)
                            infoRow("Account Holder", result.accountHolder)
                            infoRow("Bank",            result.bankName)
                            infoRow("Account",         result.accountNumber)
                            infoRow("Monthly Income",  result.monthlyIncome.currencyFormatted)
                            infoRow("Avg Balance",     result.averageBalance.currencyFormatted)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transactions").font(Theme.Typography.headline)
                            ForEach(result.transactions) { txn in
                                HStack {
                                    Image(systemName: txn.type == .credit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                    VStack(alignment: .leading) {
                                        Text(txn.description).font(Theme.Typography.subheadline)
                                        Text(txn.date.shortFormatted).font(Theme.Typography.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text((txn.type == .credit ? "+" : "-") + txn.amount.currencyFormatted)
                                        .font(Theme.Typography.mono)
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .navigationTitle("XML Result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { applicationsVM.showXMLUploadResult = false }
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typography.subheadline).foregroundStyle(.primary)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Shared helpers
    // ────────────────────────────────────────────────────────────────

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.primary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Document Upload Row
// ────────────────────────────────────────────────────────────────────

struct DocumentUploadRow: View {
    let doc: LoanDocument
    let uploadedFiles: [UploadedDocFile]
    let onUpload: (UploadedDocFile) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showPicker     = false
    @State private var showCamera     = false
    @State private var showOptions    = false
    @State private var selectedPhotos : [PhotosPickerItem] = []
    @State private var previewFile    : UploadedDocFile?   = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: doc.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.label)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.primary)
                    Text(doc.status.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                // Upload button
                Button {
                    showOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 14))
                        Text("Upload")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .confirmationDialog("Upload Document", isPresented: $showOptions, titleVisibility: .visible) {
                    Button("Choose from Files") { showPicker = true }
                    Button("Take Photo")        { showCamera = true }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding(.vertical, 10)

            // Uploaded files list
            if !uploadedFiles.isEmpty {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 36)
                    ForEach(uploadedFiles) { file in
                        Button {
                            previewFile = file
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: file.isImage ? "photo" : "doc.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.primary)
                                    .frame(width: 20)
                                Text(file.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(file.uploadedAt.timeFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.leading, 36)
                            .padding(.trailing, 4)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if file.id != uploadedFiles.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
            )
        // File picker
        .photosPicker(isPresented: $showPicker, selection: $selectedPhotos, maxSelectionCount: 1, matching: .any(of: [.images, .videos]))
        .onChange(of: selectedPhotos) { _, items in
            guard let item = items.first else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let name = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                    let file = UploadedDocFile(name: name, url: nil, isImage: true, uploadedAt: Date())
                    await MainActor.run { onUpload(file); selectedPhotos = [] }
                }
            }
        }
        // Document preview sheet
        .sheet(item: $previewFile) { file in
            DocumentPreviewSheet(file: file)
        }
    }

    private var statusColor: Color {
        switch doc.status {
        case .pending:   return Theme.Colors.neutral
        case .uploaded:  return Theme.Colors.primary
        case .verified:  return Theme.Colors.success
        case .rejected:  return Theme.Colors.critical
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Document Preview Sheet
// ────────────────────────────────────────────────────────────────────

struct DocumentPreviewSheet: View {
    let file: UploadedDocFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: file.isImage ? "photo.fill" : "doc.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Colors.primary.opacity(0.6))
                Text(file.name)
                    .font(Theme.Typography.headline)
                Text("Uploaded \(file.uploadedAt.fullFormatted)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Internal Remarks View
// ────────────────────────────────────────────────────────────────────

struct InternalRemarksView: View {
    let app: LoanApplication
    @ObservedObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var remarkText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.primary)
                Text("Internal Remarks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("Visible to staff only")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Remarks list
            if app.internalRemarks.isEmpty {
                Text("No remarks yet")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(app.internalRemarks) { remark in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(remark.author)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.primary)
                                Spacer()
                                Text(remark.timestamp.relativeFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(remark.text)
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(10)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
            }

            // Input
            HStack(spacing: 8) {
                TextField("Add internal remark...", text: $remarkText, axis: .vertical)
                    .font(Theme.Typography.subheadline)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
                    .focused($focused)

                Button {
                    applicationsVM.addInternalRemark(
                        applicationId: app.id,
                        text: remarkText,
                        author: "Amit Singh"
                    )
                    remarkText = ""
                    focused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            remarkText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.35)
                            : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(remarkText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Filter Chip
// ────────────────────────────────────────────────────────────────────

struct AppFilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.Colors.primary : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Backwards-compatible alias so ManagerApprovalsView keeps compiling unchanged.
typealias FilterChip = AppFilterChip

// ────────────────────────────────────────────────────────────────────
// MARK: - Create Application Sheet
// ────────────────────────────────────────────────────────────────────

struct CreateApplicationSheet: View {
    @ObservedObject var applicationsVM: ApplicationsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var borrowerName    = ""
    @State private var borrowerPhone   = ""
    @State private var borrowerEmail   = ""
    @State private var borrowerProfileID = ""
    @State private var borrowerAddress = ""
    @State private var selectedLoanProductID = ""
    @State private var loanAmountText  = ""
    @State private var tenureText      = ""
    @State private var monthlyIncomeText = ""
    @State private var existingEMIText   = ""
    @State private var xmlParsed         = false
    @State private var isSubmitting      = false
    @State private var submitError       = ""
    @State private var showSubmitError   = false
    @State private var isResolvingBorrower = false
    @State private var borrowerLookupHint = ""
    @State private var lookupTask: Task<Void, Never>? = nil
    
    // Dynamic documents
    struct NewDocument: Identifiable {
        let id = UUID()
        var type: DocumentType
        var label: String
        var isUploaded: Bool
    }
    @State private var newDocuments: [NewDocument] = [
        NewDocument(type: .panCard, label: "PAN Card", isUploaded: false),
        NewDocument(type: .aadhaar, label: "Aadhaar Card", isUploaded: false),
        NewDocument(type: .bankStatement, label: "Bank Statement", isUploaded: false)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Borrower Information
                        formSection(title: "Borrower Information", icon: "person.fill") {
                            VStack(spacing: 16) {
                                customTextField("Full Name", text: $borrowerName, icon: "person")
                                HStack(spacing: 16) {
                                    customTextField("Phone", text: $borrowerPhone, icon: "phone").keyboardType(.phonePad)
                                    customTextField("Email", text: $borrowerEmail, icon: "envelope").keyboardType(.emailAddress).autocapitalization(.none)
                                }
                                customTextField("Borrower Profile ID", text: $borrowerProfileID, icon: "person.text.rectangle")
                                if isResolvingBorrower || !borrowerLookupHint.isEmpty {
                                    HStack(spacing: 6) {
                                        if isResolvingBorrower {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: borrowerProfileID.isEmpty ? "exclamationmark.circle" : "checkmark.circle")
                                                .foregroundStyle(borrowerProfileID.isEmpty ? Theme.Colors.warning : Theme.Colors.success)
                                        }
                                        Text(isResolvingBorrower ? "Resolving borrower profile..." : borrowerLookupHint)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                customTextField("Residential Address", text: $borrowerAddress, icon: "mappin.and.ellipse", isMultiline: true)
                            }
                        }
                        
                        // Section 2: Loan Details
                        formSection(title: "Loan Parameters", icon: "indianrupeesign.circle.fill") {
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Loan Type").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                                        Picker("Loan Type", selection: $selectedLoanProductID) {
                                            if applicationsVM.availableLoanProducts.isEmpty {
                                                Text("No products available").tag("")
                                            } else {
                                                ForEach(applicationsVM.availableLoanProducts) { product in
                                                    Text(product.name).tag(product.id)
                                                }
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    customTextField("Tenure (months)", text: $tenureText, icon: "calendar").keyboardType(.numberPad)
                                }
                                
                                customTextField("Requested Loan Amount (₹)", text: $loanAmountText, icon: "banknote").keyboardType(.numberPad)
                            }
                        }
                        
                        // Section 3: Financials & XML
                        formSection(title: "Financial Profile", icon: "chart.bar.doc.horizontal.fill") {
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    customTextField("Monthly Income (₹)", text: $monthlyIncomeText, icon: "arrow.up.right.circle").keyboardType(.numberPad)
                                    customTextField("Existing EMI (₹)", text: $existingEMIText, icon: "arrow.down.left.circle").keyboardType(.numberPad)
                                }
                                
                                Button {
                                    withAnimation {
                                        applicationsVM.simulateXMLUpload()
                                        xmlParsed = true
                                        if let r = applicationsVM.xmlParseResult {
                                            monthlyIncomeText = String(Int(r.monthlyIncome))
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: xmlParsed ? "checkmark.seal.fill" : "doc.viewfinder.fill")
                                        Text(xmlParsed ? "Bank Statement Parsed Successfully" : "Auto-fill via Bank Statement (XML)")
                                            .fontWeight(.semibold)
                                    }
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(xmlParsed ? .white : Theme.Colors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(xmlParsed ? Theme.Colors.success : Theme.Colors.primary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        // Section 4: Documents
                        formSection(title: "Required Documents", icon: "doc.on.doc.fill") {
                            VStack(spacing: 12) {
                                ForEach($newDocuments) { $doc in
                                    HStack {
                                        Image(systemName: doc.type.icon)
                                            .foregroundStyle(Theme.Colors.primary)
                                            .frame(width: 24)
                                        Text(doc.label)
                                            .font(Theme.Typography.subheadline)
                                        Spacer()
                                        Button {
                                            withAnimation(.spring(response: 0.3)) { doc.isUploaded.toggle() }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: doc.isUploaded ? "checkmark.circle.fill" : "arrow.up.circle")
                                                Text(doc.isUploaded ? "Attached" : "Attach")
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(doc.isUploaded ? Theme.Colors.success : Theme.Colors.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(doc.isUploaded ? Theme.Colors.success.opacity(0.1) : Theme.Colors.primary.opacity(0.1))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                
                                Menu {
                                    ForEach(DocumentType.allCases) { type in
                                        Button(type.displayName) {
                                            withAnimation {
                                                newDocuments.append(NewDocument(type: type, label: type.displayName, isUploaded: false))
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Add Other Document", systemImage: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.primary)
                                        .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Loan Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction)  {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Text("Create Application")
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(canSubmit ? Theme.Colors.primary : Theme.Colors.neutral.opacity(0.2))
                        .foregroundStyle(canSubmit ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
        .alert("Unable to Create Application", isPresented: $showSubmitError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(submitError)
        }
        .task {
            if applicationsVM.availableLoanProducts.isEmpty {
                await applicationsVM.loadAvailableLoanProducts()
            }
            if selectedLoanProductID.isEmpty {
                selectedLoanProductID = applicationsVM.availableLoanProducts.first?.id ?? ""
            }
        }
        .onChange(of: applicationsVM.availableLoanProducts) { _, updatedProducts in
            if selectedLoanProductID.isEmpty {
                selectedLoanProductID = updatedProducts.first?.id ?? ""
            }
        }
        .onChange(of: borrowerEmail) { _, _ in
            scheduleBorrowerLookup()
        }
        .onChange(of: borrowerPhone) { _, _ in
            scheduleBorrowerLookup()
        }
    }

    // MARK: - Components

    private func formSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.primary)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            content()
                .padding(16)
                .background(Theme.Colors.adaptiveSurface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func customTextField(_ label: String, text: Binding<String>, icon: String, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.primary.opacity(0.7))
                    .frame(width: 16)
                
                if isMultiline {
                    TextField(label, text: text, axis: .vertical)
                        .lineLimit(2...4)
                } else {
                    TextField(label, text: text)
                }
            }
            .font(Theme.Typography.subheadline)
            .padding(12)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSubmit: Bool {
        !borrowerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !loanAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !borrowerProfileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedLoanProductID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let amount = Double(loanAmountText) ?? 0
        let tenure = Int(tenureText) ?? 12
        let income = Double(monthlyIncomeText) ?? 0
        let emi    = Double(existingEMIText) ?? 0
        let docs = newDocuments.map { doc in
            LoanDocument(
                id: UUID().uuidString,
                type: doc.type,
                label: doc.label,
                status: doc.isUploaded ? .uploaded : .pending,
                uploadedAt: doc.isUploaded ? Date() : nil
            )
        }

        isSubmitting = true
        Task {
            do {
                guard let selectedProduct = applicationsVM.availableLoanProducts.first(where: { $0.id == selectedLoanProductID }) else {
                    throw APIError.invalidArgument("Please select a valid loan product.")
                }
                try await applicationsVM.createBackendApplication(
                    borrowerProfileID: borrowerProfileID,
                    borrowerName: borrowerName,
                    borrowerPhone: borrowerPhone,
                    borrowerEmail: borrowerEmail,
                    borrowerAddress: borrowerAddress,
                    selectedLoanProduct: selectedProduct,
                    requestedAmount: amount,
                    tenureMonths: tenure,
                    monthlyIncome: income,
                    existingEMI: emi,
                    documents: docs
                )
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitError = (error as? LocalizedError)?.errorDescription ?? "Could not create application."
                    showSubmitError = true
                }
            }
        }
    }

    private func scheduleBorrowerLookup() {
        lookupTask?.cancel()

        let email = borrowerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = borrowerPhone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty || !phone.isEmpty else {
            isResolvingBorrower = false
            borrowerLookupHint = ""
            return
        }

        lookupTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                isResolvingBorrower = true
                borrowerLookupHint = ""
            }

            do {
                let resolved = try await applicationsVM.resolveBorrowerProfileID(email: email, phone: phone)
                if Task.isCancelled { return }
                await MainActor.run {
                    isResolvingBorrower = false
                    if let resolved, !resolved.isEmpty {
                        borrowerProfileID = resolved
                        borrowerLookupHint = "Borrower profile ID auto-filled."
                    } else {
                        borrowerLookupHint = "No borrower found for this email/phone."
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    isResolvingBorrower = false
                    borrowerLookupHint = "Could not auto-fetch borrower profile ID."
                }
            }
        }
    }
}
