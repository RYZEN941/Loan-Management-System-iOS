import Foundation
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import SwiftProtobuf

// MARK: - Manual Proto Message Types for media.v1

// Since proto stubs haven't been generated for the media service,
// we implement the messages manually following the proto schema.

struct Media_V1_InitiateMediaUploadRequest: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "media.v1.InitiateMediaUploadRequest"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{3}file_name\0\u{3}content_type\0\u{3}size_bytes\0\u{1}note\0")

    var fileName: String = ""
    var contentType: String = ""
    var sizeBytes: Int64 = 0
    var note: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &fileName)
            case 2: try decoder.decodeSingularStringField(value: &contentType)
            case 3: try decoder.decodeSingularInt64Field(value: &sizeBytes)
            case 4: try decoder.decodeSingularStringField(value: &note)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !fileName.isEmpty { try visitor.visitSingularStringField(value: fileName, fieldNumber: 1) }
        if !contentType.isEmpty { try visitor.visitSingularStringField(value: contentType, fieldNumber: 2) }
        if sizeBytes != 0 { try visitor.visitSingularInt64Field(value: sizeBytes, fieldNumber: 3) }
        if !note.isEmpty { try visitor.visitSingularStringField(value: note, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.fileName == rhs.fileName && lhs.contentType == rhs.contentType && lhs.sizeBytes == rhs.sizeBytes && lhs.note == rhs.note
    }
}

struct Media_V1_InitiateMediaUploadResponse: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "media.v1.InitiateMediaUploadResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{1}success\0\u{3}object_key\0\u{3}upload_url\0\u{3}upload_method\0\u{3}expires_at\0")

    var success: Bool = false
    var objectKey: String = ""
    var uploadUrl: String = ""
    var uploadMethod: String = ""
    var expiresAt: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularBoolField(value: &success)
            case 2: try decoder.decodeSingularStringField(value: &objectKey)
            case 3: try decoder.decodeSingularStringField(value: &uploadUrl)
            case 4: try decoder.decodeSingularStringField(value: &uploadMethod)
            case 5: try decoder.decodeSingularStringField(value: &expiresAt)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if success { try visitor.visitSingularBoolField(value: success, fieldNumber: 1) }
        if !objectKey.isEmpty { try visitor.visitSingularStringField(value: objectKey, fieldNumber: 2) }
        if !uploadUrl.isEmpty { try visitor.visitSingularStringField(value: uploadUrl, fieldNumber: 3) }
        if !uploadMethod.isEmpty { try visitor.visitSingularStringField(value: uploadMethod, fieldNumber: 4) }
        if !expiresAt.isEmpty { try visitor.visitSingularStringField(value: expiresAt, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.objectKey == rhs.objectKey }
}

struct Media_V1_CompleteMediaUploadRequest: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "media.v1.CompleteMediaUploadRequest"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{3}object_key\0\u{1}note\0\u{3}file_name\0\u{3}content_type\0\u{3}size_bytes\0")

    var objectKey: String = ""
    var note: String = ""
    var fileName: String = ""
    var contentType: String = ""
    var sizeBytes: Int64 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &objectKey)
            case 2: try decoder.decodeSingularStringField(value: &note)
            case 3: try decoder.decodeSingularStringField(value: &fileName)
            case 4: try decoder.decodeSingularStringField(value: &contentType)
            case 5: try decoder.decodeSingularInt64Field(value: &sizeBytes)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !objectKey.isEmpty { try visitor.visitSingularStringField(value: objectKey, fieldNumber: 1) }
        if !note.isEmpty { try visitor.visitSingularStringField(value: note, fieldNumber: 2) }
        if !fileName.isEmpty { try visitor.visitSingularStringField(value: fileName, fieldNumber: 3) }
        if !contentType.isEmpty { try visitor.visitSingularStringField(value: contentType, fieldNumber: 4) }
        if sizeBytes != 0 { try visitor.visitSingularInt64Field(value: sizeBytes, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.objectKey == rhs.objectKey }
}

