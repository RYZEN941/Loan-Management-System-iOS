import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
enum CoreAPIClient {
    static func withClient<Result>(
        operation: @escaping @Sendable (GRPCClient<HTTP2ClientTransport.Posix>) async throws -> Result
    ) async throws -> Result {
        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: APIConfig.host, port: APIConfig.port),
            transportSecurity: .tls
        )

        return try await withGRPCClient(transport: transport) { client in
            try await operation(client)
        }
    }

    static func authorizedMetadata() async -> Metadata {
        let token = await MainActor.run { SessionStore.shared.accessToken }
        var metadata: Metadata = [:]
        if !token.isEmpty {
            metadata.addString("Bearer \(token)", forKey: "authorization")
        }
        metadata.addString(UUID().uuidString, forKey: "x-request-id")
        return metadata
    }

    static func anonymousMetadata() -> Metadata {
        var metadata: Metadata = [:]
        metadata.addString(UUID().uuidString, forKey: "x-request-id")
        return metadata
    }
}
