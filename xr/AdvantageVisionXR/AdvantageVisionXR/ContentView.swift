//
//  ContentView.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var networkingManager: NetworkingManager?
    
    var body: some View {
        ZStack {
            // Main app content - only shown when connected
            if appModel.connectionState == .connected {
                mainContentView
            }
        }
        // Connection setup sheet - moved outside ZStack
        .sheet(isPresented: $appModel.showConnectionDialog) {
            ConnectionView()
                .interactiveDismissDisabled(appModel.connectionState != .connected)
        }
        .onAppear {
            // Initialize networking manager
            networkingManager = NetworkingManager(appModel: appModel)
        }
        .onChange(of: appModel.connectionState) { oldValue, newValue in
            if oldValue != .connecting && newValue == .connecting {
                // When state changes to connecting, start the connection process
                Task {
                    await networkingManager?.connect()
                }
            }
            
            // Update sheet visibility based on connection state
            if newValue == .connected {
                // Hide sheet when connected
                appModel.showConnectionDialog = false
            } else if newValue == .disconnected && oldValue == .connected {
                // Show sheet when disconnected from connected state
                appModel.showConnectionDialog = true
            }
        }
        .onAppear {
            // Show connection dialog when app appears if not connected
            if appModel.connectionState != .connected {
                appModel.showConnectionDialog = true
            }
        }
    }
    
    // The main app view shown when connected
    private var mainContentView: some View {
        VStack {
            // Connection status indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Connected to \(appModel.serverAddress)")
                    .font(.caption)
                
                Spacer()
                
                Button(action: {
                    appModel.showConnectionDialog = true
                }) {
                    Label("Connection Settings", systemImage: "network")
                }
            }
            .padding()
            
            Spacer()
            
            // 3D preview (placeholder)
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .frame(width: 300, height: 300)
            
            Text("AdvantageScope 3D View")
                .font(.title)
                .padding()
            
            Text("Connected and ready for 3D data")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Immersive space toggle
            ToggleImmersiveSpaceButton()
                .padding()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    networkingManager?.disconnect()
                }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environmentObject(AppModel())
}
