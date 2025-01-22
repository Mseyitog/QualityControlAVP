/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view model for the immersive space.
*/

import Foundation
import ARKit
import RealityKit
import QuartzCore
import SwiftUI

@Observable
final class PlacementManager {
    
    private let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider()
    
    private var planeAnchorHandler: PlaneAnchorHandler
    private var persistenceManager: PersistenceManager
    
    // DEBUG
    private var isSessionRunning: Bool = false // Tracks session state
    private var inspectionPoints: [Entity] = [] // Hold references to the points
    var countButton: Entity?
    var descriptionButton: Entity?
    var yesNoButton: Entity?
    
    enum InspectionPointType: String {
        case forCount = "InspectionPointForCount"
        case forDescription = "InspectionPointForDescription"
        case forYesNoQuestion = "InspectionPointForYesNoQuestion"
    }


    
    var appState: AppState? = nil {
        didSet {
            persistenceManager.placeableObjectsByFileName = appState?.placeableObjectsByFileName ?? [:]
        }
    }

    private var currentDrag: DragState? = nil {
        didSet {
            placementState.dragInProgress = currentDrag != nil
        }
    }
    
    var placementState = PlacementState()

    var rootEntity: Entity
    
    private let deviceLocation: Entity
    private let raycastOrigin: Entity
    private let placementLocation: Entity
    private weak var placementTooltip: Entity? = nil
    weak var dragTooltip: Entity? = nil
    weak var deleteButton: Entity? = nil
    
    // Place objects on planes with a small gap.
    static private let placedObjectsOffsetOnPlanes: Float = 0.01
    
    // Snap dragged objects to a nearby horizontal plane within +/- 4 centimeters.
    static private let snapToPlaneDistanceForDraggedObjects: Float = 0.04
    
    @MainActor
    init() {
        let root = Entity()
        rootEntity = root
        placementLocation = Entity()
        deviceLocation = Entity()
        raycastOrigin = Entity()
        
        planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
        persistenceManager = PersistenceManager(worldTracking: worldTracking, rootEntity: root)
        persistenceManager.loadPersistedObjects()
        
        rootEntity.addChild(placementLocation)
        
        deviceLocation.addChild(raycastOrigin)
        
        // Angle raycasts 15 degrees down.
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
    }
    
    func saveWorldAnchorsObjectsMapToDisk() {
        persistenceManager.saveWorldAnchorsObjectsMapToDisk()
    }
    
    @MainActor
    func addPlacementTooltip(_ tooltip: Entity) {
        placementTooltip = tooltip
        tooltip.name = "tooltip"
        // Add a tooltip 10 centimeters in front of the placement location to give
        // users feedback about why they can’t currently place an object.
        placementLocation.addChild(tooltip)
        tooltip.position = [0.0, 0.05, 0.2]
        
        for child in placementLocation.children {
            print("Child in placement tooltip name: \(child.name)")
        }
        print("end debug")
    }
    
//    func removeHighlightedObject() async {
//        if let highlightedObject = placementState.highlightedObject {
//            await persistenceManager.removeObject(highlightedObject)
//        }
//    }
    
    //DRBUG

