import Foundation

public final class Tracker: Sendable {
    let dispatcher: TrackingDispatcherProtocol
    let networkClient: TrackingNetworkClientProtocol
    let sharedParameters: [String: Sendable]

    public init(
        dataStore: TrackingDataStoreProtocol,
        configuration: TrackingSystemConfiguration,
        logConfiguration: TrackingConfiguration
    ) {
        self.networkClient = TrackingNetworkClient(
            configuration: configuration.networkClientConfiguration,
            logConfiguration: logConfiguration
        )
        self.dispatcher = TrackingDispatcher(
            dataStore: dataStore,
            networkClient: networkClient,
            errorHandler: configuration.errorHandler
        )
        self.sharedParameters = logConfiguration.sharedParameters
    }

    public func sendLog(name: String, payload: [String: Sendable]) {
        let merged = sharedParameters.merging(payload, uniquingKeysWith: { $1 })
        dispatcher.sendLog(name: name, payload: merged)
    }

    public func sendLogs(name: String, payloads: [[String: Sendable]]) {
        let merged = payloads.map { sharedParameters.merging($0, uniquingKeysWith: { $1 }) }
        dispatcher.sendLogs(name: name, payloads: merged)
    }
}

