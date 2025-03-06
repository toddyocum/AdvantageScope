//
//  AppCoordinator.swift
//  AdvantageVisionXR
//
//  Created on 3/5/25.
//

import Foundation
import Combine
import RealityKit

/// # App Coordinator
///
/// Coordinates the flow of data between different parts of the app.
/// Handles the processing of different WebSocket message types and
/// manages the 3D scene state.
///
/// This class acts as the central coordinator for:
/// - Processing settings messages from AdvantageScope
/// - Processing command messages that define what to render
/// - Managing available assets (3D models)
/// - Coordinating model loading and scene updates

class AppCoordinator: ObservableObject {
    // MARK: - Properties
    
    /// Reference to the shared app model
    private var appModel: AppModel
    
    /// Reference to the model loader
    private var modelLoader: ModelLoader
    
    /// Collection of active subscriptions to prevent memory leaks
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    /// Current entities to display in the scene
    @Published var currentEntities: [Entity] = []
    
    /// Latest XR settings received from AdvantageScope
    @Published var settings: XRSettings?
    
    /// Available 3D assets from AdvantageScope
    @Published var assets: AdvantageScopeAssets?
    
    // MARK: - Initialization
    
    /// Initialize the coordinator with required dependencies
    /// - Parameters:
    ///   - appModel: The shared app model
    ///   - modelLoader: The model loader for 3D content
    init(appModel: AppModel, modelLoader: ModelLoader) {
        self.appModel = appModel
        self.modelLoader = modelLoader
        setupObservers()
    }
    
    // MARK: - Setup
    
    /// Set up observers for different notification types
    private func setupObservers() {
        // Observe settings updates
        NotificationCenter.default.publisher(for: NetworkingManager.settingsReceivedNotification)
            .compactMap { $0.object as? XRSettings }
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.handleSettingsUpdate(settings)
            }
            .store(in: &cancellables)
        
        // Observe command updates
        NotificationCenter.default.publisher(for: NetworkingManager.commandReceivedNotification)
            .compactMap { $0.object as? ThreeDimensionRendererCommand }
            .receive(on: RunLoop.main)
            .sink { [weak self] command in
                self?.handleCommandUpdate(command)
            }
            .store(in: &cancellables)
        
        // Observe assets updates
        NotificationCenter.default.publisher(for: NetworkingManager.assetsReceivedNotification)
            .compactMap { $0.object as? AdvantageScopeAssets }
            .receive(on: RunLoop.main)
            .sink { [weak self] assets in
                self?.handleAssetsUpdate(assets)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Message Handlers
    
    /// Process a settings update from AdvantageScope
    /// - Parameter settings: The new XR settings
    private func handleSettingsUpdate(_ settings: XRSettings) {
        self.settings = settings
        // Apply settings to the view if needed
        print("Received settings update: calibrationMode=\(settings.calibrationMode), showFloor=\(settings.showFloor)")
    }
    
    /// Process a command update from AdvantageScope
    /// - Parameter command: The new command with rendering instructions
    private func handleCommandUpdate(_ command: ThreeDimensionRendererCommand) {
        print("Received command with \(command.objects.count) objects")
        
        // Process the command to update the 3D scene
        modelLoader.processCommand(command, assets: assets)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error processing command: \(error)")
                    }
                },
                receiveValue: { [weak self] entities in
                    self?.updateEntities(entities)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Process an assets update from AdvantageScope
    /// - Parameter assets: The new available assets
    private func handleAssetsUpdate(_ assets: AdvantageScopeAssets) {
        self.assets = assets
        print("Received assets update: \(assets.robots?.count ?? 0) robots, \(assets.fields?.count ?? 0) fields")
    }
    
    // MARK: - Scene Management
    
    /// Update the scene with new entities
    /// - Parameter entities: The new entities to display
    private func updateEntities(_ entities: [Entity]) {
        // Update the current entities
        self.currentEntities = entities
        
        // Notify ImmersiveView about the new entities
        NotificationCenter.default.post(
            name: AdvantageVisionXRApp.sceneUpdatedNotification,
            object: entities
        )
    }
}