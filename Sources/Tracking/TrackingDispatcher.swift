import Foundation

actor TrackingDispatcher: TrackingDispatcherProtocol {
    private let dataStore: TrackingDataStoreProtocol
    private let networkClient: TrackingNetworkClientProtocol
    private let errorHandler: TrackingErrorHandler

    private(set) var digestingTask: Task<Void, Never>?
    var isDigesting: Bool {
        digestingTask != nil
    }
    private let executor: LogSerialExecutor
    let unownedExecutor: UnownedSerialExecutor

    public init(dataStore: TrackingDataStoreProtocol, networkClient: TrackingNetworkClientProtocol, errorHandler: @escaping TrackingErrorHandler) {
        self.dataStore = dataStore
        self.networkClient = networkClient
        self.errorHandler = errorHandler
        executor = LogSerialExecutor()
        self.unownedExecutor = executor.asUnownedSerialExecutor()
    }

    nonisolated func sendLog(name: String, payload: [String: Sendable]) {
        self.sendLogs(name: name, payloads: [payload])
    }

    nonisolated func sendLogs(name: String, payloads: [[String: Sendable]]) {
        if payloads.isEmpty { return }
        guard let encoded = try? Self.makeLogData(name: name, payloads: payloads) else {
            return
        }
        Task.detached(priority: .utility) {
            await self.saveAndStartDigesting(data: encoded)
        }
    }

    private static func makeLogData(name: String, payloads: [[String: Sendable]]) throws -> [Data] {
        let encoder = JSONEncoder()
        let now = Date()
        let events: [TrackingLog] = payloads.map {
            TrackingLog(
                eventId: name,
                eventTime: now,
                payload: $0
            )
        }
        return try events.map { try encoder.encode($0) }
    }

    func saveAndStartDigesting(data: [Data]) {
        do {
            _ = try dataStore.save(data: data)
            startDigesting()
        } catch {
            errorHandler(error)
        }
    }

    func startDigesting() {
        if self.isDigesting { return }
        digestingTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            var shouldContinue = true
            while shouldContinue {
                shouldContinue = await self.digestdataStore()
            }
            await self.stopDigesting()
        }
    }

    private func stopDigesting() {
        digestingTask?.cancel()
        digestingTask = nil
    }

    private func digestdataStore() async -> Bool {
        guard isDigesting else { return false }
        if Task.isCancelled {
            return false
        }
        do {
            let dataToSend = try dataStore.getData(count: 50)
            if dataToSend.isEmpty || Task.isCancelled {
                return false
            }

            try await networkClient.send(trackingDataList: dataToSend)
            let ids = dataToSend.map { $0.id }
            try dataStore.deleteData(ids: ids)
            await Task.yield()
            return true
        } catch {
            // select log failed or network error
            // stop digesting
            errorHandler(error)
            return false
        }
    }
}

private final class LogSerialExecutor: SerialExecutor {
    private let serialQueue = DispatchQueue(label: "TrackingDispatcher.LogSerialExecutor", qos: .utility)

    nonisolated func enqueue(_ job: UnownedJob) {
        serialQueue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}