    @MainActor
    func generateInspectionPoints(for object: PlacedObject) {
        // Get inspection points for the specific object name
        let loader = InspectionPointLoader()
        let inspectionPointsData = loader.getInspectionPoints(for: object.fileName) // Retrieve inspection points

        // Get the object's transform matrix for conversion
        let objectTransform = object.transformMatrix(relativeTo: nil)

        for (index, (inspectionType, inspectionPoint)) in inspectionPointsData.enumerated() {
            // Transform inspection point coordinates (cm) to ARKit coordinates (meters)
            let transformedCoordinate = objectTransform.transformPoint(inspectionPoint.position / 100.0) // Convert cm to meters

            // Determine the button type based on the inspection type
            let buttonEntity: Entity
            switch inspectionType {
            case .forCount:
                guard let countButton else { continue }
                buttonEntity = countButton
            case .forDescription:
                guard let descriptionButton else { continue }
                buttonEntity = descriptionButton
            case .forYesNoQuestion:
                guard let yesNoButton else { continue }
                buttonEntity = yesNoButton
            default:
                print("Unknown inspection type: \(inspectionType)")
                continue
            }

            // Configure the button's position and scale relative to the object
            buttonEntity.position = transformedCoordinate
            buttonEntity.scale = [1 / object.scale.x, 1 / object.scale.y, 1 / object.scale.z] // Scale relative to the object
            buttonEntity.name = "\(object.name)_InspectionButton\(index)"

            // Attach the button to the object's UI origin
            rootEntity.addChild(buttonEntity)

            // Store the button in the inspectionPoints array
            inspectionPoints.append(buttonEntity)

            print("Added \(inspectionType) button: \(buttonEntity.name) at \(buttonEntity.position)")
        }
    }




//    @MainActor
//    func generateInspectionPointsFromRCP(for object: PlacedObject, rcpCoordinates: [SIMD3<Float>]) {
//        // Get the object's transform matrix for conversion
//        let objectTransform = object.transformMatrix(relativeTo: nil)
//
//        for (index, coordinate) in rcpCoordinates.enumerated() {
//            // Transform RCP coordinates (cm) to ARKit coordinates (meters)
//            let transformedCoordinate = objectTransform.transformPoint(coordinate / 100.0) // Convert cm to meters
//
//            // Create a simple UI element (button-like Entity)
////            let buttonEntity = ModelEntity(mesh: .generateBox(size: [0.05, 0.05, 0.005])) // Flat rectangular button
////            buttonEntity.name = "InspectionButton\(index)"
////            buttonEntity.position = transformedCoordinate
////            buttonEntity.generateCollisionShapes(recursive: true)
////            buttonEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)] // Style the button
//            
//            // Add a tap gesture to the button
////                    buttonEntity.components[CollisionComponent.self] = CollisionComponent(shapes: [.generateBox(size: [0.05, 0.05, 0.005])])
////                    rootEntity.scene?.subscribe(to: CollisionEvents.Began.self, on: buttonEntity) { [weak self] event in
////                        print("\(buttonEntity.name) clicked!")
////                    }
//            
//            guard let yesNoButton else { return }
//
//            yesNoButton.position = transformedCoordinate
//            yesNoButton.scale = [1 / object.scale.x, 1 / object.scale.y, 1 / object.scale.z] // Scale relative to the object
//
//            // Attach the button to the object's uiOrigin for better management
//            rootEntity.addChild(yesNoButton)
////            buttonEntity.scale = [1 / object.scale.x, 1 / object.scale.y, 1 / object.scale.z] // Scale relative to the object
//
//
//            // Keep track of the button for future reference
//            inspectionPoints.append(yesNoButton)
//
////            print("Added inspection button: \(buttonEntity.name) at \(buttonEntity.position)")
//        }
//    }

//    @MainActor
//    func generateInspectionPointsFromRCP(for object: PlacedObject, rcpCoordinates: [SIMD3<Float>]) {
//        let objectTransform = object.transformMatrix(relativeTo: nil)
//
//        for (index, coordinate) in rcpCoordinates.enumerated() {
//            // Transform RCP coordinates (cm) to ARKit coordinates (meters)
//            let transformedCoordinate = objectTransform.transformPoint(coordinate / 100.0) // Convert cm to meters
//
//            let point = ModelEntity(mesh: .generateSphere(radius: 0.02)) // Small sphere
//            point.name = "InspectionPoint\(index)"
//            point.position = transformedCoordinate
//            point.generateCollisionShapes(recursive: true)
//            point.model?.materials = [SimpleMaterial(color: .blue, isMetallic: false)]
//
//            rootEntity.addChild(point)
//            inspectionPoints.append(point) // Keep track of the point
//            print("Added inspection point: \(point.name) at \(point.position)")
//        }
//    }
    
