//
//  AdminLoansView.swift
//  lms_project
//
//  TAB 2 — Full Lifecycle Loan Management
//

import SwiftUI

struct AdminLoansView: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Binding var showProfile: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var sidebarCollapsed = false
    @State private var selectedOfficerName = ""

    private let filters: [(label: String, status: ApplicationStatus?)] = [
        ("All", nil), ("Pending", .pending), ("Under Review", .underReview),
        ("Approved", .approved), ("Rejected", .rejected)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if !sidebarCollapsed {
                            listPanel
                                .frame(width: geo.size.width * Theme.Layout.splitLeftRatio)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }
                        detailPanel
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Loans")
            .navigationBarTitleDisplayMode(.inline)
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
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear { loansVM.loadData() }
            .alert(loansVM.actionMessage ?? "", isPresented: $loansVM.showActionAlert) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $loansVM.showEscalateSheet) { escalateSheet }
            .sheet(isPresented: $loansVM.showReassignSheet) { reassignSheet }
        }
    }

    // MARK: - List Panel

    private var listPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search loans...", text: $loansVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(filters, id: \.label) { filter in
                        filterChip(label: filter.label, status: filter.status)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }

            HStack {
                Text("\(loansVM.filteredApplications.count) loans")
                    .font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xs)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(loansVM.filteredApplications) { app in
                        AdminLoanRow(app: app,
                                     isSelected: loansVM.selectedApplication?.id == app.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    loansVM.selectedApplication = app
                                }
                            }
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    private func filterChip(label: String, status: ApplicationStatus?) -> some View {
        let isActive = loansVM.filterStatus == status
        return Button {
            withAnimation { loansVM.filterStatus = status }
        } label: {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(isActive ? .white : Theme.Colors.primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isActive ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let app = loansVM.selectedApplication {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        loanHeader(app)
                        loanKPIs(app)
                        borrowerInfoSection(app)
                        loanDetailsSection(app)
                        emiScheduleSection(app)
                        paymentHistorySection(app)
                        documentsSection(app)
                        timelineSection(app)
                        actionsSection(app)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44)).foregroundStyle(.tertiary)
                    Text("Select a loan to view details")
                        .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Header & KPIs

    private func loanHeader(_ app: LoanApplication) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.borrower.name).font(Theme.Typography.title)
                Text(app.id).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: app.status)
                GenericBadge(text: app.riskLevel.displayName, color: app.riskLevel.color)
            }
        }
    }

    private func loanKPIs(_ app: LoanApplication) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            miniKPI(title: "Amount", value: app.loan.amount.shortCurrency, icon: "indianrupeesign.circle", color: Theme.Colors.primary)
            miniKPI(title: "EMI", value: app.loan.emi.shortCurrency, icon: "calendar.badge.checkmark", color: Theme.Colors.secondary)
            miniKPI(title: "CIBIL", value: "\(app.financials.cibilScore)", icon: "chart.bar.fill", color: cibilColor(app.financials.cibilScore))
            miniKPI(title: "FOIR", value: "\(Int(app.financials.dtiRatio * 100))%", icon: "percent", color: app.financials.dtiRatio > 0.4 ? Theme.Colors.critical : Theme.Colors.success)
        }
    }

    private func miniKPI(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
            Text(title).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.sm)
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Borrower Info

    private func borrowerInfoSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Borrower Info", icon: "person.text.rectangle")
            VStack(spacing: 0) {
                detailRow("Full Name", app.borrower.name)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Phone", app.borrower.phone)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Email", app.borrower.email)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Employer", app.borrower.employer)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Employment", app.borrower.employmentType)
                Divider().padding(.leading, Theme.Spacing.md)
                HStack {
                    Text("KYC Status").font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    GenericBadge(text: "Verified", color: Theme.Colors.success)
                }
                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - Loan Details

    private func loanDetailsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Loan Details", icon: "doc.text")
            VStack(spacing: 0) {
                detailRow("Loan Type", app.loan.type.displayName)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Amount", app.loan.amount.currencyFormatted)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Tenure", "\(app.loan.tenure) months")
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Interest Rate", "\(app.loan.interestRate)%")
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Monthly EMI", app.loan.emi.currencyFormatted)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Assigned LO", app.assignedTo)
                Divider().padding(.leading, Theme.Spacing.md)
                detailRow("Branch", app.branch)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - EMI Schedule

    private func emiScheduleSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "EMI Schedule", icon: "calendar")
            let emiData = generateEMISchedule(app)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Month").font(Theme.Typography.caption2).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Due Date").font(Theme.Typography.caption2).frame(maxWidth: .infinity)
                    Text("Amount").font(Theme.Typography.caption2).frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Status").font(Theme.Typography.caption2).frame(width: 80, alignment: .trailing)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 8)
                Divider()
                ForEach(emiData, id: \.month) { emi in
                    HStack {
                        Text(emi.month).font(Theme.Typography.caption).frame(maxWidth: .infinity, alignment: .leading)
                        Text(emi.dueDate).font(Theme.Typography.caption).frame(maxWidth: .infinity)
                        Text(app.loan.emi.currencyFormatted).font(Theme.Typography.caption).frame(maxWidth: .infinity, alignment: .trailing)
                        GenericBadge(text: emi.status, color: emi.statusColor).frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 8)
                    if emi.month != emiData.last?.month { Divider().padding(.leading, Theme.Spacing.md) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private struct EMIItem { let month: String; let dueDate: String; let status: String; let statusColor: Color }

    private func generateEMISchedule(_ app: LoanApplication) -> [EMIItem] {
        [
            EMIItem(month: "Jan 2025", dueDate: "05 Jan", status: "Paid", statusColor: Theme.Colors.success),
            EMIItem(month: "Feb 2025", dueDate: "05 Feb", status: "Paid", statusColor: Theme.Colors.success),
            EMIItem(month: "Mar 2025", dueDate: "05 Mar", status: "Pending", statusColor: Theme.Colors.warning),
            EMIItem(month: "Apr 2025", dueDate: "05 Apr", status: "Upcoming", statusColor: Theme.Colors.neutral),
        ]
    }

    // MARK: - Payment History

    private func paymentHistorySection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Payment History", icon: "indianrupeesign.circle")
            HStack(spacing: Theme.Spacing.md) {
                paymentStatCard(label: "Paid", value: "2", color: Theme.Colors.success)
                paymentStatCard(label: "Pending", value: "1", color: Theme.Colors.warning)
                paymentStatCard(label: "Overdue", value: "0", color: Theme.Colors.critical)
            }
        }
    }

    private func paymentStatCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Documents

    private func documentsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Document Verification", icon: "paperclip")
            VStack(spacing: 0) {
                ForEach(app.documents) { doc in
                    HStack {
                        Image(systemName: doc.type.icon).font(.system(size: 16)).foregroundStyle(Theme.Colors.primary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.label).font(Theme.Typography.subheadline)
                            if doc.status == .verified {
                                Text("OCR match: ✓ Verified").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.success)
                            }
                        }
                        Spacer()
                        DocStatusBadge(status: doc.status)
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if doc.id != app.documents.last?.id { Divider().padding(.leading, 48) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - Timeline

    private func timelineSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Loan Timeline", icon: "clock")
            VStack(spacing: 0) {
                timelineRow(icon: "plus.circle.fill", label: "Application Created", date: app.createdAt, color: Theme.Colors.primary, isFirst: true)
                timelineConnector
                timelineRow(icon: "doc.badge.arrow.up.fill", label: "Documents Uploaded", date: app.createdAt.addingTimeInterval(43200), color: Theme.Colors.secondary, isFirst: false)
                timelineConnector
                timelineRow(icon: "arrow.right.circle.fill", label: "Sent for Review", date: app.createdAt.addingTimeInterval(86400), color: Theme.Colors.warning, isFirst: false)
                if app.status == .approved || app.status == .rejected {
                    timelineConnector
                    timelineRow(
                        icon: app.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill",
                        label: app.status == .approved ? "Approved" : "Rejected",
                        date: app.slaDeadline,
                        color: app.status == .approved ? Theme.Colors.success : Theme.Colors.critical,
                        isFirst: false
                    )
                    if app.status == .approved {
                        timelineConnector
                        timelineRow(icon: "banknote.fill", label: "Disbursed", date: app.slaDeadline.addingTimeInterval(86400), color: Theme.Colors.success, isFirst: false)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private var timelineConnector: some View {
        HStack {
            Rectangle()
                .fill(Theme.Colors.adaptiveBorder(colorScheme))
                .frame(width: 2, height: 20)
                .padding(.leading, Theme.Spacing.md + 11)
            Spacer()
        }
    }

    private func timelineRow(icon: String, label: String, date: Date, color: Color, isFirst: Bool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color).frame(width: 24)
            Text(label).font(Theme.Typography.subheadline)
            Spacer()
            Text(date.shortFormatted).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
    }

    // MARK: - Actions

    private func actionsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Actions", icon: "bolt.circle")
            actionButton(label: "Reassign LO", icon: "arrow.triangle.2.circlepath", color: Theme.Colors.secondary) { loansVM.beginReassign(app) }
        }
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label).fontWeight(.medium)
            }
            .font(Theme.Typography.subheadline).foregroundStyle(color)
            .frame(maxWidth: .infinity).frame(height: Theme.Layout.buttonHeight)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typography.subheadline)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    // MARK: - Sheets

    private var escalateSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Add a note for the senior manager:")
                    .font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $loansVM.escalateNote)
                    .frame(height: 120).padding(Theme.Spacing.sm)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Escalate Application").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { loansVM.showEscalateSheet = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Escalate") { loansVM.confirmEscalate() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.medium])
    }

    private var reassignSheet: some View {
        NavigationStack {
            List(loansVM.loanOfficers, id: \.id) { officer in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedOfficerName = officer.name
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        loansVM.confirmReassign(to: officer.name)
                        selectedOfficerName = ""
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.circle").foregroundStyle(Theme.Colors.primary)
                        Text(officer.name).font(Theme.Typography.subheadline)
                        Spacer()
                        if selectedOfficerName == officer.name || loansVM.selectedApplication?.assignedTo == officer.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.primary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Reassign To").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { loansVM.showReassignSheet = false } }
            }
        }
        .presentationDetents([.medium])
    }

    private func cibilColor(_ score: Int) -> Color {
        score >= 750 ? Theme.Colors.success : (score >= 650 ? Theme.Colors.warning : Theme.Colors.critical)
    }
}

// MARK: - Admin Loan Row

struct AdminLoanRow: View {
    let app: LoanApplication
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(app.riskLevel.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16)).foregroundStyle(app.riskLevel.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.borrower.name).font(Theme.Typography.headline)
                    Spacer()
                    StatusBadge(status: app.status)
                }
                HStack {
                    Text(app.loan.type.displayName)
                        .font(Theme.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Risk: \(app.riskLevel.displayName)")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(app.riskLevel.color)
                    Text("·").foregroundStyle(.tertiary)
                    Text(app.loan.amount.shortCurrency)
                        .font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Amount Extension

private extension Double {
    var shortCurrency: String {
        if self >= 10_000_000 { return "₹\(String(format: "%.1f", self / 10_000_000)) Cr" }
        if self >= 100_000    { return "₹\(String(format: "%.0f", self / 100_000)) L" }
        return "₹\(String(format: "%.0f", self))"
    }
}
