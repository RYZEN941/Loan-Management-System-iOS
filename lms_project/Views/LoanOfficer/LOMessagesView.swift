//
//  LOMessagesView.swift
//  lms_project
//

import SwiftUI

struct LOMessagesView: View {
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var showQuickReplies = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // LEFT: Conversation List
                    conversationList
                        .frame(width: geometry.size.width * Theme.Layout.messageSplitLeft)
                    
                    Divider()
                    
                    // RIGHT: Chat Panel
                    chatPanel
                        .frame(width: geometry.size.width * Theme.Layout.messageSplitRight)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        messagesVM.resetAddUser()
                        messagesVM.showAddUser = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                messagesVM.loadConversations()
            }
            .sheet(isPresented: $messagesVM.showAddUser) {
                NavigationStack {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Start New Conversation")
                            .font(Theme.Typography.headline)
                            .padding(.top)
                        
                        TextField("Enter email or phone number", text: $messagesVM.addUserInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        if let error = messagesVM.addUserError {
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.critical)
                        }
                        
                        Button("Add User") {
                            messagesVM.submitAddUser()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.primary)
                        .padding(.top)
                        
                        Spacer()
                    }
                    .navigationTitle("Add User")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                messagesVM.showAddUser = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Conversation List
    
    private var conversationList: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search conversations")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messagesVM.conversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: messagesVM.selectedConversation?.id == conversation.id
                        )
                        .onTapGesture {
                            messagesVM.selectConversation(conversation)
                        }
                        
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }
    
    // MARK: - Chat Panel
    
    private var chatPanel: some View {
        VStack(spacing: 0) {
            if let conversation = messagesVM.selectedConversation {
                // Chat Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Text(String(conversation.participantName.prefix(1)))
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(conversation.participantName)
                            .font(Theme.Typography.headline)
                        Text(conversation.participantRole)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Online indicator
                    if conversation.isOnline {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.Colors.success)
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.success)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurface(colorScheme))
                
                Divider()
                
                // Messages
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(messagesVM.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                
                Divider()
                
                // Quick Replies
                if showQuickReplies {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(QuickReplyTemplate.templates) { template in
                                Button {
                                    messagesVM.sendQuickReply(template)
                                    showQuickReplies = false
                                } label: {
                                    Text(template.label)
                                        .font(Theme.Typography.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1))
                                        .foregroundStyle(Theme.Colors.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                
                // Input Bar
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        showQuickReplies.toggle()
                    } label: {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 20))
                            .foregroundStyle(showQuickReplies ? Theme.Colors.primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button {} label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Type a message...", text: $messagesVM.messageText)
                        .font(Theme.Typography.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    Button {
                        messagesVM.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                messagesVM.messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.Colors.neutral.opacity(0.4)
                                : Theme.Colors.primary
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(messagesVM.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.adaptiveSurface(colorScheme))
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "message")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select a conversation")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Text(String(conversation.participantName.prefix(1)))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.primary)
                
                if conversation.isOnline {
                    Circle()
                        .fill(Theme.Colors.success)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.Colors.adaptiveSurface(colorScheme), lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.participantName)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversation.lastMessageTime.relativeFormatted)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                
                HStack {
                    Text(conversation.lastMessage)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Theme.Colors.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1) : Color.clear)
        .contentShape(Rectangle())
    }
}
