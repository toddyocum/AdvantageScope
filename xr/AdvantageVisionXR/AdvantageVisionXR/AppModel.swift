//
//  AppModel.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI

// Define a struct for saved connections
struct SavedConnection: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var address: String
    var port: Int
    
    static func == (lhs: SavedConnection, rhs: SavedConnection) -> Bool {
        return lhs.address == rhs.address && lhs.port == rhs.port
    }
}

/// Maintains app-wide state
@MainActor
class AppModel: ObservableObject {
    let immersiveSpaceID = "ImmersiveSpace"
    let defaultServerPort = 56328 // Same port as AdvantageScope XR server
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
    @Published var connectionState = ConnectionState.disconnected
    @Published var serverAddress = ""
    @Published var serverPort = 56328
    @Published var serverAddresses: [String] = []
    @Published var savedConnections: [SavedConnection] = []
    
    // If true, the connection dialog is displayed
    @Published var showConnectionDialog = true
    
    init() {
        // Load saved connections from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "savedConnections"),
           let decoded = try? JSONDecoder().decode([SavedConnection].self, from: savedData) {
            savedConnections = decoded
        }
    }
    
    func saveConnection(name: String, address: String, port: Int) {
        let newConnection = SavedConnection(name: name, address: address, port: port)
        
        // Don't add duplicates
        if !savedConnections.contains(where: { $0.address == address && $0.port == port }) {
            savedConnections.append(newConnection)
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(savedConnections) {
                UserDefaults.standard.set(encoded, forKey: "savedConnections")
            }
        }
    }
    
    func deleteConnection(at index: Int) {
        if index >= 0 && index < savedConnections.count {
            savedConnections.remove(at: index)
            
            // Update UserDefaults
            if let encoded = try? JSONEncoder().encode(savedConnections) {
                UserDefaults.standard.set(encoded, forKey: "savedConnections")
            }
        }
    }
    
    func connect(to address: String, port: Int) {
        serverAddress = address
        serverPort = port
        serverAddresses = [address]
        connectionState = .connecting
        // Connection logic will be implemented in a Networking class
    }
}
