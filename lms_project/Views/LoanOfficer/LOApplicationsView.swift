//
//  LOApplicationsView.swift
//  lms_project
//

import SwiftUI

struct LOApplicationsView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    HStack(spacing: 1) {
                        // LEFT: Application List
                        applicationListPanel
                            .frame(width: geometry.size.width * Theme.Layout.splitLeftRatio)
                        
                        Divider()
                        
                        // RIGHT: Application Detail
                        applicationDetailPanel
                            .frame(width: geometry.size.width * Theme.Layout.splitRightRatio - 1)
                    }
                }
            }
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                applicationsVM.loadData()
            }
            .alert("Action", isPresented: $applicationsVM.showActionAlert) {
                Button("OK") {}
            } message: {
                Text(applicationsVM.actionMessage ?? "")
            }
            .sheet(isPresented: $applicationsVM.showXMLUploadResult) {
                xmlResultSheet
            }
        }
    }
    
    // MARK: - Application List Panel
    
    private var applicationListPanel: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search applications...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                        applicationsVM.filterStatus = nil
                    }
                    ForEach(ApplicationStatus.allCases) { status in
                        FilterChip(label: status.displayName, isSelected: applicationsVM.filterStatus == status) {
                            applicationsVM.filterStatus = status
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.sm)
            
            Divider()
            
            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(applicationsVM.filteredApplications) { app in
                        ApplicationRow(
                            application: app,
                            isSelected: applicationsVM.selectedApplication?.id == app.id
                        )
                        .onTapGesture {
                            applicationsVM.selectApplication(app)
                        }
                        
                        Divider().padding(.leading, 72)
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }
    
    // MARK: - Application Detail Panel
    
    private var applicationDetailPanel: some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Section 1: Borrower Profile
                        borrowerProfileSection(app)
                        
                        Divider()
                        
                        // Section 2: Documents
                        documentsSection(app)
                        
                        Divider()
                        
                        // Section 3: AI/OCR Verification
                        verificationSection(app)
                        
                        Divider()
                        
                        // Section 4: Financial Section
                        financialSection(app)
                        
                        Divider()
                        
                        // Section 5: Conversation
                        conversationSection(app)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    // Section 6: Action Panel
                    LOActionPanel(
                        onRecommend: { applicationsVM.recommendApplication(app) },
                        onReject: { applicationsVM.rejectApplication(app) },
                        onRequestDocs: { applicationsVM.requestDocuments(app) }
                    )
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                }
            } else {
                emptyDetailView
            }
        }
    }
    
    // MARK: - Section 1: Borrower Profile
    
    private func borrowerProfileSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Borrower Profile", icon: "person.fill")
            
            HStack(alignment: .top) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text(app.borrower.name)
                            .font(Theme.Typography.title)
                        Spacer()
                        StatusBadge(status: app.status)
                    }
                    
                    Text(app.loan.amount.currencyFormatted + " • " + app.loan.type.displayName)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                profileField(label: "Date of Birth", value: app.borrower.dob.shortFormatted)
                profileField(label: "Employer", value: app.borrower.employer)
                profileField(label: "Address", value: app.borrower.address)
                profileField(label: "Employment Type", value: app.borrower.employmentType)
            }
        }
    }
    
    private func profileField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
    }
    
    // MARK: - Section 2: Documents
    
    private func documentsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Documents", icon: "doc.fill")
            
            ForEach(app.documents) { doc in
                DocumentRow(document: doc)
            }
            
            // XML Upload Button
            Button {
                applicationsVM.simulateXMLUpload()
            } label: {
                Label("Upload XML", systemImage: "arrow.up.doc.fill")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Section 3: AI/OCR Verification
    
    private func verificationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "AI/OCR Verification", icon: "cpu")
            
            let mismatches = app.verification.filter { !$0.isMatch }.count
            if mismatches > 0 {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.warning)
                    Text("\(mismatches) mismatch\(mismatches > 1 ? "es" : "") found")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.Colors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            
            ForEach(app.verification) { item in
                VerificationRow(item: item)
            }
        }
    }
    
    // MARK: - Section 4: Financial
    
    private func financialSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Financial Details", icon: "indianrupeesign.circle")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.md) {
                financeCard(label: "Monthly Income", value: app.financials.monthlyIncome.currencyFormatted, icon: "arrow.up.circle")
                financeCard(label: "Annual Income", value: app.financials.annualIncome.currencyFormatted, icon: "calendar")
                financeCard(label: "Existing EMI", value: app.financials.existingEMI.currencyFormatted, icon: "arrow.down.circle")
                financeCard(label: "CIBIL Score", value: "\(app.financials.cibilScore)", icon: "chart.bar",
                            valueColor: cibilColor(app.financials.cibilScore))
                financeCard(label: "DTI Ratio", value: app.financials.dtiRatio.percentFormatted, icon: "percent",
                            valueColor: dtiColor(app.financials.dtiRatio))
                financeCard(label: "Bank Balance", value: app.financials.bankBalance.currencyFormatted, icon: "building.columns")
            }
        }
    }
    
    private func financeCard(label: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
    
    // MARK: - Section 5: Conversation
    
    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Conversation", icon: "bubble.left.and.bubble.right")
            
            let messages = applicationsVM.messagesForApplication(app.id)
            
            // Message bubbles
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(messages) { msg in
                    appMessageBubble(msg)
                }
            }
            
            // Input bar
            HStack(spacing: Theme.Spacing.sm) {
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                TextField("Type a message...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                            ? Theme.Colors.neutral.opacity(0.4)
                            : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .onAppear {
            applicationsVM.loadApplicationMessages(for: app.id)
        }
    }
    
    private func appMessageBubble(_ msg: ApplicationMessage) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if msg.isFromCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: msg.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Manager remark styled differently
                if msg.type == .managerRemark {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11))
                        Text("Manager: \(msg.senderName)")
                            .font(Theme.Typography.caption2)
                    }
                    .foregroundStyle(Color(hex: "6F42C1"))
                } else if !msg.isFromCurrentUser {
                    Text(msg.senderName)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(msg.text)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(msg.type == .managerRemark ? Color(hex: "6F42C1") : (msg.isFromCurrentUser ? .white : .primary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        msg.type == .managerRemark
                        ? Color(hex: "6F42C1").opacity(0.1)
                        : (msg.isFromCurrentUser ? Theme.Colors.primary : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                Text(msg.timestamp.timeFormatted)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if !msg.isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - XML Result Sheet
    
    private var xmlResultSheet: some View {
        NavigationStack {
            if let result = applicationsVM.xmlParseResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Parsed Info
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Parsed Data")
                                .font(Theme.Typography.title)
                            
                            profileField(label: "Account Holder", value: result.accountHolder)
                            profileField(label: "Bank", value: result.bankName)
                            profileField(label: "Account", value: result.accountNumber)
                            profileField(label: "Monthly Income", value: result.monthlyIncome.currencyFormatted)
                            profileField(label: "Average Balance", value: result.averageBalance.currencyFormatted)
                        }
                        
                        Divider()
                        
                        // Transactions
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Transactions")
                                .font(Theme.Typography.headline)
                            
                            ForEach(result.transactions) { txn in
                                HStack {
                                    Image(systemName: txn.type == .credit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                    
                                    VStack(alignment: .leading) {
                                        Text(txn.description)
                                            .font(Theme.Typography.subheadline)
                                        Text(txn.date.shortFormatted)
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(txn.type == .credit ? "+\(txn.amount.currencyFormatted)" : "-\(txn.amount.currencyFormatted)")
                                        .font(Theme.Typography.mono)
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Divider()
                        
                        // Summary
                        HStack(spacing: Theme.Spacing.lg) {
                            VStack(alignment: .leading) {
                                Text("Total Credits")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                Text(result.totalCredits.currencyFormatted)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.success)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Total Debits")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                Text(result.totalDebits.currencyFormatted)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.critical)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .navigationTitle("XML Upload Result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            applicationsVM.showXMLUploadResult = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            applicationsVM.showXMLUploadResult = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyDetailView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select an application to view details")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func cibilColor(_ score: Int) -> Color {
        if score >= 750 { return Theme.Colors.success }
        if score >= 650 { return Theme.Colors.warning }
        return Theme.Colors.critical
    }
    
    private func dtiColor(_ ratio: Double) -> Color {
        if ratio <= 0.30 { return Theme.Colors.success }
        if ratio <= 0.40 { return Theme.Colors.warning }
        return Theme.Colors.critical
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(Theme.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Colors.primary : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.Colors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
