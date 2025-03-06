//
//  ConnectionView.swift
//  AdvantageVisionXR
//
//  Created on 3/4/25.
//

import SwiftUI

/// # Connection View
///
/// This view provides the connection interface for AdvantageVisionXR.
/// It allows users to connect to AdvantageScope servers manually by entering
/// server addresses and port numbers, and to save and manage connection profiles.
///
/// ## Features:
/// - Manual server connection with address and port input
/// - Save and load connection profiles
/// - Connection status indicator
/// - Delete saved connections with confirmation
///
/// ## How it connects to AdvantageScope:
/// When a connection is initiated, this view passes the connection parameters
/// to the AppModel, which then instructs NetworkingManager to establish a WebSocket
/// connection to the specified AdvantageScope server.
struct ConnectionView: View {
    // MARK: - Properties
    
    /// Access to the shared app model
    @EnvironmentObject private var appModel: AppModel
    
    // MARK: - State Properties
    
    /// Name for saving the current connection settings
    @State private var connectionName = ""
    
    /// Server address input (IP or hostname)
    @State private var serverAddress = ""
    
    /// Server port input (defaults to AdvantageScope's XR port)
    @State private var serverPort = "56328"
    
    /// Controls whether the delete confirmation dialog is shown
    @State private var showDeleteConfirmation = false
    
    /// Tracks which connection is being deleted
    @State private var connectionToDelete: Int?
    
    /// Tracks the currently focused input field for keyboard management
    @FocusState private var focusedField: Field?
    
    // MARK: - Field Types
    
    /// Enum for tracking focused fields
    enum Field {
        case name, address, port
    }
    
    // MARK: - View Body
    
    var body: some View {
        // Use NavigationStack for navigation hierarchy and title
        NavigationStack {
            VStack {
                // Form provides a scrollable, sectioned interface
                Form {
                    // SECTION: Manual connection inputs
                    Section("Manual Connection") {
                        // Server address input field
                        TextField("Server Address (IP or hostname)", text: $serverAddress)
                            .keyboardType(.URL)  // Shows URL-optimized keyboard
                            .autocorrectionDisabled()  // Disable autocorrect for addresses
                            .textInputAutocapitalization(.never)  // Don't capitalize
                            .focused($focusedField, equals: .address)  // Track focus state
                        
                        // Port number input field
                        TextField("Port", text: $serverPort)
                            .keyboardType(.numberPad)  // Shows number keyboard
                            .focused($focusedField, equals: .port)
                        
                        // Connect button
                        Button(action: connectToServer) {
                            Text("Connect")
                        }
                        // Disable if address is empty or port is invalid
                        .disabled(serverAddress.isEmpty || !isValidPort(serverPort))
                    }
                    
                    // SECTION: Save connection for future use
                    Section("Save Connection") {
                        // Connection name input
                        TextField("Connection Name", text: $connectionName)
                            .focused($focusedField, equals: .name)
                        
                        // Save button
                        Button(action: saveConnection) {
                            Text("Save Current Settings")
                        }
                        // Disable if any required field is missing or invalid
                        .disabled(serverAddress.isEmpty || connectionName.isEmpty || !isValidPort(serverPort))
                    }
                    
                    // SECTION: List of saved connections (only shown if there are any)
                    if !appModel.savedConnections.isEmpty {
                        Section("Saved Connections") {
                            // Loop through saved connections
                            ForEach(appModel.savedConnections.indices, id: \.self) { index in
                                let connection = appModel.savedConnections[index]
                                HStack {
                                    // Connection details
                                    VStack(alignment: .leading) {
                                        Text(connection.name)
                                            .font(.headline)
                                        Text("\(connection.address):\(connection.port)")
                                            .font(.caption)
                                    }
                                    
                                    Spacer()
                                    
                                    // Load button to use this connection
                                    Button(action: {
                                        serverAddress = connection.address
                                        serverPort = String(connection.port)
                                    }) {
                                        Text("Load")
                                    }
                                    
                                    // Delete button with confirmation
                                    Button(action: {
                                        connectionToDelete = index
                                        showDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    // SECTION: Future feature placeholder
                    Section("Network Discovery") {
                        // Future implementation for automatic server discovery
                        Text("Automatic discovery will be available in a future update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Connect to AdvantageScope")
                // Confirmation dialog for deleting connections
                .confirmationDialog(
                    "Delete Connection",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    // Delete button with destructive styling
                    Button("Delete", role: .destructive) {
                        if let index = connectionToDelete {
                            appModel.deleteConnection(at: index)
                        }
                    }
                    // Cancel button
                    Button("Cancel", role: .cancel) {}
                } message: {
                    // Show connection name in confirmation message
                    if let index = connectionToDelete, 
                       index >= 0 && index < appModel.savedConnections.count {
                        Text("Are you sure you want to delete '\(appModel.savedConnections[index].name)'?")
                    }
                }
                
                // Connection status indicator at bottom of view
                HStack {
                    // Color-coded status indicator (red, yellow, green)
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 10, height: 10)
                    
                    // Status text
                    Text(connectionStatusText)
                        .font(.caption)
                    
                    Spacer()
                }
                .padding()
            }
            // Add toolbar with Done button
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Dismiss keyboard if active
                        focusedField = nil
                        
                        // Only allow dismissing the sheet if connected
                        if appModel.connectionState == .connected {
                            appModel.showConnectionDialog = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the appropriate status indicator color based on connection state
    private var connectionStatusColor: Color {
        switch appModel.connectionState {
        case .disconnected:
            return .red         // Red for disconnected
        case .connecting:
            return .yellow      // Yellow for in-progress connection
        case .connected:
            return .green       // Green for connected
        }
    }
    
    /// Returns the appropriate status text based on connection state
    private var connectionStatusText: String {
        switch appModel.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected to \(appModel.serverAddress)"
        }
    }
    
    // MARK: - Private Methods
    
    /// Initiates a connection to the server with the current address and port
    private func connectToServer() {
        // Validate port number is in valid range
        guard let port = Int(serverPort), port > 0 && port < 65536 else { return }
        
        // Pass connection parameters to app model
        appModel.connect(to: serverAddress, port: port)
    }
    
    /// Saves the current connection settings with the specified name
    private func saveConnection() {
        // Validate port number is in valid range
        guard let port = Int(serverPort), port > 0 && port < 65536 else { return }
        
        // Save the connection to the app model
        appModel.saveConnection(name: connectionName, address: serverAddress, port: port)
        
        // Clear the name field after saving
        connectionName = ""
    }
    
    /// Validates a port string to ensure it's a valid port number
    /// - Parameter portString: The port string to validate
    /// - Returns: True if the port is valid, false otherwise
    private func isValidPort(_ portString: String) -> Bool {
        // Try to convert to integer
        guard let port = Int(portString) else { return false }
        
        // Check port is in valid range (1-65535)
        return port > 0 && port < 65536
    }
}

/// Preview for SwiftUI Canvas and Simulator
#Preview {
    ConnectionView()
        .environmentObject(AppModel())
}