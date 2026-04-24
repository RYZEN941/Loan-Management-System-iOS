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
    var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                }
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
