//
//  LOMessagesView.swift
//  lms_project
//

import SwiftUI

struct LOMessagesView: View {

    // MARK: - Role filter chips
    private enum MsgChip: String, CaseIterable {
        case all        = "All"
        case borrower   = "Borrower"
        case officer    = "Loan Officer"
        case dst        = "DST"
        case manager    = "Manager"
    }

    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var showQuickReplies      = false
    @State private var sidebarCollapsed      = false
    @State private var selectedChip: MsgChip = .all

    private let sidebarWidth: CGFloat = 300

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // ── LEFT: Conversation list ──
                        if !sidebarCollapsed {
                            conversationList
                                .frame(width: sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }

                        // ── RIGHT: Chat panel ──
                        chatPanel
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left: sidebar toggle
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.left")
                            .symbolVariant(sidebarCollapsed ? .none : .fill)
                    }
                }
                // Left: new conversation
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        messagesVM.openNewConversationSheet()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                // Right: profile only
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: sidebarCollapsed)
            .onAppear {
                messagesVM.loadConversations()
            }
            .onDisappear {
                messagesVM.pauseActiveSubscription()
            }
            .sheet(isPresented: $messagesVM.showAddUser) {
                NavigationStack {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Start New Conversation")
                            .font(Theme.Typography.headline)
                            .padding(.top)

                        TextField("Search name, email, phone", text: $messagesVM.addUserInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .onChange(of: messagesVM.addUserInput) { _, _ in
                                messagesVM.searchEligibleUsers()
                            }

                        if messagesVM.isLoadingAddUserResults {
                            ProgressView("Loading users...")
                                .font(Theme.Typography.caption)
                        }

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(messagesVM.addUserResults) { user in
                                    Button {
                                        messagesVM.createConversation(with: user)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(user.name)
                                                    .font(Theme.Typography.subheadline)
                                                    .foregroundStyle(.primary)
                                                Text("\(user.role) · \(user.email)")
                                                    .font(Theme.Typography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(12)
                                        .background(Theme.Colors.adaptiveSurface(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }

                        if let error = messagesVM.addUserError {
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.critical)
                        }

                        Spacer()
                    }
                    .navigationTitle("Add User")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { messagesVM.showAddUser = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Conversation List (left panel)

    private var filteredConversations: [Conversation] {
        let roleFiltered: [Conversation]
        switch selectedChip {
        case .all:      roleFiltered = messagesVM.conversations
        case .borrower: roleFiltered = messagesVM.conversations.filter { $0.participantRole.lowercased().contains("borrower") }
        case .officer:  roleFiltered = messagesVM.conversations.filter { $0.participantRole.lowercased().contains("officer") }
        case .dst:      roleFiltered = messagesVM.conversations.filter { $0.participantRole.lowercased().contains("dst") }
        case .manager:  roleFiltered = messagesVM.conversations.filter { $0.participantRole.lowercased().contains("manager") }
        }

        let search = messagesVM.conversationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return roleFiltered }
        return roleFiltered.filter {
            $0.participantName.lowercased().contains(search) ||
            $0.participantEmail.lowercased().contains(search) ||
            $0.lastMessage.lowercased().contains(search)
        }
    }

    private var unreadConversations: [Conversation] {
        filteredConversations.filter { $0.unreadCount > 0 }
    }

    private var readConversations: [Conversation] {
        filteredConversations.filter { $0.unreadCount == 0 }
    }

    private var conversationList: some View {
        VStack(spacing: 0) {

            // ── Header (matches Applications panel) ──
            HStack(alignment: .bottom) {
                Text("Conversations")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                Text("\(filteredConversations.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // ── Search bar (matches Applications panel) ──
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.primary)
                    .font(.system(size: 14, weight: .bold))
                TextField("Search conversations", text: $messagesVM.conversationSearchQuery)
                    .font(Theme.Typography.subheadline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            // ── Filter chips ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MsgChip.allCases, id: \.self) { chip in
                        AppFilterChip(label: chip.rawValue, isSelected: selectedChip == chip) {
                            withAnimation(.spring(response: 0.3)) { selectedChip = chip }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            Divider()

            // ── List ──
            if messagesVM.isLoading && filteredConversations.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading conversations...")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredConversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(Theme.Colors.primary.opacity(0.3))
                    Text("No conversations found")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !unreadConversations.isEmpty {
                            conversationSection(title: "Unread", conversations: unreadConversations)
                        }

                        if !readConversations.isEmpty {
                            conversationSection(title: unreadConversations.isEmpty ? "All Conversations" : "Recent", conversations: readConversations)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    private func conversationSection(title: String, conversations: [Conversation]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ForEach(conversations) { conversation in
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

    // MARK: - Chat Panel (right)

    private var chatPanel: some View {
        VStack(spacing: 0) {
            if let conversation = messagesVM.selectedConversation {
                // Chat header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Text(String(conversation.participantName.prefix(1)))
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(width: 36, height: 36)           // ← fixes off-centre text
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(conversation.participantName)
                            .font(Theme.Typography.headline)
                        Text(conversation.participantRole)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(conversation.participantEmail)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 6, height: 6)
                        Text(connectionLabel)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(connectionColor)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurface(colorScheme))

                Divider()

                // Messages scroll
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Conversation")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.adaptiveSurface(colorScheme))
                            .clipShape(Capsule())
                            .padding(.top, 4)

                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(messagesVM.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))

                Divider()

                // Quick replies strip
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
                                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
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

                // ── Input bar ──
                HStack(spacing: Theme.Spacing.sm) {
                    // Quick-reply toggle
                    Button {
                        showQuickReplies.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(showQuickReplies ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $messagesVM.messageText)
                            .font(Theme.Typography.body)
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 16)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
                    )

                    // Send
                    Button {
                        messagesVM.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                messagesVM.messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.Colors.neutral.opacity(0.3)
                                : Theme.Colors.primary
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(messagesVM.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurface(colorScheme).ignoresSafeArea())

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

    private var connectionLabel: String {
        switch messagesVM.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Offline"
        }
    }

    private var connectionColor: Color {
        switch messagesVM.connectionState {
        case .connected: return Theme.Colors.success
        case .connecting, .reconnecting: return Theme.Colors.warning
        case .disconnected: return Theme.Colors.neutral
        }
    }

}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Avatar — text centred with explicit frame + multilineTextAlignment
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 50, height: 50)

                Text(String(conversation.participantName.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 50, height: 50)
                    .multilineTextAlignment(.center)

                if conversation.isOnline {
                    Circle()
                        .fill(Theme.Colors.success)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Theme.Colors.adaptiveSurface(colorScheme), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.participantName)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(conversation.participantRole)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(conversation.lastMessageTime.relativeFormatted)
                        .font(.system(size: 11, weight: .medium))
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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Theme.Colors.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected
            ? Theme.Colors.primary.opacity(colorScheme == .dark ? 0.15 : 0.05)
            : Color.clear
        )
        .overlay(
            HStack {
                if isSelected {
                    Rectangle()
                        .fill(Theme.Colors.primary)
                        .frame(width: 4)
                        .transition(.move(edge: .leading))
                }
                Spacer()
            }
        )
        .contentShape(Rectangle())
    }
}
