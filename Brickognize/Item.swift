//
//  Item.swift
//  Brickognize
//
//  Created by Patrick Mill on 8/20/25.
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
