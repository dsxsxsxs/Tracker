import Testing
import Foundation
@testable import Tracking

@Suite
struct DataEncodingTests {
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    @Test
    func encodeLogEvent() throws {
        let now = Date()
        let payload: [String: Sendable] = ["key": "value"]
        let event = TrackingLog(
            eventId: "test",
            eventTime: now,
            payload: payload
        )
        let data = try encoder.encode(event)
        let encodedString = try #require(String(data: data, encoding: .utf8))

        let expectedDictionary: [String: Sendable] = [
            "eventId": "test",
            "eventTime": now.timestamp,
            "payload": payload
        ]
        let expected = try JSONSerialization.data(withJSONObject: expectedDictionary, options: [.prettyPrinted, .sortedKeys])
        let expectedString = try #require(String(data: expected, encoding: .utf8))

        #expect(encodedString == expectedString)
    }

    @Test
    func encodeLogEventHaveNestedObjects() throws {
        let now = Date()
        let array: [Int] = [1, 2, 3]
        let dictionary: [String: Sendable] = ["some": "value"]
        let payload: [String: Sendable] = [
            "key": "value",
            "array": array,
            "dictionary": dictionary
        ]
        let event = TrackingLog(
            eventId: "test",
            eventTime: now,
            payload: payload
        )
        let data = try encoder.encode(event)
        let encodedString = try #require(String(data: data, encoding: .utf8))

        let expectedDictionary: [String: Sendable] = [
            "eventId": "test",
            "eventTime": now.timestamp,
            "payload": payload
        ]
        let expected = try JSONSerialization.data(withJSONObject: expectedDictionary, options: [.prettyPrinted, .sortedKeys])
        let expectedString = try #require(String(data: expected, encoding: .utf8))

        #expect(encodedString == expectedString)
    }

    @Test
    func encodeDictionaryArrayToData() throws {
        let dics: [[String: AnyHashable]] = (0 ..< 30).map {
            [
                "id": $0,
                "key1": "value",
                "key2": false,
                "key4": 1.1
            ]
        }
        let units: [TrackingData] = try dics.enumerated().map {
            .init(id: $0, data: try JSONSerialization.data(withJSONObject: $1, options: [.prettyPrinted, .sortedKeys]))
        }

        let actualEncoded = try units.asData()
        let temporaryDecoded = try JSONSerialization.jsonObject(with: actualEncoded, options: []) as! [[String: Sendable]]
        let encoded = try JSONSerialization.data(withJSONObject: temporaryDecoded, options: [.prettyPrinted, .sortedKeys])
        let expectEncoded = try JSONSerialization.data(withJSONObject: dics, options: [.prettyPrinted, .sortedKeys])

        #expect(encoded == expectEncoded)
    }

    @Test
    func deflatedSizeLessThanOriginal() throws {
        let sourceString = """
        Lorem ipsum dolor sit amet consectetur adipiscing elit mi
        nibh ornare proin blandit diam ridiculus, faucibus mus
        dui eu vehicula nam donec dictumst sed vivamus bibendum
        aliquet efficitur. Felis imperdiet sodales dictum morbi
        vivamus augue dis duis aliquet velit ullamcorper porttitor,
        lobortis dapibus hac purus aliquam natoque iaculis blandit
        montes nunc pretium.
        """
        let data = Data(sourceString.utf8)
        let deflated = try data.deflated()
        // 222 bytes < 364 bytes
        #expect(deflated.count < data.count)
    }
}
