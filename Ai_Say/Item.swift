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
    var prompt: String?
    var userText: String?
    var aiResponse: String?
    var score: Double?
    var audioPath: String?
    var isAudio: Bool = false
    
    init(timestamp: Date, prompt: String? = nil, userText: String? = nil) {
        self.timestamp = timestamp
        self.prompt = prompt
        self.userText = userText
    }
}
