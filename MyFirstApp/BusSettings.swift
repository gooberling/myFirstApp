//
//  BusSettings.swift
//  MyFirstApp
//
//  What the user chose: one stop, one service, one direction, one lead time,
//  plus the weekday window that arms tracking on its own.
//

import Foundation
import Observation

struct Stop: Identifiable, Hashable {
    let id: String        // ATCO code
    let name: String
    let detail: String
    let latitude: Double
    let longitude: Double
}

struct Service: Identifiable, Hashable {
    var id: String { line }
    let line: String
    let detail: String
}

struct Direction: Identifiable, Hashable {
    var id: String { ref }
    let ref: String       // matches SIRI-VM DirectionRef
    let name: String      // "Towards Brighton"
    let detail: String
}

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
    static let stops = [
        Stop(id: "149000006512", name: "Moda Hove Central (adj)", detail: "ATCO 149000006512 · 5 min walk",
             latitude: 50.838147, longitude: -0.177475),
        Stop(id: "149000006497", name: "Hove Station (Stop B)", detail: "Goldstone Villas · 9 min walk",
             latitude: 50.837600, longitude: -0.170500),
        Stop(id: "149000006401", name: "Palmeira Square (Stop D)", detail: "Church Road · 14 min walk",
             latitude: 50.826900, longitude: -0.157700),
    ]
    static let services = [
        Service(line: "3X", detail: "Express · Portslade — Brighton Station"),
        Service(line: "1", detail: "Whitehawk — Portslade"),
        Service(line: "7", detail: "Brighton Marina — Mile Oak"),
        Service(line: "49", detail: "Brighton — Portslade Station"),
    ]
    static let directions = [
        Direction(ref: "inbound", name: "Towards Brighton", detail: "Inbound · to Brighton Station"),
        Direction(ref: "outbound", name: "Towards Portslade", detail: "Outbound · to Mile Oak"),
    ]
    static let leadTimes = [3, 6, 10]

    var stop: Stop
    var service: Service
    var direction: Direction
    var leadMinutes: Int
    var schedule: Schedule

    init() {
        let d = UserDefaults.standard
        stop = Self.stops.first { $0.id == d.string(forKey: "stopID") } ?? Self.stops[0]
        service = Self.services.first { $0.line == d.string(forKey: "serviceLine") } ?? Self.services[0]
        direction = Self.directions.first { $0.ref == d.string(forKey: "directionRef") } ?? Self.directions[0]
        let lead = d.integer(forKey: "leadMinutes")
        leadMinutes = Self.leadTimes.contains(lead) ? lead : Int(BusConfig.warningTime / 60)
        schedule = Schedule(rawValue: d.string(forKey: "schedule") ?? "") ?? .morning
    }

    func save() {
        let d = UserDefaults.standard
        d.set(stop.id, forKey: "stopID")
        d.set(service.line, forKey: "serviceLine")
        d.set(direction.ref, forKey: "directionRef")
        d.set(leadMinutes, forKey: "leadMinutes")
        d.set(schedule.rawValue, forKey: "schedule")
    }

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

    var leadSeconds: TimeInterval { TimeInterval(leadMinutes * 60) }
}
