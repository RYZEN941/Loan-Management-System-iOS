//
//  CardView.swift
//  lms_project
//

import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
    }
}

// MARK: - KPI Card

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .cardStyle(colorScheme: colorScheme)
    }
}
