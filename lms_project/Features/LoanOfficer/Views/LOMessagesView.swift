//
//  LOMessagesView.swift
//  lms_project
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct LOMessagesView: View {
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var showQuickReplies = false
    @State private var showAttachmentOptions = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    
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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conversations")
                        .font(Theme.Typography.headline)
                    Text("\(messagesVM.conversations.count) active chats")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            
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
            .padding(.bottom, Theme.Spacing.sm)
            
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
                        Text(conversation.participantEmail)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
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
                
                // Input Bar (Floating Style)
                HStack(spacing: Theme.Spacing.sm) {
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
                        
                        Button {
                            showAttachmentOptions = true
                        } label: {
                            Image(systemName: "paperclip")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
                    )
                    
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
                .background(
                    Theme.Colors.adaptiveSurface(colorScheme)
                        .ignoresSafeArea()
                )
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
        .confirmationDialog("Attach File", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
            Button("Choose Photo") {
                showPhotoPicker = true
            }
            Button("Choose Document") {
                showFileImporter = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    showCamera = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let _ = try? await item.loadTransferable(type: Data.self) {
                    let name = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                    await MainActor.run {
                        messagesVM.sendMessage(attachmentName: name)
                        selectedPhoto = nil
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image, .plainText, .data], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let fileURL = urls.first {
                messagesVM.sendMessage(attachmentName: fileURL.lastPathComponent)
            }
        }
        .sheet(isPresented: $showCamera) {
            LOImagePicker(sourceType: .camera) { image in
                showCamera = false
                if image != nil {
                    let name = "Camera_\(Int(Date().timeIntervalSince1970)).jpg"
                    messagesVM.sendMessage(attachmentName: name)
                }
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
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Text(String(conversation.participantName.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.primary)
                
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

private struct LOImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        
        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }
    }
}