    func removeInspectionPoints() {
            for point in inspectionPoints {
                point.removeFromParent()
            }
            inspectionPoints.removeAll()
            print("Removed all inspection points.")
        }
    // DEBUG
    @MainActor
    func handleInspectionPointTap(type: InspectionPointType, navigationPath: Binding<[String]>) {
        // Update state and navigate based on type
        appState?.highlightedPoint = type
        appState?.isInspectionDetailsOpen = true
        
        print("Tapped on inspection point: \(type.rawValue)")
    }

//    func handleTapOnInspectionPoint(_ point: ModelEntity) async {
//            // Highlight the tapped point
//            highlightEntity(point)
//
//            // Update the app state to reflect the selected inspection point
//            appState?.highlightedPoint = point
//            await print("Tapped on \(point.name)")
//
//            // Trigger navigation
//            appState?.navigationPath.append("InspectionDetail")
//        }
//
//        private func highlightEntity(_ entity: ModelEntity) {
//            // Add visual feedback for highlighting
//            entity.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: false)]
//        }
        
//        func highlightInspectionPoint(_ point: ModelEntity) {
//            // Reset previous highlight
//            if let highlightedPoint {
//                highlightedPoint.model?.materials = [SimpleMaterial(color: .blue, isMetallic: false)]
//            }
//            
//            // Highlight the new point
//            highlightedPoint = point
//            highlightedPoint?.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: true)]
//            print("Highlighted inspection point: \(point.name ?? "Unnamed")")
//        }
//        
//        func handleTapOnInspectionPoint(_ point: ModelEntity) {
//            print("Tapped on inspection point: \(point.name ?? "Unnamed")")
//            
//            // Open detailed view logic (handled at the app state level)
//            Task {
//                await appState?.openInspectionDetail(for: point.name ?? "Unknown Point")
//            }
//        }
    // DEBUG
//    @MainActor
//    func generateInspectionPoints(for object: PlacedObject) {
//        let objectPosition = object.position
//        let objectBounds = object.extents
//        
//        print("Object name :\(object.name)")
//
//        // Generate points relative to the object's bounds
//        let points = [
//            SIMD3<Float>(objectPosition.x + objectBounds.x / 2, objectPosition.y, objectPosition.z), // Right
////            SIMD3<Float>(9.238, 12.689, 12.099),
////            SIMD3<Float>(9.484, 12.913, 11.382),
//            SIMD3<Float>(objectPosition.x - objectBounds.x / 2, objectPosition.y, objectPosition.z), // Left
//            SIMD3<Float>(objectPosition.x, objectPosition.y + objectBounds.y / 2, objectPosition.z), // Top
//            SIMD3<Float>(objectPosition.x, objectPosition.y - objectBounds.y / 2, objectPosition.z), // Bottom
//            SIMD3<Float>(objectPosition.x, objectPosition.y, objectPosition.z + objectBounds.z / 2), // Front
//            SIMD3<Float>(objectPosition.x, objectPosition.y, objectPosition.z - objectBounds.z / 2)  // Back
//        ]
//
//        for (index, position) in points.enumerated() {
//            let point = ModelEntity(mesh: .generateSphere(radius: 0.02))
//            point.name = "InspectionPoint\(index)"
//            point.position = position
//            point.generateCollisionShapes(recursive: true)
//            point.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
//
//            rootEntity.addChild(point)
//            print("Added inspection point: InspectionPoint\(index) at \(position)")
//        }
//    }

    
    // DEBUG
    @MainActor
    func removeHighlightedObject() async {
        guard let highlightedObject = placementState.highlightedObject else { return }

        await persistenceManager.removeObject(highlightedObject)
        placementState.highlightedObject = nil

        // If the removed object is the placed object, reset the state.
        if placementState.placedObject === highlightedObject {
            placementState.placedObject = nil
            placementState.userPlacedAnObject = false
        }
    }

