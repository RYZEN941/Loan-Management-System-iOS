//
//  StatusBadge.swift
//  lms_project
//

import SwiftUI

struct StatusBadge: View {
    let status: ApplicationStatus
    
    var body: some View {
        Text(status.displayName)
            .font(Theme.Typography.caption2)
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - Generic Badge

struct GenericBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Document Status Badge

struct DocStatusBadge: View {
    let status: DocumentStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))
            Text(status.displayName)
                .font(Theme.Typography.caption2)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12))
        .clipShape(Capsule())
    }
}
