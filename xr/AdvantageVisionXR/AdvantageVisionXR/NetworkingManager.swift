//
//  NetworkingManager.swift
//  AdvantageVisionXR
//
//  Created on 3/4/25.
//

import Foundation
import SwiftUI
import Combine

// This will need a dependency for WebSockets in the app's package file
// We'll use Starscream: https://github.com/daltoniam/Starscream

@MainActor
class NetworkingManager: ObservableObject {
    private var appModel: AppModel
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnecting = false
    private var pingTimer: Timer?
    private var receiveTimer: Timer?
    
    // For handling model data
    @Published private(set) var modelData: Data?
    @Published private(set) var isConnected = false
    
    init(appModel: AppModel) {
        self.appModel = appModel
    }
    
    // Connect to the server
    func connect() async {
        guard !appModel.serverAddresses.isEmpty else {
            appModel.connectionState = .disconnected
            return
        }
        
        // Create URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = 10.0
        session = URLSession(configuration: sessionConfig)
        
        // Create websocket connection
        let serverAddress = appModel.serverAddresses[0]
        let serverPort = appModel.serverPort
        let urlString = "ws://\(serverAddress):\(serverPort)/ws"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            appModel.connectionState = .disconnected
            return
        }
        
        // Connect to the WebSocket
        socket = session?.webSocketTask(with: url)
        socket?.resume()
        
        // Start receive loop
        await receiveMessage()
        
        // Start ping timer (keep connection alive)
        startPingTimer()
        
        // Start receive timeout timer
        startReceiveTimer()
    }
    
    // Disconnect from the server
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        
        receiveTimer?.invalidate()
        receiveTimer = nil
        
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        
        isConnected = false
        appModel.connectionState = .disconnected
    }
    
    // MARK: - Private methods
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.sendPing()
            }
        }
    }
    
    private func startReceiveTimer() {
        receiveTimer?.invalidate()
        receiveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            // If no message received within timeout, consider connection lost
            guard let self = self else { return }
            if self.appModel.connectionState == .connecting {
                Task {
                    await self.handleDisconnection()
                }
            }
        }
    }
    
    private func sendPing() async {
        guard let socket = socket else { return }
        
        // Create a Task to handle the asynchronous ping
        return await withCheckedContinuation { continuation in
            socket.sendPing { error in
                if let error = error {
                    print("Error sending ping: \(error)")
                    Task {
                        await self.handleDisconnection()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func receiveMessage() async {
        guard let socket = socket else { return }
        
        do {
            let message = try await socket.receive()
            
            // Reset receive timer on successful message
            startReceiveTimer()
            
            // Mark connection as established
            if !isConnected {
                isConnected = true
                appModel.connectionState = .connected
            }
            
            // Process the received message
            switch message {
            case .data(let data):
                handleBinaryMessage(data)
            case .string(let text):
                handleTextMessage(text)
            @unknown default:
                break
            }
            
            // Continue listening for messages
            await receiveMessage()
            
        } catch {
            print("WebSocket receive error: \(error)")
            await handleDisconnection()
        }
    }
    
    private func handleTextMessage(_ text: String) {
        // Handle text messages (could be used for metadata or commands)
        print("Received text message: \(text)")
    }
    
    private func handleBinaryMessage(_ data: Data) {
        // Store the model data
        self.modelData = data
        
        // Post notification with the model data
        NotificationCenter.default.post(
            name: AdvantageVisionXRApp.modelDataReceivedNotification,
            object: data
        )
    }
    
    private func handleDisconnection() async {
        if reconnecting {
            return
        }
        
        reconnecting = true
        disconnect()
        
        // Try to reconnect after a delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        reconnecting = false
        await connect()
    }
}