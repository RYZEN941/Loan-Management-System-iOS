import Foundation
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import SwiftProtobuf

@available(iOS 18.0, *)
struct ChatAPI {
    private let service = GRPCCore.ServiceDescriptor(fullyQualifiedService: "chat.v1.ChatService")

    func listEligibleUsers(query: String = "", limit: Int32 = 50, offset: Int32 = 0) async throws -> [Chat_V1_ChatUser] {
        var request = Chat_V1_ListChatEligibleUsersRequest()
        request.query = query
        request.limit = limit
        request.offset = offset

        do {
            let response: Chat_V1_ListChatEligibleUsersResponse = try await unaryAuthorized(
                request,
                method: "ListChatEligibleUsers"
            )
            return response.items
        } catch {
            throw APIError.from(error)
        }
    }

    func createOrGetDirectRoom(targetUserID: String) async throws -> Chat_V1_ChatRoom {
        var request = Chat_V1_CreateOrGetDirectRoomRequest()
        request.targetUserID = targetUserID

        do {
            let response: Chat_V1_CreateOrGetDirectRoomResponse = try await unaryAuthorized(
                request,
                method: "CreateOrGetDirectRoom"
            )
            return response.room
        } catch {
            throw APIError.from(error)
        }
    }

    func listMyChatRooms(limit: Int32 = 50, offset: Int32 = 0) async throws -> [Chat_V1_ChatRoom] {
        var request = Chat_V1_ListMyChatRoomsRequest()
        request.limit = limit
        request.offset = offset

        do {
            let response: Chat_V1_ListMyChatRoomsResponse = try await unaryAuthorized(
                request,
                method: "ListMyChatRooms"
            )
            return response.items
        } catch {
            throw APIError.from(error)
        }
    }

    func listRoomMessages(roomID: String, limit: Int32 = 50, offset: Int32 = 0) async throws -> [Chat_V1_ChatMessage] {
        var request = Chat_V1_ListRoomMessagesRequest()
        request.roomID = roomID
        request.limit = limit
        request.offset = offset

        do {
            let response: Chat_V1_ListRoomMessagesResponse = try await unaryAuthorized(
                request,
                method: "ListRoomMessages"
            )
            return response.items
        } catch {
            throw APIError.from(error)
        }
    }

    func sendMessage(roomID: String, body: String) async throws -> Chat_V1_ChatMessage {
        var request = Chat_V1_SendMessageRequest()
        request.roomID = roomID
        request.messageType = .text
        request.body = body

        do {
            let response: Chat_V1_SendMessageResponse = try await unaryAuthorized(
                request,
                method: "SendMessage"
            )
            return response.message
        } catch {
            throw APIError.from(error)
        }
    }

    func subscribeRoomMessages(
        roomID: String,
        afterMessageID: String?,
        onEvent: @escaping @Sendable (Chat_V1_ChatMessageEvent) async -> Void
    ) async throws {
        var request = Chat_V1_SubscribeRoomMessagesRequest()
        request.roomID = roomID
        if let afterMessageID, !afterMessageID.isEmpty {
            request.afterMessageID = afterMessageID
        }

        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: APIConfig.host, port: APIConfig.port),
            transportSecurity: .tls
        )

        do {
            try await withGRPCClient(transport: transport) { client in
                let metadata = await CoreAPIClient.authorizedMetadata()
                let descriptor = GRPCCore.MethodDescriptor(service: service, method: "SubscribeRoomMessages")

                let rpcRequest = GRPCCore.ClientRequest<Chat_V1_SubscribeRoomMessagesRequest>(
                    message: request,
                    metadata: metadata
                )

                try await client.serverStreaming(
                    request: rpcRequest,
                    descriptor: descriptor,
                    serializer: GRPCProtobuf.ProtobufSerializer<Chat_V1_SubscribeRoomMessagesRequest>(),
                    deserializer: GRPCProtobuf.ProtobufDeserializer<Chat_V1_ChatMessageEvent>(),
                    options: .defaults
                ) { response in
                    for try await event in response.messages {
                        await onEvent(event)
                    }
                }
            }
        } catch {
            throw APIError.from(error)
        }
    }

    private func unaryAuthorized<Request: SwiftProtobuf.Message & Sendable, Response: SwiftProtobuf.Message & Sendable>(
        _ request: Request,
        method: String
    ) async throws -> Response {
        try await CoreAPIClient.withAuthorizedClient { client, metadata in
            let descriptor = GRPCCore.MethodDescriptor(service: service, method: method)
            return try await client.unary(
                request: .init(message: request, metadata: metadata),
                descriptor: descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Request>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Response>(),
                options: .defaults
            ) { response in
                try response.message
            }
        }
    }
}
