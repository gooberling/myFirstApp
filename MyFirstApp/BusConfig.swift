//
//  BusConfig.swift
//  MyFirstApp
//
//  API credentials and tuning constants. The stop and service being tracked are
//  no longer hardcoded here — they come from the user's selection (BusSettings)
//  backed by the bundled catalog (StopCatalog).
//

import Foundation

enum BusConfig {
    /// Paste your key from https://data.bus-data.dft.gov.uk/account/settings/
    static let apiKey = "c65f58b2d52a4791d9f5ab35358d4791d666ee8c"

    /// How often to re-fetch vehicle positions while tracking.
    static let pollInterval: TimeInterval = 15

    /// Assumed average bus speed (~20 km/h urban) used to turn distance into an ETA.
    static let assumedBusSpeed = 5.5 // metres per second

    /// Ignore vehicles further than this from the stop.
    static let searchRadius = 8_000.0 // metres

    /// Half-size, in degrees, of the bounding box sent to the BODS API.
    static let boundingBoxHalfSize = 0.08
}
