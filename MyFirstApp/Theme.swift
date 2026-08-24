//
//  Theme.swift
//  MyFirstApp
//
//  Modernist tokens: flat, flush left, zero corner radius, 2px rules.
//

import SwiftUI

enum Theme {
    static let ground = Color(red: 0.953, green: 0.949, blue: 0.949)   // #f3f2f2
    static let ink = Color(red: 0.125, green: 0.118, blue: 0.114)      // #201e1d
    static let accent = Color(red: 0.925, green: 0.188, blue: 0.075)   // #ec3013
    static let accentPressed = Color(red: 0.867, green: 0.169, blue: 0.059) // #dd2b0f

    static var divider: Color { ink.opacity(0.4) }
    static var hairline: Color { ink.opacity(0.18) }
    static var muted: Color { ink.opacity(0.55) }

    /// Archivo if it is in the bundle, otherwise the system face at the same weight.
    static func heading(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .custom("Archivo", size: size).weight(weight)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Archivo", size: size).weight(weight)
    }
}

/// The small flush-left uppercase label the system uses above every block.
struct Kicker: View {
    let text: String
    var color: Color = Theme.muted

    var body: some View {
        Text(text.uppercased())
            .font(Theme.heading(11))
            .tracking(1.5)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The 2px rule. Never soften it to a hairline.
struct Rule: View {
    var color: Color = Theme.divider
    var height: CGFloat = 2
    var body: some View { Rectangle().fill(color).frame(height: height) }
}

/// Flush-left block button. Label starts at the left padding edge, never centred.
struct PosterButton: View {
    let title: String
    var fill: Color = Theme.accent
    var label: Color = Theme.ground
    var border: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.heading(20))
                .foregroundStyle(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
                .background(fill)
                .overlay(border.map { Rectangle().stroke($0, lineWidth: 2) })
        }
        .buttonStyle(.plain)
    }
}

extension PosterButton {
    static func outlined(_ title: String, label: Color = Theme.ink, action: @escaping () -> Void) -> PosterButton {
        PosterButton(title: title, fill: .clear, label: label, border: label.opacity(0.4), action: action)
    }
}
