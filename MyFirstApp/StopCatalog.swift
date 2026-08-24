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

/// A service (bus line) that calls at a stop, with the destinations seen for it
/// in the timetable. The first destination is used as the headsign shown to the user.
struct Service: Identifiable, Hashable, Decodable {
    let line: String
    let destinations: [String]

    var id: String { line }
    var headsign: String { destinations.first ?? "" }
}

/// One tracked stop and the services that actually call there.
struct Stop: Identifiable, Hashable, Decodable {
    let atco: String
    let name: String
    let lat: Double
    let lon: Double
    let walkMinutes: Int
    let services: [Service]

    var id: String { atco }
    var detail: String { "ATCO \(atco) · \(walkMinutes) min walk" }
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
