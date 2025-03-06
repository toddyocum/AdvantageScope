//
//  ModelLoader.swift
//  AdvantageVisionXR
//
//  Created on 3/4/25.
//

import Foundation
import RealityKit
import Combine
import ModelIO
import MetalKit

/// # ModelLoader
///
/// This class is responsible for converting 3D model data received
/// from AdvantageScope into RealityKit Entity objects that can be displayed
/// in the immersive space.
///
/// ## What this does:
/// 1. Processes commands from AdvantageScope to create 3D scenes
/// 2. Downloads and caches 3D models (GLB/GLTF format)
/// 3. Applies position, rotation, and other transforms
/// 4. Returns RealityKit Entities ready for display
///
/// ## How 3D models flow through the app:
/// AdvantageScope → WebSocket (MessagePack) → Commands & Assets → ModelLoader → RealityKit Entities → ImmersiveView
class ModelLoader {
    // MARK: - Private Properties
    
    /// Collection to store active Combine publishers to prevent memory leaks
    private var cancellables = Set<AnyCancellable>()
    
    /// Directory for temporarily storing model files during processing
    /// This avoids keeping large model data in memory
    private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AdvantageVisionXR", isDirectory: true)
    
    /// Cache for downloaded models to avoid repeatedly downloading the same models
    private var modelCache = [String: Entity]()
    
    // MARK: - Initialization
    
