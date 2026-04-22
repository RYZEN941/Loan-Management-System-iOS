// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written gRPC-Swift 2 (GRPCCore) client stubs matching media/v1/media.proto.
// service: media.v1.MediaService

import GRPCCore
import GRPCProtobuf

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public enum Media_V1_MediaService: Sendable {
    public static let descriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService")

    public enum Method: Sendable {
        public enum InitiateMediaUpload: Sendable {
            public typealias Input = Media_V1_InitiateMediaUploadRequest
            public typealias Output = Media_V1_InitiateMediaUploadResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService"),
                method: "InitiateMediaUpload",
                type: .unary
            )
        }
        public enum CompleteMediaUpload: Sendable {
            public typealias Input = Media_V1_CompleteMediaUploadRequest
            public typealias Output = Media_V1_CompleteMediaUploadResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService"),
                method: "CompleteMediaUpload",
                type: .unary
            )
        }
        public enum ListMedia: Sendable {
            public typealias Input = Media_V1_ListMediaRequest
            public typealias Output = Media_V1_ListMediaResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService"),
                method: "ListMedia",
                type: .unary
            )
        }
    }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Media_V1_MediaService {
    public struct Client<Transport: GRPCCore.ClientTransport>: Sendable {
        private let client: GRPCCore.GRPCClient<Transport>

        public init(wrapping client: GRPCCore.GRPCClient<Transport>) {
            self.client = client
        }

        public func initiateMediaUpload(
            request: GRPCCore.ClientRequest<Media_V1_InitiateMediaUploadRequest>,
            options: GRPCCore.CallOptions = .defaults
        ) async throws -> Media_V1_InitiateMediaUploadResponse {
            try await self.client.unary(
                request: request,
                descriptor: Media_V1_MediaService.Method.InitiateMediaUpload.descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Media_V1_InitiateMediaUploadRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Media_V1_InitiateMediaUploadResponse>(),
                options: options
            ) { response in
                try response.message
            }
        }

        public func completeMediaUpload(
            request: GRPCCore.ClientRequest<Media_V1_CompleteMediaUploadRequest>,
            options: GRPCCore.CallOptions = .defaults
        ) async throws -> Media_V1_CompleteMediaUploadResponse {
            try await self.client.unary(
                request: request,
                descriptor: Media_V1_MediaService.Method.CompleteMediaUpload.descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Media_V1_CompleteMediaUploadRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Media_V1_CompleteMediaUploadResponse>(),
                options: options
            ) { response in
                try response.message
            }
        }

        public func listMedia(
            request: GRPCCore.ClientRequest<Media_V1_ListMediaRequest>,
            options: GRPCCore.CallOptions = .defaults
        ) async throws -> Media_V1_ListMediaResponse {
            try await self.client.unary(
                request: request,
                descriptor: Media_V1_MediaService.Method.ListMedia.descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Media_V1_ListMediaRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Media_V1_ListMediaResponse>(),
                options: options
            ) { response in
                try response.message
            }
        }
    }
}
