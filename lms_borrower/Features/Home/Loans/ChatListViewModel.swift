// ChatListViewModel.swift
// lms_borrower/Features/Home/Loans
//
// ViewModel for ChatListView - manages chat rooms and user discovery.

import Foundation
import Combine

@MainActor
@available(iOS 18.0, *)
final class ChatListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var eligibleUsers: [ChatUser] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var conversationSearchQuery: String = ""
    @Published var userSearchQuery: String = ""
    @Published var participantNames: [String: String] = [:]

    private let chatService: ChatServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: String = ""
    private var searchDebounceTask: Task<Void, Never>?

    init(chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.chatService = chatService
        self.currentUserID = Self.resolveCurrentUserID()
        loadChatRooms()
    }

    private static func resolveCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    // MARK: - Data Loading

    func loadChatRooms() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let rooms = try await chatService.listMyChatRooms(limit: 50, offset: 0)
                let names = await resolveParticipantNames(for: rooms)
                await MainActor.run {
                    self.chatRooms = rooms
                    self.participantNames.merge(names) { _, new in new }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func resolveParticipantNames(for rooms: [ChatRoom]) async -> [String: String] {
        var names: [String: String] = [:]
        for room in rooms {
            let otherID = room.otherUserID(currentUserID: currentUserID)
            if names[otherID] == nil {
                names[otherID] = "User"
            }
        }
        do {
            let users = try await chatService.listEligibleUsers(query: "", limit: 100, offset: 0)
            for user in users {
                names[user.id] = user.displayName
            }
        } catch {
            // Best-effort: names without a match stay "User"
        }
        return names
    }

    // MARK: - Search with debounce

    func searchEligibleUsers() {
        searchDebounceTask?.cancel()
        let trimmedQuery = userSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            eligibleUsers = []
            return
        }

        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let users = try await chatService.listEligibleUsers(
                    query: trimmedQuery,
                    limit: 20,
                    offset: 0
                )
                await MainActor.run {
                    self.eligibleUsers = users
                    for user in users {
                        self.participantNames[user.id] = user.displayName
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Room Creation

    func createRoomWithUser(userID: String, contextApplicationID: String? = nil) async throws -> ChatRoom {
        let room = try await chatService.createOrGetDirectRoom(
            targetUserID: userID,
            contextApplicationID: contextApplicationID
        )
        if !chatRooms.contains(where: { $0.id == room.id }) {
            chatRooms.insert(room, at: 0)
        }
        if participantNames[userID] == nil {
            if let user = eligibleUsers.first(where: { $0.id == userID }) {
                participantNames[userID] = user.displayName
            }
        }
        return room
    }

    // MARK: - UI Helpers

    func chatPreviewModels() -> [ChatPreviewModel] {
        return chatRooms.map { room in
            let otherUserID = room.otherUserID(currentUserID: currentUserID)
            let participantName = participantNames[otherUserID] ?? "User"
            return ChatPreviewModel(from: room, participantName: participantName, hasUnread: false)
        }
    }

    func filteredChatRooms(currentUserID: String) -> [ChatRoom] {
        let trimmedQuery = conversationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return chatRooms }

        return chatRooms.filter { room in
            let otherUserID = room.otherUserID(currentUserID: currentUserID)
            let participantName = participantNames[otherUserID] ?? "User"
            return participantName.localizedCaseInsensitiveContains(trimmedQuery)
                || room.lastMessageText.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func refresh() {
        loadChatRooms()
    }
}
