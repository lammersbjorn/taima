// The SQLite store is Apple-only; Android keeps records with its own storage
// and shares the record JSON and backup format instead.
#if canImport(SQLite3)
import Foundation
import SQLite3

public enum StoreError: Error, LocalizedError {
    case sqlite(String)

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): String(localized: "Database error: \(message)", bundle: .taimaLocalization)
        }
    }
}

/// Explicit SQLite storage. Bags are stored as JSON documents next to the few
/// columns that need indexing, so adding a field never needs a migration.
public final class BagStore: @unchecked Sendable {
    public static let schemaVersion = 2

    private var db: OpaquePointer?
    private let lock = NSLock()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }()

    /// Pass `nil` for an in-memory store.
    public init(url: URL?) throws {
        let path = url?.path ?? ":memory:"
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        // The app and the Live Activity intent can write at the same time.
        sqlite3_busy_timeout(db, 3000)
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
        try migrate()
    }

    deinit {
        sqlite3_close_v2(db)
    }

    private func migrate() throws {
        var version: Int32 = 0
        try query("PRAGMA user_version") { statement in
            version = sqlite3_column_int(statement, 0)
        }
        if version < 1 {
            try execute("""
                CREATE TABLE IF NOT EXISTS bag (
                    id TEXT PRIMARY KEY NOT NULL,
                    collected_on REAL NOT NULL,
                    body TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS bag_collected ON bag (collected_on DESC);
                CREATE TABLE IF NOT EXISTS producer_key (
                    key TEXT PRIMARY KEY NOT NULL,
                    producer TEXT NOT NULL
                );
                PRAGMA user_version = 1;
                """)
        }
        if version < 2 {
            try execute("""
                CREATE TABLE IF NOT EXISTS wishlist (
                    key TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    added_at REAL NOT NULL
                );
                PRAGMA user_version = 2;
                """)
        }
    }

    // MARK: - Bags

    /// Rows this version couldn't read in the last `allBags()`. They stay
    /// in the database untouched.
    public private(set) var unreadableCount = 0

    public func allBags() throws -> [Bag] {
        var bags: [Bag] = []
        var unreadable = 0
        try query("SELECT body FROM bag ORDER BY collected_on DESC") { statement in
            if let text = sqlite3_column_text(statement, 0),
               let bag = try? decoder.decode(Bag.self, from: Data(String(cString: text).utf8)) {
                bags.append(bag)
            } else {
                unreadable += 1
            }
        }
        unreadableCount = unreadable
        return bags
    }

    public func bag(id: UUID) throws -> Bag? {
        var found: Bag?
        try query("SELECT body FROM bag WHERE id = ?", .text(id.uuidString)) { statement in
            if let text = sqlite3_column_text(statement, 0) {
                found = try? decoder.decode(Bag.self, from: Data(String(cString: text).utf8))
            }
        }
        return found
    }

    /// Learned grower identifiers, for backups.
    public func producerKeys() throws -> [String: String] {
        var keys: [String: String] = [:]
        try query("SELECT key, producer FROM producer_key") { statement in
            if let key = sqlite3_column_text(statement, 0), let producer = sqlite3_column_text(statement, 1) {
                keys[String(cString: key)] = String(cString: producer)
            }
        }
        return keys
    }

    public func save(_ bag: Bag) throws {
        let body = String(decoding: try encoder.encode(bag), as: UTF8.self)
        try run(
            "INSERT INTO bag (id, collected_on, body) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET collected_on = excluded.collected_on, body = excluded.body",
            .text(bag.id.uuidString), .double(bag.collectedOn.timeIntervalSince1970), .text(body)
        )
    }

    public func delete(id: UUID) throws {
        try run("DELETE FROM bag WHERE id = ?", .text(id.uuidString))
    }

    // MARK: - Reset

    /// Removes every record: bags, wishlist and learned growers. The file
    /// is compacted so deleted rows don't linger on disk.
    public func eraseAll() throws {
        try execute("""
            BEGIN IMMEDIATE;
            DELETE FROM bag;
            DELETE FROM wishlist;
            DELETE FROM producer_key;
            COMMIT;
            """)
        try execute("VACUUM")
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }

    // MARK: - Wishlist

    public func wishlist() throws -> [WishItem] {
        var items: [WishItem] = []
        try query("SELECT key, name, added_at FROM wishlist ORDER BY added_at DESC") { statement in
            guard let key = sqlite3_column_text(statement, 0), let name = sqlite3_column_text(statement, 1) else { return }
            items.append(WishItem(key: String(cString: key), name: String(cString: name), addedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))))
        }
        return items
    }

    public func addWish(_ item: WishItem) throws {
        try run("INSERT INTO wishlist (key, name, added_at) VALUES (?, ?, ?) ON CONFLICT(key) DO NOTHING",
                .text(item.key), .text(item.name), .double(item.addedAt.timeIntervalSince1970))
    }

    public func removeWish(key: String) throws {
        try run("DELETE FROM wishlist WHERE key = ?", .text(key))
    }

    // MARK: - Producer memory

    /// Remembers which producer prints these identifiers.
    public func remember(producer: String, for keys: [String]) throws {
        let name = producer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        for key in keys {
            try run(
                "INSERT INTO producer_key (key, producer) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET producer = excluded.producer",
                .text(key), .text(name)
            )
        }
    }

    public func producer(for keys: [String]) throws -> String? {
        for key in keys {
            var found: String?
            try query("SELECT producer FROM producer_key WHERE key = ?", .text(key)) { statement in
                found = sqlite3_column_text(statement, 0).map { String(cString: $0) }
            }
            if let found { return found }
        }
        return nil
    }

    // MARK: - SQLite helpers

    private enum Value {
        case text(String)
        case double(Double)
    }

    private func execute(_ sql: String) throws {
        lock.lock(); defer { lock.unlock() }
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? String(localized: "unknown", bundle: .taimaLocalization)
            sqlite3_free(error)
            throw StoreError.sqlite(message)
        }
    }

    private func run(_ sql: String, _ values: Value...) throws {
        try query(sql, values) { _ in }
    }

    private func query(_ sql: String, _ values: Value..., row: (OpaquePointer) throws -> Void) throws {
        try query(sql, values, row: row)
    }

    private func query(_ sql: String, _ values: [Value], row: (OpaquePointer) throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
            case .double(let number): sqlite3_bind_double(statement, position, number)
            }
        }
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                try row(statement)
            } else if result == SQLITE_DONE {
                return
            } else {
                throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}
#endif
