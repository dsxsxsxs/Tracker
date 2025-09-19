import Foundation
import SQLite3
import os

private let tableName = "Tracking"
private let primaryKey = "id"
private let dataKey = "rawData"

public final class TrackingSQLiteDataStore: TrackingDataStoreProtocol {
    private let databasePointer = DatabasePointer()
    private var db: OpaquePointer? {
        get { databasePointer.pointer }
        set { databasePointer.pointer = newValue }
    }

    private let databaseFileURL: URL

    public init() throws {
        databaseFileURL = try Self.getDatabaseFileURL()
        try openDatabase()
        try createTable()
    }

    init(shouldCreateTable: Bool) {
        databaseFileURL = try! Self.getDatabaseFileURL()
        if shouldCreateTable {
            try! createTable()
        } else {
            try! deleteDatabase()
        }
        try! openDatabase()
    }

    deinit {
        if db == nil { return }
        sqlite3_close(db)
        db = nil
    }

    func openDatabase() throws {
        if sqlite3_open(databaseFileURL.path, &db) != SQLITE_OK {
            throw error()
        }
    }

    func createTable() throws {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(primaryKey) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(dataKey) BLOB
        );
        """
        if sqlite3_exec(db, createTableString, nil, nil, nil) != SQLITE_OK {
            throw error()
        }
    }

    public func save(data: [Data]) throws -> [TrackingData] {
        if data.isEmpty {
            return []
        }
        let insertStatementString = "INSERT INTO \(tableName) (\(dataKey)) VALUES (?);"
        do {
            beginTransaction()
            for data in data {
                try executeUpdate(sql: insertStatementString, values: [data])
            }
            try commit()

            let lastInsertRowId = self.lastInsertRowId()
            let startID = lastInsertRowId - data.count + 1
            return zip(startID ... lastInsertRowId, data).map { TrackingData(id: $0, data: $1) }
        } catch {
            rollback()
            throw error
        }
    }

    public func getData(count: Int) throws -> [TrackingData] {
        let selectStatementString = "SELECT * FROM \(tableName) ORDER BY id ASC LIMIT ?;"
        let result = try executeQuery(sql: selectStatementString, values: [count])
        return result.map { row in
            let id = row[0] as! Int
            let data = row[1] as! Data
            return TrackingData(id: id, data: data)
        }
    }

    public func deleteData(ids: [Int]) throws {
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let deleteStatementString = "DELETE FROM \(tableName) WHERE id IN (\(placeholders));"
        do {
            beginTransaction()
            try executeUpdate(sql: deleteStatementString, values: ids)
            try commit()
        } catch {
            rollback()
            throw error
        }
    }

    func emptyDatabase() throws {
        let deleteStatementString = "DELETE FROM \(tableName);"
        do {
            beginTransaction()
            try executeUpdate(sql: deleteStatementString, values: [])
            try commit()
        } catch {
            rollback()
            throw error
        }
    }
}

extension TrackingSQLiteDataStore {
    final class QueryResult: Sequence {
        struct Iterator: IteratorProtocol {
            typealias Element = [Any]
            var statement: OpaquePointer?
            func next() -> [Any]? {
                guard sqlite3_step(statement) == SQLITE_ROW else {
                    return nil
                }
                let columnCount = sqlite3_column_count(statement)
                var row = [Any]()
                for i in 0 ..< columnCount {
                    switch sqlite3_column_type(statement, i) {
                    case SQLITE_INTEGER:
                        row.append(Int(sqlite3_column_int(statement, i)))
                    case SQLITE_TEXT:
                        row.append(String(cString: sqlite3_column_text(statement, i)))
                    case SQLITE_BLOB:
                        let data = Data(bytes: sqlite3_column_blob(statement, i), count: Int(sqlite3_column_bytes(statement, i)))
                        row.append(data)
                    default:
                        row.append(())
                    }
                }
                return row
            }
        }

        typealias Element = [Any]
        var statement: OpaquePointer?

        init(statement: OpaquePointer?) {
            self.statement = statement
        }

        deinit {
            sqlite3_finalize(statement)
        }

        func makeIterator() -> Iterator {
            Iterator(statement: statement)
        }
    }

    private func executeUpdate(sql: String, values: [Any]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            throw error(sql: sql)
        }

        for (index, value) in values.enumerated() {
            switch value {
            case let value as Int:
                sqlite3_bind_int(statement, Int32(index + 1), Int32(value))
            case let value as String:
                let nsString = value as NSString
                sqlite3_bind_text(statement, Int32(index + 1), nsString.utf8String, -1, nil)
            case let value as Data:
                let nsData = NSData(data: value)
                sqlite3_bind_blob(statement, Int32(index + 1), nsData.bytes, Int32(nsData.count), nil)
            default:
                break
            }
        }
        let result = sqlite3_step(statement)
        if result != SQLITE_DONE && result != SQLITE_OK {
            sqlite3_finalize(statement)
            throw error(sql: sql)
        }
        sqlite3_finalize(statement)
    }

    private func executeQuery(sql: String, values: [Any]) throws -> QueryResult {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw error(sql: sql)
        }

        for (index, value) in values.enumerated() {
            switch value {
            case let value as Int:
                sqlite3_bind_int(statement, Int32(index + 1), Int32(value))
            case let value as String:
                let nsString = value as NSString
                sqlite3_bind_text(statement, Int32(index + 1), nsString.utf8String, -1, nil)
            case let value as Data:
                let nsData = NSData(data: value)
                sqlite3_bind_blob(statement, Int32(index + 1), nsData.bytes, Int32(nsData.count), nil)
            default:
                break
            }
        }
        return QueryResult(statement: statement)
    }

    private func beginTransaction() {
        try? executeUpdate(sql: "begin transaction", values: [])
    }

    private func rollback() {
        try? executeUpdate(sql: "rollback transaction", values: [])
    }

    private func commit() throws {
        try executeUpdate(sql: "commit transaction", values: [])
    }

    private static func getDatabaseFileURL() throws -> URL {
        guard let fileURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("tracking.sqlite") else {
            throw NSError(domain: "[SQLiteDatabase] Failed to get database file URL", code: -1, userInfo: nil)
        }
        return fileURL
    }

    private func lastInsertRowId() -> Int {
        Int(sqlite3_last_insert_rowid(db))
    }

    func dropTable() throws {
        let dropTableString = "DROP TABLE \(tableName);"
        if sqlite3_exec(db, dropTableString, nil, nil, nil) != SQLITE_OK {
            throw error(sql: dropTableString)
        }
    }

    private func deleteDatabase() throws {
        if FileManager.default.fileExists(atPath: databaseFileURL.path) {
            try FileManager.default.removeItem(at: databaseFileURL)
        }
    }

    private func error(sql: String? = nil, function: String = #function, line: Int = #line) -> Error {
        let message = String(cString: sqlite3_errmsg(db))
        var userInfo: [String: Sendable] = [
            "function": function,
            "line": line
        ]
        userInfo["sql"] = sql
        return NSError(domain: "[SQLiteDatabase] \(message).\nat \(function),\nline \(line)\n sql:\(String(describing: sql))", code: Int(sqlite3_errcode(db)), userInfo: userInfo)
    }
}

private final class DatabasePointer: @unchecked Sendable {
    let lock = NSRecursiveLock()
    private var _pointer: OpaquePointer?

    var pointer: OpaquePointer? {
        get {
            defer { lock.unlock() }
            lock.lock()
            return _pointer
        }
        set {
            defer { lock.unlock() }
            lock.lock()
            _pointer = newValue
        }
    }
}

final class TrackingInMemoryDatabase: Sendable, TrackingDataStoreProtocol {
    private let primaryKey = OSAllocatedUnfairLock<Int>(initialState: 1)
    private let lockedDataList = OSAllocatedUnfairLock<[TrackingData]>(initialState: [])
    private var dataList: [TrackingData] {
        get { lockedDataList.withLockUnchecked { $0 } }
        set { lockedDataList.withLockUnchecked { $0 = newValue } }
    }

    private var lastID: Int {
        primaryKey.withLockUnchecked { pk in
            defer { pk += 1 }
            return pk
        }
    }

    func save(data: [Data]) throws -> [TrackingData] {
        if dataList.count > 100 { return [] }
        let toInsert: [TrackingData] = data.enumerated()
            .map { .init(id: lastID, data: $1) }
        dataList += toInsert
        return toInsert
    }

    func getData(count: Int) throws -> [TrackingData] {
        if dataList.isEmpty { return [] }
        let startIndex = max(0, dataList.count - count)
        let endIndex = dataList.count
        return Array(dataList[startIndex ..< endIndex])
    }

    func deleteData(ids: [Int]) throws {
        if ids.isEmpty { return }
        dataList = dataList.filter { !ids.contains($0.id) }

    }

    func clear() {
        primaryKey.withLockUnchecked { $0 = 1 }
        dataList = []
    }
}
