//
//  ContentView.swift
//  MyFirstApp
//
//  Live view of 3X buses approaching the stop, with a start/stop control.
//

import SwiftUI

struct ContentView: View {
    @State private var tracker = BusTracker()

    var body: some View {
        NavigationStack {
            List {
                if BusConfig.apiKey == "YOUR_BODS_API_KEY" {
                    Section {
                        Label("No API key set. Paste your BODS key into BusConfig.swift.",
                              systemImage: "key.slash")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        tracker.isTracking ? tracker.stopTracking() : tracker.startTracking()
                    } label: {
                        Label(tracker.isTracking ? "Stop tracking" : "Start tracking the \(BusConfig.lineName)",
                              systemImage: tracker.isTracking ? "stop.circle.fill" : "bus.fill")
                    }
                } footer: {
                    statusText
                }

                if tracker.isTracking {
                    Section("Nearby \(BusConfig.lineName) buses") {
                        if tracker.buses.isEmpty {
                            Text("No \(BusConfig.lineName) buses within \(Int(BusConfig.searchRadius / 1000)) km right now.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(tracker.buses) { bus in
                                BusRow(bus: bus)
                            }
                        }
                    }
                }
            }
            .navigationTitle(BusConfig.stopName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusText: Text {
        if let error = tracker.errorMessage {
            Text(error)
        } else if let updated = tracker.lastUpdated {
            Text("Updated \(updated, format: .dateTime.hour().minute().second()). You'll get a notification when a bus is about \(Int(BusConfig.warningTime / 60)) minutes away.")
        } else if tracker.isTracking {
            Text("Fetching live bus positions…")
        } else {
            Text("Tracking polls live positions every \(Int(BusConfig.pollInterval)) seconds while the app is open.")
        }
    }
}

private struct BusRow: View {
    let bus: ApproachingBus

    var body: some View {
        HStack {
            Image(systemName: bus.isClosingIn ? "arrow.down.forward.circle.fill" : "circle.dashed")
                .foregroundStyle(bus.isClosingIn ? .green : .secondary)

            VStack(alignment: .leading) {
                Text("~\(bus.etaMinutes) min away")
                    .font(.headline)
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailText: String {
        let kilometres = Measurement(value: bus.distance, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        var parts = [kilometres]
        if !bus.destination.isEmpty { parts.append("to \(bus.destination)") }
        if !bus.direction.isEmpty { parts.append("(\(bus.direction))") }
        return parts.joined(separator: " ")
    }
}

#Preview {
    ContentView()
}
