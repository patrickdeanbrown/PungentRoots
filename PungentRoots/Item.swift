//
//  Item.swift
//  PungentRoots
//
//  Created by Patrick Brown on 9/17/25.
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