struct Media_V1_CompleteMediaUploadResponse: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "media.v1.CompleteMediaUploadResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{1}success\0\u{3}media_id\0\u{3}file_url\0\u{3}uploaded_at\0")

    var success: Bool = false
    var mediaID: String = ""
    var fileUrl: String = ""
    var uploadedAt: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularBoolField(value: &success)
            case 2: try decoder.decodeSingularStringField(value: &mediaID)
            case 3: try decoder.decodeSingularStringField(value: &fileUrl)
            case 4: try decoder.decodeSingularStringField(value: &uploadedAt)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if success { try visitor.visitSingularBoolField(value: success, fieldNumber: 1) }
        if !mediaID.isEmpty { try visitor.visitSingularStringField(value: mediaID, fieldNumber: 2) }
        if !fileUrl.isEmpty { try visitor.visitSingularStringField(value: fileUrl, fieldNumber: 3) }
        if !uploadedAt.isEmpty { try visitor.visitSingularStringField(value: uploadedAt, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.mediaID == rhs.mediaID }
}

// MARK: - Service Method Descriptors

enum Media_V1_MediaService {
    enum Method {
        enum InitiateMediaUpload {
            static let descriptor = GRPCCore.MethodDescriptor(service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService"), method: "InitiateMediaUpload")
        }
        enum CompleteMediaUpload {
            static let descriptor = GRPCCore.MethodDescriptor(service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "media.v1.MediaService"), method: "CompleteMediaUpload")
        }
    }
}

// MARK: - MediaAPI

@available(iOS 18.0, *)
struct MediaAPI {

    /// Full upload flow: initiate → HTTP PUT → complete → return mediaID
    func uploadFile(data: Data, fileName: String, contentType: String, note: String = "") async throws -> String {
        // Step 1: Initiate
        let initResponse = try await initiateMediaUpload(
            fileName: fileName, contentType: contentType, sizeBytes: Int64(data.count), note: note
        )
        guard initResponse.success, !initResponse.uploadUrl.isEmpty else {
            throw APIError.invalidArgument("Failed to initiate media upload.")
        }

        // Step 2: HTTP PUT to presigned URL (no auth header)
        guard let url = URL(string: initResponse.uploadUrl) else {
            throw APIError.invalidArgument("Invalid upload URL returned.")
        }
        var putRequest = URLRequest(url: url)
        putRequest.httpMethod = "PUT"
        putRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        putRequest.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: putRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidArgument("Failed to upload file to storage.")
        }

        // Step 3: Complete
        let completeResponse = try await completeMediaUpload(
            objectKey: initResponse.objectKey,
            fileName: fileName,
            contentType: contentType,
            sizeBytes: Int64(data.count),
            note: note
        )
        guard completeResponse.success, !completeResponse.mediaID.isEmpty else {
            throw APIError.invalidArgument("Failed to complete media upload.")
        }

        return completeResponse.mediaID
    }

    // MARK: - Private gRPC Methods

    private func initiateMediaUpload(
        fileName: String,
        contentType: String,
        sizeBytes: Int64,
        note: String = ""
    ) async throws -> Media_V1_InitiateMediaUploadResponse {
        var req = Media_V1_InitiateMediaUploadRequest()
        req.fileName = fileName
        req.contentType = contentType
        req.sizeBytes = sizeBytes
        req.note = note

        let metadata = await CoreAPIClient.authorizedMetadata()
        return try await CoreAPIClient.withClient { client in
            try await client.unary(
                request: .init(message: req, metadata: metadata),
                descriptor: Media_V1_MediaService.Method.InitiateMediaUpload.descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Media_V1_InitiateMediaUploadRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Media_V1_InitiateMediaUploadResponse>(),
                options: .defaults
            ) { response in
                try response.message
            }
        }
    }

    private func completeMediaUpload(
        objectKey: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int64,
        note: String = ""
    ) async throws -> Media_V1_CompleteMediaUploadResponse {
        var req = Media_V1_CompleteMediaUploadRequest()
        req.objectKey = objectKey
        req.fileName = fileName
        req.contentType = contentType
        req.sizeBytes = sizeBytes
        req.note = note

        let metadata = await CoreAPIClient.authorizedMetadata()
        return try await CoreAPIClient.withClient { client in
            try await client.unary(
                request: .init(message: req, metadata: metadata),
                descriptor: Media_V1_MediaService.Method.CompleteMediaUpload.descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Media_V1_CompleteMediaUploadRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Media_V1_CompleteMediaUploadResponse>(),
                options: .defaults
            ) { response in
                try response.message
            }
        }
    }
}
