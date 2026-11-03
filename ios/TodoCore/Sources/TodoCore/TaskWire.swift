import Foundation

public enum WireError: Error, Equatable {
    case malformed
}

/// Czas w protokole: całkowite milisekundy od epoki Unix.
enum WireTime {
    static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func date(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    /// Data zaokrąglona do pełnych ms, tak jak przechodzi przez protokół i powiadomienia.
    static func wholeMilliseconds(_ date: Date) -> Date {
        self.date(milliseconds(date))
    }
}

/// Serializacja słowników zbudowanych wyłącznie z typów JSON.
enum WireJSON {
    static func data(_ object: Any) -> Data {
        // Wejście składa się tylko ze String/NSNumber/Bool/tablic/słowników, więc
        // isValidJSONObject wyklucza jedyny przypadek, w którym serializacja rzuca.
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return Data() }
        return data
    }

    static func object(_ data: Data) -> [String: Any]? {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return parsed as? [String: Any]
    }
}

/// Format przewodowy zadania, wspólny z `todo::encodeTask`/`decodeTask` w firmware.
/// Klucze: id, owner, title, prio (0...2), due (ms, pomijane gdy brak), status ("active"/"done"),
/// rem (ms, pomijane gdy brak), created, updated (ms), by, del.
public enum TaskWire {
    public static func jsonObject(_ task: TodoTask) -> [String: Any] {
        var object: [String: Any] = [
            "id": task.id,
            "owner": task.ownerId,
            "title": task.title,
            "prio": task.priority.rawValue,
            "status": task.status.rawValue,
            "created": WireTime.milliseconds(task.createdAt),
            "updated": WireTime.milliseconds(task.updatedAt),
            "by": task.updatedBy,
            "del": task.deleted,
        ]
        if let due = task.dueAt { object["due"] = WireTime.milliseconds(due) }
        if let reminder = task.reminderAt { object["rem"] = WireTime.milliseconds(reminder) }
        return object
    }

    public static func task(from object: [String: Any]) throws -> TodoTask {
        guard let id = object["id"] as? String,
              let owner = object["owner"] as? String,
              let title = object["title"] as? String,
              let by = object["by"] as? String,
              let prioRaw = object["prio"] as? Int, let priority = Priority(rawValue: prioRaw),
              let statusRaw = object["status"] as? String, let status = TaskStatus(rawValue: statusRaw),
              let created = object["created"] as? Int64,
              let updated = object["updated"] as? Int64,
              let deleted = object["del"] as? Bool
        else { throw WireError.malformed }
        return TodoTask(
            id: id,
            ownerId: owner,
            title: title,
            priority: priority,
            dueAt: try optionalTime(object["due"]),
            status: status,
            reminderAt: try optionalTime(object["rem"]),
            createdAt: WireTime.date(created),
            updatedAt: WireTime.date(updated),
            updatedBy: by,
            deleted: deleted
        )
    }

    public static func encode(_ task: TodoTask) -> Data {
        WireJSON.data(jsonObject(task))
    }

    public static func decode(_ data: Data) throws -> TodoTask {
        guard let object = WireJSON.object(data) else { throw WireError.malformed }
        return try task(from: object)
    }

    private static func optionalTime(_ value: Any?) throws -> Date? {
        guard let value, !(value is NSNull) else { return nil }
        guard let ms = value as? Int64 else { throw WireError.malformed }
        return WireTime.date(ms)
    }
}
