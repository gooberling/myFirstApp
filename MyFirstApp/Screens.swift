//
//  Screens.swift
//  MyFirstApp
//
//  The picker sheet, the armed poster (option 1c) and the alert.
//

import SwiftUI
import MapKit

// MARK: - Picker

struct PickerSheet: View {
    let kind: PickerKind
    let settings: BusSettings
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onClose) {
                Kicker(text: closesOnTap ? "← Back" : "✓ Done", color: Theme.accent)
            }
            .buttonStyle(.plain)

            Text(kind.title)
                .font(Theme.heading(32))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Rule().padding(.top, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(options, id: \.0) { label, detail, selected, choose in
                        Button {
                            choose()
                            settings.save()
                            if closesOnTap { onClose() } // multi-select stays open
                        } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label)
                                        .font(Theme.heading(19, .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(detail)
                                        .font(Theme.body(13))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer(minLength: 8)
                                if selected {
                                    Rectangle().fill(Theme.accent).frame(width: 16, height: 16)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 20)
                            .overlay(alignment: .bottom) { Rule(color: Theme.hairline, height: 1) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground)
    }

    private typealias Option = (String, String, Bool, () -> Void)

    /// The service picker is multi-select: taps toggle and the sheet stays open.
    private var closesOnTap: Bool { kind != .service }

    private var options: [Option] {
        switch kind {
        case .service:
            var rows: [Option] = [
                ("All services", "Notify me for any bus at this stop",
                 settings.allSelected, { settings.selectAllServices() })
            ]
            rows += settings.stop.services.map { s in
                (s.line, "Towards " + s.headsign, settings.isSelected(s.line),
                 { settings.toggle(s.line) })
            }
            return rows
        case .buffer:
            return BusSettings.bufferOptions.map { n in
                ("\(settings.stop.walkMinutes + n) min warning", bufferDetail(n),
                 n == settings.bufferMinutes, { settings.bufferMinutes = n })
            }
        case .schedule:
            return Schedule.allCases.map { s in
                (s.name, s.detail, s == settings.schedule, { settings.schedule = s })
            }
        case .stop:
            return StopCatalog.stops.map { s in
                (s.name, s.detail, s.atco == settings.stop.atco, { settings.select(stop: s) })
            }
        }
    }

    private func bufferDetail(_ n: Int) -> String {
        switch n {
        case 0: "Exactly your walk time"
        case 2: "A little slack on top of the walk"
        default: "Plenty of slack"
        }
    }
}

#Preview("Service picker") {
    PickerSheet(kind: .service, settings: BusSettings()) {}
}

// MARK: - Armed (option 1c — red poster, one number)

struct ArmedView: View {
    let settings: BusSettings
    let tracker: BusTracker
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: watchingLabel, color: Theme.ground)
                Kicker(text: tracker.isTracking ? "Live" : "Paused", color: Theme.ground.opacity(0.7))
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            Rule(color: Theme.ground).padding(.top, 14)

            Spacer(minLength: 12)
            Text(minutesLabel)
                .font(Theme.heading(190))
                .monospacedDigit()
                .kerning(-10)
                .foregroundStyle(Theme.ground)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(caption)
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ground)
                .padding(.top, -18)
                .padding(.bottom, 12)
            BusMapStrip(stop: settings.stop, buses: tracker.buses)
                .frame(height: 200)
                .overlay(Rectangle().stroke(Theme.ground, lineWidth: 2))

            Spacer(minLength: 16)
            Rule(color: Theme.ground).padding(.top, 18)
            Text("Buzzing at \(settings.alertLeadMinutes) min. Screen off is fine.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.ground.opacity(0.82))
                .padding(.top, 12)

            PosterButton(title: "Stop watching", fill: .clear, label: Theme.ground,
                         border: Theme.ground, action: onStop)
                .padding(.top, 28)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.accent)
    }

    /// Prefer a confirmed closing-in bus, else the nearest one we've seen so we
    /// can show a number after the first poll instead of waiting for two.
    private var nearestBus: ApproachingBus? {
        tracker.buses.first { $0.isClosingIn } ?? tracker.buses.first
    }

    private var caption: String {
        nearestBus == nil ? "Finding buses…" : "Minutes from bus stop"
    }

    private var minutesLabel: String {
        guard let next = nearestBus else { return "…" } // searching for buses
        return "\(next.etaMinutes)"
    }

    /// Show the specific incoming bus if we have one, else the selection summary.
    private var watchingLabel: String {
        if let next = nearestBus {
            return "\(next.line) · towards \(next.destination)"
        }
        return settings.serviceSummary
    }
}

