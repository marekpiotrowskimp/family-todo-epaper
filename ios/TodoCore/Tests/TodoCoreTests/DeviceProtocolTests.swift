import Foundation
import Testing
@testable import TodoCore

@Suite struct DeviceAuthTests {
    @Test func macMatchesSharedVectors() {
        #expect(DeviceAuth.mac(secret: Vectors.secret, nonce: Vectors.nonce, userId: "anna").hex == Vectors.annaMacHex)
        #expect(DeviceAuth.mac(secret: Vectors.secret, nonce: Vectors.nonce, userId: "żaneta").hex == Vectors.zanetaMacHex)
    }
}

@Suite struct DeviceProtocolTests {
    @Test func encodesHello() {
        #expect(jsonObject(DeviceProtocol.encode(.hello)) == ["op": "hello"])
    }

    @Test func encodesAuthWithHexMac() {
        let data = DeviceProtocol.encode(.auth(userId: "anna", displayName: "Anna", mac: Vectors.annaMac))
        #expect(jsonObject(data) == ["op": "auth", "user": "anna", "name": "Anna", "mac": Vectors.annaMacHex])
    }

    @Test func encodesPull() {
        #expect(jsonObject(DeviceProtocol.encode(.pull(since: 5, limit: 20))) == ["op": "pull", "since": 5, "limit": 20])
    }

    @Test func encodesPushWithWireTasks() throws {
        let object = try #require(jsonObject(DeviceProtocol.encode(.push([fullTask]))))
        #expect(object["op"] as? String == "push")
        let tasks = try #require(object["tasks"] as? [NSDictionary])
        #expect(tasks == [try #require(jsonObject(fullTaskJSON))])
    }

    @Test func decodesHello() throws {
        let json = #"{"ok":true,"nonce":"a0a1a2a3a4a5a6a7a8a9aaabacadaeaf","store":"S1","rev":12}"#
        #expect(try DeviceProtocol.decodeHello(Data(json.utf8)) == DeviceHello(nonce: Vectors.nonce, storeId: "S1", revision: 12))
    }

    @Test func decodesSuccessfulAck() throws {
        try DeviceProtocol.decodeAck(Data(#"{"ok":true}"#.utf8))
    }

    @Test(arguments: ["bad_mac", "unknown_member", "not_authenticated", "no_session"])
    func authErrorsMapToUnauthorized(code: String) {
        let json = #"{"ok":false,"err":"\#(code)"}"#
        #expect(throws: SyncError.unauthorized) { try DeviceProtocol.decodeAck(Data(json.utf8)) }
    }

    @Test(arguments: ["batch_too_large", "bad_request", "bad_frame"])
    func otherErrorsKeepDeviceCode(code: String) {
        let json = #"{"ok":false,"err":"\#(code)"}"#
        #expect(throws: SyncError.device(code)) { try DeviceProtocol.decodeAck(Data(json.utf8)) }
    }

    @Test func decodesPushResults() throws {
        let json = #"{"ok":true,"results":["inserted","updated","ignored","rejected_full","rejected_invalid"],"rev":13}"#
        #expect(try DeviceProtocol.decodePush(Data(json.utf8)) == [.inserted, .updated, .ignored, .rejectedFull, .rejectedInvalid])
    }

    @Test func pushErrorIsThrown() {
        #expect(throws: SyncError.unauthorized) {
            try DeviceProtocol.decodePush(Data(#"{"ok":false,"err":"not_authenticated"}"#.utf8))
        }
    }

    @Test func decodesPullPage() throws {
        let json = #"{"ok":true,"store":"S1","rev":20,"more":true,"tasks":[\#(fullTaskJSON)]}"#
        #expect(try DeviceProtocol.decodePull(Data(json.utf8)) == DevicePull(storeId: "S1", revision: 20, tasks: [fullTask], more: true))
    }

    @Test(arguments: [
        "to nie json",
        #"{"ok":true,"results":["inserted","nowy_wynik"],"rev":1}"#,
        #"{"ok":true,"store":"S1","rev":20,"more":false,"tasks":[{"id":"x"}]}"#,
    ])
    func malformedResponsesAreRejected(json: String) throws {
        try DeviceProtocol.decodeAck(Data(#"{"ok":true}"#.utf8))  // kontrola: poprawna odpowiedź przechodzi
        #expect(throws: SyncError.malformedResponse) {
            if json.contains("results") {
                _ = try DeviceProtocol.decodePush(Data(json.utf8))
            } else if json.contains("tasks") {
                _ = try DeviceProtocol.decodePull(Data(json.utf8))
            } else {
                _ = try DeviceProtocol.decodeHello(Data(json.utf8))
            }
        }
    }
}
