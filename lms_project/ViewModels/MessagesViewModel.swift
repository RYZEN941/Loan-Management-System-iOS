//
//  MessagesViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation? = nil
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    
    private let dataService = MockDataService.shared
    
    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    // MARK: - Load Data
    
    func loadConversations() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.conversations = self.dataService.fetchConversations()
            if self.selectedConversation == nil {
                self.selectedConversation = self.conversations.first
            }
            self.loadMessages()
            self.isLoading = false
        }
    }
    
    func selectConversation(_ conversation: Conversation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedConversation = conversation
            // Mark as read
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index].unreadCount = 0
            }
        }
        loadMessages()
    }
    
    func loadMessages() {
        guard let conversation = selectedConversation else { return }
        messages = dataService.fetchMessages(conversationId: conversation.id)
    }
    
    // MARK: - Send Message
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversation = selectedConversation else { return }
        
        let newMessage = Message(
            id: "MSG-\(UUID().uuidString.prefix(6))",
            conversationId: conversation.id,
            senderId: "LO-001",
            senderName: "Amit Singh",
            text: messageText,
            timestamp: Date(),
            isFromCurrentUser: true
        )
        
        withAnimation {
            messages.append(newMessage)
        }
        
        // Update last message in conversation
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].lastMessage = messageText
            conversations[index].lastMessageTime = Date()
        }
        
        messageText = ""
    }
    
    func sendQuickReply(_ template: QuickReplyTemplate) {
        messageText = template.text
        sendMessage()
    }
}
