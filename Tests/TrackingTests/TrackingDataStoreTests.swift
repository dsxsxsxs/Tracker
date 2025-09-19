import Testing
@testable import Tracking

private let sqlite = TrackingSQLiteDataStore(shouldCreateTable: false)
private let inMemory = TrackingInMemoryDatabase()
private let suts: [TrackingDataStoreProtocol] = [sqlite, inMemory]

@Suite(.serialized)
final class TrackingDataStoreTests {

    init() throws {
        try sqlite.createTable()
    }

    deinit {
        // FIXME: can not throw from deinit.
        try! sqlite.dropTable()
        inMemory.clear()
    }

    @Test(arguments: suts)
    func insertNothing(sut: TrackingDataStoreProtocol) throws {
        let result = try sut.save(data: [])
        #expect(result.count == 0)
        let selectResult = try sut.getData(count: 10)
        #expect(selectResult.count == 0)
    }

    @Test(arguments: suts)
    func saveCorrectly(sut: TrackingDataStoreProtocol) throws {
        // MEMO: PK starts from 1
        let ids: [Int] = Array(1 ... 10)
        let mockStringData = ids
            .compactMap { "データdata資料📊\($0)".data(using: .utf8) }
        let result = try sut.save(data: mockStringData)

        #expect(result.count == mockStringData.count)
        #expect(result.map { $0.data } == mockStringData)
        #expect(result.map { $0.id } == ids)

        let selectResult = try sut.getData(count: 10)

        #expect(selectResult.count == mockStringData.count)
        #expect(selectResult.compactMap { String(data: $0.data, encoding: .utf8) } == mockStringData.compactMap { String(data: $0, encoding: .utf8) })
        #expect(selectResult.map { $0.id } == ids)
    }

    @Test(arguments: suts)
    func testDeleteLogs(sut: TrackingDataStoreProtocol) throws {
        try insert10Logs(sut)
        let ids = [1, 3, 5, 7, 9]
        try sut.deleteData(ids: ids)
        let result = try sut.getData(count: 10)
        #expect(result.count == 5)
        #expect(result.map { $0.id } == [2, 4, 6, 8, 10])
    }

    @Test(arguments: suts)
    func deleteNoLog(sut: TrackingDataStoreProtocol) throws {
        try insert10Logs(sut)
        try sut.deleteData(ids: [])
        let result = try sut.getData(count: 10)
        #expect(result.count == 10)
        #expect(result.map { $0.id } == Array(1 ... 10))
    }

    @Test(arguments: suts)
    func deleteAllLogs(sut: TrackingDataStoreProtocol) throws {
        try insert10Logs(sut)
        let ids = Array(1 ... 10)
        try sut.deleteData(ids: ids)
        let result = try sut.getData(count: 10)
        #expect(result.count == 0)
    }

    @Test
    func testEmptyDatabase() throws {
        try insert10Logs(sqlite)
        try insert10Logs(sqlite)
        try insert10Logs(sqlite)
        try sqlite.emptyDatabase()
        let result = try sqlite.getData(count: 10)
        #expect(result.count == 0)
    }

    @Test(arguments: suts)
    func integratedOperations(sut: TrackingDataStoreProtocol) throws {
        try insert10Logs(sut)
        try insert10Logs(sut)
        try insert10Logs(sut)
        let result = try sut.getData(count: 30)
        #expect(result.count == 30)
        #expect(result.map { $0.id } == Array(1 ... 30))
        let ids = Array(1 ... 30)
        try sut.deleteData(ids: ids)
        let result2 = try sut.getData(count: 30)
        #expect(result2.count == 0)
        try insert10Logs(sut)
        try insert10Logs(sut)
        let result3 = try sut.getData(count: 20)
        #expect(result3.count == 20)
        #expect(result3.map { $0.id } == Array(31 ... 50))
        let idsToDelete = [32, 35, 38, 47, 41, 33, 44]
        let expected = Set(31 ... 50).subtracting(Set(idsToDelete))
        try sut.deleteData(ids: idsToDelete)
        let result4 = try sut.getData(count: 20)
        #expect(result4.count == expected.count)
        #expect(result4.map { $0.id } == Array(expected).sorted())
    }

    func insert10Logs(_ sut: TrackingDataStoreProtocol) throws {
        let ids: [Int] = Array(1 ... 10)
        let mockStringData = ids
            .compactMap { "data\($0)".data(using: .utf8) }
        _ = try sut.save(data: mockStringData)
    }
}
