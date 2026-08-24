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
        case .service:
            settings.stop.services.map { s in
                ("Service " + s.line, "Towards " + s.headsign, s.line == settings.service.line,
                 { settings.service = s })
            }
        case .buffer:
            BusSettings.bufferOptions.map { n in
                ("\(settings.stop.walkMinutes + n) min warning", bufferDetail(n),
                 n == settings.bufferMinutes, { settings.bufferMinutes = n })
            }
        case .schedule:
            Schedule.allCases.map { s in
                (s.name, s.detail, s == settings.schedule, { settings.schedule = s })
            }
        case .stop:
            StopCatalog.stops.map { s in
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

// MARK: - Armed (option 1c — red poster, one number)

struct ArmedView: View {
    let settings: BusSettings
    let tracker: BusTracker
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "\(settings.service.line) · towards \(settings.service.headsign)", color: Theme.ground)
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
            Text("The \(settings.service.line) to \(settings.service.headsign) is about \(settings.alertLeadMinutes) minutes from \(settings.stop.name).")
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
