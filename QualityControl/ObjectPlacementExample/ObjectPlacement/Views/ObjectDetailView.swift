//
//  ObjectDetailView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct ObjectDetailView: View {
    var appState: AppState
    let onDelete: () -> Void
    
    @State private var presentConfirmationDialog = false
    @State var navigationPath: [String] = [] // Path to manage navigation

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Button("Position") {
                    navigationPath.append("Position")
                }
                .buttonStyle(.bordered)

                Button("Inspection") {
                    navigationPath.append("Inspection")
                }
                .buttonStyle(.bordered)
                
                Button("Remove", systemImage: "trash") {
                    presentConfirmationDialog = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.borderless)
                .confirmationDialog("Remove the object?", isPresented: $presentConfirmationDialog, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .navigationTitle("Object Details")
            .navigationDestination(for: String.self) { destination in
                if destination == "Position" {
                    PositionView(appState: appState)
                } else if destination == "Inspection" {
                    InspectionView(appState: appState)
                }
                else if destination == "InspectionDetail"
                {
                    InspectionDetailView(appState: appState)
                }
            }
            .padding()
            .onChange(of: appState.isInspectionDetailsOpen) { newVal in
                if newVal == false
                {
                    return
                }
                        navigationPath.append("InspectionDetail")
                        print("Navigation path changed in ODV: \(newVal)")
                    }
        }
        
    }
}
