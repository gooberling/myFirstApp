//
//  MyFirstAppTests.swift
//  MyFirstAppTests
//
//  Created by Nick D on 10/07/2026.
//

import Testing
import Foundation
@testable import MyFirstApp

struct MyFirstAppTests {

    // MARK: - Catalog

    @Test func catalogLoadsBothStops() {
        let atcos = Set(StopCatalog.stops.map(\.atco))
        #expect(atcos.contains("149000006512")) // To town
        #expect(atcos.contains("149000007515")) // To school
    }

    @Test func eachStopOffersIndividualServicesWithout2B() throws {
        for atco in ["149000006512", "149000007515"] {
            let stop = try #require(StopCatalog.stops.first { $0.atco == atco })
            let labels = stop.services.map(\.line)
            #expect(labels == ["3X", "5", "5A", "5B", "N5"]) // 5-family un-grouped
            #expect(!labels.contains("2B"))                   // 2B still excluded
        }
    }

    // MARK: - Decoding

    @Test func decodesServiceFromJSON() throws {
        let json = Data(#"{"line":"5A","lines":["5A"],"destinations":["Craignair Avenue"]}"#.utf8)
        let service = try JSONDecoder().decode(Service.self, from: json)
        #expect(service.line == "5A")
        #expect(service.lines == ["5A"])
        #expect(service.headsign == "Craignair Avenue")
    }

    // MARK: - Multi-select behaviour

    @MainActor @Test func selectAllWatchesEveryOfferedLine() throws {
        let settings = BusSettings()
        let town = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        settings.select(stop: town)
        settings.selectAllServices()
        #expect(settings.allSelected)
        #expect(Set(settings.trackedLines) == ["3X", "5", "5A", "5B", "N5"])
        #expect(settings.serviceSummary == "All services")
    }

    @MainActor @Test func togglingLeavesAtLeastOneSelected() throws {
        let settings = BusSettings()
        let town = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        settings.select(stop: town)
        settings.selectAllServices()

        for line in ["5", "5A", "5B", "N5"] { settings.toggle(line) }
        #expect(settings.trackedLines == ["3X"])
        #expect(!settings.allSelected)

        settings.toggle("3X") // removing the last one is refused
        #expect(settings.trackedLines == ["3X"])
    }

    @MainActor @Test func togglingBackOnRestoresAllSelected() throws {
        let settings = BusSettings()
        let town = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        settings.select(stop: town)
        settings.selectAllServices()
        settings.toggle("5") // drop one
        #expect(!settings.allSelected)
        settings.toggle("5") // add it back
        #expect(settings.allSelected)
    }

    @MainActor @Test func selectingStopPrunesInvalidLines() {
        let settings = BusSettings()
        let x = Service(line: "3X", lines: ["3X"], destinations: ["Town"])
        let nine = Service(line: "9", lines: ["9"], destinations: ["Elsewhere"])
        let stopA = Stop(atco: "A", name: "A", lat: 0, lon: 0, walkMinutes: 5, services: [x, nine], approach: nil)
        let stopB = Stop(atco: "B", name: "B", lat: 0, lon: 0, walkMinutes: 5, services: [x], approach: nil)

        settings.select(stop: stopA)
        settings.selectedLines = ["3X", "9"]
        settings.select(stop: stopB) // "9" doesn't call here
        #expect(settings.selectedLines == ["3X"])
    }

    // MARK: - Alert lead

    @MainActor @Test func alertLeadIsWalkPlusBuffer() {
        let settings = BusSettings()
        settings.bufferMinutes = 2
        #expect(settings.alertLeadMinutes == settings.stop.walkMinutes + 2)
        #expect(settings.alertLeadSeconds == Double(settings.alertLeadMinutes) * 60)
    }
}
