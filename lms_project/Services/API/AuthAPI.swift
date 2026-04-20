import Foundation
import GRPCCore

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
}
