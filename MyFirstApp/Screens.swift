//
//  Screens.swift
//  MyFirstApp
//
//  The picker sheet, the armed poster (option 1c) and the alert.
//

import SwiftUI

// MARK: - Picker

struct PickerSheet: View {
    let kind: PickerKind
    let settings: BusSettings
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onClose) {
                Kicker(text: "← Back", color: Theme.accent)
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
                            onClose()
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

    private var options: [Option] {
        switch kind {
        case .direction:
            BusSettings.directions.map { d in
                (d.name, d.detail, d.ref == settings.direction.ref, { settings.direction = d })
            }
        case .service:
            BusSettings.services.map { s in
                ("Service " + s.line, s.detail, s.line == settings.service.line, { settings.service = s })
            }
        case .lead:
            BusSettings.leadTimes.map { n in
                ("\(n) minutes", leadDetail(n), n == settings.leadMinutes, { settings.leadMinutes = n })
            }
        case .schedule:
            Schedule.allCases.map { s in
                (s.name, s.detail, s == settings.schedule, { settings.schedule = s })
            }
        case .stop:
            BusSettings.stops.map { s in
                (s.name, s.detail, s.id == settings.stop.id, { settings.stop = s })
            }
        }
    }

    private func leadDetail(_ n: Int) -> String {
        switch n {
        case 3: "You are already at the door"
        case 6: "Matches BusConfig.warningTime"
        default: "Time to find your shoes"
        }
    }
}

// MARK: - Armed (option 1c — red poster, one number)

struct ArmedView: View {
    let settings: BusSettings
    let tracker: BusTracker
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "\(settings.service.line) · \(settings.direction.name.lowercased())", color: Theme.ground)
                Kicker(text: tracker.isTracking ? "Live" : "Paused", color: Theme.ground.opacity(0.7))
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            Rule(color: Theme.ground).padding(.top, 14)

            Spacer(minLength: 0)
            Text(minutesLabel)
                .font(Theme.heading(260))
                .monospacedDigit()
                .kerning(-14)
                .foregroundStyle(Theme.ground)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)

            Rule(color: Theme.ground)
            Text("Minutes from \(settings.stop.name)")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ground)
                .padding(.top, 22)
            Text("Buzzing at \(settings.leadMinutes). Screen off is fine.")
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

    private var minutesLabel: String {
        guard let next = tracker.buses.first(where: { $0.isClosingIn }) else { return "–" }
        return "\(next.etaMinutes)"
    }
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
            Text("The \(settings.service.line) \(settings.direction.name.lowercased()) is about \(settings.leadMinutes) minutes from \(settings.stop.name).")
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
