//
//  BusTracker.swift
//  MyFirstApp
//
//  Polls the BODS SIRI-VM feed for the selected stop and line, and raises a local
//  notification when a bus is within the warning lead (walk time + buffer) of the stop.
//

import Foundation
import CoreLocation
import Observation
import UserNotifications

/// A live sighting of the tracked line, with its estimated time to reach the stop.
struct ApproachingBus: Identifiable {
    let id: String // vehicleRef
    let line: String
    let direction: String
    let destination: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let eta: TimeInterval
    /// True once the distance has shrunk between two polls, i.e. the bus is
    /// heading towards the stop rather than away from it.
    let isClosingIn: Bool

    var etaMinutes: Int { Int((eta / 60).rounded()) }
}

enum BusTrackerError: LocalizedError {
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse(401):
            return "BODS rejected the API key. Paste your key into BusConfig.apiKey."
        case .badResponse(let code):
            return "BODS returned HTTP \(code)."
        }
    }
}

/// What the tracker is currently following.
private struct TrackingTarget {
    let stop: Stop
    let lines: [String]      // BODS line refs being watched
    let label: String        // display summary, e.g. "All services" or "3X, 5A"
    let leadSeconds: TimeInterval

    var location: CLLocation { CLLocation(latitude: stop.lat, longitude: stop.lon) }

    func matches(_ vehicleLine: String) -> Bool {
        lines.contains { $0.caseInsensitiveCompare(vehicleLine) == .orderedSame }
    }
}

@MainActor
@Observable
final class BusTracker {
    var buses: [ApproachingBus] = []
    var isTracking = false
    var lastUpdated: Date?
    var errorMessage: String?

    private var pollTask: Task<Void, Never>?
    private var previousDistances: [String: CLLocationDistance] = [:]
    private var notifiedVehicles: Set<String> = []
    private var target: TrackingTarget?

    func startTracking(stop: Stop, lines: [String], label: String, leadSeconds: TimeInterval) {
        guard !isTracking else { return }
        target = TrackingTarget(stop: stop, lines: lines, label: label, leadSeconds: leadSeconds)
        isTracking = true
        errorMessage = nil
        previousDistances.removeAll()
        notifiedVehicles.removeAll()
        pollTask = Task {
            // Fetch immediately so the armed screen has data as soon as possible;
            // the permission prompt must not block that first request.
            await poll()
            await requestNotificationPermission()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(BusConfig.pollInterval))
                await poll()
            }
        }
    }

    func stopTracking() {
        pollTask?.cancel()
        pollTask = nil
        isTracking = false
        buses = []
        target = nil
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private func poll() async {
        do {
            let vehicles = try await fetchVehicles()
            updateBuses(from: vehicles)
            lastUpdated = Date()
            errorMessage = nil
        } catch is CancellationError {
            // Tracking was stopped; nothing to report.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchVehicles() async throws -> [VehiclePosition] {
        guard let target else { return [] }
        var components = URLComponents(string: "https://data.bus-data.dft.gov.uk/api/v1/datafeed/")!
        let halfSize = BusConfig.boundingBoxHalfSize
        let box = [target.stop.lon - halfSize, target.stop.lat - halfSize,
                   target.stop.lon + halfSize, target.stop.lat + halfSize]
        var items = [
            URLQueryItem(name: "boundingBox", value: box.map { String($0) }.joined(separator: ",")),
            URLQueryItem(name: "api_key", value: BusConfig.apiKey),
        ]
        // Only narrow the feed with lineRef when watching a single line; multiple
        // selected lines are filtered client-side in updateBuses.
        if target.lines.count == 1 {
            items.append(URLQueryItem(name: "lineRef", value: target.lines[0]))
        }
        components.queryItems = items

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw BusTrackerError.badResponse(http.statusCode)
        }
        return SiriVMParser.parse(data)
    }

    private func updateBuses(from vehicles: [VehiclePosition]) {
        guard let target else { return }
        var updated: [ApproachingBus] = []
        var newDistances: [String: CLLocationDistance] = [:]

        for vehicle in vehicles where target.matches(vehicle.lineName) {
            guard !vehicle.vehicleRef.isEmpty else { continue }

            let location = CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude)
            let distance = location.distance(from: target.location)
            guard distance <= BusConfig.searchRadius else { continue }

            newDistances[vehicle.vehicleRef] = distance
            let isClosingIn = previousDistances[vehicle.vehicleRef].map { distance < $0 } ?? false
            let bus = ApproachingBus(id: vehicle.vehicleRef,
                                     line: vehicle.lineName,
                                     direction: vehicle.direction,
                                     destination: vehicle.destination,
                                     coordinate: location.coordinate,
                                     distance: distance,
                                     eta: distance / BusConfig.assumedBusSpeed,
                                     isClosingIn: isClosingIn)
            updated.append(bus)

            if isClosingIn, bus.eta <= target.leadSeconds, !notifiedVehicles.contains(bus.id) {
                notifiedVehicles.insert(bus.id)
                sendWarning(for: bus, target: target)
            }
        }

        previousDistances = newDistances
        buses = updated.sorted { $0.eta < $1.eta }
    }

    private func sendWarning(for bus: ApproachingBus, target: TrackingTarget) {
        let content = UNMutableNotificationContent()
        content.title = "\(bus.line) approaching"
        content.body = "Leave now — about \(bus.etaMinutes) min from the bus stop."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "bus-\(bus.id)-\(Date().timeIntervalSince1970)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Lets warning banners appear even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
