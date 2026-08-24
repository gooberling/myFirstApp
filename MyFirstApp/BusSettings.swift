//
//  BusSettings.swift
//  MyFirstApp
//
//  What the user chose: which stop (its direction is implied), which service that
//  actually calls there, how much safety buffer on top of the walk time, and the
//  weekday window that arms tracking on its own. Stops and services come from the
//  bundled catalog (StopCatalog); this type only holds the selection.
//

import Foundation
import Observation

enum Schedule: String, CaseIterable, Identifiable {
    case morning, wideMorning, off
    var id: String { rawValue }

    var name: String {
        switch self {
        case .morning: "Weekdays 07:30 – 09:00"
        case .wideMorning: "Weekdays 07:00 – 10:00"
        case .off: "No schedule"
        }
    }
    var detail: String {
        switch self {
        case .morning: "Arms itself Mon to Fri"
        case .wideMorning: "A wider morning window"
        case .off: "Only when I tap start"
        }
    }
    var short: String {
        switch self {
        case .morning: "Weekdays 07:30"
        case .wideMorning: "Weekdays 07:00"
        case .off: "Off"
        }
    }
    /// Hours the window covers, used to decide whether to auto-arm.
    var window: (open: Int, close: Int)? {
        switch self {
        case .morning: (7, 9)
        case .wideMorning: (7, 10)
        case .off: nil
        }
    }
}

@MainActor
@Observable
final class BusSettings {
    /// Extra minutes of warning on top of a stop's walk time.
    static let bufferOptions = [0, 2, 5]

    var stop: Stop
    var service: Service
    var bufferMinutes: Int
    var schedule: Schedule

    init() {
        let d = UserDefaults.standard
        let stops = StopCatalog.stops
        let resolvedStop = stops.first { $0.atco == d.string(forKey: "stopID") } ?? stops[0]
        stop = resolvedStop
        service = resolvedStop.services.first { $0.line == d.string(forKey: "serviceLine") }
            ?? resolvedStop.services[0]
        // integer(forKey:) can't tell "unset" from an explicit 0 (a valid option),
        // so check for the key before falling back to the default buffer.
        if let stored = d.object(forKey: "bufferMinutes") as? Int, Self.bufferOptions.contains(stored) {
            bufferMinutes = stored
        } else {
            bufferMinutes = Self.bufferOptions[1]
        }
        schedule = Schedule(rawValue: d.string(forKey: "schedule") ?? "") ?? .morning
    }

    func save() {
        let d = UserDefaults.standard
        d.set(stop.atco, forKey: "stopID")
        d.set(service.line, forKey: "serviceLine")
        d.set(bufferMinutes, forKey: "bufferMinutes")
        d.set(schedule.rawValue, forKey: "schedule")
    }

    /// Switch stops, keeping the same service line if the new stop also has it,
    /// otherwise falling back to that stop's first service.
    func select(stop newStop: Stop) {
        stop = newStop
        if let match = newStop.services.first(where: { $0.line == service.line }) {
            service = match
        } else {
            service = newStop.services[0]
        }
        save()
    }

    /// Total warning: the stop's walk time plus the chosen safety buffer.
    var alertLeadMinutes: Int { stop.walkMinutes + bufferMinutes }
    var alertLeadSeconds: TimeInterval { TimeInterval(alertLeadMinutes * 60) }

    /// True when the schedule window covers right now on a weekday.
    var shouldAutoArm: Bool {
        guard let window = schedule.window else { return false }
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return false }
        let hour = cal.component(.hour, from: now)
        return hour >= window.open && hour < window.close
    }
}
