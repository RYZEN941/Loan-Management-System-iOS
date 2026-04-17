//
//  ManagerApprovalsView.swift
//  lms_project
//

import SwiftUI

struct ManagerApprovalsView: View {
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
                        approvalsList
                            .frame(width: geometry.size.width * Theme.Layout.splitLeftRatio)
                        
                        Divider()
                        
                        approvalDetail
                            .frame(width: geometry.size.width * Theme.Layout.splitRightRatio - 1)
                    }
                }
            }
            .navigationTitle("Approvals")
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
        }
    }
    
    // MARK: - Approvals List
    
    private var approvalsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Approval Queue")
                    .font(Theme.Typography.headline)
                Spacer()
                let count = recommendedApps.count
                Text("\(count)")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            
            Divider()
            
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(label: "Recommended", isSelected: applicationsVM.filterStatus == .recommended) {
                    applicationsVM.filterStatus = .recommended
                }
                FilterChip(label: "All", isSelected: applicationsVM.filterStatus == nil) {
                    applicationsVM.filterStatus = nil
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            
            Divider()
            
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
    
    private var recommendedApps: [LoanApplication] {
        applicationsVM.applications.filter { $0.status == .recommended }
    }
    
    // MARK: - Approval Detail
    
    private var approvalDetail: some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(app.borrower.name)
                                    .font(Theme.Typography.title)
                                Text(app.loan.amount.currencyFormatted + " • " + app.loan.type.displayName)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                            Spacer()
                            StatusBadge(status: app.status)
                        }
                        
                        Divider()
                        
                        financialSummary(app)
                        
                        Divider()
                        
                        documentsSummary(app)
                        
                        Divider()
                        
                        verificationSummary(app)
                        
                        Divider()
                        
                        // Conversation (merged remarks)
                        conversationSection(app)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    if app.status == .recommended {
                        ManagerActionPanel(
                            onApprove: { applicationsVM.approveApplication(app) },
                            onReject: { applicationsVM.rejectApplication(app) },
                            onSendBack: { applicationsVM.sendBackApplication(app) }
                        )
                        .background(Theme.Colors.adaptiveSurface(colorScheme))
                    }
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select an application to review")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Conversation (Application-Specific with Manager Remarks)
    
    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Conversation & Remarks", icon: "bubble.left.and.bubble.right")
            
            let messages = applicationsVM.messagesForApplication(app.id)
            
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(messages) { msg in
                    managerMessageBubble(msg)
                }
            }
            
            // Manager remark input
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Add remark...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id,
                        senderName: "Deepak Mehta",
                        senderRole: "Manager",
                        isManagerRemark: true
                    )
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Theme.Colors.neutral.opacity(0.4)
                            : Color(hex: "6F42C1")
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
    
    private func managerMessageBubble(_ msg: ApplicationMessage) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if msg.isFromCurrentUser || msg.type == .managerRemark { Spacer(minLength: 60) }
            
            VStack(alignment: (msg.isFromCurrentUser || msg.type == .managerRemark) ? .trailing : .leading, spacing: 2) {
                if msg.type == .managerRemark {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11))
                        Text("Manager: \(msg.senderName)")
                            .font(Theme.Typography.caption2)
                    }
                    .foregroundStyle(Color(hex: "6F42C1"))
                } else {
                    Text("\(msg.senderName) (\(msg.senderRole))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(msg.text)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(
                        msg.type == .managerRemark ? Color(hex: "6F42C1") :
                        (msg.isFromCurrentUser ? .white : .primary)
                    )
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
            
            if !(msg.isFromCurrentUser || msg.type == .managerRemark) { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - Financial Summary
    
    private func financialSummary(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Financial Summary", icon: "indianrupeesign.circle")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                       spacing: Theme.Spacing.md) {
                summaryCard(label: "Monthly Income", value: app.financials.monthlyIncome.currencyFormatted)
                summaryCard(label: "CIBIL Score", value: "\(app.financials.cibilScore)",
                            color: app.financials.cibilScore >= 750 ? Theme.Colors.success :
                                   app.financials.cibilScore >= 650 ? Theme.Colors.warning : Theme.Colors.critical)
                summaryCard(label: "DTI Ratio", value: app.financials.dtiRatio.percentFormatted,
                            color: app.financials.dtiRatio <= 0.30 ? Theme.Colors.success :
                                   app.financials.dtiRatio <= 0.40 ? Theme.Colors.warning : Theme.Colors.critical)
                summaryCard(label: "Loan EMI", value: app.loan.emi.currencyFormatted)
                summaryCard(label: "Bank Balance", value: app.financials.bankBalance.currencyFormatted)
                summaryCard(label: "Risk Level", value: app.riskLevel.displayName, color: app.riskLevel.color)
            }
        }
    }
    
    private func summaryCard(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
    
    // MARK: - Documents Summary
    
    private func documentsSummary(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Documents", icon: "doc.fill")
            ForEach(app.documents) { doc in
                HStack {
                    Image(systemName: doc.type.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(doc.label)
                        .font(Theme.Typography.subheadline)
                    Spacer()
                    DocStatusBadge(status: doc.status)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Verification Summary
    
    private func verificationSummary(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Verification Results", icon: "cpu")
            ForEach(app.verification) { item in
                VerificationRow(item: item)
            }
        }
    }
}
