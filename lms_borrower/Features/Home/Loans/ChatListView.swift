import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChatSheet = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Support & Chat")
                            .font(.largeTitle).bold()
                        Text("We're here to help with your loan and account.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search conversations...", text: $viewModel.searchQuery)
                            .onChange(of: viewModel.searchQuery) { _, _ in
                                viewModel.searchEligibleUsers()
                            }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Chat List
                    if viewModel.isLoading {
                        ProgressView("Loading conversations...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else if viewModel.chatRooms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("No conversations yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Start a new conversation to get help with your loan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.chatRooms) { room in
                                Button {
                                    router.push(.chatConversation(roomID: room.id))
                                } label: {
                                    ChatRoomPreviewRow(room: room)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 80) // Space for floating button
                    }
                }
            }
            .refreshable {
                viewModel.refresh()
            }

            // Floating New Chat Button
            Button {
                showNewChatSheet = true
            } label: {
                Image(systemName: "plus.message.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(18)
                    .background(DS.primary)
                    .clipShape(Circle())
                    .shadow(color: .mainBlue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(20)
            .sheet(isPresented: $showNewChatSheet) {
                NewChatSheet(viewModel: viewModel)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct ChatRoomPreviewRow: View {
    let room: ChatRoom
    // TODO: Get current user ID from auth service
    private let currentUserID = ""

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(DS.primaryLight)
                    .frame(width: 50, height: 50)

                Text("U") // Placeholder - should be participant initials
                    .font(.title3).bold()
                    .foregroundColor(.mainBlue)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("User") // Placeholder - should be participant name
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(room.lastMessageTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(room.contextApplicationID != nil ? "Loan Application" : "General")
                    .font(.caption).bold()
                    .foregroundColor(.secondary)

                Text(room.lastMessageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct NewChatSheet: View {
    @ObservedObject var viewModel: ChatListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUser: ChatUser?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.eligibleUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Search for users to start a conversation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    List {
                        ForEach(viewModel.eligibleUsers) { user in
                            Button {
                                selectedUser = user
                                if let room = viewModel.createRoomWithUser(userID: user.id) {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(DS.primaryLight)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(user.initials)
                                                .font(.headline)
                                                .foregroundColor(.mainBlue)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName)
                                            .font(.headline)
                                        Text(user.role)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView().environmentObject(AppRouter())
    }
}
