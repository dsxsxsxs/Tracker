//
//  Encoder+SendableDictionary.swift
//  Tracking
//
//  Created by jiacheng.shih on 2025/07/30.
//

private struct AnyCodingKeys: CodingKey {
    var stringValue: String

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

extension KeyedEncodingContainerProtocol where Key == AnyCodingKeys {
    mutating func encode(_ value: [String: Sendable]) throws {
        for (key, value) in value {
            let key = AnyCodingKeys(stringValue: key)
            switch value {
            case let value as Bool:
                try encode(value, forKey: key)
            case let value as Int:
                try encode(value, forKey: key)
            case let value as String:
                try encode(value, forKey: key)
            case let value as Double:
                try encode(value, forKey: key)
            case let value as [String: Sendable]:
                try encode(value, forKey: key)
            case let value as [Sendable]:
                try encode(value, forKey: key)
            case Optional<Sendable>.none:
                try encodeNil(forKey: key)
            default:
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Invalid JSON value"))
            }
        }
    }
}

extension KeyedEncodingContainerProtocol {
    mutating func encode(_ value: [String: Sendable]?, forKey key: Key) throws {
        guard let value = value else { return }

        var container = nestedContainer(keyedBy: AnyCodingKeys.self, forKey: key)
        try container.encode(value)
    }

    mutating func encode(_ value: [Sendable]?, forKey key: Key) throws {
        guard let value = value else { return }

        var container = nestedUnkeyedContainer(forKey: key)
        try container.encode(value)
    }
}

extension UnkeyedEncodingContainer {
    mutating func encode(_ value: [Sendable]) throws {
        for (index, value) in value.enumerated() {
            switch value {
            case let value as Bool:
                try encode(value)
            case let value as Int:
                try encode(value)
            case let value as String:
                try encode(value)
            case let value as Double:
                try encode(value)
            case let value as [String: Sendable]:
                try encode(value)
            case let value as [Sendable]:
                try encodeNestedArray(value)
            case Optional<Sendable>.none:
                try encodeNil()
            default:
                let keys = AnyCodingKeys(intValue: index).map({ [ $0 ] }) ?? []
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + keys, debugDescription: "Invalid JSON value"))
            }
        }
    }

    mutating func encode(_ value: [String: Sendable]) throws {
        var container = nestedContainer(keyedBy: AnyCodingKeys.self)
        try container.encode(value)
    }

    mutating func encodeNestedArray(_ value: [Sendable]) throws {
        var container = nestedUnkeyedContainer()
        try container.encode(value)
    }
}
