//
//  Item.swift
//  MyFirstApp
//
//  Created by Nick D on 10/07/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
