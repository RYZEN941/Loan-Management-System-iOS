//
//  SectionHeader.swift
//  lms_project
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            
            Text(title)
                .font(Theme.Typography.title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
