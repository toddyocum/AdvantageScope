//
//  ContentView.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

/// # Content View
///
/// This is the main 2D window view for the AdvantageVisionXR app.
/// It displays the connection status, provides controls for managing the connection,
/// and offers a button to toggle between 2D and immersive 3D views.
///
/// ## App Window Flow:
/// 1. On first launch, the connection dialog is shown automatically
/// 2. After connecting, this view displays connection status and controls
/// 3. The user can toggle between 2D and immersive 3D modes
/// 4. Connection can be managed or disconnected from this view
///
/// ## How this integrates with AdvantageScope:
/// This view serves as the main control panel for the AdvantageVisionXR app,
/// showing connection status and providing access to the immersive 3D view
/// where AdvantageScope's 3D models are displayed.
struct ContentView: View {
    // MARK: - Properties
    
    /// Access to the shared app model
    @EnvironmentObject private var appModel: AppModel
    
    /// Reference to the networking manager for connection handling
    @State private var networkingManager: NetworkingManager?
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // Main app content - only shown when connected to AdvantageScope
            if appModel.connectionState == .connected {
                mainContentView
            }
        }
        // Connection setup sheet - presented modally over the main view
        .sheet(isPresented: $appModel.showConnectionDialog) {
            ConnectionView()
                // Prevent dismissing by dragging unless connected
                // This ensures users must establish a connection first
                .interactiveDismissDisabled(appModel.connectionState != .connected)
        }
        // Initialize networking when view appears
        .onAppear {
            // Create the networking manager with a reference to the app model
            networkingManager = NetworkingManager(appModel: appModel)
        }
        // React to changes in connection state
        .onChange(of: appModel.connectionState) { oldValue, newValue in
            // When transitioning to the connecting state, start the connection process
            if oldValue != .connecting && newValue == .connecting {
                Task {
                    await networkingManager?.connect()
                }
            }
            
            // Update the connection dialog visibility based on connection state
            if newValue == .connected {
                // Hide dialog when connected
                appModel.showConnectionDialog = false
            } else if newValue == .disconnected && oldValue == .connected {
                // Show dialog when disconnected from a previously connected state
                appModel.showConnectionDialog = true
            }
        }
        // Show connection dialog on first launch if not connected
        .onAppear {
            if appModel.connectionState != .connected {
                appModel.showConnectionDialog = true
            }
        }
    }
    
    // MARK: - Main Content View
    
    /// The main content view shown when connected to AdvantageScope
    private var mainContentView: some View {
        VStack {
            // Connection status header
            HStack {
                // Green indicator for active connection
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                // Display the connected server address
                Text("Connected to \(appModel.serverAddress)")
                    .font(.caption)
                
                Spacer()
                
                // Button to show connection settings
                Button(action: {
                    appModel.showConnectionDialog = true
                }) {
                    Label("Connection Settings", systemImage: "network")
                }
            }
            .padding()
            
            Spacer()
            
            // 3D preview in the 2D window
            // This shows a placeholder model from the Reality Composer Pro package
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .frame(width: 300, height: 300)
            
            // App title
            Text("AdvantageScope 3D View")
                .font(.title)
                .padding()
            
            // Status message
            Text("Connected and ready for 3D data")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Immersive mode toggle button
            // This allows switching between 2D and 3D immersive views
            ToggleImmersiveSpaceButton()
                .padding()
        }
        .padding()
        // Toolbar with disconnect button
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    // Disconnect from the server
                    networkingManager?.disconnect()
                }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            }
        }
    }
}

/// Preview for SwiftUI Canvas and Simulator
#Preview(windowStyle: .automatic) {
    ContentView()
        .environmentObject(AppModel())
}
