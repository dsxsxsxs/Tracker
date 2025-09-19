//
//  TrackerUsage.swift
//  Tracking
//
//  Created by jiacheng.shih on 2025/07/30.
//

var oldLogger: OldLogger {
    fatalError()
}
var tracker: Tracker {
    fatalError()
}

struct RemoteConfig {
    let shouldSendLogToOldLogger: Bool
    let shouldSendLogToNewTracker: Bool

    static let current: Self = RemoteConfig(
        shouldSendLogToOldLogger: true,
        shouldSendLogToNewTracker: false
    )
}

struct OldTapEventLog {
    func send() {
        guard RemoteConfig.current.shouldSendLogToOldLogger else {
            return
        }
        oldLogger.logEvents(name: name, parameters: [parameter])
    }

    func sendToNewTracker() -> Self {
        let tapEvent = Tracker.TapEvent(name: name, payload: parameter)
        tapEvent.send()
        return self
    }

    let name: String
    let parameter: [String: Sendable]
}

extension Tracker {
    struct TapEvent {
        func send() {
            guard RemoteConfig.current.shouldSendLogToNewTracker else {
                return
            }
            tracker.sendLog(name: name, payload: payload)
        }
        let name: String
        let payload: [String: Sendable]
    }
}

struct OldLogger: Sendable {
    func logEvents(name: String, parameters: [[String: Sendable]]) {}
}

struct DualSendTracker: Sendable {
    let oldLogger: OldLogger
    let tracker: Tracker
    func sendLogs(name: String, parameters: [[String: Sendable]]) {
        oldLogger.logEvents(name: name, parameters: parameters)

        var editedParameters: [[String: Sendable]] = parameters
        for (index, parameter) in editedParameters.enumerated() {
            if let someValue = parameter["some_key"] {
                editedParameters[index]["some_key"] = nil
                editedParameters[index]["some_new_key"] = someValue
            }
            // その他諸々マッピング
        }
        tracker.sendLogs(name: name, payloads: parameters)
    }
}

func dualSendViaHelperMethod() {
    let tapEvent = OldTapEventLog(
        name: "home.like_button.tap",
        parameter: [
            "item_id": "12345"
    ])
    tapEvent.sendToNewTracker().send()
}

func dualSendManually() {
    let logName = "home.like_button.tap"
    let itemID = "12345"
    let oldTapEvent = OldTapEventLog(
        name: logName,
        parameter: [
            "item_id": itemID
    ])
    oldTapEvent.send()
    let tapEvent = Tracker.TapEvent(
        name: logName,
        payload: [
            "new_item_id": itemID
    ])
    tapEvent.send()
}
