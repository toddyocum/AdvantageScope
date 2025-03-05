//
//  ConnectionView.swift
//  AdvantageVisionXR
//
//  Created on 3/4/25.
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appModel: AppModel
    
    @State private var connectionName = ""
    @State private var serverAddress = ""
    @State private var serverPort = "56328"
    @State private var showDeleteConfirmation = false
    @State private var connectionToDelete: Int?
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, address, port
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Manual Connection") {
                        TextField("Server Address (IP or hostname)", text: $serverAddress)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .address)
                        
                        TextField("Port", text: $serverPort)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .port)
                        
                        Button(action: connectToServer) {
                            Text("Connect")
                        }
                        .disabled(serverAddress.isEmpty || !isValidPort(serverPort))
                    }
                    
                    Section("Save Connection") {
                        TextField("Connection Name", text: $connectionName)
                            .focused($focusedField, equals: .name)
                        
                        Button(action: saveConnection) {
                            Text("Save Current Settings")
                        }
                        .disabled(serverAddress.isEmpty || connectionName.isEmpty || !isValidPort(serverPort))
                    }
                    
                    if !appModel.savedConnections.isEmpty {
                        Section("Saved Connections") {
                            ForEach(appModel.savedConnections.indices, id: \.self) { index in
                                let connection = appModel.savedConnections[index]
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(connection.name)
                                            .font(.headline)
                                        Text("\(connection.address):\(connection.port)")
                                            .font(.caption)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        serverAddress = connection.address
                                        serverPort = String(connection.port)
                                    }) {
                                        Text("Load")
                                    }
                                    
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
                    
                    Section("Network Discovery") {
                        // Future implementation for discovery
                        Text("Automatic discovery will be available in a future update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Connect to AdvantageScope")
                .confirmationDialog(
                    "Delete Connection",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let index = connectionToDelete {
                            appModel.deleteConnection(at: index)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if let index = connectionToDelete, 
                       index >= 0 && index < appModel.savedConnections.count {
                        Text("Are you sure you want to delete '\(appModel.savedConnections[index].name)'?")
                    }
                }
                
                // Connection status indicator
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 10, height: 10)
                    
                    Text(connectionStatusText)
                        .font(.caption)
                    
                    Spacer()
                }
                .padding()
            }
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
    
    private var connectionStatusColor: Color {
        switch appModel.connectionState {
        case .disconnected:
            return .red
        case .connecting:
            return .yellow
        case .connected:
            return .green
        }
    }
    
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
    
    private func connectToServer() {
        guard let port = Int(serverPort), port > 0 && port < 65536 else { return }
        appModel.connect(to: serverAddress, port: port)
    }
    
    private func saveConnection() {
        guard let port = Int(serverPort), port > 0 && port < 65536 else { return }
        appModel.saveConnection(name: connectionName, address: serverAddress, port: port)
        connectionName = ""
    }
    
    private func isValidPort(_ portString: String) -> Bool {
        guard let port = Int(portString) else { return false }
        return port > 0 && port < 65536
    }
}

#Preview {
    ConnectionView()
        .environmentObject(AppModel())
}