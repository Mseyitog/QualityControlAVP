//
//  SwiftUIView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

struct InspectionView: View {
    var appState: AppState
    
    @State private var isGeneratingReport: Bool = false
        @State private var reportGenerationSuccess: Bool = false
        @State private var reportError: String?

    
    var body: some View {
        VStack {
            Text("Inspect Object")
                .font(.title)
                .padding()
            
            // Button to generate the Excel report
                            Button(action: generateReport) {
                                Text("Generate Report")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding()
                            .disabled(isGeneratingReport)
                            
                            // Feedback for report generation
                            if isGeneratingReport {
                                ProgressView("Generating Report...")
                                    .padding()
                            }
                            if let reportError = reportError {
                                Text("Error: \(reportError)")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                            if reportGenerationSuccess {
                                Text("Report generated successfully!")
                                    .foregroundColor(.green)
                                    .padding()
                            }

                            Spacer()
        }
        .padding()
        .onAppear {
                    addInspectionPoints()
                }
                .onDisappear {
                    removeInspectionPoints()
                }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addInspectionPoints() {
        guard let object = appState.placementManager?.placementState.placedObject else {
            print("No object available for inspection points.")
            return
        }

        let objectName = object.fileName
        let loader = InspectionPointLoader()

        // Load inspection points for the specific object name
        let inspectionPointsData = loader.getInspectionPoints(for: objectName)

        Task {
            // Dynamically generate inspection points for the placed object
            await appState.placementManager?.generateInspectionPoints(for: object)

            // Update AppState with the loaded inspection points
            for (type, pointData) in inspectionPointsData {
                // Check if the inspection point already exists
                if appState.inspectionPoints[objectName]?[type] == nil {
                    // Only add the inspection point if it doesn't already exist
                    let inspectionPoint = InspectionPoint(
                        name: pointData.name,
                        position: pointData.position,
                        count: pointData.count,
                        hasCount: pointData.hasCount,
                        description: pointData.description,
                        hasDescription: pointData.hasDescription,
                        isCorrect: pointData.isCorrect,
                        hasIsCorrect: pointData.hasIsCorrect
                    )
                    appState.inspectionPoints[objectName, default: [:]][type] = inspectionPoint
                } else {
                    print("Inspection point for type \(type.rawValue) already exists and won't be overwritten.")
                }
            }
        }
    }

//    
//    private func addInspectionPoints() {
//        guard let object = appState.placementManager?.placementState.placedObject else {
//            print("No object available for inspection points.")
//            return
//        }
//
//        let objectName = object.fileName
//        let loader = InspectionPointLoader()
//        
//        // Load inspection points for the specific object name
//        let inspectionPointsData = loader.getInspectionPoints(for: objectName)
//        
////        // Collect RCP coordinates from the loaded inspection points
////        let rcpCoordinates: [SIMD3<Float>] = inspectionPointsData.values.map { pointData in
////            pointData.position
////        }
//        
//        Task {
////            let inputTime = Date().timeIntervalSince1970
//
//            // Dynamically generate inspection points for the placed object
////            await appState.placementManager?.generateInspectionPointsFromRCP(for: object, rcpCoordinates: rcpCoordinates)
//            await appState.placementManager?.generateInspectionPoints(for: object)
//            
//            // Update AppState with the loaded inspection points
//            for (type, pointData) in inspectionPointsData {
//                let inspectionPoint = InspectionPoint(
//                    name: pointData.name,
//                    position: pointData.position,
//                    count: pointData.count,
//                    hasCount: pointData.hasCount,
//                    description: pointData.description,
//                    hasDescription: pointData.hasDescription,
//                    isCorrect: pointData.isCorrect,
//                    hasIsCorrect: pointData.hasIsCorrect
//                )
//                
//                appState.inspectionPoints[type] = inspectionPoint
//            }
////            let outputTime = Date().timeIntervalSince1970
////                let latency = outputTime - inputTime
////                print("Latency in generating inspection points: \(latency) seconds")
//        }
//    }


    
//    private func addInspectionPoints() {
//            guard let object = appState.placementManager?.placementState.placedObject else {
//                print("No object available for inspection points.")
//                return
//            }
//
//            let rcpCoordinates: [SIMD3<Float>] = [
//                SIMD3<Float>(9.238, 12.689, 12.099),
//            ]
//
//            Task {
//                await appState.placementManager?.generateInspectionPointsFromRCP(for: object, rcpCoordinates: rcpCoordinates)
//            }
//        }

        private func removeInspectionPoints() {
            Task {
                await appState.placementManager?.removeInspectionPoints()
            }
        }
    
    private func generateReport() {
        isGeneratingReport = true
        reportGenerationSuccess = false
        reportError = nil

        Task {
            do {
                // Ensure the placement manager and placed object are available
                guard let placementManager = appState.placementManager,
                      let placedObject = placementManager.placementState.placedObject else {
                    throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No object available for report generation"])
                }

                // Calculate object dimensions
                let dimensions = placedObject.extents
                let width = Double(dimensions.x)
                let height = Double(dimensions.y)
                let depth = Double(dimensions.z)

                // Use the object's name and inspection points
                let objectName = placedObject.fileName
                guard let inspectionPoints = appState.inspectionPoints[objectName]?.values else {
                    throw NSError(domain: "ReportGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "No inspection points available for the object"])
                }

                // Create a VirtualObject using the dynamic data
                let virtualObject = VirtualObject(
                    name: objectName,
                    width: width,
                    height: height,
                    depth: depth,
                    inspectionPoints: Array(inspectionPoints)
                )

                // Define the reports directory
                let reportsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path

                // Create a ReportGenerator instance
                let reportGenerator = ReportGenerator(for: virtualObject, reportsDirectory: reportsDirectory)

                // Generate the report
                try reportGenerator.createReport()
                reportGenerationSuccess = true
                print("Report generated at: \(reportGenerator.filePath)")
            } catch {
                reportError = error.localizedDescription
            }
            isGeneratingReport = false
        }
    }

    
//    private func generateReport() {
//        isGeneratingReport = true
//        reportGenerationSuccess = false
//        reportError = nil
//
//        Task {
//            do {
//                // Ensure the placement manager and placed object are available
//                guard let placementManager = appState.placementManager,
//                      let placedObject = placementManager.placementState.placedObject else {
//                    throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No object available for report generation"])
//                }
//
//                // Calculate object dimensions
//                let dimensions = placedObject.extents
//                let width = Double(dimensions.x)
//                let height = Double(dimensions.y)
//                let depth = Double(dimensions.z)
//
//                // Use the object's name and inspection points
//                let objectName = placedObject.fileName
//                let inspectionPoints = Array(appState.inspectionPoints.values)
//                
//                // Create a VirtualObject using the dynamic data
//                let virtualObject = VirtualObject(
//                    name: objectName,
//                    width: width,
//                    height: height,
//                    depth: depth,
//                    inspectionPoints: inspectionPoints
//                )
//                
//                // Define the reports directory
//                                let reportsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
//                                
//                                // Create a ReportGenerator instance
//                                let reportGenerator = ReportGenerator(for: virtualObject, reportsDirectory: reportsDirectory)
//                                
//                                // Generate the report
//                                try reportGenerator.createReport()
//                                reportGenerationSuccess = true
//                                print("Report generated at: \(reportGenerator.filePath)")
//            } catch {
//                reportError = error.localizedDescription
//            }
//            isGeneratingReport = false
//        }
//    }
}
