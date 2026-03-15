//
//  Item.swift
//  Imperium
//
//  Created by Sanskaar Nair on 2026-03-16.
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
