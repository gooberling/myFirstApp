//
//  StopCatalog.swift
//  MyFirstApp
//
//  Loads the bundled stop -> services catalog (Resources/stops.json), which is
//  generated offline from BODS timetable data by Tools/build_stops.py. BODS has
//  no live "which services call at this stop" API, so this baked lookup is how
//  the app knows what to offer for each stop.
//

import Foundation

/// A pickable service. `line` is the label shown to the user (e.g. "3X" or "Any 5")
/// and `lines` is the set of BODS line refs it tracks — usually one, but a grouped
/// option like "Any 5" tracks several (5, 5A, 5B, N5) at once.
struct Service: Identifiable, Hashable, Decodable {
    let line: String
    let lines: [String]
    let destinations: [String]

    var id: String { line }
    var headsign: String { destinations.first ?? "" }

    /// True if a live vehicle's line ref belongs to this service.
    func matches(_ vehicleLine: String) -> Bool {
        lines.contains { $0.caseInsensitiveCompare(vehicleLine) == .orderedSame }
    }
}

/// One tracked stop and the services that actually call there.
struct Stop: Identifiable, Hashable, Decodable {
    /// The compass direction buses approach this stop from. Used to bias the map
    /// so the stop sits at the far edge, leaving room to watch the bus close in.
    enum Approach: String { case north, south }

    let atco: String
    let name: String
    let lat: Double
    let lon: Double
    let walkMinutes: Int
    let services: [Service]
    let approach: String?

    var id: String { atco }
    var detail: String { "\(walkMinutes) min walk" }
    var approachDirection: Approach? { approach.flatMap(Approach.init) }
}

/// The bundled catalog, decoded once on first use.
enum StopCatalog {
    static let stops: [Stop] = load()

    private static func load() -> [Stop] {
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "json") else {
            assertionFailure("stops.json is missing from the app bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Stop].self, from: data)
        } catch {
            assertionFailure("stops.json could not be decoded: \(error)")
            return []
        }
    }
}
