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

    private let chatService: ChatServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.chatService = chatService
        loadChatRooms()
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
            let otherUserID = room.otherUserID(currentUserID: "") // Will need actual current user ID
            let participantName = participantNames[otherUserID] ?? "Unknown"
            return ChatPreviewModel(from: room, participantName: participantName, hasUnread: false)
        }
    }

    func refresh() {
        loadChatRooms()
    }
}
