import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChatSheet = false

    private var currentUserID: String {
        sessionStore.borrowerProfileId.isEmpty ? "" : sessionStore.borrowerProfileId
    }

    private var visibleRooms: [ChatRoom] {
        viewModel.filteredChatRooms(currentUserID: currentUserID)
    }
    
    var body: some View {
        ZStack {
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
                        TextField("Search conversations...", text: $viewModel.conversationSearchQuery)
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
                    } else if visibleRooms.isEmpty && viewModel.chatRooms.isEmpty {
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
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 72)
                    } else if visibleRooms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No matching conversations")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try a different name or keyword.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 72)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(visibleRooms) { room in
                                Button {
                                    router.push(.chatConversation(roomID: room.id))
                                } label: {
                                    let otherUserID = room.otherUserID(currentUserID: currentUserID)
                                    let participantName = viewModel.participantNames[otherUserID] ?? "User"
                                    ChatRoomPreviewRow(room: room, participantName: participantName)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 110)
            }
            .refreshable {
                viewModel.refresh()
            }

            // Floating New Chat Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        viewModel.userSearchQuery = ""
                        viewModel.eligibleUsers = []
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
                    .padding(.trailing, 20)
                    .padding(.bottom, 86)
                    .sheet(isPresented: $showNewChatSheet) {
                        NewChatSheet(viewModel: viewModel)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Retry") { viewModel.refresh() }
            Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct ChatRoomPreviewRow: View {
    let room: ChatRoom
    let participantName: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(DS.primaryLight)
                    .frame(width: 50, height: 50)

                Text(String(participantName.prefix(1)).uppercased())
                    .font(.title3).bold()
                    .foregroundColor(.mainBlue)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(participantName)
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
    @EnvironmentObject var router: AppRouter
    @State private var selectedUser: ChatUser?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search support team or staff...", text: $viewModel.userSearchQuery)
                        .onChange(of: viewModel.userSearchQuery) { _, _ in
                            viewModel.searchEligibleUsers()
                        }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if viewModel.userSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Search to start a conversation")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Find a support team member or staff contact to begin chatting.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    Spacer()
                } else if viewModel.eligibleUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No users found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.eligibleUsers) { user in
                            Button {
                                selectedUser = user
                                createRoomAndNavigate(user: user)
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

                                    if isCreating && selectedUser?.id == user.id {
                                        ProgressView()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .disabled(isCreating)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private func createRoomAndNavigate(user: ChatUser) {
        isCreating = true
        Task {
            do {
                let room = try await viewModel.createRoomWithUser(userID: user.id)
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    router.push(.chatConversation(roomID: room.id))
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // errorMessage is set by viewModel
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
