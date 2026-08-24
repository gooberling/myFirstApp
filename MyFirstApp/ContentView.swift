//
//  ContentView.swift
//  MyFirstApp
//
//  Home → pickers → armed → alert. The chosen stop and service drive BusTracker;
//  the stop's walk time (plus a buffer) sets how early the alert fires.
//

import SwiftUI

enum Screen { case home, armed, alert }

struct ContentView: View {
    @State private var tracker = BusTracker()
    @State private var settings = BusSettings()
    @State private var screen: Screen = .home
    @State private var picker: PickerKind?

    var body: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(settings: settings, tracker: tracker,
                         onEdit: { picker = $0 },
                         onStart: start)
            case .armed:
                ArmedView(settings: settings, tracker: tracker, onStop: stop)
            case .alert:
                AlertView(settings: settings,
                          onNext: { screen = .armed },
                          onDone: stop)
            }
        }
        .background(screen == .home ? Theme.ground : Color.clear)
        .sheet(item: $picker) { kind in
            PickerSheet(kind: kind, settings: settings) { picker = nil }
        }
        .onChange(of: nearestETA) { _, eta in
            guard screen == .armed, let eta, eta <= settings.alertLeadSeconds else { return }
            screen = .alert
        }
        .task {
            if settings.shouldAutoArm { start() }
        }
    }

    /// The soonest closing-in vehicle on the chosen line, in seconds. The tracker
    /// already filters to the selected stop and line, so anything closing in is
    /// heading to our stop.
    private var nearestETA: TimeInterval? {
        tracker.buses
            .filter(\.isClosingIn)
            .map(\.eta)
            .min()
    }

    private func start() {
        tracker.startTracking(stop: settings.stop,
                              lines: settings.trackedLines,
                              label: settings.serviceSummary,
                              leadSeconds: settings.alertLeadSeconds)
        screen = .armed
    }

    private func stop() {
        tracker.stopTracking()
        screen = .home
    }
}

#Preview {
    ContentView()
}

enum PickerKind: String, Identifiable {
    case service, buffer, schedule, stop
    var id: String { rawValue }

    var title: String {
        switch self {
        case .service: "Which services?"
        case .buffer: "How much extra warning?"
        case .schedule: "When should it arm itself?"
        case .stop: "Which stop?"
        }
    }
}

// MARK: - Home

struct HomeView: View {
    let settings: BusSettings
    let tracker: BusTracker
    let onEdit: (PickerKind) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Watching")
            Text(settings.stop.name)
                .font(Theme.heading(38))
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
            Text(settings.stop.detail)
                .font(Theme.body(15))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .padding(.top, 8)
            Text("Watching \(settings.serviceSummary)")
                .font(Theme.body(15))
                .foregroundStyle(Theme.accent)
                .padding(.top, 6)

            Rule().padding(.top, 26)

            SettingRow(label: "Services", value: settings.serviceSummary) { onEdit(.service) }
            SettingRow(label: "Warn me", value: "\(settings.alertLeadMinutes) min") { onEdit(.buffer) }
            SettingRow(label: "Schedule", value: settings.schedule.short) { onEdit(.schedule) }
            SettingRow(label: "Stop", value: "Change") { onEdit(.stop) }

            Spacer(minLength: 28)

            Text(status)
                .font(Theme.body(13))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 14)

            PosterButton(title: "Start watching now", action: onStart)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .background(Theme.ground)
    }

    private var status: String {
        if let error = tracker.errorMessage { return error }
        let base = settings.schedule == .off
            ? "Tap start and it polls every \(Int(BusConfig.pollInterval)) seconds."
            : "\(settings.schedule.name) — it arms itself."
        return base + " Warns \(settings.alertLeadMinutes) min ahead (\(settings.stop.walkMinutes) min walk + \(settings.bufferMinutes))."
    }
}

private struct SettingRow: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Kicker(text: label)
                Spacer(minLength: 8)
                Text(value)
                    .font(Theme.heading(18, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                Chevron()
            }
            .padding(.vertical, 18)
            .overlay(alignment: .bottom) { Rule(color: Theme.hairline, height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct Chevron: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 1, y: 1))
            p.addLine(to: CGPoint(x: 7, y: 7))
            p.addLine(to: CGPoint(x: 1, y: 13))
        }
        .stroke(Theme.accent, lineWidth: 2)
        .frame(width: 8, height: 14)
    }
}
