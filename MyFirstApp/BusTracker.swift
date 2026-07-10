//
//  BusTracker.swift
//  MyFirstApp
//
//  Polls the BODS SIRI-VM feed and raises a local notification when a
//  tracked bus is within the warning time of the stop.
//

import Foundation
import CoreLocation
import Observation
import UserNotifications

/// A live sighting of the tracked line, with its estimated time to reach the stop.
struct ApproachingBus: Identifiable {
    let id: String // vehicleRef
    let direction: String
    let destination: String
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

    private let stopLocation = CLLocation(latitude: BusConfig.stopLatitude,
                                          longitude: BusConfig.stopLongitude)

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        errorMessage = nil
        previousDistances.removeAll()
        notifiedVehicles.removeAll()
        pollTask = Task {
            await requestNotificationPermission()
            while !Task.isCancelled {
                await poll()
                try? await Task.sleep(for: .seconds(BusConfig.pollInterval))
            }
        }
    }

    func stopTracking() {
        pollTask?.cancel()
        pollTask = nil
        isTracking = false
        buses = []
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
        var components = URLComponents(string: "https://data.bus-data.dft.gov.uk/api/v1/datafeed/")!
        let halfSize = BusConfig.boundingBoxHalfSize
        let box = [BusConfig.stopLongitude - halfSize, BusConfig.stopLatitude - halfSize,
                   BusConfig.stopLongitude + halfSize, BusConfig.stopLatitude + halfSize]
        components.queryItems = [
            URLQueryItem(name: "boundingBox", value: box.map { String($0) }.joined(separator: ",")),
            URLQueryItem(name: "lineRef", value: BusConfig.lineName),
            URLQueryItem(name: "api_key", value: BusConfig.apiKey),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw BusTrackerError.badResponse(http.statusCode)
        }
        return SiriVMParser.parse(data)
    }

    private func updateBuses(from vehicles: [VehiclePosition]) {
        var updated: [ApproachingBus] = []
        var newDistances: [String: CLLocationDistance] = [:]

        for vehicle in vehicles where vehicle.lineName.caseInsensitiveCompare(BusConfig.lineName) == .orderedSame {
            guard !vehicle.vehicleRef.isEmpty else { continue }

            let location = CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude)
            let distance = location.distance(from: stopLocation)
            guard distance <= BusConfig.searchRadius else { continue }

            newDistances[vehicle.vehicleRef] = distance
            let isClosingIn = previousDistances[vehicle.vehicleRef].map { distance < $0 } ?? false
            let bus = ApproachingBus(id: vehicle.vehicleRef,
                                     direction: vehicle.direction,
                                     destination: vehicle.destination,
                                     distance: distance,
                                     eta: distance / BusConfig.assumedBusSpeed,
                                     isClosingIn: isClosingIn)
            updated.append(bus)

            if isClosingIn, bus.eta <= BusConfig.warningTime, !notifiedVehicles.contains(bus.id) {
                notifiedVehicles.insert(bus.id)
                sendWarning(for: bus)
            }
        }

        previousDistances = newDistances
        buses = updated.sorted { $0.eta < $1.eta }
    }

    private func sendWarning(for bus: ApproachingBus) {
        let content = UNMutableNotificationContent()
        content.title = "\(BusConfig.lineName) approaching"
        content.body = "About \(bus.etaMinutes) min from \(BusConfig.stopName)."
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
