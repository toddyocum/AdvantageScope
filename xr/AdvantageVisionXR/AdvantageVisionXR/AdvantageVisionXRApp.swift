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
/// 2. It receives 3D model data (GLTF/GLB format) from AdvantageScope
/// 3. It renders these models in an immersive 3D environment
/// 4. Users can interact with and manipulate the 3D views

// The @main attribute tells Swift this is the entry point for the application
@main
struct AdvantageVisionXRApp: App {
    // MARK: - State Properties
    
    // @StateObject creates and owns an observable object that persists for the app's lifetime
    @StateObject private var appModel = AppModel()
    
    // @State properties are value types that trigger UI updates when changed
    @State private var networkingManager: NetworkingManager?
    @State private var modelLoader = ModelLoader()
    
    // Combine cancellables collection stores active subscriptions to prevent memory leaks
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Notification Names
    
    /// Notification sent when binary model data is received from AdvantageScope
    static let modelDataReceivedNotification = Notification.Name("ModelDataReceived")
    
    /// Notification sent when a RealityKit Entity is ready to be displayed
    static let modelEntityReadyNotification = Notification.Name("ModelEntityReady")
    
    // MARK: - App Scene Builder
    
    /// SwiftUI Scene declaration using @SceneBuilder
    /// For visionOS apps, scenes define different UI experiences (windows, immersive spaces)
    @SceneBuilder var body: some SwiftUI.Scene {
        // Create the standard 2D window interface
        WindowGroup {
            ContentView()
                // Make appModel available to all child views through the environment
                .environmentObject(appModel)
                // Task modifier runs an async task when the view appears
                .task {
                    await setupNetworking()
                }
        }

        // Define the immersive 3D space
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                // These lifecycle events track the immersive space state
                .onAppear {
                    // Update app state when immersive view appears
                    appModel.immersiveSpaceState = .open
                    setupModelObserver()
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
        }
    }
    
    /// Set up observers for model data notifications
    private func setupModelObserver() {
        // Create a Combine publisher from NotificationCenter
        // This listens for the modelDataReceivedNotification
        NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelDataReceivedNotification)
            // Extract and type-cast the Data object from the notification
            .compactMap { $0.object as? Data }
            // For each data packet received, process it
            .sink { modelData in
                processModelData(modelData)
            }
            // Store the subscription to prevent memory leaks
            .store(in: &cancellables)
    }
    
    // MARK: - Data Processing Pipeline
    
    /// Process binary model data received from AdvantageScope
    /// This is part of the data pipeline: WebSocket → Binary Data → RealityKit Entity
    private func processModelData(_ data: Data) {
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