    // DEBUG
    @MainActor
    func removeAllPlacedObjects() async {
        let inputTime = Date().timeIntervalSince1970

        await persistenceManager.removeAllPlacedObjects()

        // Reset placement state after removing all objects.
        placementState.placedObject = nil
        placementState.userPlacedAnObject = false
        // DEBUG
        appState?.inspectionPoints.removeAll()
        
        let outputTime = Date().timeIntervalSince1970
            let latency = outputTime - inputTime
            print("Latency in remove placed object: \(latency) seconds")
    }

    
//    DEBUG
    @MainActor
    func runARKitSession() async {
        // DEBUG
        if (isSessionRunning)
        {
            print("ARKit session is already running.")
            return
        }
        
        do {
            // Ensure a fresh configuration by stopping any running session first
//            appState?.arkitSession.stop()
//            appState?.arkitSession = ARKitSession()
//            
//            print("appState: %d", appState == nil ? 0 : 1)
            
            // Restart with a new configuration and data providers
            try await appState!.arkitSession.run([worldTracking, planeDetection])
            
            isSessionRunning = true
        } catch {
            print("Failed to run ARKit session: \(error.localizedDescription)")
        }
    }


//    @MainActor
//    func runARKitSession() async {
//        do {
//            
//            // Run a new set of providers every time when entering the immersive space.
//            try await appState!.arkitSession.run([worldTracking, planeDetection])
//        } catch {
//            // No need to handle the error here; the app is already monitoring the
//            // session for error.
//            return
//        }
//        
//        if let firstFileName = appState?.modelDescriptors.first?.fileName, let object = appState?.placeableObjectsByFileName[firstFileName] {
//            select(object)
//        }
//    }

    @MainActor
    func collisionBegan(_ event: CollisionEvents.Began) {
        guard let selectedObject = placementState.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }

        placementState.activeCollisions += 1
    }
    
    @MainActor
    func collisionEnded(_ event: CollisionEvents.Ended) {
        guard let selectedObject = placementState.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }
        guard placementState.activeCollisions > 0 else {
            print("Received a collision ended event without a corresponding collision start event.")
            return
        }

        placementState.activeCollisions -= 1
    }
    
    @MainActor
    func select(_ object: PlaceableObject?) {
        if let oldSelection = placementState.selectedObject {
            // Remove the current preview entity.
            placementLocation.removeChild(oldSelection.previewEntity)

            // Handle deselection. Selecting the same object again in the app deselects it.
            if oldSelection.descriptor.fileName == object?.descriptor.fileName {
                select(nil)
                return
            }
        }
        
        // Update state.
        placementState.selectedObject = object
        appState?.selectedFileName = object?.descriptor.fileName
        
        if let object {
            // Add new preview entity.
            placementLocation.addChild(object.previewEntity)
            for child in placementLocation.children {
                print("Child name: \(child.name)")
            }
        }
    }
    
    @MainActor
    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            persistenceManager.process(anchorUpdate)
        }
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())

        placementState.deviceAnchorPresent = deviceAnchor != nil
        placementState.planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
        placementState.selectedObject?.previewEntity.isEnabled = placementState.shouldShowPreview
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
        await updateUserFacingUIOrientations(deviceAnchor)
        await checkWhichObjectDeviceIsPointingAt(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }
    
    @MainActor
    private func updateUserFacingUIOrientations(_ deviceAnchor: DeviceAnchor) async {
        
        // 1. Orient the front side of the highlighted object’s UI to face the user.
        if let uiOrigin = placementState.highlightedObject?.uiOrigin {
            // Set the UI to face the user (on the y-axis only).
            uiOrigin.look(at: deviceAnchor.originFromAnchorTransform.translation)
            let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
            uiOrigin.setOrientation(uiRotationOnYAxis, relativeTo: nil)
        }
        
        // DEBUG
//        // 2. Orient each UI element to face the user.
//        for entity in [placementTooltip, dragTooltip] {
//            if let entity {
//                entity.look(at: deviceAnchor.originFromAnchorTransform.translation)
//                
////                DEBUG
//                if let uiOrigin = placementState.highlightedObject?.uiOrigin {
//                    // Set the UI to face the user (on the y-axis only).
//                    let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
//                    entity.setOrientation(uiRotationOnYAxis, relativeTo: nil)
//                }
//            }
//        }
        // 2. Orient each UI element to face the user.
        for entity in [placementTooltip, dragTooltip, deleteButton] {
            if let entity {
                entity.look(at: deviceAnchor.originFromAnchorTransform.translation)
            }
        }
    }
    
    @MainActor
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
//        let inputTime = Date().timeIntervalSince1970

        
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned
        
        // Determine a placement location on planes in front of the device by casting a ray.
        
        // Cast the ray from the device origin.
        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
    
        // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
        // (The downward angle is configurable using the `raycastOrigin` orientation.)
        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        
        // Only consider raycast results that are within 0.2 to 3 meters from the device.
        let minDistance: Float = 0.2
        let maxDistance: Float = 3
        
        // Only raycast against horizontal planes.
        let collisionMask = PlaneAnchor.allPlanesCollisionGroup

        var originFromPointOnPlaneTransform: float4x4? = nil
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: collisionMask)
                                                  .first, result.distance > minDistance {
            if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                originFromPointOnPlaneTransform?.translation = result.position + [0.0, PlacementManager.placedObjectsOffsetOnPlanes, 0.0]
            }
        }
        // DEBUG
        
