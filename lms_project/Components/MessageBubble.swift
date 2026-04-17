//
//  MessageBubble.swift
//  lms_project
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if message.isFromCurrentUser { Spacer(minLength: 80) }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(message.text)
                        .font(Theme.Typography.body)
                        .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                    
                    // Attachment
                    if let attachmentName = message.attachmentName {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 12))
                            Text(attachmentName)
                                .font(Theme.Typography.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            message.isFromCurrentUser
                            ? Color.white.opacity(0.15)
                            : Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.3 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isFromCurrentUser
                    ? Theme.Colors.primary
                    : Theme.Colors.adaptiveSurfaceSecondary(colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(message.timestamp.timeFormatted)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if !message.isFromCurrentUser { Spacer(minLength: 80) }
        }
    }
}
