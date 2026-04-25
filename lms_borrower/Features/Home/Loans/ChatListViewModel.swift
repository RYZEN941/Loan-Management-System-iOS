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
    @Published var searchQuery: String = ""
    @Published var participantNames: [String: String] = [:] // Cache for participant names

    private let chatService: ChatServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: String = ""

    init(chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.chatService = chatService
        self.currentUserID = getCurrentUserID()
        loadChatRooms()
    }

    private func getCurrentUserID() -> String {
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
                await MainActor.run {
                    self.chatRooms = rooms
                    // Populate participant names from eligible users if available
                    for room in rooms {
                        let otherUserID = room.otherUserID(currentUserID: currentUserID)
                        if participantNames[otherUserID] == nil {
                            // Check if we have this user in eligible users
                            if let user = eligibleUsers.first(where: { $0.id == otherUserID }) {
                                participantNames[otherUserID] = user.displayName
                            }
                        }
                    }
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

    func searchEligibleUsers() {
        guard !searchQuery.isEmpty else {
            eligibleUsers = []
            return
        }

        Task {
            do {
                let users = try await chatService.listEligibleUsers(
                    query: searchQuery,
                    limit: 20,
                    offset: 0
                )
                await MainActor.run {
                    self.eligibleUsers = users
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Room Creation

    func createRoomWithUser(userID: String, contextApplicationID: String? = nil) -> ChatRoom? {
        var createdRoom: ChatRoom?

        Task {
            do {
                let room = try await chatService.createOrGetDirectRoom(
                    targetUserID: userID,
                    contextApplicationID: contextApplicationID
                )
                await MainActor.run {
                    // Add to beginning of list if not already present
                    if !self.chatRooms.contains(where: { $0.id == room.id }) {
                        self.chatRooms.insert(room, at: 0)
                    }
                    createdRoom = room
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        return createdRoom
    }

    // MARK: - UI Helpers

    func chatPreviewModels(participantNames: [String: String]) -> [ChatPreviewModel] {
        return chatRooms.map { room in
            let otherUserID = room.otherUserID(currentUserID: currentUserID)
            let participantName = participantNames[otherUserID] ?? "Unknown"
            return ChatPreviewModel(from: room, participantName: participantName, hasUnread: false)
        }
    }

    func refresh() {
        loadChatRooms()
    }
}
