import Testing
import Foundation
@testable import Tracking

@Suite
struct TrackingDispatcherTests {
    private let dataStore = MockDatabase()
    private let networkClient = MockNetworkClient()
    private let sut: TrackingDispatcher

    init() {
        sut = .init(
            dataStore: dataStore,
            networkClient: networkClient,
            errorHandler: { _ in }
        )
    }

    @Test
    func send1LogByDigesting() async throws {
        await sut.saveAndStartDigesting(data: [Data()])
        await sut.digestingTask?.value
        #expect(dataStore.dataList.count == 0)
        #expect(dataStore.operations == [
            .insert, .select, .delete,
            // MEMO: select empty so stop digesting.
            .select
        ])
        #expect(networkClient.sentDataList.count == 1)
        let isDigesting = await sut.isDigesting
        #expect(isDigesting == false)
    }

    @Test
    func send4LogsByDigesting() async throws {
        await sut.saveAndStartDigesting(data: Array(repeating: Data(), count: 4))
        await sut.digestingTask?.value
        #expect(dataStore.dataList.count == 0)
        #expect(dataStore.operations == [
            .insert, .select, .delete,
            // MEMO: select empty so stop digesting.
            .select
        ])
        #expect(networkClient.sentDataList.count == 1)
        #expect(networkClient.sentDataList.flatMap { $0 }.count == 4)

        let isDigesting = await sut.isDigesting
        #expect(isDigesting == false)
    }

    @Test
    func digestLogImmediately() async throws {
        _ = try dataStore.save(data: [Data(), Data()])
        dataStore.operations = []
        await sut.startDigesting()
        await sut.digestingTask?.value
        #expect(dataStore.dataList.count == 0)
        #expect(dataStore.operations == [.select, .delete, .select])
        #expect(networkClient.sentDataList.count == 1)
    }

    @Test
    func notDigestEmptyDatabase() async throws {
        dataStore.operations = []
        await sut.startDigesting()
        await sut.digestingTask?.value
        #expect(dataStore.dataList.count == 0)
        #expect(dataStore.operations == [.select])
        #expect(networkClient.sentDataList.count == 0)
    }

    @Test
    func notSendWhenNetworkUnavailable() async throws {
        networkClient.isEnabled = false
        _ = try dataStore.save(data: [Data(), Data()])
        dataStore.operations = []
        await sut.startDigesting()
        await sut.digestingTask?.value
        #expect(dataStore.dataList.count == 2)
        #expect(dataStore.operations == [.select])
        #expect(networkClient.sentDataList.count == 0)
    }

    @Test
    func DigestLoopStopWhenEmpty() async throws {
        let data70 = Array(repeating: Data(), count: 70)
        _ = try dataStore.save(data: data70)
        dataStore.operations = []

        await sut.saveAndStartDigesting(data: [Data()])
        await sut.digestingTask?.value

        #expect(dataStore.operations == [
            .insert,
            .select, .delete,
            .select, .delete,
            .select
        ])
        #expect(networkClient.sentDataList.count == 2)
        #expect(networkClient.sentDataList.flatMap { $0 }.count == 71)
    }

    @Test
    func testConcurrentDigestCalls() async throws {
        let data70 = Array(repeating: Data(), count: 70)
        _ = try dataStore.save(data: data70)
        dataStore.operations = []

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.sut.saveAndStartDigesting(data: [Data()])
                await self.sut.digestingTask?.value
            }
            group.addTask {
                await self.sut.startDigesting()
            }
            group.addTask {
                await self.sut.startDigesting()
            }
        }

        #expect(networkClient.sentDataList.flatMap { $0 }.count == 71)
    }
}

private final class MockDatabase: @unchecked Sendable, TrackingDataStoreProtocol {
    enum DatabaseOperation: Equatable {
        case insert
        case select
        case delete
    }

    var operations: [DatabaseOperation] = []
    var dataList: [TrackingData] = []
    var idBase = 0
    func save(data: [Data]) throws -> [TrackingData] {
        let toInsert = data.map {
            defer { idBase += 1 }
            return TrackingData(id: idBase, data: $0)
        }
        dataList += toInsert
        operations.append(.insert)
        return toInsert
    }

    func getData(count: Int) throws -> [TrackingData] {
        operations.append(.select)
        return Array(dataList.prefix(count))
    }

    func deleteData(ids: [Int]) throws {
        operations.append(.delete)
        dataList = dataList.filter { !ids.contains($0.id) }
    }
}

private final class MockNetworkClient: @unchecked Sendable, TrackingNetworkClientProtocol {
    var sentDataList: [[TrackingData]] = []
    var isEnabled = true
    func send(trackingDataList: [TrackingData]) async throws {
        guard isEnabled else {
            throw NSError(domain: "NetworkUnavailable", code: 0, userInfo: nil)
        }
        sentDataList.append(trackingDataList)
    }
}
