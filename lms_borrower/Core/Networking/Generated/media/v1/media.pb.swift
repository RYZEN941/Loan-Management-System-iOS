// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written Swift-Protobuf types matching media/v1/media.proto.
// package: media.v1
// service: MediaService

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftProtobuf

fileprivate let _media_protobuf_package = "media.v1"

public struct Media_V1_InitiateMediaUploadRequest: Sendable {
    public var fileName: String = ""
    public var contentType: String = ""
    public var sizeBytes: Int64 = 0
    public var note: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_InitiateMediaUploadResponse: Sendable {
    public var success: Bool = false
    public var objectKey: String = ""
    public var uploadURL: String = ""
    public var uploadMethod: String = ""
    public var expiresAt: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_CompleteMediaUploadRequest: Sendable {
    public var objectKey: String = ""
    public var note: String = ""
    public var fileName: String = ""
    public var contentType: String = ""
    public var sizeBytes: Int64 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_CompleteMediaUploadResponse: Sendable {
    public var success: Bool = false
    public var mediaID: String = ""
    public var fileURL: String = ""
    public var uploadedAt: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_ListMediaRequest: Sendable {
    public var limit: Int32 = 0
    public var offset: Int32 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_MediaItem: Sendable {
    public var mediaID: String = ""
    public var fileName: String = ""
    public var contentType: String = ""
    public var sizeBytes: Int64 = 0
    public var fileURL: String = ""
    public var note: String = ""
    public var uploadedAt: String = ""
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Media_V1_ListMediaResponse: Sendable {
    public var items: [Media_V1_MediaItem] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

extension Media_V1_InitiateMediaUploadRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".InitiateMediaUploadRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "file_name"),
        2: .standard(proto: "content_type"),
        3: .standard(proto: "size_bytes"),
        4: .same(proto: "note"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.fileName)
            case 2: try decoder.decodeSingularStringField(value: &self.contentType)
            case 3: try decoder.decodeSingularInt64Field(value: &self.sizeBytes)
            case 4: try decoder.decodeSingularStringField(value: &self.note)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.fileName.isEmpty { try visitor.visitSingularStringField(value: self.fileName, fieldNumber: 1) }
        if !self.contentType.isEmpty { try visitor.visitSingularStringField(value: self.contentType, fieldNumber: 2) }
        if self.sizeBytes != 0 { try visitor.visitSingularInt64Field(value: self.sizeBytes, fieldNumber: 3) }
        if !self.note.isEmpty { try visitor.visitSingularStringField(value: self.note, fieldNumber: 4) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.fileName == rhs.fileName &&
        lhs.contentType == rhs.contentType &&
        lhs.sizeBytes == rhs.sizeBytes &&
        lhs.note == rhs.note &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_InitiateMediaUploadResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".InitiateMediaUploadResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .standard(proto: "object_key"),
        3: .standard(proto: "upload_url"),
        4: .standard(proto: "upload_method"),
        5: .standard(proto: "expires_at"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBoolField(value: &self.success)
            case 2: try decoder.decodeSingularStringField(value: &self.objectKey)
            case 3: try decoder.decodeSingularStringField(value: &self.uploadURL)
            case 4: try decoder.decodeSingularStringField(value: &self.uploadMethod)
            case 5: try decoder.decodeSingularStringField(value: &self.expiresAt)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.objectKey.isEmpty { try visitor.visitSingularStringField(value: self.objectKey, fieldNumber: 2) }
        if !self.uploadURL.isEmpty { try visitor.visitSingularStringField(value: self.uploadURL, fieldNumber: 3) }
        if !self.uploadMethod.isEmpty { try visitor.visitSingularStringField(value: self.uploadMethod, fieldNumber: 4) }
        if !self.expiresAt.isEmpty { try visitor.visitSingularStringField(value: self.expiresAt, fieldNumber: 5) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.success == rhs.success &&
        lhs.objectKey == rhs.objectKey &&
        lhs.uploadURL == rhs.uploadURL &&
        lhs.uploadMethod == rhs.uploadMethod &&
        lhs.expiresAt == rhs.expiresAt &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_CompleteMediaUploadRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".CompleteMediaUploadRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "object_key"),
        2: .same(proto: "note"),
        3: .standard(proto: "file_name"),
        4: .standard(proto: "content_type"),
        5: .standard(proto: "size_bytes"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.objectKey)
            case 2: try decoder.decodeSingularStringField(value: &self.note)
            case 3: try decoder.decodeSingularStringField(value: &self.fileName)
            case 4: try decoder.decodeSingularStringField(value: &self.contentType)
            case 5: try decoder.decodeSingularInt64Field(value: &self.sizeBytes)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.objectKey.isEmpty { try visitor.visitSingularStringField(value: self.objectKey, fieldNumber: 1) }
        if !self.note.isEmpty { try visitor.visitSingularStringField(value: self.note, fieldNumber: 2) }
        if !self.fileName.isEmpty { try visitor.visitSingularStringField(value: self.fileName, fieldNumber: 3) }
        if !self.contentType.isEmpty { try visitor.visitSingularStringField(value: self.contentType, fieldNumber: 4) }
        if self.sizeBytes != 0 { try visitor.visitSingularInt64Field(value: self.sizeBytes, fieldNumber: 5) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.objectKey == rhs.objectKey &&
        lhs.note == rhs.note &&
        lhs.fileName == rhs.fileName &&
        lhs.contentType == rhs.contentType &&
        lhs.sizeBytes == rhs.sizeBytes &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_CompleteMediaUploadResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".CompleteMediaUploadResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .standard(proto: "media_id"),
        3: .standard(proto: "file_url"),
        4: .standard(proto: "uploaded_at"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBoolField(value: &self.success)
            case 2: try decoder.decodeSingularStringField(value: &self.mediaID)
            case 3: try decoder.decodeSingularStringField(value: &self.fileURL)
            case 4: try decoder.decodeSingularStringField(value: &self.uploadedAt)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.mediaID.isEmpty { try visitor.visitSingularStringField(value: self.mediaID, fieldNumber: 2) }
        if !self.fileURL.isEmpty { try visitor.visitSingularStringField(value: self.fileURL, fieldNumber: 3) }
        if !self.uploadedAt.isEmpty { try visitor.visitSingularStringField(value: self.uploadedAt, fieldNumber: 4) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.success == rhs.success &&
        lhs.mediaID == rhs.mediaID &&
        lhs.fileURL == rhs.fileURL &&
        lhs.uploadedAt == rhs.uploadedAt &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_ListMediaRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".ListMediaRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "limit"),
        2: .same(proto: "offset"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &self.limit)
            case 2: try decoder.decodeSingularInt32Field(value: &self.offset)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.limit != 0 { try visitor.visitSingularInt32Field(value: self.limit, fieldNumber: 1) }
        if self.offset != 0 { try visitor.visitSingularInt32Field(value: self.offset, fieldNumber: 2) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.limit == rhs.limit && lhs.offset == rhs.offset && lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_MediaItem: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".MediaItem"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "media_id"),
        2: .standard(proto: "file_name"),
        3: .standard(proto: "content_type"),
        4: .standard(proto: "size_bytes"),
        5: .standard(proto: "file_url"),
        6: .same(proto: "note"),
        7: .standard(proto: "uploaded_at"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.mediaID)
            case 2: try decoder.decodeSingularStringField(value: &self.fileName)
            case 3: try decoder.decodeSingularStringField(value: &self.contentType)
            case 4: try decoder.decodeSingularInt64Field(value: &self.sizeBytes)
            case 5: try decoder.decodeSingularStringField(value: &self.fileURL)
            case 6: try decoder.decodeSingularStringField(value: &self.note)
            case 7: try decoder.decodeSingularStringField(value: &self.uploadedAt)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.mediaID.isEmpty { try visitor.visitSingularStringField(value: self.mediaID, fieldNumber: 1) }
        if !self.fileName.isEmpty { try visitor.visitSingularStringField(value: self.fileName, fieldNumber: 2) }
        if !self.contentType.isEmpty { try visitor.visitSingularStringField(value: self.contentType, fieldNumber: 3) }
        if self.sizeBytes != 0 { try visitor.visitSingularInt64Field(value: self.sizeBytes, fieldNumber: 4) }
        if !self.fileURL.isEmpty { try visitor.visitSingularStringField(value: self.fileURL, fieldNumber: 5) }
        if !self.note.isEmpty { try visitor.visitSingularStringField(value: self.note, fieldNumber: 6) }
        if !self.uploadedAt.isEmpty { try visitor.visitSingularStringField(value: self.uploadedAt, fieldNumber: 7) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.mediaID == rhs.mediaID &&
        lhs.fileName == rhs.fileName &&
        lhs.contentType == rhs.contentType &&
        lhs.sizeBytes == rhs.sizeBytes &&
        lhs.fileURL == rhs.fileURL &&
        lhs.note == rhs.note &&
        lhs.uploadedAt == rhs.uploadedAt &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Media_V1_ListMediaResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _media_protobuf_package + ".ListMediaResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "items"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &self.items)
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.items.isEmpty { try visitor.visitRepeatedMessageField(value: self.items, fieldNumber: 1) }
        try self.unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items && lhs.unknownFields == rhs.unknownFields
    }
}
