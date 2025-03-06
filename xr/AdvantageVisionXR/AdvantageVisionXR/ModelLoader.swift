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
/// This class is responsible for converting binary 3D model data received
/// from AdvantageScope into RealityKit Entity objects that can be displayed
/// in the immersive space.
///
/// ## What this does:
/// 1. Takes binary data (GLB/GLTF format) from AdvantageScope
/// 2. Saves it temporarily to the filesystem
/// 3. Loads it using RealityKit's model loading capabilities
/// 4. Returns a RealityKit Entity ready for display
///
/// ## How 3D models flow through the app:
/// AdvantageScope → WebSocket → Binary Data → ModelLoader → RealityKit Entity → ImmersiveView
class ModelLoader {
    // MARK: - Private Properties
    
    /// Collection to store active Combine publishers to prevent memory leaks
    private var cancellables = Set<AnyCancellable>()
    
    /// Directory for temporarily storing model files during processing
    /// This avoids keeping large model data in memory
    private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AdvantageVisionXR", isDirectory: true)
    
    // MARK: - Initialization
    
    /// Sets up the model loader and ensures the temporary directory exists
    init() {
        // Create temp directory if it doesn't exist yet
        try? FileManager.default.createDirectory(at: tempDirectory, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
    }
    
    // MARK: - Public Methods
    
    /// Loads a GLTF/GLB model from binary data into a RealityKit Entity
    /// - Parameter data: Binary model data in GLB format
    /// - Returns: A publisher that will deliver the loaded Entity or an error
    func loadModel(from data: Data) -> AnyPublisher<Entity, Error> {
        // Future is a Combine publisher that will eventually produce a single result
        return Future<Entity, Error> { promise in
            // Create a unique filename for this model
            let tempFile = self.tempDirectory.appendingPathComponent("model_\(UUID().uuidString).glb")
            
            do {
                // Write the binary data to the temp file
                try data.write(to: tempFile)
                
                // Load the model asynchronously using RealityKit's built-in GLB support
                // This returns a Combine publisher
                ModelEntity.loadModelAsync(contentsOf: tempFile)
                    .sink(
                        // Handle completion (success or failure)
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                // Normal completion - nothing to do here
                                break
                            case .failure(let error):
                                // Loading failed - pass the error back
                                promise(.failure(error))
                                
                                // Clean up the temp file
                                try? FileManager.default.removeItem(at: tempFile)
                            }
                        },
                        // Handle successful model loading
                        receiveValue: { modelEntity in
                            // Pass the loaded model entity back
                            promise(.success(modelEntity))
                            
                            // Clean up the temp file
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    )
                    // Store the subscription to prevent memory leaks
                    .store(in: &self.cancellables)
                
            } catch {
                // Handle file system errors
                promise(.failure(error))
            }
        }
        // Convert the specific publisher type to a type-erased AnyPublisher
        .eraseToAnyPublisher()
    }
    
    /// Alternative loading method using ModelIO for more fine-grained control
    /// - Parameter data: Binary model data
    /// - Returns: A publisher that will deliver the loaded Entity or an error
    func loadModelWithModelIO(from data: Data) -> AnyPublisher<Entity, Error> {
        return Future<Entity, Error> { promise in
            // Create a unique filename for this model
            let tempFile = self.tempDirectory.appendingPathComponent("model_\(UUID().uuidString).glb")
            
            do {
                // Write the binary data to the temp file
                try data.write(to: tempFile)
                
                // Set up ModelIO import with Metal device
                // ModelIO provides lower-level control over 3D model loading
                let asset = MDLAsset(
                    url: tempFile,                                        // Source file URL
                    vertexDescriptor: nil,                                // Use default vertex layout
                    bufferAllocator: MTKMeshBufferAllocator(              // Use Metal for buffers
                        device: MTLCreateSystemDefaultDevice()!           // Get default Metal device
                    )
                )
                
                // Convert ModelIO asset to RealityKit entity
                do {
                    let entity = try Entity.load(contentsOf: tempFile)
                    promise(.success(entity))
                } catch {
                    promise(.failure(error))
                }
                
                // Clean up the temp file
                try? FileManager.default.removeItem(at: tempFile)
                
            } catch {
                // Handle file system errors
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Process model data received from AdvantageScope
    /// - Parameter data: Binary data packet from AdvantageScope
    /// - Returns: A publisher that will deliver the processed Entity or an error
    func processModelPacket(_ data: Data) -> AnyPublisher<Entity, Error> {
        // FUTURE ENHANCEMENT: This method will need to be updated when AdvantageScope
        // implements the full MessagePack format for model data. Currently, it assumes
        // the data is a direct GLB file.
        
        // For now, just pass the data directly to the model loader
        return loadModel(from: data)
    }
}