//
//  AdvantageVisionXRApp.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI
import Combine
import RealityKit

/// # AdvantageVisionXR App
///
/// This is the main entry point for the AdvantageVisionXR application.
/// 
/// ## App Purpose:
/// AdvantageVisionXR is an Apple Vision Pro app that connects to AdvantageScope
/// (a robotics data visualization tool) to display 3D models and data in mixed reality.
/// It serves as a companion app that brings AdvantageScope's visualizations into spatial computing.
///
/// ## How it works:
/// 1. The app connects to AdvantageScope over a WebSocket connection
/// 2. It receives MessagePack-encoded data from AdvantageScope with 3D scene information
/// 3. It processes different message types (settings, commands, assets)
/// 4. It renders these 3D scenes in an immersive environment
/// 5. Users can interact with and manipulate the 3D visualizations

// The @main attribute tells Swift this is the entry point for the application
@main
struct AdvantageVisionXRApp: App {
    // MARK: - State Properties
    
    // @StateObject creates and owns observable objects that persist for the app's lifetime
    @StateObject private var appModel: AppModel
    @StateObject private var appCoordinator: AppCoordinator
    
    // @State properties are value types that trigger UI updates when changed
    @State private var networkingManager: NetworkingManager?
    @State private var modelLoader: ModelLoader
    
    // Combine cancellables collection stores active subscriptions to prevent memory leaks
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize app components
    init() {
        // Create app model and model loader
        let model = AppModel()
        let loader = ModelLoader()
        
        // Initialize state objects
        _appModel = StateObject(wrappedValue: model)
        _modelLoader = State(initialValue: loader)
        
        // Create app coordinator with dependencies
        _appCoordinator = StateObject(wrappedValue: AppCoordinator(
            appModel: model,
            modelLoader: loader
        ))
    }
    
    // MARK: - Notification Names
    
    /// Notification sent when binary model data is received from AdvantageScope (legacy)
    static let modelDataReceivedNotification = Notification.Name("ModelDataReceived")
    
    /// Notification sent when a RealityKit Entity is ready to be displayed (legacy)
    static let modelEntityReadyNotification = Notification.Name("ModelEntityReady")
    
    /// Notification sent when the scene has been updated with new entities
    static let sceneUpdatedNotification = Notification.Name("SceneUpdated")
    
    // MARK: - App Scene Builder
    
    /// SwiftUI Scene declaration using @SceneBuilder
    /// For visionOS apps, scenes define different UI experiences (windows, immersive spaces)
    @SceneBuilder var body: some SwiftUI.Scene {
        // Create the standard 2D window interface
        WindowGroup {
            ContentView()
                // Make models available to all child views through the environment
                .environmentObject(appModel)
                .environmentObject(appCoordinator)
                // Task modifier runs an async task when the view appears
                .task {
                    await setupNetworking()
                }
        }

        // Define the immersive 3D space
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .environmentObject(appCoordinator)
                // These lifecycle events track the immersive space state
                .onAppear {
                    // Update app state when immersive view appears
                    appModel.immersiveSpaceState = .open
                    setupLegacyModelObserver()
                }
                .onDisappear {
                    // Update app state when immersive view disappears
                    appModel.immersiveSpaceState = .closed
                }
        }
        // Set this space to mixed reality mode (combines virtual content with real world)
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    
    // MARK: - Setup and Configuration
    
    /// Initialize networking components
    /// @MainActor ensures this runs on the main thread for UI updates
    @MainActor
    private func setupNetworking() async {
        // Create networking manager if needed
        if networkingManager == nil {
            networkingManager = NetworkingManager(appModel: appModel)
            
            // Setup shared instance for model downloads
            NetworkingManager.setupShared(with: appModel)
        }
    }
    
    /// Set up observers for legacy model data notifications
    /// This provides backward compatibility with the old approach
    private func setupLegacyModelObserver() {
        // Create a Combine publisher from NotificationCenter
        // This listens for the modelDataReceivedNotification
        NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelDataReceivedNotification)
            // Extract and type-cast the Data object from the notification
            .compactMap { $0.object as? Data }
            // For each data packet received, process it
            .sink { modelData in
                processLegacyModelData(modelData)
            }
            // Store the subscription to prevent memory leaks
            .store(in: &cancellables)
    }
    
    // MARK: - Legacy Data Processing Pipeline
    
    /// Process binary model data received from AdvantageScope (legacy approach)
    /// This is part of the old data pipeline: WebSocket → Binary Data → RealityKit Entity
    private func processLegacyModelData(_ data: Data) {
        // The ModelLoader processes binary data and creates a RealityKit entity
        modelLoader.processModelPacket(data)
            // Ensure UI updates happen on the main thread
            .receive(on: DispatchQueue.main)
            // Handle the asynchronous result using Combine
            .sink(
                // Handle completion (including errors)
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading model: \(error)")
                    }
                },
                // Handle successful entity creation
                receiveValue: { entity in
                    // Send the entity to ImmersiveView through NotificationCenter
                    NotificationCenter.default.post(
                        name: AdvantageVisionXRApp.modelEntityReadyNotification,
                        object: entity
                    )
                }
            )
            // Store subscription to prevent memory leaks
            .store(in: &cancellables)
    }
}
