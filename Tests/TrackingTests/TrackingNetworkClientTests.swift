import Testing
import Foundation
@testable import Tracking

@Suite
final class TrackingNetworkClientTests: @unchecked Sendable {
    private let emptyLogConfig = TrackingConfiguration(
        environment: .development,
        headers: [:],
        sharedParameters: [:]
    )
    var receivedSuspendSeconds: [Int] = []
    private var networking: ImmediateNetworking!
    private var sut: TrackingNetworkClient!

    init() {
        self.networking = ImmediateNetworking(statusCode: 200)
        sut = TrackingNetworkClient(
            configuration: .init(
                maxRetryCount: 3,
                suspend: {
                    self.receivedSuspendSeconds.append($0)
                },
                networking: networking
            ),
            logConfiguration: self.emptyLogConfig
        )
    }

    @Test
    func sendSucceed() async throws {
        let trackingDataList = [
            TrackingData(id: 1, data: Data()),
        ]
        try await sut.send(trackingDataList: trackingDataList)
        #expect(networking.receivedRequests.count == 1)
        #expect(receivedSuspendSeconds == [])
    }

    @Test
    func failWithWrongResponse() async throws {
        self.sut = TrackingNetworkClient(
            configuration: .init(
                maxRetryCount: 0,
                suspend: {
                    self.receivedSuspendSeconds.append($0)
                },
                networking: BrokenNetworking()
            ),
            logConfiguration: self.emptyLogConfig
        )
        let trackingDataList = [
            TrackingData(id: 1, data: Data()),
        ]

        await #expect {
            try await self.sut.send(trackingDataList: trackingDataList)
        } throws: { error in
            let nsError = error as NSError
            return nsError.domain == "Invalid Response"
        }
        #expect(receivedSuspendSeconds == [])
    }

    @Test
    func failHTTP400ThenRetry3Times() async throws {
        self.networking = ImmediateNetworking(statusCode: 400)
        self.sut = TrackingNetworkClient(
            configuration: .init(
                maxRetryCount: 3,
                suspend: {
                    self.receivedSuspendSeconds.append($0)
                },
                networking: networking
            ),
            logConfiguration: self.emptyLogConfig
        )
        let trackingDataList = [
            TrackingData(id: 1, data: Data()),
        ]

        await #expect {
            try await self.sut.send(trackingDataList: trackingDataList)
        } throws: { error in
            let nsError = error as NSError
            return nsError.code == 400
        }
        #expect(networking.receivedRequests.count == 4)
        #expect(receivedSuspendSeconds == [2, 4, 8])
    }
}

private final class ImmediateNetworking: @unchecked Sendable, TrackingNetworkClientNetworking {
    var receivedRequests: [URLRequest] = []
    let statusCode: Int

    init(statusCode: Int) {
        self.statusCode = statusCode
    }

    func executeRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        receivedRequests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

private final class BrokenNetworking: TrackingNetworkClientNetworking {
    func executeRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        (Data(), URLResponse())
    }
}
