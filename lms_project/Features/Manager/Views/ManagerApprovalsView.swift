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
    
    // Sanction Letter State
    @State private var showApprovalConfirmation = false
    @State private var showRegenerateConfirmation = false
    @State private var showRevokeConfirmation = false
    @State private var previewLetter: SanctionLetterVersion? = nil
    @State private var selectedVersionIndex = 0
    @State private var highRiskOnly = false

    // Edit Terms State
    @State private var showEditTerms = false
    @State private var editTenureText = ""
    @State private var editInterestRateText = ""

    // Assign Officer State
    @State private var showAssignOfficerAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                ManagerTheme.Colors.background(colorScheme).ignoresSafeArea()

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
            .sheet(item: $previewLetter) { version in sanctionLetterPreview(version) }
            .sheet(isPresented: $showEditTerms) {
                if let app = applicationsVM.selectedApplication {
                    editTermsSheet(app)
                }
            }
            .alert("Approve this application?", isPresented: $showApprovalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") { 
                    if let app = applicationsVM.selectedApplication {
                        applicationsVM.approveApplication(app)
                    }
                }
            } message: { Text("This will update the application status to Approved and create the loan ledger.") }
            .alert("Regenerate sanction letter?", isPresented: $showRegenerateConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate") {
                    if let app = applicationsVM.selectedApplication {
                        applicationsVM.regenerateSanctionLetter(app)
                    }
                }
            } message: { Text("Sanction letter generation is not implemented in the backend yet.") }
            .alert("Revoke this sanction letter?", isPresented: $showRevokeConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Revoke", role: .destructive) {
                    if let app = applicationsVM.selectedApplication {
                        applicationsVM.revokeSanctionLetter(app)
                    }
                }
            } message: { Text("Sanction letter revocation is not implemented in the backend yet.") }
            .alert("Assign Officer", isPresented: $showAssignOfficerAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Officer assignment requires a staff directory endpoint that is not yet implemented in the backend. Please assign the officer manually in the admin panel.")
            }
        }
    }

    // MARK: - Sidebar
    private var applicationListPanel: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(ManagerTheme.Colors.primary(colorScheme)).font(.system(size: 14, weight: .bold))
                TextField("Search applications...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(12)
            .background(ManagerTheme.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
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
                    .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ManagerTheme.Colors.primary(colorScheme).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            // Filter chips — all manager-relevant statuses
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AppFilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        withAnimation { applicationsVM.filterStatus = nil }
                    }
                    AppFilterChip(label: "Forwarded", isSelected: applicationsVM.filterStatus == .officerApproved) {
                        withAnimation { applicationsVM.filterStatus = .officerApproved }
                    }
                    AppFilterChip(label: "In Review", isSelected: applicationsVM.filterStatus == .underReview) {
                        withAnimation { applicationsVM.filterStatus = .underReview }
                    }
                    AppFilterChip(label: "Approved", isSelected: applicationsVM.filterStatus == .approved) {
                        withAnimation { applicationsVM.filterStatus = .approved }
                    }
                    AppFilterChip(label: "Rejected", isSelected: applicationsVM.filterStatus == .rejected) {
                        withAnimation { applicationsVM.filterStatus = .rejected }
                    }
                    AppFilterChip(label: "High Risk", isSelected: highRiskOnly) {
                        withAnimation { highRiskOnly.toggle() }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            Divider()

            if displayedApplications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 32, weight: .thin)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme).opacity(0.3))
                    Text("No applications found").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedApplications) { app in
                            ManagerApplicationRow(
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
        .background(ManagerTheme.Colors.surface(colorScheme))
    }

    // MARK: - Detail Panel
    private var applicationDetailPanel: some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        selectedApplicationHint(app)
                        detailHeader(app)
                        financialSection(app)
                        borrowerInfoSection(app)
                        editTermsSummarySection(app)   // ← Manager can edit terms
                        documentsSummarySection(app)
                        sanctionLetterSection(app)
                        verificationSection(app)
                        conversationSection(app)
                    }
                    .padding(20)
                }
                .background(ManagerTheme.Colors.background(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    if app.status == .officerApproved || app.status == .managerReview ||
                       app.status == .underReview || app.status == .pending {
                        ManagerActionPanel(
                            onApprove: { showApprovalConfirmation = true },
                            onRejectWithRemarks: { applicationsVM.beginRejectWithRemarks(app) },
                            onSendBack: { applicationsVM.beginSendBack(app) },
                            onEditTerms: {
                                editTenureText = "\(app.loan.tenure)"
                                editInterestRateText = String(format: "%.2f", app.loan.interestRate)
                                showEditTerms = true
                            },
                            onAssignOfficer: { showAssignOfficerAlert = true }
                        )
                        .background(ManagerTheme.Colors.surface(colorScheme))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
                    }
                }
                .onChange(of: applicationsVM.selectedApplication) { _ in
                    selectedVersionIndex = 0
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.badge.questionmark").font(.system(size: 48, weight: .thin)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme).opacity(0.4))
                    Text("Select an application to review").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var displayedApplications: [LoanApplication] {
        let base = applicationsVM.filteredApplications
        return highRiskOnly ? base.filter { $0.riskLevel == .high } : base
    }

    private func selectedApplicationHint(_ app: LoanApplication) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
            Text("Reviewing: \(app.id)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ManagerTheme.Colors.textSecondary(colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ManagerTheme.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Detail Header
    private func detailHeader(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(ManagerTheme.Colors.primary(colorScheme).opacity(0.12)).frame(width: 56, height: 56)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(app.borrower.name).font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    Text(app.loan.amount.currencyFormatted + " · " + app.loan.type.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
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
                    .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                Spacer()
                Text("Due: \(app.slaDeadline.shortFormatted)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(ManagerTheme.Colors.primary(colorScheme).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
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
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
        )
    }

    private func infoCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).textCase(.uppercase)
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ManagerTheme.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
        )
    }

    // MARK: - Financials
    private func financialSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Risk & Credit Analysis", icon: "gauge.with.needle.fill")
                .description("Key financial indicators, CIBIL score, and DTI ratios for risk mitigation.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                finCard("Monthly Income",  app.financials.monthlyIncome.currencyFormatted, "dollarsign.circle.fill", ManagerTheme.Colors.primary(colorScheme))
                finCard("CIBIL Score",     "\(app.financials.cibilScore)", "bolt.fill", cibilColor(app.financials.cibilScore))
                finCard("DTI Ratio",       app.financials.dtiRatio.percentFormatted, "chart.pie.fill", dtiColor(app.financials.dtiRatio))
                finCard("Annual Income",   app.financials.annualIncome.currencyFormatted, "calendar.badge.clock", ManagerTheme.Colors.primary(colorScheme))
                finCard("Bank Balance",    app.financials.bankBalance.currencyFormatted, "building.columns.fill", ManagerTheme.Colors.primary(colorScheme))
                finCard("Risk Assessment", app.riskLevel.displayName, "shield.lefthalf.filled", app.riskLevel.adaptiveColor(colorScheme))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
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
        .background(ManagerTheme.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 0.5)
        )
    }

    private func cibilColor(_ s: Int) -> Color { 
        s >= 750 ? Theme.Colors.adaptiveSuccess(colorScheme) : s >= 650 ? Theme.Colors.adaptiveWarning(colorScheme) : Theme.Colors.adaptiveCritical(colorScheme) 
    }
    private func dtiColor(_ r: Double) -> Color { 
        r <= 0.30 ? Theme.Colors.adaptiveSuccess(colorScheme) : r <= 0.40 ? Theme.Colors.adaptiveWarning(colorScheme) : Theme.Colors.adaptiveCritical(colorScheme) 
    }

    // MARK: - Documents
    private func documentsSummarySection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Document Verification", icon: "doc.on.doc.fill")
                .description("Final checklist of all verified documents submitted by the borrower.")
            VStack(spacing: 0) {
                ForEach(app.documents) { doc in
                    HStack {
                        Image(systemName: doc.type.icon).font(.system(size: 14)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme)).frame(width: 24)
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
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Sanction Letter
    private func sanctionLetterSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sanction Letter", icon: "doc.badge.shield.fill")
                .description("Official loan approval document and version history.")
            
            if app.status == .approved, let sanction = app.sanctionLetter {
                // Ensure index is valid
                let versions = sanction.versions.sorted(by: { $0.version > $1.version })
                let safeIndex = min(max(0, selectedVersionIndex), versions.count - 1)
                let current = versions[safeIndex]
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Menu {
                                ForEach(versions.indices, id: \.self) { idx in
                                    Button {
                                        selectedVersionIndex = idx
                                    } label: {
                                        HStack {
                                            Text("Version: v\(versions[idx].version)")
                                            if idx == selectedVersionIndex {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Version: v\(current.version)").font(.system(size: 14, weight: .bold))
                                    Image(systemName: "chevron.down").font(.system(size: 10))
                                }
                                .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ManagerTheme.Colors.primary(colorScheme).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            HStack(spacing: 6) {
                                Circle().fill(current.status == .sent ? Theme.Colors.success : Theme.Colors.critical).frame(width: 8, height: 8)
                                Text("Status: \(current.status.displayName)").font(.system(size: 13, weight: .medium))
                            }
                            Text("Generated on: \(current.generatedAt.shortFormatted)").font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        letterActionBtn(title: "View Document", icon: "eye") { previewLetter = current }
                        letterActionBtn(title: "Download PDF", icon: "arrow.down.doc") { downloadSanctionLetter(current) }
                        letterActionBtn(title: "Regenerate", icon: "arrow.clockwise") { showRegenerateConfirmation = true }
                        letterActionBtn(title: "Mark as Revoked", icon: "xmark.shield", isDestructive: true) { showRevokeConfirmation = true }
                    }
                }
                .padding(16)
                .background(ManagerTheme.Colors.surfaceSecondary(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack {
                    Image(systemName: "doc.text.fill").foregroundStyle(.tertiary)
                    Text("Not generated yet").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(ManagerTheme.Colors.surfaceSecondary(colorScheme).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
        )
    }

    private func downloadSanctionLetter(_ version: SanctionLetterVersion) {
        let fileName = "Sanction_Letter_v\(version.version).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let content = "SANCTION LETTER v\(version.version)\nGenerated on: \(version.generatedAt)\nStatus: \(version.status.displayName)"
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // On iPad, we need to provide a source view for the popover
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func letterActionBtn(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isDestructive ? Theme.Colors.adaptiveCritical(colorScheme) : ManagerTheme.Colors.primary(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isDestructive ? Theme.Colors.adaptiveCritical(colorScheme).opacity(0.08) : ManagerTheme.Colors.primary(colorScheme).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func sanctionLetterPreview(_ version: SanctionLetterVersion) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        // Letter Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SANCTION LETTER").font(.system(size: 24, weight: .black))
                                Text("LMS BANKING CORP").font(.system(size: 12, weight: .bold)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Version: v\(version.version)").font(.system(size: 10, weight: .bold))
                                Text("Date: \(version.generatedAt.shortFormatted)").font(.system(size: 10))
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dear Borrower,").font(.system(size: 16, weight: .semibold))
                            Text("We are pleased to inform you that your loan application has been approved under the following terms and conditions:")
                                .font(.system(size: 14))
                                .lineSpacing(4)
                        }
                        
                        VStack(spacing: 0) {
                            previewRow(label: "Loan ID", value: "LOAN-\(version.version)001")
                            previewRow(label: "Approved Amount", value: "₹25,00,000")
                            previewRow(label: "Interest Rate", value: "10.5% p.a.")
                            previewRow(label: "Tenure", value: "60 Months")
                            previewRow(label: "EMI Amount", value: "₹53,745")
                        }
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("Please review and sign the attached documents to proceed with the disbursement.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Spacer(minLength: 100)
                        
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Rectangle().frame(width: 120, height: 1)
                                Text("Authorized Signatory").font(.system(size: 10, weight: .bold))
                                Text("LMS Manager").font(.system(size: 8)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(40)
                }
            }
            .navigationTitle("Sanction Letter Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { previewLetter = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func previewRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold))
        }
        .padding(12)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Verification
    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Identity & Fraud Checks", icon: "checkmark.shield.fill")
                .description("AI-powered verification results for identity and financial documents.")
            ForEach(app.verification) { item in VerificationRow(item: item) }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
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
                    .background(ManagerTheme.Colors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
                    )
                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id, senderName: "Deepak Mehta",
                        senderRole: "Manager", isManagerRemark: true)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                        .foregroundStyle(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Color.secondary.opacity(0.3) : ManagerTheme.Colors.primary(colorScheme))
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
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
                    .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                } else {
                    Text("\(msg.senderName)").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                }
                Text(msg.text)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(msg.type == .managerRemark ? .white : (msg.isFromCurrentUser ? .white : .primary))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        msg.type == .managerRemark ? ManagerTheme.Colors.primary(colorScheme)
                        : (msg.isFromCurrentUser ? ManagerTheme.Colors.primary(colorScheme).opacity(0.8) : ManagerTheme.Colors.surfaceSecondary(colorScheme))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(msg.timestamp.timeFormatted).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            if !(msg.isFromCurrentUser || msg.type == .managerRemark) { Spacer(minLength: 80) }
        }
    }

    // MARK: - Edit Terms Summary (in detail panel)
    private func editTermsSummarySection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Loan Terms", icon: "pencil.and.list.clipboard")
                    .description("Offered tenure and interest rate for this application.")
                Spacer()
                Button {
                    editTenureText = "\(app.loan.tenure)"
                    editInterestRateText = String(format: "%.2f", app.loan.interestRate)
                    showEditTerms = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ManagerTheme.Colors.primary(colorScheme).opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoCard("Requested Amount", app.loan.amount.currencyFormatted)
                infoCard("Tenure", "\(app.loan.tenure) months")
                infoCard("Interest Rate", String(format: "%.2f%%", app.loan.interestRate))
                infoCard("EMI", app.loan.emi.currencyFormatted)
                infoCard("Loan Type", app.loan.type.displayName)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(ManagerTheme.Colors.surface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Edit Terms Sheet
    private func editTermsSheet(_ app: LoanApplication) -> some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tenure (months)").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 60", text: $editTenureText)
                            .keyboardType(.numberPad)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Interest Rate (% p.a.)").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 10.50", text: $editInterestRateText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Update Loan Terms")
                } footer: {
                    Text("These terms will be saved via the backend and affect the EMI calculation. The borrower will need to re-acknowledge before disbursement.")
                }

                Section {
                    Button {
                        let tenure = Int(editTenureText) ?? app.loan.tenure
                        let rate = Double(editInterestRateText) ?? app.loan.interestRate
                        applicationsVM.updateLoanTerms(
                            applicationId: app.id,
                            tenureMonths: tenure,
                            offeredInterestRate: rate
                        )
                        showEditTerms = false
                    } label: {
                        Text("Save Terms")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(ManagerTheme.Colors.primary(colorScheme))
                    .disabled(
                        editTenureText.isEmpty || editInterestRateText.isEmpty ||
                        Int(editTenureText) == nil || Double(editInterestRateText) == nil
                    )
                }
            }
            .navigationTitle("Edit Loan Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEditTerms = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Section Label
    private func sectionLabel(_ title: String, icon: String) -> some View {

        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
            Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(1.0)
        }
    }

    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill").font(.system(size: 48)).foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                    Text("Rejection Remarks").font(Theme.Typography.title)
                }
                .padding(.top)
                
                Text("Explain why this application is being rejected.")
                    .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                
                TextEditor(text: $applicationsVM.rejectionRemarksText)
                    .padding(12)
                    .background(ManagerTheme.Colors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ManagerTheme.Colors.border(colorScheme), lineWidth: 1))
                    .frame(height: 180).padding(.horizontal)
                
                Button { applicationsVM.confirmRejectWithRemarks() } label: {
                    Text("Confirm Rejection").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Theme.Colors.adaptiveCritical(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(applicationsVM.rejectionRemarksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { applicationsVM.showRejectionRemarksSheet = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
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
                        Text("Select a reason").tag("Select a reason")
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
                    .disabled(applicationsVM.sendBackReason == "Select a reason" || 
                              (applicationsVM.sendBackReason == "Other" &&
                               applicationsVM.sendBackCustomRemark.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .navigationTitle("Send Back").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { applicationsVM.showSendBackSheet = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