/// A live map showing the stop and each tracked bus's actual position. Positions
/// refresh each poll (~15s), so markers hop rather than glide.
private struct BusMapStrip: View {
    let stop: Stop
    let buses: [ApproachingBus]
    @State private var camera: MapCameraPosition

    init(stop: Stop, buses: [ApproachingBus]) {
        self.stop = stop
        self.buses = buses
        // ~250 m radius (500 m span). Shift the centre towards the approach side so
        // the stop sits at the far edge, leaving room to watch the bus close in.
        let offsetMeters = 200.0
        let dLat = offsetMeters / 111_320.0 // metres per degree latitude
        var centerLat = stop.lat
        switch stop.approachDirection {
        case .north: centerLat += dLat // room to the north; stop near the bottom
        case .south: centerLat -= dLat // room to the south; stop near the top
        case nil: break
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: stop.lon),
            latitudinalMeters: 500, longitudinalMeters: 500)
        _camera = State(initialValue: .region(region))
    }

    private var stopCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
    }

    var body: some View {
        Map(position: $camera) {
            Annotation("Stop", coordinate: stopCoordinate) {
                // Flat ink square = the stop, matching the poster's marker style.
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 14, height: 14)
                    .overlay(Rectangle().stroke(Theme.ground, lineWidth: 2))
            }
            .annotationTitles(.hidden)
            ForEach(buses) { bus in
                Annotation(bus.line, coordinate: bus.coordinate) {
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 16, height: 16)
                            .overlay(Rectangle().stroke(Theme.ground, lineWidth: 2))
                        Text(bus.line)
                            .font(Theme.heading(10))
                            .foregroundStyle(Theme.ground)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.ink)
                    }
                }
            }
            .annotationTitles(.hidden) // we draw our own labels
        }
        // Muted, flat, no POI clutter — as close to the flat palette as MapKit allows.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        // Warm the neutral tiles slightly towards the accent so it reads as one piece.
        .overlay(Theme.accent.opacity(0.10).blendMode(.multiply).allowsHitTesting(false))
    }
}

#Preview("Armed") {
    let tracker = BusTracker()
    tracker.buses = [ApproachingBus(id: "v1", line: "5A", direction: "inbound",
                                    destination: "Craignair Avenue",
                                    coordinate: CLLocationCoordinate2D(latitude: 50.8425, longitude: -0.1770),
                                    distance: 1320, eta: 240, isClosingIn: true)]
    return ArmedView(settings: BusSettings(), tracker: tracker, onStop: {})
}

// MARK: - Alert

struct AlertView: View {
    let settings: BusSettings
    let onNext: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Bus alert · now", color: Theme.ground.opacity(0.8))
            Rule(color: Theme.ground.opacity(0.7)).padding(.top, 16)

            Text("Leave now")
                .font(Theme.heading(76))
                .foregroundStyle(Theme.ground)
                .padding(.top, 52)
            Text("\(settings.alertServicePhrase) is about \(settings.alertLeadMinutes) minutes from the bus stop.")
                .font(Theme.body(20))
                .foregroundStyle(Theme.ground)
                .padding(.top, 22)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                PosterButton(title: "Not this one — watch the next", fill: .clear,
                             label: Theme.ground, border: Theme.ground, action: onNext)
                PosterButton(title: "On my way", fill: Theme.ground, label: Theme.ink, action: onDone)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.accent)
    }
}

#Preview("Alert") {
    AlertView(settings: BusSettings(), onNext: {}, onDone: {})
}
