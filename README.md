# Modernist screens for MyFirstApp

Drag `Theme.swift`, `BusSettings.swift`, `ContentView.swift` and `Screens.swift` into the
MyFirstApp target (replacing the existing ContentView.swift). `BusTracker.swift`,
`SiriVMParser.swift` and `MyFirstAppApp.swift` stay as they are.

## Three changes needed in the existing code

1. **BusTracker should read the user's choices, not BusConfig constants.** Add
   `lineName`, `warningTime` and the stop coordinate as properties on `BusTracker`
   (defaulting to the BusConfig values) and set them from `BusSettings` in
   `startTracking()`. Until then the tracker still follows 3X at Moda Hove Central
   regardless of what the pickers say, and the UI is a display layer only.
2. **Filter by direction.** `ContentView.nearestETA` matches
   `ApproachingBus.direction` against the chosen `DirectionRef`. The BODS feed
   publishes these as `inbound`/`outbound` on most operators but not all — log
   `vehicle.direction` once against the live feed and adjust the two `ref` values in
   `BusSettings.directions` to whatever Brighton & Hove actually sends.
3. **Background running.** Notifications only fire while the app is polling. For the
   weekday schedule to work with the phone in a pocket you need a background mode
   (location updates, or a server-side push). `shouldAutoArm` currently only arms when
   the app is opened inside the window.

## Fonts

The design is set in Archivo. Add `Archivo-Regular.ttf`, `Archivo-SemiBold.ttf` and
`Archivo-ExtraBold.ttf` to the target, list them under `UIAppFonts` in Info.plist, and
`Theme.heading` / `Theme.body` pick them up. Without the files SwiftUI silently falls
back to the system face, which still reads correctly but loses the character.

## What the screens are

- **Home** — stop as the headline, five ruled rows (direction, service, warn me,
  schedule, stop), red flush-left start button.
- **Picker sheet** — one list, red square marks the current choice.
- **Armed (1c)** — full red field, the ETA as a single number, outlined stop button.
- **Alert** — red field, "Leave now", then watch-the-next or on-my-way.