    /// Sets up the model loader and ensures the temporary directory exists
    init() {
        // Create temp directory if it doesn't exist yet
        try? FileManager.default.createDirectory(at: tempDirectory, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
    }
    
    // MARK: - Public Methods
    
    /// Process a ThreeDimensionRendererCommand to create scene entities
    /// - Parameters:
    ///   - command: The command containing rendering instructions
    ///   - assets: Available 3D assets information
    /// - Returns: A publisher that will deliver an array of entities or an error
    func processCommand(_ command: ThreeDimensionRendererCommand, 
                      assets: AdvantageScopeAssets?) -> AnyPublisher<[Entity], Error> {
        // Create a Future that will eventually deliver the scene entities
        return Future<[Entity], Error> { promise in
            Task {
                do {
                    // Array to hold all entities for this scene
                    var entities = [Entity]()
                    
                    // Process each object in the command
                    for object in command.objects {
                        // Skip objects marked as not visible
                        if let visible = object.visible, !visible {
                            continue
                        }
                        
                        // Process based on object type
                        switch object.type {
                        case "robot":
                            if let entity = try await self.createRobotEntity(object, assets: assets) {
                                entities.append(entity)
                            }
                            
                        case "gamePiece":
                            if let entity = try await self.createGamePieceEntity(object, assets: assets) {
                                entities.append(entity)
                            }
                            
                        case "field":
                            if let entity = try await self.createFieldEntity(object, assets: assets) {
                                entities.append(entity)
                            }
                            
                        // Add cases for other object types as needed
                        default:
                            print("Unhandled object type: \(object.type)")
                            // For unknown types, create a simple placeholder
                            if let entity = self.createPlaceholderEntity(for: object) {
                                entities.append(entity)
                            }
                        }
                    }
                    
                    // Return the array of entities
                    promise(.success(entities))
                    
                } catch {
                    // Handle errors
                    print("Error processing command: \(error)")
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Process legacy model data (old behavior, will be deprecated)
    /// - Parameter data: Binary model data packet
    /// - Returns: A publisher that will deliver the processed Entity or an error
    func processModelPacket(_ data: Data) -> AnyPublisher<Entity, Error> {
        // Legacy method for backward compatibility
        // This will be replaced by the new command/asset based approach
        return loadModel(from: data)
    }
    
    // MARK: - Entity Creation Methods
    
    /// Creates a robot entity from a render object
    /// - Parameters:
    ///   - object: The render object containing position and metadata
    ///   - assets: Available 3D assets
    /// - Returns: A configured robot entity or nil if creation failed
    private func createRobotEntity(_ object: RenderObject, 
                                  assets: AdvantageScopeAssets?) async throws -> Entity? {
        // We need a pose and assets to create a robot
        guard let pose = object.pose else {
            return createPlaceholderEntity(for: object)
        }
        
        // Find the robot model to use
        let robotPath = findRobotModelPath(for: object, in: assets)
        
        // Download and create the model entity
        let entity = try await getOrDownloadModel(path: robotPath)
        
        // Apply position from the pose
        if pose.position.count >= 3 {
            entity.position = SIMD3<Float>(
                Float(pose.position[0]),
                Float(pose.position[1]),
                Float(pose.position[2])
            )
        }
        
        // Apply rotation from the pose (if it's a quaternion)
        if pose.rotation.count >= 4 {
            entity.orientation = simd_quatf(
                real: Float(pose.rotation[0]),
                imag: SIMD3<Float>(
                    Float(pose.rotation[1]),
                    Float(pose.rotation[2]),
                    Float(pose.rotation[3])
                )
            )
        }
        
        // Apply color if available
        if let color = object.color, color.count >= 3 {
            applyColor(to: entity, color: color)
        }
        
        return entity
    }
    
    /// Creates a game piece entity from a render object
    /// - Parameters:
    ///   - object: The render object containing position and metadata
    ///   - assets: Available 3D assets
    /// - Returns: A configured game piece entity or nil if creation failed
    private func createGamePieceEntity(_ object: RenderObject,
                                      assets: AdvantageScopeAssets?) async throws -> Entity? {
        // Similar to createRobotEntity but for game pieces
        guard let pose = object.pose else {
            return createPlaceholderEntity(for: object)
        }
        
        // For simplicity, use a primitive shape for game pieces
        // A proper implementation would find the game piece model in assets
        let entity = ModelEntity(mesh: .generateSphere(radius: 0.1))
        
        // Apply position from the pose
        if pose.position.count >= 3 {
            entity.position = SIMD3<Float>(
                Float(pose.position[0]),
                Float(pose.position[1]),
                Float(pose.position[2])
            )
        }
        
        // Apply color if available
        if let color = object.color, color.count >= 3 {
            applyColor(to: entity, color: color)
        } else {
            // Default game piece color (yellow)
            let material = SimpleMaterial(color: .yellow, roughness: 0.5, isMetallic: false)
            entity.model?.materials = [material]
        }
        
        return entity
    }
    
    /// Creates a field entity from a render object
    /// - Parameters:
    ///   - object: The render object containing position and metadata
    ///   - assets: Available 3D assets
    /// - Returns: A configured field entity or nil if creation failed
    private func createFieldEntity(_ object: RenderObject,
                                 assets: AdvantageScopeAssets?) async throws -> Entity? {
        // Find the field model to use
        guard let fieldAssets = assets?.fields, !fieldAssets.isEmpty else {
            return createPlaceholderField()
        }
        
        // Use the first field asset
        let fieldPath = fieldAssets[0].path
        
        // Download and create the model entity
        let entity = try await getOrDownloadModel(path: fieldPath)
        
        // Apply transforms from the asset definition
        if let position = fieldAssets[0].position, position.count >= 3 {
            entity.position = SIMD3<Float>(
                Float(position[0]),
                Float(position[1]),
                Float(position[2])
            )
        }
        
        if let rotation = fieldAssets[0].rotation, rotation.count >= 4 {
            entity.orientation = simd_quatf(
                real: Float(rotation[0]),
                imag: SIMD3<Float>(
                    Float(rotation[1]),
                    Float(rotation[2]),
                    Float(rotation[3])
                )
            )
        }
        
        if let scale = fieldAssets[0].scale {
            let scaleValue = Float(scale)
            entity.scale = SIMD3<Float>(scaleValue, scaleValue, scaleValue)
        }
        
        return entity
    }
    
    /// Creates a simple placeholder entity for unknown object types
    /// - Parameter object: The render object to represent
    /// - Returns: A simple entity representing the object
    private func createPlaceholderEntity(for object: RenderObject) -> Entity? {
        // Create a simple box for objects without a specific model
        let entity = ModelEntity(mesh: .generateBox(size: 0.2), materials: [SimpleMaterial(color: .gray, roughness: 0.5, isMetallic: false)])
        
        // Apply position if available
        if let pose = object.pose, pose.position.count >= 3 {
            entity.position = SIMD3<Float>(
                Float(pose.position[0]),
                Float(pose.position[1]),
                Float(pose.position[2])
            )
        }
        
        // Apply color if available
        if let color = object.color, color.count >= 3 {
            applyColor(to: entity, color: color)
        }
        
        return entity
    }
    
    /// Creates a placeholder field when no field asset is available
    /// - Returns: A simple plane representing a field
    private func createPlaceholderField() -> Entity {
        // Create a simple plane to represent the field
        let entity = ModelEntity(
            mesh: .generatePlane(width: 8, depth: 4),
            materials: [SimpleMaterial(color: .gray, roughness: 0.8, isMetallic: false)]
        )
        
        // Position at origin on the ground
        entity.position = SIMD3<Float>(0, -0.01, 0)  // Slightly below origin to avoid z-fighting
        
        return entity
    }
    
    // MARK: - Helper Methods
    
    /// Finds the appropriate robot model path for an object
    /// - Parameters:
    ///   - object: The render object to find a model for
    ///   - assets: Available 3D assets
    /// - Returns: Path to the robot model
    private func findRobotModelPath(for object: RenderObject, in assets: AdvantageScopeAssets?) -> String {
        // If there are available robot models, use the first one
        if let robotAssets = assets?.robots, !robotAssets.isEmpty {
            return robotAssets[0].path
        }
        
        // Default robot model path as fallback
        return "defaultRobot.glb"
    }
    
    /// Gets a model from cache or downloads it
    /// - Parameter path: Path to the model
    /// - Returns: The entity for the model
    private func getOrDownloadModel(path: String) async throws -> Entity {
        // Check cache first
        if let cachedEntity = modelCache[path] {
            return cachedEntity.clone(recursive: true)
        }
        
        // Try to download the model
        do {
            let modelData = try await NetworkingManager.shared.downloadModel(path: path)
            let entity = try await loadModel(from: modelData).async()
            
            // Cache the entity
            modelCache[path] = entity
            
            return entity.clone(recursive: true)
        } catch {
            print("Error downloading model \(path): \(error)")
            
            // If download fails, return a placeholder
            let placeholder = ModelEntity(mesh: .generateBox(size: 0.2), materials: [SimpleMaterial(color: .purple, roughness: 0.5, isMetallic: false)])
            return placeholder
        }
    }
    
    /// Applies a color to an entity
    /// - Parameters:
    ///   - entity: The entity to color
    ///   - color: Array of color components [r, g, b] or [r, g, b, a]
    private func applyColor(to entity: Entity, color: [Double]) {
        guard let modelEntity = entity as? ModelEntity else { return }
        
        // Create color from components
        let red = Float(color[0])
        let green = Float(color[1])
        let blue = Float(color[2])
        let alpha = color.count > 3 ? Float(color[3]) : 1.0
        
        // Create material with the color
        let material = SimpleMaterial(
            color: .init(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)),
            roughness: 0.5,
            isMetallic: false
        )
        
        // Apply to model
        modelEntity.model?.materials = [material]
    }
    
    // MARK: - Model Loading Methods
    
    /// Loads a GLTF/GLB model from binary data into a RealityKit Entity
    /// - Parameter data: Binary model data in GLB format
    /// - Returns: A publisher that will deliver the loaded Entity or an error
    func loadModel(from data: Data) -> AnyPublisher<Entity, Error> {
        return Future<Entity, Error> { promise in
            // Create a unique filename for this model
            let tempFile = self.tempDirectory.appendingPathComponent("model_\(UUID().uuidString).glb")
            
            do {
                // Write the binary data to the temp file
                try data.write(to: tempFile)
                
                // Load the model asynchronously using RealityKit's built-in GLB support
                ModelEntity.loadModelAsync(contentsOf: tempFile)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                promise(.failure(error))
                                try? FileManager.default.removeItem(at: tempFile)
                            }
                        },
                        receiveValue: { modelEntity in
                            promise(.success(modelEntity))
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    )
                    .store(in: &self.cancellables)
                
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    /// Convert a publisher to an async/await pattern
    /// - Returns: The value from the publisher
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            )
        }
    }
}
