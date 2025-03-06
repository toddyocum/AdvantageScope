//
//  XRTypes.swift
//  AdvantageVisionXR
//
//  Created on 3/5/25.
//

import Foundation

/// # XR Communication Types
///
/// This file defines the data structures that match AdvantageScope's 
/// WebSocket message format for XR visualization.
///
/// The messages use MessagePack for efficient binary serialization and
/// come in three main types:
/// - Settings: Configuration for visualization display
/// - Command: Instructions for rendering 3D content
/// - Assets: Available 3D models and their properties

/// Represents message types that can be received from AdvantageScope
enum XRPacketType: String, Codable {
    case settings
    case command
    case assets
}

/// Base protocol for all XR packets
protocol XRPacket: Codable {
    var type: XRPacketType { get }
    var time: TimeInterval { get }
}

/// Settings packet containing visualization configuration
struct XRSettingsPacket: XRPacket, Codable {
    let type: XRPacketType = .settings
    let time: TimeInterval
    let value: XRSettings
}

/// Command packet containing 3D rendering instructions
struct XRCommandPacket: XRPacket, Codable {
    let type: XRPacketType = .command
    let time: TimeInterval
    let value: ThreeDimensionRendererCommand
}

/// Assets packet containing available models and configurations
struct XRAssetsPacket: XRPacket, Codable {
    let type: XRPacketType = .assets
    let time: TimeInterval
    let value: AdvantageScopeAssets
}

/// Settings for XR visualization
struct XRSettings: Codable {
    let calibrationMode: Bool
    let streamingMode: Bool
    let showFloor: Bool
    let showAxes: Bool
    // Add other settings as needed
}

/// 3D visualization command from AdvantageScope
struct ThreeDimensionRendererCommand: Codable {
    let gameType: String?
    let originAlliance: String?
    let objects: [RenderObject]
    // Add other properties as needed
}

/// Represents an object to render in 3D space
struct RenderObject: Codable {
    let type: String  // "robot", "ghost", "gamePiece", etc.
    let pose: Pose?
    let color: [Double]?
    let visible: Bool?
    let metadata: [String: String]?
    // Add other properties based on object type
}

/// 3D pose information
struct Pose: Codable {
    let position: [Double]  // [x, y, z]
    let rotation: [Double]  // [quaternion components]
}

/// Available assets for visualization
struct AdvantageScopeAssets: Codable {
    let fields: [FieldAsset]?
    let robots: [RobotAsset]?
    // Add other asset types as needed
}

/// Field visualization asset
struct FieldAsset: Codable {
    let path: String
    let rotation: [Double]?
    let position: [Double]?
    let scale: Double?
    // Add other properties
}

/// Robot visualization asset
struct RobotAsset: Codable {
    let path: String
    let rotation: [Double]?
    let position: [Double]?
    let scale: Double?
    // Add other properties
}