//
//  SiriVMParser.swift
//  MyFirstApp
//
//  Extracts vehicle positions from a BODS SIRI-VM XML response.
//

import Foundation

/// One live vehicle position from the SIRI-VM feed.
struct VehiclePosition {
    var vehicleRef = ""
    var lineName = ""
    var direction = ""
    var destination = ""
    var latitude = 0.0
    var longitude = 0.0
    var recordedAt: Date?
}

final class SiriVMParser: NSObject, XMLParserDelegate {
    private var vehicles: [VehiclePosition] = []
    private var current: VehiclePosition?
    private var text = ""
    private var insideVehicleLocation = false

    static func parse(_ data: Data) -> [VehiclePosition] {
        let delegate = SiriVMParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.vehicles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        text = ""
        switch elementName {
        case "VehicleActivity":
            current = VehiclePosition()
        case "VehicleLocation":
            insideVehicleLocation = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "VehicleActivity":
            if let current { vehicles.append(current) }
            current = nil
        case "VehicleLocation":
            insideVehicleLocation = false
        case "RecordedAtTime":
            current?.recordedAt = Self.date(from: value)
        case "LineRef", "PublishedLineName":
            // PublishedLineName follows LineRef in the feed, so it wins when present.
            if !value.isEmpty { current?.lineName = value }
        case "DirectionRef":
            current?.direction = value
        case "DestinationName", "DestinationDisplay":
            if !value.isEmpty { current?.destination = value }
        case "DestinationRef":
            // Only a stop code, but better than nothing if no name is published.
            if let current, current.destination.isEmpty { self.current?.destination = value }
        case "VehicleRef":
            current?.vehicleRef = value
        case "Latitude":
            if insideVehicleLocation { current?.latitude = Double(value) ?? 0 }
        case "Longitude":
            if insideVehicleLocation { current?.longitude = Double(value) ?? 0 }
        default:
            break
        }
        text = ""
    }

    // SIRI timestamps appear both with and without fractional seconds.
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plainFormatter = ISO8601DateFormatter()

    private static func date(from string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string)
    }
}
