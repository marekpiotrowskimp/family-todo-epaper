import Foundation
import Testing
@testable import TodoCore

/// Te same napisy co w test/test_codec firmware.
let fullTaskJSON = #"{"id":"0b6f2c1e-3d4a-4c5b-9e8f-1a2b3c4d5e6f","owner":"anna","title":"Kupić mleko","prio":2,"due":1793520000000,"status":"done","rem":1793516400000,"created":1793430000000,"updated":1793433600000,"by":"bartek","del":false}"#
let minimalTaskJSON = #"{"id":"t-2","owner":"bartek","title":"Wynieść śmieci","prio":0,"status":"active","created":1000,"updated":2000,"by":"bartek","del":true}"#

let fullTask = TodoTask(
    id: "0b6f2c1e-3d4a-4c5b-9e8f-1a2b3c4d5e6f",
    ownerId: "anna",
    title: "Kupić mleko",
    priority: .high,
    dueAt: ms(1_793_520_000_000),
    status: .done,
    reminderAt: ms(1_793_516_400_000),
    createdAt: ms(1_793_430_000_000),
    updatedAt: ms(1_793_433_600_000),
    updatedBy: "bartek",
    deleted: false
)

let minimalTask = TodoTask(
    id: "t-2",
    ownerId: "bartek",
    title: "Wynieść śmieci",
    priority: .low,
    createdAt: ms(1000),
    updatedAt: ms(2000),
    updatedBy: "bartek",
    deleted: true
)

@Suite struct TaskWireTests {
    @Test func encodesFullTaskToSharedJSON() throws {
        let encoded = try #require(jsonObject(TaskWire.encode(fullTask)))
        #expect(encoded == jsonObject(fullTaskJSON))
    }

    @Test func encodingOmitsAbsentDueAndReminder() throws {
        let encoded = try #require(jsonObject(TaskWire.encode(minimalTask)))
        #expect(encoded == jsonObject(minimalTaskJSON))
        #expect(encoded["due"] == nil)
        #expect(encoded["rem"] == nil)
    }

    @Test func decodesFullTask() throws {
        #expect(try TaskWire.decode(Data(fullTaskJSON.utf8)) == fullTask)
    }

    @Test func decodesTaskWithoutDueAndReminder() throws {
        let task = try TaskWire.decode(Data(minimalTaskJSON.utf8))
        #expect(task == minimalTask)
        #expect(task.dueAt == nil)
        #expect(task.reminderAt == nil)
    }

    @Test(arguments: [
        #"{"owner":"a","title":"x","prio":1,"status":"active","created":1,"updated":1,"by":"a","del":false}"#,
        #"{"id":"x","owner":"a","title":"x","prio":3,"status":"active","created":1,"updated":1,"by":"a","del":false}"#,
        #"{"id":"x","owner":"a","title":"x","prio":1,"status":"later","created":1,"updated":1,"by":"a","del":false}"#,
        "to nie json",
    ])
    func rejectsMalformedTask(json: String) throws {
        _ = try TaskWire.decode(Data(fullTaskJSON.utf8))  // kontrola: poprawny JSON przechodzi
        #expect(throws: WireError.malformed) { try TaskWire.decode(Data(json.utf8)) }
    }
}
