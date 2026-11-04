import Foundation

/// The seam between the cashier client and the network. Production uses `URLSessionTransport`; tests use `StubTransport`.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// A private ephemeral session: no shared cookie jar, no cache. Cookies are handled by `CashierSession` (stored in the Keychain).
struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    init(timeout: TimeInterval = 15) {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.timeoutIntervalForRequest = timeout
        c.waitsForConnectivity = false
        session = URLSession(configuration: c)
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
