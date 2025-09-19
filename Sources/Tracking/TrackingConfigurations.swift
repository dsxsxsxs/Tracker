public enum TrackingEnvironment: Sendable {
    case development
    case production
}

public struct TrackingConfiguration: Sendable {
    var environment: TrackingEnvironment
    var headers: [String: String]
    var sharedParameters: [String: Sendable]
}
public struct TrackingSystemConfiguration: Sendable {
    let networkClientConfiguration: TrackingNetworkClientConfiguration
    let errorHandler: @Sendable (Error) -> Void
}
public struct TrackingNetworkClientConfiguration: Sendable {
    let maxRetryCount: Int
    let suspend: @Sendable (Int) async throws -> Void
    let networking: TrackingNetworkClientNetworking
}

public typealias TrackingErrorHandler = @Sendable (Error) -> Void

