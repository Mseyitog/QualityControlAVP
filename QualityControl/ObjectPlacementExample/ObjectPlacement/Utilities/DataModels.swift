//
//  DataModels.swift
//  Quality Control
//
//  Created by Melike SEYİTOĞLU on 9.12.2024.
//

import Foundation

struct InspectionPoint : Identifiable {
            let id = UUID()
            let name: String
            let position: SIMD3<Float>
    var count: Int?              // e.g. number of occurrences
    var hasCount: Bool
    
    var description: String?     // detailed information
    var hasDescription: Bool
    
    var isCorrect: Bool?         // replaced 'exists' with 'isCorrect'
    var hasIsCorrect: Bool
}

struct VirtualObject {
    var name: String
    var width: Double
    var height: Double
    var depth: Double
    var inspectionPoints: [InspectionPoint]
}
