//
//  ImmersiveView.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

/// # Immersive View
///
/// This is the main 3D view that creates an immersive mixed reality experience
/// for AdvantageVisionXR. It receives and displays 3D models from AdvantageScope.
///
/// ## What this view does:
/// - Creates and manages the 3D environment with lighting and ground reference
/// - Displays 3D models received from AdvantageScope
/// - Provides UI controls for manipulating the view (scale, position, etc.)
/// - Shows information about the connection and model
///
/// ## How models are displayed:
/// Models are received as RealityKit Entity objects via NotificationCenter,
/// then added to the root entity in the 3D scene.
struct ImmersiveView: View {
    // MARK: - Properties
    
    /// Access to the shared app model 
    @EnvironmentObject private var appModel: AppModel
    
    /// The currently loaded model entity
    @State private var modelEntity: Entity?
    
    /// Root entity that contains all scene elements
    @State private var rootEntity: Entity?
    
    /// Controls whether to show the model info panel
    @State private var showModelInfo = false
    
    /// Tracks the current scale of the model
    @State private var currentScale: Float = 1.0
    
    /// Collection to store active Combine subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Body
    
    /// The main view builder
    var body: some View {
        ZStack {
            // RealityView is the main container for 3D content in visionOS
            // It has two phases - initial setup and updates
            RealityView { content in
                // INITIAL PHASE: Set up the 3D scene
                
                // Create a root entity to hold all 3D content
                rootEntity = Entity()
                
                // Add an anchor to position content relative to the real world
                // This anchors content to a horizontal surface like a floor or table
                let anchor = AnchorEntity(.plane(
                    .horizontal,                // Look for horizontal planes
                    classification: .floor,     // Prefer surfaces classified as floors
                    minimumBounds: [0.5, 0.5]   // Minimum size requirement (0.5m x 0.5m)
                ))
                anchor.addChild(rootEntity!)
                
                // Add a reference grid from RealityKit content bundle
                if let gridEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    rootEntity?.addChild(gridEntity)
                }
                
                // Set up directional light (like sunlight)
                let directionalLight = DirectionalLight()
                directionalLight.light.color = .white
                directionalLight.light.intensity = 1000
                // Point the light at the scene center from above and to the side
                directionalLight.look(at: [0, 0, 0], from: [5, 5, 5], relativeTo: nil)
                
                // Add ambient lighting using PointLight
                // This ensures the model is visible from all angles
                let ambientLight = PointLight()
                ambientLight.light.color = .white
                ambientLight.light.intensity = 500
                ambientLight.light.attenuationRadius = 20  // Light reaches 20 meters
                
                // Add the lights to the scene
                rootEntity?.addChild(directionalLight)
                rootEntity?.addChild(ambientLight)
                
                // Add the anchor (which contains everything) to the RealityView content
                content.add(anchor)
                
            } update: { content in
                // UPDATE PHASE: This runs whenever the view needs to update
                
                // If we have a model entity that hasn't been added to the scene yet, add it
                if let modelData = modelEntity, modelEntity?.parent == nil {
                    rootEntity?.addChild(modelData)
                }
            }
            // Add gesture support for pinch-to-zoom
            .gesture(
                // MagnifyGesture (pinch) allows the user to scale the model
                MagnifyGesture()
                    // During the gesture, update scale in real time
                    .onChanged { value in
                        let scale = Float(value.magnification)
                        if let rootEntity = rootEntity {
                            // Apply the scale to all three dimensions
                            rootEntity.transform.scale = SIMD3<Float>(
                                currentScale * scale,
                                currentScale * scale, 
                                currentScale * scale
                            )
                        }
                    }
                    // When the gesture ends, update the stored scale value
                    .onEnded { value in
                        currentScale *= Float(value.magnification)
                    }
            )
            
            // Overlay panel showing connection and model information
            if showModelInfo {
                VStack {
                    Text("Model Info")
                        .font(.title)
                        .padding()
                    
                    Text("Connection Status: \(appModel.connectionState == .connected ? "Connected" : "Disconnected")")
                        .padding()
                    
                    if appModel.connectionState == .connected {
                        Text("Connected to: \(appModel.serverAddress)")
                            .padding()
                    }
                    
                    Button(action: {
                        showModelInfo = false
                    }) {
                        Text("Hide Info")
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
                // Panel styling
                .frame(width: 400, height: 300)
                .background(.ultraThinMaterial)   // Semi-transparent background
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
        // Add a toolbar with controls
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Info button toggles the information panel
                Button(action: {
                    showModelInfo.toggle()
                }) {
                    Label("Info", systemImage: "info.circle")
                }
                
                // Reset button returns the model to its original position and scale
                Button(action: resetModelPosition) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                
                Spacer()
                
                // Scale controls for adjusting model size
                Button(action: { scaleModel(factor: 0.5) }) {
                    Label("Scale Down", systemImage: "minus.circle")
                }
                
                Button(action: { scaleModel(factor: 2.0) }) {
                    Label("Scale Up", systemImage: "plus.circle")
                }
            }
        }
        // Set up notification observer when the view appears
        .onAppear {
            // Subscribe to notifications about new model entities
            NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelEntityReadyNotification)
                // Extract and convert the notification payload to an Entity
                .compactMap { $0.object as? Entity }
                // Ensure UI updates happen on the main thread
                .receive(on: RunLoop.main)
                // Process each entity as it arrives
                .sink { entity in
                    updateModel(entity)
                }
                // Store the subscription to prevent memory leaks
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resets the model to its original position and scale
    private func resetModelPosition() {
        if let rootEntity = rootEntity {
            // Reset the transformation matrix to identity (default position and rotation)
            rootEntity.transform = .identity
            currentScale = 1.0
        }
    }
    
    /// Scales the model by a specific factor
    /// - Parameter factor: The scaling factor to apply (e.g., 0.5 for half size, 2.0 for double)
    private func scaleModel(factor: Float) {
        if let rootEntity = rootEntity {
            // Update the current scale
            currentScale *= factor
            
            // Apply the new scale to the entity
            rootEntity.transform.scale = SIMD3<Float>(currentScale, currentScale, currentScale)
        }
    }
    
    /// Updates the displayed model with a new entity
    /// - Parameter entity: The RealityKit Entity to display
    func updateModel(_ entity: Entity) {
        // Store the new model entity - the update block in RealityView will add it to the scene
        modelEntity = entity
    }
}

/// Preview for SwiftUI Canvas and Simulator
#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environmentObject(AppModel())
}
