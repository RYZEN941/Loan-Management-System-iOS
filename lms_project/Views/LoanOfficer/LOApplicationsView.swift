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
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField("Search...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Filter chips — only key statuses
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AppFilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        applicationsVM.filterStatus = nil
                    }
                    AppFilterChip(label: "Pending", isSelected: applicationsVM.filterStatus == .new) {
                        applicationsVM.filterStatus = .new
                    }
                    AppFilterChip(label: "Under Review", isSelected: applicationsVM.filterStatus == .underReview) {
                        applicationsVM.filterStatus = .underReview
                    }
                    AppFilterChip(label: "Recommended", isSelected: applicationsVM.filterStatus == .recommended) {
                        applicationsVM.filterStatus = .recommended
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

            // Count
            HStack {
                Text("\(applicationsVM.filteredApplications.count) applications")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            Divider()

            // List
            if applicationsVM.filteredApplications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No applications")
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
                                isSelected: applicationsVM.selectedApplication?.id == app.id
                            )
                            .onTapGesture { applicationsVM.selectApplication(app) }
                            Divider().padding(.leading, 56)
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
                        onRecommend: { applicationsVM.recommendApplication(app) },
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(app.borrower.name)
                            .font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    Text(app.loan.amount.currencyFormatted + " · " + app.loan.type.displayName)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.primary)
                    Text("ID: \(app.id)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Borrower meta row
            HStack(spacing: 20) {
                metaItem(icon: "building.2", text: app.borrower.employer)
                metaItem(icon: "person.fill", text: app.borrower.employmentType)
                metaItem(icon: "phone", text: app.borrower.phone)
                Spacer()
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.adaptiveSurface(colorScheme))
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
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Financial Details", icon: "indianrupeesign.circle")

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
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private func cibilColor(_ s: Int)    -> Color { s >= 750 ? Theme.Colors.success : s >= 650 ? Theme.Colors.neutral : Theme.Colors.critical }
    private func dtiColor(_ r: Double)   -> Color { r <= 0.30 ? Theme.Colors.success : r <= 0.40 ? Theme.Colors.neutral : Theme.Colors.critical }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Documents Section
    // ────────────────────────────────────────────────────────────────

    private func documentsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Documents", icon: "doc.fill")

            ForEach(app.documents) { doc in
                DocumentUploadRow(
                    doc: doc,
                    uploadedFiles: applicationsVM.uploadedFiles[doc.id] ?? [],
                    onUpload: { file in
                        applicationsVM.recordUploadedFile(file, forDocumentId: doc.id)
                    }
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Verification Section
    // ────────────────────────────────────────────────────────────────

    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("OCR Verification", icon: "cpu")

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
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

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
                            .foregroundStyle(msg.isFromCurrentUser ? .white : .primary)
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
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
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
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                .foregroundStyle(isSelected ? .white : .secondary)
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

    @State private var borrowerName    = ""
    @State private var borrowerPhone   = ""
    @State private var borrowerEmail   = ""
    @State private var borrowerAddress = ""
    @State private var selectedLoanType: LoanType = .homeLoan
    @State private var loanAmountText  = ""
    @State private var tenureText      = ""
    @State private var monthlyIncomeText = ""
    @State private var existingEMIText   = ""
    @State private var panUploaded       = false
    @State private var aadhaarUploaded   = false
    @State private var bankUploaded      = false
    @State private var xmlParsed         = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Borrower") {
                    TextField("Full Name",     text: $borrowerName)
                    TextField("Phone",         text: $borrowerPhone).keyboardType(.phonePad)
                    TextField("Email",         text: $borrowerEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    TextField("Address",       text: $borrowerAddress, axis: .vertical).lineLimit(2...3)
                }
                Section("Loan Details") {
                    Picker("Loan Type", selection: $selectedLoanType) {
                        ForEach(LoanType.allCases) { t in Text(t.displayName).tag(t) }
                    }
                    TextField("Amount (₹)",    text: $loanAmountText).keyboardType(.numberPad)
                    TextField("Tenure (months)", text: $tenureText).keyboardType(.numberPad)
                }
                Section("Financials") {
                    TextField("Monthly Income (₹)", text: $monthlyIncomeText).keyboardType(.numberPad)
                    TextField("Existing EMI (₹)",   text: $existingEMIText).keyboardType(.numberPad)
                }
                Section("Documents") {
                    docToggle("PAN Card",        icon: "creditcard",           isUploaded: $panUploaded)
                    docToggle("Aadhaar Card",    icon: "person.text.rectangle", isUploaded: $aadhaarUploaded)
                    docToggle("Bank Statement",  icon: "building.columns",      isUploaded: $bankUploaded)
                    Button {
                        applicationsVM.simulateXMLUpload()
                        xmlParsed = true
                        if let r = applicationsVM.xmlParseResult {
                            monthlyIncomeText = String(Int(r.monthlyIncome))
                        }
                    } label: {
                        Label(
                            xmlParsed ? "XML Parsed" : "Upload XML",
                            systemImage: xmlParsed ? "checkmark.circle.fill" : "arrow.up.doc"
                        )
                        .foregroundStyle(xmlParsed ? Theme.Colors.success : Theme.Colors.primary)
                    }
                }
            }
            .navigationTitle("New Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Save Draft")         { submit(draft: true) }
                        Button("Submit Application") { submit(draft: false) }
                    } label: {
                        Text("Save").fontWeight(.semibold)
                    }
                    .disabled(borrowerName.isEmpty || loanAmountText.isEmpty)
                }
            }
        }
    }

    private func docToggle(_ label: String, icon: String, isUploaded: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Theme.Colors.primary).frame(width: 24)
            Text(label)
            Spacer()
            Button { isUploaded.wrappedValue.toggle() } label: {
                Image(systemName: isUploaded.wrappedValue ? "checkmark.circle.fill" : "icloud.and.arrow.up")
                    .foregroundStyle(isUploaded.wrappedValue ? Theme.Colors.success : .secondary)
                    .font(.system(size: 18))
            }.buttonStyle(.plain)
        }
    }

    private func submit(draft: Bool) {
        let amount = Double(loanAmountText) ?? 0
        let tenure = Int(tenureText) ?? 12
        let income = Double(monthlyIncomeText) ?? 0
        let emi    = Double(existingEMIText) ?? 0

        let newApp = LoanApplication(
            id: "APP-\(Int(Date().timeIntervalSince1970))",
            borrower: Borrower(
                name: borrowerName,
                dob: Calendar.current.date(byAdding: .year, value: -30, to: Date())!,
                address: borrowerAddress.isEmpty ? "Address TBD" : borrowerAddress,
                employer: "To be verified",
                employmentType: "Salaried",
                phone: borrowerPhone,
                email: borrowerEmail
            ),
            loan: LoanDetails(
                amount: amount,
                type: selectedLoanType,
                tenure: tenure,
                interestRate: selectedLoanType == .homeLoan ? 8.5 : 12.0,
                emi: amount * 0.008
            ),
            financials: Financials(
                monthlyIncome: income,
                annualIncome: income * 12,
                existingEMI: emi,
                dtiRatio: income > 0 ? (emi / income) : 0,
                cibilScore: 0,
                bankBalance: 0
            ),
            documents: [
                LoanDocument(id: "DOC-PAN-\(Int(Date().timeIntervalSince1970))", type: .panCard, label: "PAN Card",
                             status: panUploaded ? .uploaded : .pending, uploadedAt: panUploaded ? Date() : nil),
                LoanDocument(id: "DOC-AAD-\(Int(Date().timeIntervalSince1970))", type: .aadhaar, label: "Aadhaar Card",
                             status: aadhaarUploaded ? .uploaded : .pending, uploadedAt: aadhaarUploaded ? Date() : nil),
                LoanDocument(id: "DOC-BS-\(Int(Date().timeIntervalSince1970))", type: .bankStatement, label: "Bank Statement",
                             status: bankUploaded ? .uploaded : .pending, uploadedAt: bankUploaded ? Date() : nil)
            ],
            verification: [],
            notes: [],
            internalRemarks: [],
            status: draft ? .assigned : .new,
            assignedTo: "LO-001",
            branch: "Mumbai Central",
            riskLevel: .medium,
            createdAt: Date(),
            slaDeadline: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        )

        applicationsVM.applications.insert(newApp, at: 0)
        applicationsVM.selectedApplication = newApp
        dismiss()
    }
}
