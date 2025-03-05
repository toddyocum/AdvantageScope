//
//  AdvantageVisionXRApp.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI
import Combine
import RealityKit

@main
struct AdvantageVisionXRApp: App {
    // No typealias needed when using @SceneBuilder
    
    @StateObject private var appModel = AppModel()
    @State private var networkingManager: NetworkingManager?
    @State private var modelLoader = ModelLoader()
    
    // To keep track of subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    
    // Notification names
    static let modelDataReceivedNotification = Notification.Name("ModelDataReceived")
    static let modelEntityReadyNotification = Notification.Name("ModelEntityReady")
    
    @SceneBuilder var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    await setupNetworking()
                }
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    setupModelObserver()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    
    // Set up networking and model loading pipeline
    @MainActor
    private func setupNetworking() async {
        // Create networking manager if needed
        if networkingManager == nil {
            networkingManager = NetworkingManager(appModel: appModel)
        }
    }
    
    // Setup the observer for model data
    private func setupModelObserver() {
        // Observe when model data is received
        NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelDataReceivedNotification)
            .compactMap { $0.object as? Data }
            .sink { modelData in
                processModelData(modelData)
            }
            .store(in: &cancellables)
    }
    
    // Process model data received from AdvantageScope
    private func processModelData(_ data: Data) {
        // Use the model loader to convert the binary data to a RealityKit entity
        modelLoader.processModelPacket(data)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading model: \(error)")
                    }
                },
                receiveValue: { entity in
                    // Post notification with the entity for ImmersiveView to pick up
                    NotificationCenter.default.post(
                        name: AdvantageVisionXRApp.modelEntityReadyNotification,
                        object: entity
                    )
                }
            )
            .store(in: &cancellables)
    }
}
