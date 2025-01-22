/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view shown inside the immersive space.
*/

import RealityKit
import SwiftUI

@MainActor
struct ObjectPlacementRealityView: View {
    var appState: AppState
    
    @State private var placementManager = PlacementManager()
    
    @State private var collisionBeganSubscription: EventSubscription? = nil
    @State private var collisionEndedSubscription: EventSubscription? = nil
    
    //DEBUG
    @State var navigationPath: [String] = [] // Navigation stack path
    
    private enum Attachments {
        case placementTooltip
        case dragTooltip
        case deleteButton
        case inspectionPointForCount
        case inspectionPointForDescription
        case inspectionPointForYesNoQuestion
    }

    var body: some View {

        RealityView { content, attachments in
            content.add(placementManager.rootEntity)
            placementManager.appState = appState
            
            if let placementTooltipAttachment = attachments.entity(for: Attachments.placementTooltip) {
                placementManager.addPlacementTooltip(placementTooltipAttachment)
            }
            
//            if let dragTooltipAttachment = attachments.entity(for: Attachments.dragTooltip) {
//                placementManager.dragTooltip = dragTooltipAttachment
//            }
            
//            if let deleteButtonAttachment = attachments.entity(for: Attachments.deleteButton) {
//                placementManager.deleteButton = deleteButtonAttachment
//            }
            
            // Attach buttons to the AR scene
            if let countButtonAttachment = attachments.entity(for: Attachments.inspectionPointForCount) {
                placementManager.countButton = countButtonAttachment
            }
            if let descriptionButtonAttachment = attachments.entity(for: Attachments.inspectionPointForDescription) {
                placementManager.descriptionButton = descriptionButtonAttachment
            }
            if let yesNoButtonAttachment = attachments.entity(for: Attachments.inspectionPointForYesNoQuestion) {
                placementManager.yesNoButton = yesNoButtonAttachment
            }
            
            collisionBeganSubscription = content.subscribe(to: CollisionEvents.Began.self) {  [weak placementManager] event in
                placementManager?.collisionBegan(event)
            }
            
            collisionEndedSubscription = content.subscribe(to: CollisionEvents.Ended.self) {  [weak placementManager] event in
                placementManager?.collisionEnded(event)
            }
            
            Task {
                // Run the ARKit session after the user opens the immersive space.
                await placementManager.runARKitSession()
            }
        } update: { update, attachments in
            let placementState = placementManager.placementState

            // DEBUG
            if let placementTooltip = attachments.entity(for: Attachments.placementTooltip) {
                // Hide the placement tooltip if an object is placed.
                placementTooltip.isEnabled = placementState.shouldShowPlacementUI
            }

            if let dragTooltip = attachments.entity(for: Attachments.dragTooltip) {
                // Hide the drag tooltip if no object is present.
                dragTooltip.isEnabled = placementState.placedObject != nil
            }
            
            // END DEBUG
//
//            if let placementTooltip = attachments.entity(for: Attachments.placementTooltip) {
////                placementTooltip.isEnabled = (placementState.selectedObject != nil && placementState.shouldShowPreview)
//
//                // DEBUG
//                placementTooltip.isEnabled = (placementState.placedObject == nil && placementState.shouldShowPreview)
//
//            }
//            
//            if let dragTooltip = attachments.entity(for: Attachments.dragTooltip) {
//                // Dismiss the drag tooltip after the user demonstrates it.
//                dragTooltip.isEnabled = !placementState.userDraggedAnObject
//            }

            if let selectedObject = placementState.selectedObject {
                selectedObject.isPreviewActive = placementState.isPlacementPossible
            }
        } attachments: {
            Attachment(id: Attachments.placementTooltip) {
                PlacementTooltip(placementState: placementManager.placementState)
            }
            Attachment(id: Attachments.dragTooltip) {
                TooltipView(text: "Drag to reposition.")
            }
            Attachment(id: Attachments.deleteButton) {
                DeleteButton {
//                    Task {
//                        await placementManager.removeHighlightedObject()
//                    }
                    
                    // DEBUG
                    Task {
                        // Remove the currently highlighted or placed object.
//                        if let placedObject = placementManager.placementState.placedObject {
//                            await placementManager.removeHighlightedObject()
                        // }
                            //DEBUG
                            await placementManager.removeAllPlacedObjects()
                        
                    }
                }
            }
            Attachment(id: Attachments.inspectionPointForCount) {
                InspectionPointButton(
                    pointName: "Count",
                    isDisabled: appState.isInspectionDetailsOpen
                ) {
                    placementManager.handleInspectionPointTap(type: .forCount, navigationPath: $navigationPath)
                }
            }
            Attachment(id: Attachments.inspectionPointForDescription) {
                InspectionPointButton(
                    pointName: "Description",
                    isDisabled: appState.isInspectionDetailsOpen
                ) {
                    placementManager.handleInspectionPointTap(type: .forDescription, navigationPath: $navigationPath)
                }
            }
            Attachment(id: Attachments.inspectionPointForYesNoQuestion) {
                InspectionPointButton(
                    pointName: "Yes/No",
                    isDisabled: appState.isInspectionDetailsOpen
                ) {
                    placementManager.handleInspectionPointTap(type: .forYesNoQuestion, navigationPath: $navigationPath)
                }
            }
        }
        .task {
            // Monitor ARKit anchor updates once the user opens the immersive space.
            //
            // Tasks attached to a view automatically receive a cancellation
            // signal when the user dismisses the view. This ensures that
            // loops that await anchor updates from the ARKit data providers
            // immediately end.
            await placementManager.processWorldAnchorUpdates()
        }
        .task {
            await placementManager.processDeviceAnchorUpdates()
        }
        .task {
            await placementManager.processPlaneDetectionUpdates()
        }
        .task {
            await placementManager.checkIfAnchoredObjectsNeedToBeDetached()
        }
        .task {
            await placementManager.checkIfMovingObjectsCanBeAnchored()
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { event in
//            // Place the currently selected object when the user looks directly at the selected object’s preview.
//            if event.entity.components[CollisionComponent.self]?.filter.group == PlaceableObject.previewCollisionGroup {
//                placementManager.placeSelectedObject()
//            }
            
            // DEBUG
//            // Place the currently selected object only if no object is already placed.
//                if placementManager.placementState.placedObject == nil,
//                   event.entity.components[CollisionComponent.self]?.filter.group == PlaceableObject.previewCollisionGroup {
//                    placementManager.placeSelectedObject()
//                } else {
//                    print("Placement disabled. An object is already placed.")
//                }
            let inputTime = Date().timeIntervalSince1970

            // Place an object only if no object exists.
                if placementManager.placementState.shouldShowPlacementUI,
                   event.entity.components[CollisionComponent.self]?.filter.group == PlaceableObject.previewCollisionGroup {
                    placementManager.placeSelectedObject()
                }
            
            let outputTime = Date().timeIntervalSince1970
            let latency = outputTime - inputTime
            print("Latency tap gesture(place object): \(latency) seconds")
//            END DEBUG
        })
        .gesture(DragGesture()
            .targetedToAnyEntity()
            .handActivationBehavior(.pinch) // Prevent moving objects by direct touch.
                 // DEBUG
            .onChanged { value in
                    let inputTime = Date().timeIntervalSince1970

                    
                    guard let mode = appState.mode else {
                        print("No mode selected. Ignoring drag gesture.")
                        return
                    }
                    placementManager.updateDrag(value: value, mode: mode)
                
                    let outputTime = Date().timeIntervalSince1970
                    let latency = outputTime - inputTime
                    print("Latency drag gesture(position etc.): \(latency) seconds")
                }
                .onEnded { value in
                    placementManager.endDrag()
                }
//            .onChanged { value in
//                    if let placedObject = placementManager.placementState.placedObject,
//                       value.entity.components[CollisionComponent.self]?.filter.group == PlacedObject.collisionGroup {
//                        placementManager.updateDrag(value: value)
//                    }
//                }
//                .onEnded { value in
//                    if let placedObject = placementManager.placementState.placedObject,
//                       value.entity.components[CollisionComponent.self]?.filter.group == PlacedObject.collisionGroup {
//                        placementManager.endDrag()
//                    }
//                }
//            .onChanged { value in
//                if value.entity.components[CollisionComponent.self]?.filter.group == PlacedObject.collisionGroup {
//                    placementManager.updateDrag(value: value)
//                }
//            }
//            .onEnded { value in
//                if value.entity.components[CollisionComponent.self]?.filter.group == PlacedObject.collisionGroup {
//                    placementManager.endDrag()
//                }
//            }
        )
        // DEBUG
//        .onTapGesture { value in
//            print(value)
//            
//        }
//        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { event in
//            guard let tappedEntity = event.entity as? ModelEntity,
//                  tappedEntity.name.contains("InspectionPoint") else {
//                print("tapped entity name in inspc:\(event.entity.name)")
//                return
//            }
//            print("INSPECTION WORKS")
//            Task {
//                await placementManager.handleTapOnInspectionPoint(tappedEntity)
//            }
//        })
        .onAppear() {
            print("Entering immersive space.")
            appState.immersiveSpaceOpened(with: placementManager)
//            Task {
//                await placementManager.runARKitSession() // Restart ARKit session
//            }
        }
        .onDisappear() {
            print("Leaving immersive space.")
//            Task {
//                await placementManager.pauseARKitSession() // Pause the AR session on exit
////                DEBUG
//                placementManager = PlacementManager()
////                DEBUG END
//            }
            appState.didLeaveImmersiveSpace()
        }
        //DEBUG
        .onChange(of: navigationPath) { newPath in
                    print("Navigation path changed in RV: \(newPath)")
                }
        
    }
}
