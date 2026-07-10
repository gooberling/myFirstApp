//
//  BusConfig.swift
//  MyFirstApp
//
//  Hardcoded details for the stop and route being tracked.
//

import Foundation

enum BusConfig {
    /// Paste your key from https://data.bus-data.dft.gov.uk/account/settings/
    static let apiKey = "YOUR_BODS_API_KEY"

    static let lineName = "3X"
    static let stopName = "Moda Hove Central (adj)"
    static let stopAtcoCode = "149000006512"
    static let stopLatitude = 50.838147
    static let stopLongitude = -0.177475

    /// Fire the warning notification when a bus is estimated to be this close.
    static let warningTime: TimeInterval = 6 * 60

    /// How often to re-fetch vehicle positions while tracking.
    static let pollInterval: TimeInterval = 15

    /// Assumed average bus speed (~20 km/h urban) used to turn distance into an ETA.
    static let assumedBusSpeed = 5.5 // metres per second

    /// Ignore vehicles further than this from the stop.
    static let searchRadius = 8_000.0 // metres

    /// Half-size, in degrees, of the bounding box sent to the BODS API.
    static let boundingBoxHalfSize = 0.08
}
