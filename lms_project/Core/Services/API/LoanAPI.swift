import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
struct LoanAPI {
    func listLoanProducts(limit: Int32 = 100, offset: Int32 = 0, includeDeleted: Bool = false, authorized: Bool = true) async throws -> [Loan_V1_LoanProduct] {
        var request = Loan_V1_ListLoanProductsRequest()
        request.limit = limit
        request.offset = offset
        request.includeDeleted = includeDeleted

        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.listLoanProducts(req, metadata: metadata).items
        }
    }

    func getLoanProduct(productID: String, authorized: Bool = true) async throws -> Loan_V1_LoanProduct {
        var request = Loan_V1_GetLoanProductRequest()
        request.productID = productID
        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.getLoanProduct(req, metadata: metadata).product
        }
    }

    func createLoanProduct(_ product: LoanProduct) async throws -> Loan_V1_LoanProduct {
        try await perform(product.protoCreateRequest, authorized: true) { service, req, metadata in
            try await service.createLoanProduct(req, metadata: metadata).product
        }
    }

    func updateLoanProduct(_ product: LoanProduct) async throws -> Loan_V1_LoanProduct {
        try await perform(product.protoUpdateRequest, authorized: true) { service, req, metadata in
            try await service.updateLoanProduct(req, metadata: metadata).product
        }
    }

    func deleteLoanProduct(productID: String) async throws {
        var request = Loan_V1_DeleteLoanProductRequest()
        request.productID = productID
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.deleteLoanProduct(req, metadata: metadata)
        }
    }

    func upsertEligibility(productID: String, rule: LoanProduct.EligibilityRule?) async throws {
        var request = Loan_V1_UpsertProductEligibilityRuleRequest()
        request.productID = productID
        if let rule {
            request.minAge = Int32(rule.minAge)
            request.minMonthlyIncome = rule.minMonthlyIncome
            request.minBureauScore = Int32(rule.minBureauScore)
            request.allowedEmploymentTypes = rule.allowedEmploymentTypes
        }
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.upsertProductEligibilityRule(req, metadata: metadata)
        }
    }

    func replaceFees(productID: String, fees: [LoanProduct.Fee]) async throws {
        var request = Loan_V1_ReplaceProductFeesRequest()
        request.productID = productID
        request.items = fees.map(\.protoInput)
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.replaceProductFees(req, metadata: metadata)
        }
    }

    func replaceRequiredDocuments(productID: String, documents: [LoanProduct.RequiredDocument]) async throws {
        var request = Loan_V1_ReplaceProductRequiredDocumentsRequest()
        request.productID = productID
        request.items = documents.map(\.protoInput)
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.replaceProductRequiredDocuments(req, metadata: metadata)
        }
    }

    private func perform<Request, Result>(
        _ request: Request,
        authorized: Bool,
        operation: @escaping @Sendable (Loan_V1_LoanService.Client<HTTP2ClientTransport.Posix>, Request, Metadata) async throws -> Result
    ) async throws -> Result {
        do {
            return try await CoreAPIClient.withClient { client in
                let service = Loan_V1_LoanService.Client(wrapping: client)
                let metadata = authorized ? await CoreAPIClient.authorizedMetadata() : CoreAPIClient.anonymousMetadata()
                return try await operation(service, request, metadata)
            }
        } catch {
            throw APIError.from(error)
        }
    }
}
