//
//  MessagePackDecoder.swift
//  AdvantageVisionXR
//
//  Created on 3/5/25.
//

import Foundation
import MessagePack

/// # MessagePack Decoder
///
/// Handles decoding of MessagePack-encoded data from AdvantageScope.
/// This class uses the MessagePack library to convert binary data into
/// Swift types matching the AdvantageScope protocol.
///
/// The decoder examines the message type field to determine which
/// packet type to decode into, then uses MessagePack to perform the actual decoding.

enum MessagePackError: Error {
    case invalidFormat
    case missingType
    case unsupportedType
    case decodingError(String)
}

class MessagePackDecoder {
    // Create a reusable decoder instance
    private let decoder = MessagePackDecoder()
    
    /// Decode binary MessagePack data into the appropriate packet type
    /// - Parameter data: The raw MessagePack data from the WebSocket
    /// - Returns: The decoded packet as an XRPacket object
    func decodePacket(from data: Data) throws -> XRPacket? {
        do {
            // First extract the type field to determine which packet type to use
            // We need to read the message as a dictionary to check the "type" field
            let messageObject = try MessagePackReader.readObject(from: data)
            
            // Extract the type field
            guard let messageDict = messageObject as? [String: Any],
                  let typeString = messageDict["type"] as? String,
                  let type = XRPacketType(rawValue: typeString) else {
                throw MessagePackError.missingType
            }
            
            // Create a decoder configured for MessagePack
            let decoder = MessagePackDecoder()
            
            // Decode the data to the appropriate packet type based on the "type" field
            switch type {
            case .settings:
                return try decoder.decode(XRSettingsPacket.self, from: data)
            case .command:
                return try decoder.decode(XRCommandPacket.self, from: data)
            case .assets:
                return try decoder.decode(XRAssetsPacket.self, from: data)
            }
        } catch let error as MessagePackError {
            // Pass through our custom errors
            throw error
        } catch {
            // Wrap other MessagePack errors in our custom error type
            throw MessagePackError.decodingError(error.localizedDescription)
        }
    }
    
    /// Legacy fallback for testing if MessagePack decoding fails
    /// This attempts to decode the data as JSON instead
    func attemptJSONFallback(from data: Data) throws -> XRPacket? {
        // For testing, create a JSON decoder
        let jsonDecoder = JSONDecoder()
        
        // Try to decode as JSON as a fallback
        do {
            // First, we need to convert the Data to a dictionary to check the type
            guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let typeString = dict["type"] as? String,
                  let type = XRPacketType(rawValue: typeString) else {
                throw MessagePackError.missingType
            }
            
            // Decode based on the message type
            switch type {
            case .settings:
                return try jsonDecoder.decode(XRSettingsPacket.self, from: data)
            case .command:
                return try jsonDecoder.decode(XRCommandPacket.self, from: data)
            case .assets:
                return try jsonDecoder.decode(XRAssetsPacket.self, from: data)
            }
        } catch {
            throw MessagePackError.decodingError("JSON fallback failed: \(error.localizedDescription)")
        }
    }
}

/// MessagePack reading utilities
class MessagePackReader {
    /// Read a MessagePack object from binary data
    /// - Parameter data: The MessagePack binary data
    /// - Returns: A Swift object representing the unpacked MessagePack data
    static func readObject(from data: Data) throws -> Any {
        let decoder = MessagePackDecoder()
        return try decoder.decode(AnyDecodable.self, from: data).value
    }
}

/// Helper for decoding MessagePack to Any type
struct AnyDecodable: Decodable {
    var value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let uint = try? container.decode(UInt.self) {
            self.value = uint
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "MessagePack value cannot be decoded"
            )
        }
    }
}