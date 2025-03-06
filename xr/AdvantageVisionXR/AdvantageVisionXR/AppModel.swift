//
//  AppModel.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI

/// # Saved Connection Model
///
/// Represents a stored connection profile for connecting to AdvantageScope.
/// This is a simple data structure that can be encoded/decoded for persistence.
///
/// - Codable: Allows converting to/from JSON for storage
/// - Identifiable: Provides unique ID for SwiftUI lists
/// - Equatable: Enables comparison between connections to avoid duplicates
struct SavedConnection: Codable, Identifiable, Equatable {
    /// Unique identifier for this connection (automatically generated)
    var id = UUID()
    
    /// User-friendly name for this connection
    var name: String
    
    /// Server address (IP or hostname)
    var address: String
    
    /// Server port number
    var port: Int
    
    /// Custom equality implementation - connections are equal if they point to the same server
    static func == (lhs: SavedConnection, rhs: SavedConnection) -> Bool {
        return lhs.address == rhs.address && lhs.port == rhs.port
    }
}

/// # App Model
///
/// The central state management class for AdvantageVisionXR.
/// This class follows the Observable Object pattern used in SwiftUI apps.
///
/// Features:
/// - Maintains connection state with AdvantageScope server
/// - Tracks immersive space state (open/closed)
/// - Manages saved connections
/// - Provides methods for connecting to AdvantageScope
///
/// The @MainActor attribute ensures this runs on the main thread for UI safety
@MainActor
class AppModel: ObservableObject {
    // MARK: - Constants
    
    /// Identifier for the immersive space (used by SwiftUI)
    let immersiveSpaceID = "ImmersiveSpace"
    
    /// Default port used by AdvantageScope's XR server
    let defaultServerPort = 56328
    
    // MARK: - Types
    
    /// Represents the possible states of the immersive 3D space
    enum ImmersiveSpaceState {
        /// Immersive space is not currently open
        case closed
        
        /// Immersive space is in the process of opening or closing
        case inTransition
        
        /// Immersive space is currently open and active
        case open
    }
    
    /// Represents the possible states for the connection to AdvantageScope
    enum ConnectionState {
        /// Not connected to any server
        case disconnected
        
        /// Attempting to establish a connection
        case connecting
        
        /// Successfully connected to AdvantageScope server
        case connected
    }
    
    // MARK: - Published Properties
    
    /// Current state of the immersive space
    /// @Published notifies SwiftUI views when this changes
    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
    
    /// Current connection state to AdvantageScope
    @Published var connectionState = ConnectionState.disconnected
    
    /// Address of the server (IP or hostname)
    @Published var serverAddress = ""
    
    /// Port number for connection
    @Published var serverPort = 56328
    
    /// List of potential server addresses for connection attempts
    @Published var serverAddresses: [String] = []
    
    /// Collection of user's saved connection profiles
    @Published var savedConnections: [SavedConnection] = []
    
    /// Controls whether the connection dialog is displayed
    @Published var showConnectionDialog = true
    
    // MARK: - Initialization
    
    /// Initializes the AppModel and loads any saved connections from persistent storage
    init() {
        // Load saved connections from UserDefaults (iOS/visionOS's simple key-value storage)
        if let savedData = UserDefaults.standard.data(forKey: "savedConnections"),
           let decoded = try? JSONDecoder().decode([SavedConnection].self, from: savedData) {
            savedConnections = decoded
        }
    }
    
    // MARK: - Connection Management
    
    /// Saves a new connection profile to persistent storage
    /// - Parameters:
    ///   - name: User-friendly name for this connection
    ///   - address: Server address (IP or hostname)
    ///   - port: Server port number
    func saveConnection(name: String, address: String, port: Int) {
        // Create a new connection object
        let newConnection = SavedConnection(name: name, address: address, port: port)
        
        // Only add if this exact connection doesn't already exist
        if !savedConnections.contains(where: { $0.address == address && $0.port == port }) {
            // Add to the list
            savedConnections.append(newConnection)
            
            // Persist to storage by encoding to JSON and saving to UserDefaults
            if let encoded = try? JSONEncoder().encode(savedConnections) {
                UserDefaults.standard.set(encoded, forKey: "savedConnections")
            }
        }
    }
    
    /// Deletes a saved connection
    /// - Parameter index: Index of the connection to delete
    func deleteConnection(at index: Int) {
        // Check that the index is valid
        if index >= 0 && index < savedConnections.count {
            // Remove from array
            savedConnections.remove(at: index)
            
            // Update persistent storage
            if let encoded = try? JSONEncoder().encode(savedConnections) {
                UserDefaults.standard.set(encoded, forKey: "savedConnections")
            }
        }
    }
    
    /// Initiates a connection to an AdvantageScope server
    /// - Parameters:
    ///   - address: Server address to connect to
    ///   - port: Server port to connect to
    func connect(to address: String, port: Int) {
        // Store connection parameters
        serverAddress = address
        serverPort = port
        serverAddresses = [address]
        
        // Update connection state - actual connection handled by NetworkingManager
        connectionState = .connecting
    }
}