//        if let originFromPointOnPlaneTransform {
//            // If a placement location is determined, set the transform and ensure the prefab is visible.
//            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
//            placementLocation.isEnabled = true  // Make the prefab visible
//            placementState.planeToProjectOnFound = true
//        } else {
//            // If no placement location can be determined, hide the prefab but keep the warning visible.
//            placementLocation.isEnabled = false // Hide the prefab
//            placementState.planeToProjectOnFound = false
//        }
        
//        // Ensure the warning is always visible
//        placementTooltip?.isEnabled = true
        // END DEBUG
        
        
        if let originFromPointOnPlaneTransform {
            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
            placementState.planeToProjectOnFound = true
            
            
            if placementLocation.children.count > 1
            {
                for child in placementLocation.children
                {
                    if child.name != "tooltip"
                    {
                        if placementState.placedObject == nil {
                            child.isEnabled = true
                        }
                        else if placementState.placedObject != nil
                        {
                            child.isEnabled = false
                        }
                    }
                }
               
            }
            
        } else {
            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
            let distanceFromDeviceAnchor: Float = 0.7
            let downwardsOffset: Float = -0.07
            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform

            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
            placementState.planeToProjectOnFound = false
            
            // Hide the second child if it exists
            if placementLocation.children.count > 1 {
                for child in placementLocation.children
                {
                    if child.name != "tooltip"
                    {
                        child.isEnabled = false
                    }
                }
            }
        }
        
//        if let originFromPointOnPlaneTransform {
//            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
//            placementState.planeToProjectOnFound = true
//        } else {
//            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
//            let distanceFromDeviceAnchor: Float = 0.5
//            let downwardsOffset: Float = 0.3
//            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
//            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
//            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform
//            
//            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
//            placementState.planeToProjectOnFound = false
//        }
//        let outputTime = Date().timeIntervalSince1970
//            let latency = outputTime - inputTime
//            print("Latency in update placement: \(latency) seconds")
    }
    
    @MainActor
    private func checkWhichObjectDeviceIsPointingAt(_ deviceAnchor: DeviceAnchor) async {
        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        let collisionMask = PlacedObject.collisionGroup
        
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, query: .nearest, mask: collisionMask).first {
            if let pointedAtObject = persistenceManager.object(for: result.entity) {
                setHighlightedObject(pointedAtObject)
            } else {
                setHighlightedObject(nil)
            }
        } else {
            setHighlightedObject(nil)
        }
    }
    
    @MainActor
    func setHighlightedObject(_ objectToHighlight: PlacedObject?) {
        guard placementState.highlightedObject != objectToHighlight else {
            return
        }
        placementState.highlightedObject = objectToHighlight

        // Detach UI from the previously highlighted object.
        guard let deleteButton, let dragTooltip else { return }
        deleteButton.removeFromParent()
        dragTooltip.removeFromParent()

        guard let objectToHighlight else { return }

        // Position and attach the UI to the newly highlighted object.
        let extents = objectToHighlight.extents
        let topLeftCorner: SIMD3<Float> = [-extents.x / 2, (extents.y / 2) + 0.02, 0]
        let frontBottomCenter: SIMD3<Float> = [0, (-extents.y / 2) + 0.04, extents.z / 2 + 0.04]
        deleteButton.position = topLeftCorner
        dragTooltip.position = frontBottomCenter

        objectToHighlight.uiOrigin.addChild(deleteButton)
        deleteButton.scale = 1 / objectToHighlight.scale
        objectToHighlight.uiOrigin.addChild(dragTooltip)
        dragTooltip.scale = 1 / objectToHighlight.scale
    }

