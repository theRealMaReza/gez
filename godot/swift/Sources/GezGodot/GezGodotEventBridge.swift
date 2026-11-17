import Foundation
import GezCore

/// Phase 14 bridge extension: pending historical/chronicle event pop-ups, option choices, recent events, and auto-pause setting.
extension GezGodotController {

    public func hasPendingEvent() -> Bool {
        session?.pendingPlayerEvent != nil
    }

    public func pendingEventDetails() -> [String: Any] {
        guard let s = session, let pending = s.pendingPlayerEvent else {
            return [
                "hasPending": false,
                "pauseOnEvents": session?.pauseOnEvents ?? true
            ]
        }
        var options: [[String: Any]] = []
        options.reserveCapacity(pending.options.count)
        for (idx, opt) in pending.options.enumerated() {
            options.append([
                "index": idx,
                "label": opt.label,
                "tooltip": opt.tooltip
            ])
        }
        return [
            "hasPending": true,
            "instanceID": pending.instanceID,
            "eventID": pending.eventID,
            "title": pending.title,
            "text": pending.text,
            "category": pending.category.rawValue,
            "categoryName": pending.category.displayName,
            "dateText": pending.date.description,
            "contextProvinceIndex": pending.contextProvince?.index ?? -1,
            "pauseOnEvents": s.pauseOnEvents,
            "options": options
        ]
    }

    @discardableResult
    public func chooseEventOption(instanceID: Int, optionIndex: Int) -> Bool {
        guard let s = session else { return false }
        return s.chooseEventOption(instanceID: instanceID, optionIndex: optionIndex)
    }

    public func recentEventsList(limit: Int = 6) -> [[String: Any]] {
        guard let s = session, let player = s.playerCountry else { return [] }
        return s.world.events.recentEvents(for: player, limit: limit).map { entry in
            [
                "dateText": entry.date.description,
                "eventID": entry.eventID,
                "title": entry.title,
                "category": entry.category.rawValue,
                "categoryName": entry.category.displayName,
                "chosenLabel": entry.chosenLabel,
                "effectSummary": entry.effectSummary,
                "major": entry.major
            ]
        }
    }

    public var recentEventsSignature: String {
        guard let s = session, let player = s.playerCountry else { return "" }
        let items = s.world.events.recentEvents(for: player, limit: 6)
        return "\(s.world.events.firedTotal):\(items.map { "\($0.eventID)@\($0.date.ordinal)" }.joined(separator: ";"))"
    }

    public var pauseOnEvents: Bool {
        session?.pauseOnEvents ?? true
    }

    @discardableResult
    public func setPauseOnEvents(_ enabled: Bool) -> Bool {
        guard let s = session else { return true }
        s.pauseOnEvents = enabled
        return s.pauseOnEvents
    }
}
