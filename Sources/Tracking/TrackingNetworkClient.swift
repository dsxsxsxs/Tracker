import Foundation

protocol TrackingNetworkClientNetworking: Sendable {
    func executeRequest(request: URLRequest) async throws -> (Data, URLResponse)
}

private let minimumDeflateSize: Int32 = 5120

public actor TrackingNetworkClient: TrackingNetworkClientProtocol {
    let networking: TrackingNetworkClientNetworking
    let suspend: @Sendable (Int) async throws -> Void
    let maxRetryCount: Int
    let logConfiguration: TrackingConfiguration
    let urlComponents: URLComponents

    public init(configuration: TrackingNetworkClientConfiguration, logConfiguration: TrackingConfiguration) {
        self.maxRetryCount = configuration.maxRetryCount
        self.networking = configuration.networking
        self.suspend = configuration.suspend
        let path = "/log"
        let endpoint: String = switch logConfiguration.environment {
        case .development:
            "https://dev.tracker.hoge.jp"
        case .production:
            "https://tracker.hoge.jp"
        }
        var urlComponents = URLComponents(string: endpoint)!
        urlComponents.path = path
        self.urlComponents = urlComponents
        self.logConfiguration = logConfiguration
    }

    public func send(trackingDataList: [TrackingData]) async throws {
        let urlComponents = self.urlComponents

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in logConfiguration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let rawData = try trackingDataList.asData()
        if rawData.count > minimumDeflateSize, let deflated = try? rawData.deflated() {
            request.httpBody = deflated
            request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
            request.setValue("\(deflated.count)", forHTTPHeaderField: "Content-Length")
        } else {
            request.httpBody = rawData
            request.setValue("\(rawData.count)", forHTTPHeaderField: "Content-Length")
        }

        var retryAttempts = 0
        var error: Error?
        repeat {
            do {
                if retryAttempts > 0 {
                    let delay = pow(2.0, Double(retryAttempts))
                    try await suspend(Int(delay))
                }
                try await self.executeRequest(request: request)
                error = nil
                break
            } catch let e {
                error = e
                retryAttempts += 1
            }
        } while retryAttempts <= maxRetryCount
        if let error {
            throw error
        }
    }

    private func executeRequest(request: URLRequest) async throws {
        let (_, response) = try await networking.executeRequest(request: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 0)
        }
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP Request Failed", code: httpResponse.statusCode)
        }
    }
}

extension TrackingNetworkClient {
    struct DefaultNetworking: TrackingNetworkClientNetworking {
        func executeRequest(request: URLRequest) async throws -> (Data, URLResponse) {
            try await Self.requestViaURLSession(request: request)
        }

        ///  MEMO: to workaround this warning:
        /// https://stackoverflow.com/questions/78763125/passing-argument-of-non-sendable-type-any-urlsessiontaskdelegate-outside-of
        private static func requestViaURLSession(request: URLRequest) async throws -> (Data, URLResponse) {
            try await URLSession.shared.data(for: request)
        }
    }
}
