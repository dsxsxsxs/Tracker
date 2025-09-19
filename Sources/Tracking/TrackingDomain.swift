import Foundation

public struct TrackingData: Sendable {
    let id: Int
    let data: Data
}

public protocol TrackingDataStoreProtocol: Sendable {
    func save(data: [Data]) throws -> [TrackingData]
    func getData(count: Int) throws -> [TrackingData]
    func deleteData(ids: [Int]) throws
}

public protocol TrackingNetworkClientProtocol: Sendable {
    func send(trackingDataList: [TrackingData]) async throws
}

public protocol TrackingDispatcherProtocol: Sendable {
    func sendLog(name: String, payload: [String: Sendable])
    func sendLogs(name: String, payloads: [[String: Sendable]])
}
