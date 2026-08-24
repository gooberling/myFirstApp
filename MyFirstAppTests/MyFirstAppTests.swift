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
        #expect(atcos.contains("149000006512")) // Moda Hove Central (adj)
        #expect(atcos.contains("149000007515")) // Moda Hove Central (opp)
    }

    @Test func adjStopServesExpectedLines() throws {
        let adj = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        let lines = Set(adj.services.map(\.line))
        #expect(lines.isSuperset(of: ["2B", "3X", "5"]))
    }

    @Test func oppStopHasDirectionOnlyServices() throws {
        let opp = try #require(StopCatalog.stops.first { $0.atco == "149000007515" })
        let lines = Set(opp.services.map(\.line))
        #expect(lines.contains("3X"))
        #expect(!lines.contains("2B")) // 2B only calls at the adj side
    }

    // MARK: - Decoding

    @Test func decodesServiceFromJSON() throws {
        let json = Data(#"{"line":"5","destinations":["Craignair Avenue","Hangleton"]}"#.utf8)
        let service = try JSONDecoder().decode(Service.self, from: json)
        #expect(service.line == "5")
        #expect(service.headsign == "Craignair Avenue")
    }

    // MARK: - Selection behaviour

    @MainActor @Test func selectingStopKeepsServiceWhenItStillCalls() throws {
        let settings = BusSettings()
        let adj = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        let opp = try #require(StopCatalog.stops.first { $0.atco == "149000007515" })

        settings.select(stop: adj)
        settings.service = try #require(adj.services.first { $0.line == "3X" })
        settings.select(stop: opp) // opp also has 3X
        #expect(settings.service.line == "3X")
    }

    @MainActor @Test func selectingStopResetsServiceWhenItNoLongerCalls() throws {
        let settings = BusSettings()
        let adj = try #require(StopCatalog.stops.first { $0.atco == "149000006512" })
        let opp = try #require(StopCatalog.stops.first { $0.atco == "149000007515" })

        settings.select(stop: adj)
        settings.service = try #require(adj.services.first { $0.line == "2B" }) // 2B only on adj
        settings.select(stop: opp)
        #expect(settings.service.line != "2B")
        #expect(opp.services.contains { $0.line == settings.service.line })
    }

    // MARK: - Alert lead

    @MainActor @Test func alertLeadIsWalkPlusBuffer() {
        let settings = BusSettings()
        settings.bufferMinutes = 2
        #expect(settings.alertLeadMinutes == settings.stop.walkMinutes + 2)
        #expect(settings.alertLeadSeconds == Double(settings.alertLeadMinutes) * 60)
    }
}