//    func removeAllPlacedObjects() async {
//        await persistenceManager.removeAllPlacedObjects()
//    }
    
    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeDetection.anchorUpdates {
            await planeAnchorHandler.process(anchorUpdate)
        }
    }
    
    // DEBUG
    @MainActor
    func placeSelectedObject() {
        // Ensure there’s a placeable object and no object is already placed.
        guard let objectToPlace = placementState.objectToPlace, placementState.placedObject == nil else {
            print("An object is already placed. Cannot place another.")
            return
        }

        let object = objectToPlace.materialize()

        object.position = placementLocation.position
        object.orientation = placementLocation.orientation

        Task {
            await persistenceManager.attachObjectToWorldAnchor(object)
        }

        placementState.userPlacedAnObject = true
        placementState.placedObject = object // Save the reference to the placed object.
    }

    
//    @MainActor
//    func placeSelectedObject() {
//        // Ensure there’s a placeable object.
//        guard let objectToPlace = placementState.objectToPlace else { return }
//
//        let object = objectToPlace.materialize()
//        
//        // DEBUG
//        // Remove physics components to disable falling or rotating
////        object.components[PhysicsBodyComponent.self] = nil
////        object.components[CollisionComponent.self] = nil
//        
//        object.position = placementLocation.position
//        object.orientation = placementLocation.orientation
//        
//        Task {
//            await persistenceManager.attachObjectToWorldAnchor(object)
//        }
//        placementState.userPlacedAnObject = true
//    }
    
    @MainActor
    func checkIfAnchoredObjectsNeedToBeDetached() async {
        // Check whether objects should be detached from their world anchor.
        // This runs at 10 Hz to ensure that objects are quickly detached from their world anchor
        // as soon as they are moved - otherwise a world anchor update could overwrite the
        // object’s position.
        await run(function: persistenceManager.checkIfAnchoredObjectsNeedToBeDetached, withFrequency: 10)
    }
    
    @MainActor
    func checkIfMovingObjectsCanBeAnchored() async {
        // Check whether objects can be reanchored.
        // This runs at 2 Hz - objects should be reanchored eventually but it’s not time critical.
        await run(function: persistenceManager.checkIfMovingObjectsCanBeAnchored, withFrequency: 2)
    }
    
    @MainActor
    func updateDrag(value: EntityTargetValue<DragGesture.Value>) {
        if let currentDrag, currentDrag.draggedObject !== value.entity {
            // Make sure any previous drag ends before starting a new one.
            print("A new drag started but the previous one never ended - ending that one now.")
            endDrag()
        }
        
        // At the start of the drag gesture, remember which object is being manipulated.
        if currentDrag == nil {
            guard let object = persistenceManager.object(for: value.entity) else {
                print("Unable to start drag - failed to identify the dragged object.")
                return
            }
            
            // DEBUG
            object.components[PhysicsBodyComponent.self] = nil

            object.isBeingDragged = true
            currentDrag = DragState(objectToDrag: object)
            placementState.userDraggedAnObject = true
        }
        
        // Update the dragged object’s position.
        if let currentDrag {
            // DEBUG
            
            // preserve the Y location
            let currentY = currentDrag.initialPosition.y
            let newTranslation = value.convert(value.translation3D, from: .local, to: rootEntity)
            var constrainedPosition = SIMD3<Float>(currentDrag.initialPosition.x + newTranslation.x,
                                                   currentY, // Lock Y-coordinate
                                                   currentDrag.initialPosition.z + newTranslation.z)
            currentDrag.draggedObject.position = constrainedPosition
//            currentDrag.draggedObject.position = currentDrag.initialPosition + value.convert(value.translation3D, from: .local, to: rootEntity)

            // If possible, snap the dragged object to a nearby horizontal plane.
//            let maxDistance = PlacementManager.snapToPlaneDistanceForDraggedObjects
//            if let projectedTransform = PlaneProjector.project(point: currentDrag.draggedObject.transform.matrix,
//                                                               ontoHorizontalPlaneIn: planeAnchorHandler.planeAnchors,
//                                                               withMaxDistance: maxDistance) {
//                currentDrag.draggedObject.position = projectedTransform.translation
//            }
        }
    }
    
    @MainActor
    func updateDrag(value: EntityTargetValue<DragGesture.Value>, mode: AppState.InteractionMode) {
            if currentDrag == nil {
                guard let object = placementState.placedObject else {
                    print("No object to drag.")
                    return
                }
                currentDrag = DragState(objectToDrag: object)
                print("Started dragging \(object)")
            }

            guard let currentDrag else { return }

            // Constrain movement based on the selected mode
            let translation = value.translation
            switch mode {
            case .rotation:
                // Rotate the object around the y-axis
                let rotationSpeed: Float = 0.006 // Adjust for desired constant speed

                    // Use the 3D translation to determine rotation direction and intensity
                    let dragDelta = Float(value.translation3D.x) // Use X-axis translation in 3D space
                    let rotationAngle = rotationSpeed * (dragDelta > 0 ? 1.0 : -1.0) // Determine direction

                    let rotationQuat = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0)) // Rotate around Y-axis

                    // Apply the rotation to the current orientation
                    let newOrientation = currentDrag.draggedObject.orientation * rotationQuat
                    currentDrag.draggedObject.orientation = newOrientation

