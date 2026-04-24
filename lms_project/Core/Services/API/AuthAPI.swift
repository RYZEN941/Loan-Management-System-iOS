import Foundation
import GRPCCore
import SwiftProtobuf
import GRPCProtobuf

@available(iOS 18.0, *)
struct AuthAPI {
    func loginPrimary(emailOrPhone: String, password: String) async throws -> Auth_V1_LoginPrimaryResponse {
        let request: Auth_V1_LoginRequest = {
            var req = Auth_V1_LoginRequest()
            req.emailOrPhone = emailOrPhone
            req.password = password
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.loginPrimary(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func selectLoginMFAFactor(mfaSessionID: String, factor: String) async throws -> Auth_V1_SelectLoginMFAFactorResponse {
        let request: Auth_V1_SelectLoginMFAFactorRequest = {
            var req = Auth_V1_SelectLoginMFAFactorRequest()
            req.mfaSessionID = mfaSessionID
            req.factor = factor
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.selectLoginMFAFactor(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func verifyLoginMFA(
        mfaSessionID: String,
        method: MFAMethod,
        otpCode: String,
        deviceID: String
    ) async throws -> Auth_V1_AuthTokens {
        let request: Auth_V1_VerifyLoginMFARequest = {
            var req = Auth_V1_VerifyLoginMFARequest()
            req.mfaSessionID = mfaSessionID
            req.deviceID = deviceID
            switch method {
            case .email:
                req.factor = .emailOtpCode(otpCode)
            case .sms:
                req.factor = .phoneOtpCode(otpCode)
            }
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.verifyLoginMFA(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func getMyProfile() async throws -> Auth_V1_GetMyProfileResponse {
        let request = Auth_V1_GetMyProfileRequest()
        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.getMyProfile(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> Auth_V1_ChangePasswordResponse {
        let request: Auth_V1_ChangePasswordRequest = {
            var req = Auth_V1_ChangePasswordRequest()
            req.currentPassword = currentPassword
            req.newPassword = newPassword
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.changePassword(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func logout(accessToken: String, refreshToken: String) async throws -> Auth_V1_LogoutResponse {
        let request: Auth_V1_LogoutRequest = {
            var req = Auth_V1_LogoutRequest()
            req.accessToken = accessToken
            req.refreshToken = refreshToken
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.logout(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func searchBorrowerSignupStatus(query: String, limit: Int32, offset: Int32) async throws -> Auth_V1_SearchBorrowerSignupStatusResponse {
        var req = Auth_V1_SearchBorrowerSignupStatusRequest()
        req.query = query
        req.limit = limit
        req.offset = offset
        
        let descriptor = GRPCCore.MethodDescriptor(
            service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "auth.v1.AuthService"),
            method: "SearchBorrowerSignupStatus"
        )

        let metadata = await CoreAPIClient.authorizedMetadata()
        return try await CoreAPIClient.withClient { client in
            try await client.unary(
                request: .init(message: req, metadata: metadata),
                descriptor: descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Auth_V1_SearchBorrowerSignupStatusRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Auth_V1_SearchBorrowerSignupStatusResponse>(),
                options: .defaults
            ) { response in
                try response.message
            }
        }
    }
}

// MARK: - Manual Proto Definitions for SearchBorrowerSignupStatus

struct Auth_V1_SearchBorrowerSignupStatusRequest: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusRequest"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{5}query\0\u{5}limit\0\u{6}offset\0")

    var query: String = ""
    var limit: Int32 = 0
    var offset: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &query)
            case 2: try decoder.decodeSingularInt32Field(value: &limit)
            case 3: try decoder.decodeSingularInt32Field(value: &offset)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !query.isEmpty { try visitor.visitSingularStringField(value: query, fieldNumber: 1) }
        if limit != 0 { try visitor.visitSingularInt32Field(value: limit, fieldNumber: 2) }
        if offset != 0 { try visitor.visitSingularInt32Field(value: offset, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.query == rhs.query && lhs.limit == rhs.limit && lhs.offset == rhs.offset
    }
}

struct Auth_V1_BorrowerSignupStatusItem: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.BorrowerSignupStatusItem"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{7}user_id\0\u{5}email\0\u{5}phone\0\u{11}is_email_verified\0\u{11}is_phone_verified\0\u{9}is_active\0\u{14}onboarding_completed\0\u{D}kyc_completed\0\u{13}borrower_profile_id\0\u{C}signup_stage\0")

    var userId: String = ""
    var email: String = ""
    var phone: String = ""
    var isEmailVerified: Bool = false
    var isPhoneVerified: Bool = false
    var isActive: Bool = false
    var onboardingCompleted: Bool = false
    var kycCompleted: Bool = false
    var borrowerProfileId: String = ""
    var signupStage: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &userId)
            case 2: try decoder.decodeSingularStringField(value: &email)
            case 3: try decoder.decodeSingularStringField(value: &phone)
            case 4: try decoder.decodeSingularBoolField(value: &isEmailVerified)
            case 5: try decoder.decodeSingularBoolField(value: &isPhoneVerified)
            case 6: try decoder.decodeSingularBoolField(value: &isActive)
            case 7: try decoder.decodeSingularBoolField(value: &onboardingCompleted)
            case 8: try decoder.decodeSingularBoolField(value: &kycCompleted)
            case 9: try decoder.decodeSingularStringField(value: &borrowerProfileId)
            case 10: try decoder.decodeSingularStringField(value: &signupStage)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !userId.isEmpty { try visitor.visitSingularStringField(value: userId, fieldNumber: 1) }
        if !email.isEmpty { try visitor.visitSingularStringField(value: email, fieldNumber: 2) }
        if !phone.isEmpty { try visitor.visitSingularStringField(value: phone, fieldNumber: 3) }
        if isEmailVerified { try visitor.visitSingularBoolField(value: isEmailVerified, fieldNumber: 4) }
        if isPhoneVerified { try visitor.visitSingularBoolField(value: isPhoneVerified, fieldNumber: 5) }
        if isActive { try visitor.visitSingularBoolField(value: isActive, fieldNumber: 6) }
        if onboardingCompleted { try visitor.visitSingularBoolField(value: onboardingCompleted, fieldNumber: 7) }
        if kycCompleted { try visitor.visitSingularBoolField(value: kycCompleted, fieldNumber: 8) }
        if !borrowerProfileId.isEmpty { try visitor.visitSingularStringField(value: borrowerProfileId, fieldNumber: 9) }
        if !signupStage.isEmpty { try visitor.visitSingularStringField(value: signupStage, fieldNumber: 10) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.userId == rhs.userId && lhs.email == rhs.email && lhs.phone == rhs.phone && lhs.isEmailVerified == rhs.isEmailVerified && lhs.isPhoneVerified == rhs.isPhoneVerified && lhs.isActive == rhs.isActive && lhs.onboardingCompleted == rhs.onboardingCompleted && lhs.kycCompleted == rhs.kycCompleted && lhs.borrowerProfileId == rhs.borrowerProfileId && lhs.signupStage == rhs.signupStage
    }
}

struct Auth_V1_SearchBorrowerSignupStatusResponse: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{5}items\0")

    var items: [Auth_V1_BorrowerSignupStatusItem] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !items.isEmpty { try visitor.visitRepeatedMessageField(value: items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.items == rhs.items
    }
}
