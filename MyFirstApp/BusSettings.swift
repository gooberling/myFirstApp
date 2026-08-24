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
    /// The line refs currently being watched at `stop`. Always non-empty and a
    /// subset of the stop's offered lines.
    var selectedLines: Set<String>
    var bufferMinutes: Int
    var schedule: Schedule

    init() {
        let d = UserDefaults.standard
        let stops = StopCatalog.stops
        let resolvedStop = stops.first { $0.atco == d.string(forKey: "stopID") } ?? stops[0]
        stop = resolvedStop

        let offered = Set(resolvedStop.services.map(\.line))
        let stored = Set(d.stringArray(forKey: "selectedLines") ?? [])
        let valid = stored.intersection(offered)
        selectedLines = valid.isEmpty ? offered : valid // default: all services

        // integer(forKey:) can't tell "unset" from an explicit 0 (a valid option),
        // so check for the key before falling back to the default buffer.
        if let bufferStored = d.object(forKey: "bufferMinutes") as? Int, Self.bufferOptions.contains(bufferStored) {
            bufferMinutes = bufferStored
        } else {
            bufferMinutes = Self.bufferOptions[1]
        }
        schedule = Schedule(rawValue: d.string(forKey: "schedule") ?? "") ?? .morning
    }

    func save() {
        let d = UserDefaults.standard
        d.set(stop.atco, forKey: "stopID")
        d.set(Array(selectedLines), forKey: "selectedLines")
        d.set(bufferMinutes, forKey: "bufferMinutes")
        d.set(schedule.rawValue, forKey: "schedule")
    }

    // MARK: - Service selection

    /// Lines the stop offers, in display order.
    var offeredLines: [String] { stop.services.map(\.line) }

    /// The watched lines in display order.
    var trackedLines: [String] { offeredLines.filter(selectedLines.contains) }

    func isSelected(_ line: String) -> Bool { selectedLines.contains(line) }

    /// True when every offered line is watched.
    var allSelected: Bool {
        !offeredLines.isEmpty && Set(offeredLines).isSubset(of: selectedLines)
    }

    /// Toggle one line, but never let the selection become empty.
    func toggle(_ line: String) {
        if selectedLines.contains(line) {
            if selectedLines.count > 1 { selectedLines.remove(line) }
        } else {
            selectedLines.insert(line)
        }
        save()
    }

    func selectAllServices() {
        selectedLines = Set(offeredLines)
        save()
    }

    /// A short label for the current selection, e.g. "All services" or "3X, 5A".
    var serviceSummary: String {
        allSelected ? "All services" : trackedLines.joined(separator: ", ")
    }

    /// How the alert refers to the incoming bus.
    var alertServicePhrase: String {
        allSelected ? "A bus" : "The \(serviceSummary)"
    }

    /// Switch stops, keeping any still-valid selected lines, else watching all.
    func select(stop newStop: Stop) {
        stop = newStop
        let offered = Set(newStop.services.map(\.line))
        let keep = selectedLines.intersection(offered)
        selectedLines = keep.isEmpty ? offered : keep
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