//                let rotationAngle = Float(translation.width) * 0.01 // Adjust sensitivity
//                currentDrag.draggedObject.transform.rotation *= simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
//                print("Rotating object by \(rotationAngle) radians.")

            case .forwardBack:
                // Move the object along the z-axis (forward/backward)
                
                let translation3D = value.convert(value.translation3D, from: .local, to: rootEntity)
                
                currentDrag.draggedObject.position.z = currentDrag.initialPosition.z + translation3D.z
                
//                let movement = Float(translation.height) * -0.01 // Adjust sensitivity
//                currentDrag.draggedObject.position.z = currentDrag.initialPosition.z + movement
//                print("Moving object forward/backward by \(movement).")

            case .leftRight:
                // Move the object along the x-axis (left/right)
                
                let translation3D = value.convert(value.translation3D, from: .local, to: rootEntity)
                
                currentDrag.draggedObject.position.x = currentDrag.initialPosition.x + translation3D.x
//                let movement = Float(translation.width) * 0.01 // Adjust sensitivity
//                currentDrag.draggedObject.position.x = currentDrag.initialPosition.x + movement
//                print("Moving object left/right by \(movement).")
            }
        }
    
    @MainActor
    func endDrag() {
        guard let currentDrag else { return }
        currentDrag.draggedObject.isBeingDragged = false
        self.currentDrag = nil
    }
    
//    @MainActor
//    func pauseARKitSession() async {
//        appState?.arkitSession.stop()
//    }

}

extension PlacementManager {
    /// Run a given function at an approximate frequency.
    ///
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself.
    @MainActor
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }
}
