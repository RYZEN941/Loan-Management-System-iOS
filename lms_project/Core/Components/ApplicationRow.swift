//
//  ApplicationRow.swift
//  lms_project
//

import SwiftUI

struct ApplicationRow: View {
    let application: LoanApplication
    let isSelected: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Borrower Avatar
            ZStack {
                Circle()
                    .fill(application.status.color.opacity(0.15))
                    .frame(width: Theme.Layout.avatarSize, height: Theme.Layout.avatarSize)
                
                Text(application.borrower.name.prefix(1))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(application.status.color)
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(application.borrower.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: application.status)
                }
                
                HStack(spacing: Theme.Spacing.sm) {
                    Text(application.loan.type.displayName)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.quaternary)
                    
                    Text(application.loan.amount.currencyFormatted)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    // SLA Indicator
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: application.slaStatus.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(slaColor)
                        
                        Text(slaText)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(slaColor)
                    }
                    
                    Spacer()
                    
                    // Risk badge
                    if application.riskLevel == .high {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("High Risk")
                                .font(Theme.Typography.caption2)
                        }
                        .foregroundStyle(Theme.Colors.critical)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var slaColor: Color {
        switch application.slaStatus {
        case .onTrack: return Theme.Colors.neutral
        case .urgent: return Theme.Colors.warning
        case .overdue: return Theme.Colors.critical
        }
    }
    
    private var slaText: String {
        let days = application.slaDeadline.daysRemaining
        if days < 0 { return "Overdue by \(abs(days))d" }
        if days == 0 { return "Due today" }
        return "\(days)d remaining"
    }
}
