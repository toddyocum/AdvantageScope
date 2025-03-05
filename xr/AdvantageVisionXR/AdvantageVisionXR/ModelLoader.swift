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

class ModelLoader {
    private var cancellables = Set<AnyCancellable>()
    
    // Temporary directory for storing received model files
    private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AdvantageVisionXR", isDirectory: true)
    
    init() {
        // Create temp directory if it doesn't exist
        try? FileManager.default.createDirectory(at: tempDirectory, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
    }
    
    // Load a GLTF model from binary data
    func loadModel(from data: Data) -> AnyPublisher<Entity, Error> {
        return Future<Entity, Error> { promise in
            // Write the binary data to a temporary file
            let tempFile = self.tempDirectory.appendingPathComponent("model_\(UUID().uuidString).glb")
            
            do {
                try data.write(to: tempFile)
                
                // Load the model using RealityKit's built-in GLB support
                ModelEntity.loadModelAsync(contentsOf: tempFile)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            promise(.failure(error))
                            
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    }, receiveValue: { modelEntity in
                        // Process the loaded model
                        promise(.success(modelEntity))
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempFile)
                    })
                    .store(in: &self.cancellables)
                
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Alternative method using ModelIO for more control over the import process
    func loadModelWithModelIO(from data: Data) -> AnyPublisher<Entity, Error> {
        return Future<Entity, Error> { promise in
            // Write the binary data to a temporary file
            let tempFile = self.tempDirectory.appendingPathComponent("model_\(UUID().uuidString).glb")
            
            do {
                try data.write(to: tempFile)
                
                // Set up ModelIO import
                let asset = MDLAsset(url: tempFile, 
                                    vertexDescriptor: nil,
                                    bufferAllocator: MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!))
                
                // Convert to RealityKit entity
                do {
                    let entity = try Entity.load(contentsOf: tempFile)
                    promise(.success(entity))
                } catch {
                    promise(.failure(error))
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFile)
                
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Process a MessagePack-encoded model packet from AdvantageScope
    func processModelPacket(_ data: Data) -> AnyPublisher<Entity, Error> {
        // For initial implementation, we'll assume the data is directly a GLB file
        // Later, we'll need to decode the MessagePack format used by AdvantageScope
        
        return loadModel(from: data)
    }
}