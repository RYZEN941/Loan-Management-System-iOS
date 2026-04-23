@available(iOS 18.0, *)
enum ServiceContainer {
    static let loanService: LoanServiceProtocol = LoanGRPCClient()
}
