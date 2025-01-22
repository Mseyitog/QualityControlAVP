//
//  SwiftUIView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct PositionView: View {
    var appState: AppState
    
//    enum Mode: String {
//        case rotation = "Rotation"
//        case forwardBack = "Forward-Back"
//        case leftRight = "Left-Right"
//    }

    var body: some View {
        VStack {
            Text("Adjust Position")
                .font(.title)
                .padding()

            Text("Current Mode: \(appState.mode?.rawValue ?? "None")")
                .font(.headline)
                .padding()

            // Three buttons for modes
            HStack(spacing: 20) {
                Button(action: { toggleMode(AppState.InteractionMode.rotation) }) {
                    Text("Rotation")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(appState.mode == .rotation ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }

                Button(action: { toggleMode(AppState.InteractionMode.forwardBack) }) {
                    Text("Forward-Back")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(appState.mode == .forwardBack ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }

                Button(action: { toggleMode(AppState.InteractionMode.leftRight) }) {
                    Text("Left-Right")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(appState.mode == .leftRight ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            Spacer()

            Text("Tap a mode button to select or deselect a mode.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Position")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            appState.mode = nil
        }
    }

    // Toggle the mode: Select or deselect
    private func toggleMode(_ mode: AppState.InteractionMode) {
        if appState.mode == mode {
            appState.mode = nil // Deselect the mode if it's already selected
        } else {
            appState.mode = mode // Set the selected mode
        }
    }
}
