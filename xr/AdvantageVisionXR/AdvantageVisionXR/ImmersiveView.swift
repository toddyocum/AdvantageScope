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

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity?
    @State private var rootEntity: Entity?
    @State private var showModelInfo = false
    @State private var currentScale: Float = 1.0
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            // Main RealityView for 3D content
            RealityView { content in
                // Create a root entity to hold all content
                rootEntity = Entity()
                
                // Add an anchor for positioning and scale
                let anchor = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.5, 0.5]))
                anchor.addChild(rootEntity!)
                
                // Add basic grid for reference
                if let gridEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    rootEntity?.addChild(gridEntity)
                }
                
                // Add lighting
                let directionalLight = DirectionalLight()
                directionalLight.light.color = .white
                directionalLight.light.intensity = 1000
                // For visionOS, shadow is automatically enabled for DirectionalLight
                directionalLight.look(at: [0, 0, 0], from: [5, 5, 5], relativeTo: nil)
                
                // Add ambient lighting using PointLight as an alternative
                let ambientLight = PointLight()
                ambientLight.light.color = .white
                ambientLight.light.intensity = 500
                ambientLight.light.attenuationRadius = 20
                
                rootEntity?.addChild(directionalLight)
                rootEntity?.addChild(ambientLight)
                
                // Add the root entity to the content
                content.add(anchor)
            } update: { content in
                // This is where we'll update the model when new data arrives
                if let modelData = modelEntity, modelEntity?.parent == nil {
                    rootEntity?.addChild(modelData)
                }
            }
            .gesture(
                // Scale gesture for the 3D model
                MagnifyGesture()
                    .onChanged { value in
                        let scale = Float(value.magnification)
                        if let rootEntity = rootEntity {
                            rootEntity.transform.scale = SIMD3<Float>(currentScale * scale, 
                                                                     currentScale * scale, 
                                                                     currentScale * scale)
                        }
                    }
                    .onEnded { value in
                        currentScale *= Float(value.magnification)
                    }
            )
            
            // Info overlay for model details - toggled by voice or gesture
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
                .frame(width: 400, height: 300)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
        // Toolbar with buttons
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: {
                    showModelInfo.toggle()
                }) {
                    Label("Info", systemImage: "info.circle")
                }
                
                Button(action: resetModelPosition) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                
                Spacer()
                
                // Scale controls
                Button(action: { scaleModel(factor: 0.5) }) {
                    Label("Scale Down", systemImage: "minus.circle")
                }
                
                Button(action: { scaleModel(factor: 2.0) }) {
                    Label("Scale Up", systemImage: "plus.circle")
                }
            }
        }
        .onAppear {
            // Subscribe to model entity notifications
            NotificationCenter.default.publisher(for: AdvantageVisionXRApp.modelEntityReadyNotification)
                .compactMap { $0.object as? Entity }
                .receive(on: RunLoop.main)
                .sink { entity in
                    updateModel(entity)
                }
                .store(in: &cancellables)
        }
    }
    
    // Reset model position and scale
    private func resetModelPosition() {
        if let rootEntity = rootEntity {
            rootEntity.transform = .identity
            currentScale = 1.0
        }
    }
    
    // Scale the model by a factor
    private func scaleModel(factor: Float) {
        if let rootEntity = rootEntity {
            currentScale *= factor
            rootEntity.transform.scale = SIMD3<Float>(currentScale, currentScale, currentScale)
        }
    }
    
    // This will be called from outside to update the model
    func updateModel(_ entity: Entity) {
        modelEntity = entity
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environmentObject(AppModel())
}
