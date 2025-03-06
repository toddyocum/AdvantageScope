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

class MessagePackHelper {
    /// Decode binary MessagePack data into the appropriate packet type
    /// - Parameter data: The raw MessagePack data from the WebSocket
    /// - Returns: The decoded packet as an XRPacket object
    func decodePacket(from data: Data) throws -> XRPacket? {
        do {
            // First, we need to extract the type field
            let typeName = try extractTypeField(from: data)
            guard let type = XRPacketType(rawValue: typeName) else {
                throw MessagePackError.unsupportedType
            }
            
            // Now we know the type, use MessagePack.Decoder to decode to the correct type
            let decoder = MessagePackDecoder()
            
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
            throw MessagePackError.decodingError("MessagePack decode error: \(error.localizedDescription)")
        }
    }
    
    /// Extract the "type" field from the MessagePack data
    /// - Parameter data: The raw MessagePack data
    /// - Returns: The type string
    private func extractTypeField(from data: Data) throws -> String {
        // Use a simple TypeContainer to just extract the type field
        struct TypeContainer: Decodable {
            let type: String
        }
        
        do {
            let decoder = MessagePackDecoder()
            let container = try decoder.decode(TypeContainer.self, from: data)
            return container.type
        } catch {
            // If proper decoding fails, try a more manual approach as fallback
            return try extractTypeManually(from: data)
        }
    }
    
    /// Fallback method to manually extract the type field
    /// - Parameter data: The raw MessagePack data
    /// - Returns: The type string
    private func extractTypeManually(from data: Data) throws -> String {
        // Try to decode as a dictionary and extract the type field
        let decoder = MessagePackDecoder()
        
        // This approach decodes to a dictionary that we can extract the type from
        if let dict = try? decoder.decode([String: AnyCodable].self, from: data),
           let typeValue = dict["type"],
           let typeString = typeValue.value as? String {
            return typeString
        }
        
        throw MessagePackError.missingType
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

/// Helper struct for decoding arbitrary values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
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
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let uint as UInt:
            try container.encode(uint)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Value cannot be encoded"
                )
            )
        }
    }
}