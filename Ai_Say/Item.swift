//
//  Item.swift
//  Ai_Say
//
//  Created by Alsay_Mac on 2026/1/13.
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
