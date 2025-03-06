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
/// - Displays 3D scenes received from AdvantageScope
/// - Manages multiple entities (robots, fields, game pieces, etc.)
/// - Provides UI controls for manipulating the view (scale, position, etc.)
/// - Shows information about the connection and current scene
///
/// ## How models are displayed:
/// Scene entities are received via NotificationCenter from the AppCoordinator,
/// then added to the root entity in the 3D scene.
struct ImmersiveView: View {
    // MARK: - Properties
    
    /// Access to the shared app model
    @EnvironmentObject private var appModel: AppModel
    
    /// Optional access to the app coordinator
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    /// Root entity that contains all scene elements
    @State private var rootEntity: Entity?
    
    /// Collection of current scene entities
    @State private var currentEntities: [Entity] = []
    
    /// Controls whether to show the info panel
    @State private var showModelInfo = false
    
    /// Tracks the current scale of the scene
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
                // This ensures all models are visible from all angles
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
                
                // If the AppCoordinator has updated entities, use those
                if !appCoordinator.currentEntities.isEmpty {
                    updateScene(appCoordinator.currentEntities)
                }
                
                // Legacy approach (backward compatibility)
                // If we have a single model entity that needs to be added
                if let legacyModel = legacyModelEntity, legacyModel.parent == nil {
                    // Remove any existing single model
                    if let existingModel = rootEntity?.children.first(where: { $0.name == "legacyModel" }) {
                        existingModel.removeFromParent()
                    }
                    
                    // Add the new model
                    legacyModel.name = "legacyModel"
                    rootEntity?.addChild(legacyModel)
                }
            }
            // Add gesture support for pinch-to-zoom (scales the entire scene)
            .gesture(
                // MagnifyGesture (pinch) allows the user to scale the scene
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
            
            // Overlay panel showing connection and scene information
            if showModelInfo {
                VStack {
                    Text("Scene Info")
                        .font(.title)
                        .padding()
                    
                    Text("Connection Status: \(appModel.connectionState == .connected ? "Connected" : "Disconnected")")
                        .padding()
                    
                    if appModel.connectionState == .connected {
                        Text("Connected to: \(appModel.serverAddress)")
                            .padding(.horizontal)
                        
                        // Show information about current entities
                        Text("Scene contains \(currentEntities.count) entities")
                            .padding(.top, 4)
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
                
                // Reset button returns the scene to its original position and scale
                Button(action: resetScene) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                
                Spacer()
                
                // Scale controls for adjusting scene size
                Button(action: { scaleScene(factor: 0.5) }) {
                    Label("Scale Down", systemImage: "minus.circle")
                }
                
                Button(action: { scaleScene(factor: 2.0) }) {
                    Label("Scale Up", systemImage: "plus.circle")
                }
            }
        }
        // Set up notification observers when the view appears
        .onAppear {
            // Subscribe to scene update notifications (new approach)
            NotificationCenter.default.publisher(for: AdvantageVisionXRApp.sceneUpdatedNotification)
                .compactMap { $0.object as? [Entity] }
                .receive(on: RunLoop.main)
                .sink { entities in
                    updateScene(entities)
                }
                .store(in: &cancellables)
            
            // Legacy support: Subscribe to notifications about new model entities (old approach)
            NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelEntityReadyNotification)
                .compactMap { $0.object as? Entity }
                .receive(on: RunLoop.main)
                .sink { entity in
                    updateLegacyModel(entity)
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - State Management
    
    // For backward compatibility with the old model handling approach
    @State private var legacyModelEntity: Entity?
    
    // MARK: - Helper Methods
    
    /// Resets the scene to its original position and scale
    private func resetScene() {
        if let rootEntity = rootEntity {
            // Reset the transformation matrix to identity (default position and rotation)
            rootEntity.transform = .identity
            currentScale = 1.0
        }
    }
    
    /// Scales the entire scene by a specific factor
    /// - Parameter factor: The scaling factor to apply (e.g., 0.5 for half size, 2.0 for double)
    private func scaleScene(factor: Float) {
        if let rootEntity = rootEntity {
            // Update the current scale
            currentScale *= factor
            
            // Apply the new scale to the entity
            rootEntity.transform.scale = SIMD3<Float>(currentScale, currentScale, currentScale)
        }
    }
    
    /// Updates the scene with a new set of entities
    /// - Parameter entities: The array of entities to display
    private func updateScene(_ entities: [Entity]) {
        // Store the current entities list
        currentEntities = entities
        
        // Only process if we have a root entity
        guard let rootEntity = rootEntity else { return }
        
        // Remove all existing child entities except for lights and grid
        for child in rootEntity.children {
            // Keep grid and lights
            if child is DirectionalLight || child is PointLight || child.name == "Immersive" {
                continue
            }
            // Remove all other entities
            child.removeFromParent()
        }
        
        // Add all new entities to the scene
        for entity in entities {
            rootEntity.addChild(entity)
        }
    }
    
    /// Legacy support: Updates the scene with a single model entity (old approach)
    /// - Parameter entity: The entity to display
    private func updateLegacyModel(_ entity: Entity) {
        // Store the new model entity
        legacyModelEntity = entity
    }
}

/// Preview for SwiftUI Canvas and Simulator
#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environmentObject(AppModel())
        .environmentObject(AppCoordinator(
            appModel: AppModel(),
            modelLoader: ModelLoader()
        ))
}
