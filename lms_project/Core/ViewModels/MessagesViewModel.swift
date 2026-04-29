import SwiftUI
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation? = nil
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var conversationSearchQuery = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var connectionState: ChatConnectionState = .disconnected

    @Published var showAddUser = false
    @Published var addUserInput = ""
    @Published var addUserError: String? = nil
    @Published var addUserSuccess = false
    @Published var addUserResults: [ChatCandidate] = []
    @Published var isLoadingAddUserResults = false

    private let chatAPI = ChatAPI()
    private let authAPI = AuthAPI()

    private var currentUserID: String = ""
    private var knownUsersByID: [String: Chat_V1_ChatUser] = [:]
    private var seenMessageIDsByRoom: [String: Set<String>] = [:]
    private var lastSeenMessageIDByRoom: [String: String] = [:]
    private var streamTask: Task<Void, Never>? = nil

    deinit {
        streamTask?.cancel()
    }

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func loadConversations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await ensureCurrentUserID()
                try await refreshKnownUsers(query: "")

                let rooms = try await chatAPI.listMyChatRooms(limit: 100, offset: 0)
                let mapped = rooms.map(mapConversation).sorted { $0.lastMessageTime > $1.lastMessageTime }

                let previousSelectionID = selectedConversation?.id
                conversations = mapped

                if let previousSelectionID,
                   let existing = conversations.first(where: { $0.id == previousSelectionID }) {
                    selectedConversation = existing
                } else {
                    selectedConversation = conversations.first
                }

                if selectedConversation != nil {
                    loadMessages()
                } else {
                    messages = []
                    stopActiveSubscription()
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load conversations"
                conversations = []
                messages = []
                stopActiveSubscription()
            }

            isLoading = false
        }
    }

    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].unreadCount = 0
        }
        loadMessages()
    }

    func loadMessages() {
        guard let conversation = selectedConversation else { return }

        Task {
            do {
                let rows = try await chatAPI.listRoomMessages(roomID: conversation.id, limit: 200, offset: 0)
                let ascending = rows.reversed()

                var mappedMessages: [Message] = []
                var knownIDs: Set<String> = []

                for row in ascending {
                    knownIDs.insert(row.id)
                    mappedMessages.append(mapMessage(row, roomID: conversation.id))
                }

                messages = mappedMessages
                seenMessageIDsByRoom[conversation.id] = knownIDs
                lastSeenMessageIDByRoom[conversation.id] = ascending.last?.id
                startSubscription(for: conversation.id)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load messages"
            }
        }
    }

    func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conversation = selectedConversation, !trimmed.isEmpty else { return }

        messageText = ""
        Task {
            do {
                let sent = try await chatAPI.sendMessage(roomID: conversation.id, body: trimmed)
                appendIncomingMessage(sent, roomID: conversation.id)
            } catch {
                messageText = trimmed
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to send message"
            }
        }
    }

    func sendQuickReply(_ template: QuickReplyTemplate) {
        messageText = template.text
        sendMessage()
    }

    func openNewConversationSheet() {
        resetAddUser()
        showAddUser = true
        searchEligibleUsers()
    }

    func searchEligibleUsers() {
        isLoadingAddUserResults = true
        addUserError = nil

        Task {
            do {
                let query = addUserInput.trimmingCharacters(in: .whitespacesAndNewlines)
                try await refreshKnownUsers(query: query)

                let all = knownUsersByID.values
                    .filter { $0.userID != currentUserID }
                    .map { mapCandidate($0) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                addUserResults = all
            } catch {
                addUserResults = []
                addUserError = (error as? LocalizedError)?.errorDescription ?? "Failed to load chat users"
            }

            isLoadingAddUserResults = false
        }
    }

    func createConversation(with candidate: ChatCandidate) {
        addUserError = nil

        Task {
            do {
                _ = try await chatAPI.createOrGetDirectRoom(targetUserID: candidate.id)
                addUserSuccess = true
                showAddUser = false
                addUserInput = ""
                try await refreshKnownUsers(query: "")
                let rooms = try await chatAPI.listMyChatRooms(limit: 100, offset: 0)
                let mapped = rooms.map(mapConversation).sorted { $0.lastMessageTime > $1.lastMessageTime }
                conversations = mapped
                if let room = mapped.first(where: { $0.participantUserID == candidate.id }) {
                    selectConversation(room)
                }
            } catch {
                addUserError = (error as? LocalizedError)?.errorDescription ?? "Failed to start conversation"
            }
        }
    }

    func resetAddUser() {
        addUserInput = ""
        addUserError = nil
        addUserSuccess = false
        addUserResults = []
        isLoadingAddUserResults = false
    }

    func pauseActiveSubscription() {
        stopActiveSubscription()
    }

    private func ensureCurrentUserID() async throws {
        if !currentUserID.isEmpty { return }
        let profile = try await authAPI.getMyProfile()
        currentUserID = profile.userID
    }

    private func refreshKnownUsers(query: String) async throws {
        var merged: [String: Chat_V1_ChatUser] = knownUsersByID
        var offset: Int32 = 0
        let limit: Int32 = 100

        while true {
            let page = try await chatAPI.listEligibleUsers(query: query, limit: limit, offset: offset)
            for user in page {
                merged[user.userID] = user
            }
            if page.count < Int(limit) {
                break
            }
            offset += limit
        }

        knownUsersByID = merged
    }

    private func startSubscription(for roomID: String) {
        stopActiveSubscription()
        connectionState = .connecting

        streamTask = Task {
            await runSubscriptionLoop(roomID: roomID)
        }
    }

    private func stopActiveSubscription() {
        streamTask?.cancel()
        streamTask = nil
        connectionState = .disconnected
    }

    private func runSubscriptionLoop(roomID: String) async {
        var attempt = 0

        while !Task.isCancelled {
            guard selectedConversation?.id == roomID else {
                return
            }

            do {
                connectionState = attempt == 0 ? .connecting : .reconnecting

                try await chatAPI.subscribeRoomMessages(
                    roomID: roomID,
                    afterMessageID: lastSeenMessageIDByRoom[roomID]
                ) { [weak self] event in
                    await self?.handleStreamEvent(event, roomID: roomID)
                }

                throw APIError.unavailable("Subscription ended")
            } catch {
                if Task.isCancelled { return }

                if case APIError.permissionDenied = error {
                    connectionState = .disconnected
                    errorMessage = (error as? LocalizedError)?.errorDescription
                    return
                }
                if case APIError.notFound = error {
                    connectionState = .disconnected
                    errorMessage = (error as? LocalizedError)?.errorDescription
                    return
                }

                attempt += 1
                connectionState = .reconnecting

                let delaySeconds = min(Double(2 << min(attempt, 6)), 30.0) + Double.random(in: 0...0.6)
                let delayNanos = UInt64(delaySeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNanos)
            }
        }
    }

    private func handleStreamEvent(_ event: Chat_V1_ChatMessageEvent, roomID: String) {
        connectionState = .connected

        guard selectedConversation?.id == roomID else {
            return
        }

        switch event.payload {
        case .message(let message):
            appendIncomingMessage(message, roomID: roomID)
        case .heartbeat:
            break
        case nil:
            break
        }
    }

    private func appendIncomingMessage(_ proto: Chat_V1_ChatMessage, roomID: String) {
        var seen = seenMessageIDsByRoom[roomID, default: []]
        guard !seen.contains(proto.id) else { return }

        seen.insert(proto.id)
        seenMessageIDsByRoom[roomID] = seen
        lastSeenMessageIDByRoom[roomID] = proto.id

        let mapped = mapMessage(proto, roomID: roomID)
        messages.append(mapped)

        if let index = conversations.firstIndex(where: { $0.id == roomID }) {
            conversations[index].lastMessage = mapped.text
            conversations[index].lastMessageTime = mapped.timestamp
            if selectedConversation?.id != roomID {
                conversations[index].unreadCount += 1
            }
        }
    }

    private func mapCandidate(_ user: Chat_V1_ChatUser) -> ChatCandidate {
        ChatCandidate(
            id: user.userID,
            name: user.name.isEmpty ? user.email : user.name,
            role: readableRole(user.role),
            email: user.email
        )
    }

    private func mapConversation(_ room: Chat_V1_ChatRoom) -> Conversation {
        let participantID = room.userAID == currentUserID ? room.userBID : room.userAID
        let participant = knownUsersByID[participantID]
        let latestBody = room.hasLatestMessage ? room.latestMessage.body : ""
        let latestAtRaw = room.hasLatestMessage ? room.latestMessage.createdAt : room.updatedAt

        return Conversation(
            id: room.id,
            participantUserID: participantID,
            participantName: {
                guard let participant else { return "Unknown User" }
                return participant.name.isEmpty ? "Unknown User" : participant.name
            }(),
            participantRole: readableRole(participant?.role ?? ""),
            participantEmail: participant?.email ?? "",
            lastMessage: latestBody,
            lastMessageTime: parseDate(latestAtRaw),
            unreadCount: 0,
            isOnline: false
        )
    }

    private func mapMessage(_ message: Chat_V1_ChatMessage, roomID: String) -> Message {
        let sender = knownUsersByID[message.senderUserID]
        return Message(
            id: message.id,
            conversationId: roomID,
            senderId: message.senderUserID,
            senderName: {
                guard let sender else { return "User" }
                return sender.name.isEmpty ? "User" : sender.name
            }(),
            text: message.body,
            timestamp: parseDate(message.createdAt),
            isFromCurrentUser: message.senderUserID == currentUserID,
            attachmentName: nil
        )
    }

    private func parseDate(_ value: String) -> Date {
        guard !value.isEmpty else { return Date() }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        return Date()
    }

    private func readableRole(_ role: String) -> String {
        switch role.lowercased() {
        case "officer": return "Loan Officer"
        case "manager": return "Manager"
        case "admin": return "Admin"
        case "borrower": return "Borrower"
        case "dst": return "DST"
        default: return role.isEmpty ? "User" : role.capitalized
        }
    }
}
