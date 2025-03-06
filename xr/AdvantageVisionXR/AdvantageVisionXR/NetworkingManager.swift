//
//  NetworkingManager.swift
//  AdvantageVisionXR
//
//  Created on 3/4/25.
//

import Foundation
import SwiftUI
import Combine

/// # NetworkingManager
///
/// This class handles WebSocket communication with AdvantageScope.
/// It establishes and maintains the connection, sending and receiving messages,
/// and processing the data received from AdvantageScope.
///
/// ## How it connects to AdvantageScope:
/// AdvantageScope runs a WebSocket server on port 56328 when its 3D visualization 
/// is configured for XR viewing. This manager connects to that server and receives
/// MessagePack-encoded data for 3D visualization.
///
/// ## Key features:
/// - WebSocket connection using URLSessionWebSocketTask
/// - MessagePack decoding of multiple message types
/// - Auto-reconnect on connection loss
/// - Keep-alive with ping messages
/// - Connection timeout detection
/// - HTTP model downloads
///
/// The @MainActor attribute ensures this class always operates on the main thread
/// for UI safety since it interacts with SwiftUI's published properties.
@MainActor
class NetworkingManager: ObservableObject {
    // MARK: - Static Properties
    
    /// Shared instance for model downloads
    static var shared: NetworkingManager!
    
    /// Notification for settings updates
    static let settingsReceivedNotification = Notification.Name("SettingsReceived")
    
    /// Notification for command updates
    static let commandReceivedNotification = Notification.Name("CommandReceived")
    
    /// Notification for assets updates
    static let assetsReceivedNotification = Notification.Name("AssetsReceived")
    
    // MARK: - Private Properties
    
    /// Reference to the shared app model
    private var appModel: AppModel
    
    /// The WebSocket connection task
    private var socket: URLSessionWebSocketTask?
    
    /// The URL session used for the WebSocket
    private var session: URLSession?
    
    /// Flag to prevent multiple reconnect attempts
    private var reconnecting = false
    
    /// Timer that sends periodic pings to keep connection alive
    private var pingTimer: Timer?
    
    /// Timer to detect connection timeouts
    private var receiveTimer: Timer?
    
    /// MessagePack decoder for binary messages
    private let messageDecoder = MessagePackDecoder()
    
    // MARK: - Published Properties
    
    /// Whether the connection is currently established
    @Published private(set) var isConnected = false
    
    /// Latest settings received from AdvantageScope
    @Published private(set) var latestSettings: XRSettings?
    
    /// Latest command received from AdvantageScope
    @Published private(set) var latestCommand: ThreeDimensionRendererCommand?
    
    /// Available assets information from AdvantageScope
    @Published private(set) var availableAssets: AdvantageScopeAssets?
    
    // MARK: - Computed Properties
    
    /// Base URL for the server (used for HTTP model downloads)
    private var serverBaseURL: URL? {
        guard !appModel.serverAddress.isEmpty else { return nil }
        return URL(string: "http://\(appModel.serverAddress):\(appModel.serverPort)")
    }
    
    // MARK: - Initialization
    
    /// Initialize with a reference to the app model
    /// - Parameter appModel: The shared application model
    init(appModel: AppModel) {
        self.appModel = appModel
        
        // Setup shared instance if needed
        if NetworkingManager.shared == nil {
            NetworkingManager.shared = self
        }
    }
    
    /// Set up the shared instance
    /// - Parameter appModel: The app model to use
    static func setupShared(with appModel: AppModel) {
        shared = NetworkingManager(appModel: appModel)
    }
    
    // MARK: - Public Methods
    
    /// Establishes a WebSocket connection to the AdvantageScope server
    ///
    /// This asynchronous method:
    /// 1. Creates a URL session
    /// 2. Formulates the WebSocket URL
    /// 3. Establishes the connection
    /// 4. Starts the message receiving loop
    /// 5. Configures keep-alive timers
    func connect() async {
        // Verify we have a server address to connect to
        guard !appModel.serverAddresses.isEmpty else {
            appModel.connectionState = .disconnected
            return
        }
        
        // Create URL session with timeout configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = 10.0  // 10 second timeout
        session = URLSession(configuration: sessionConfig)
        
        // Build the WebSocket URL: ws://hostname:port/ws
        let serverAddress = appModel.serverAddresses[0]
        let serverPort = appModel.serverPort
        let urlString = "ws://\(serverAddress):\(serverPort)/ws"
        
        // Validate URL
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            appModel.connectionState = .disconnected
            return
        }
        
        // Create and start the WebSocket task
        socket = session?.webSocketTask(with: url)
        socket?.resume()
        
        // Start receiving messages in a loop
        await receiveMessage()
        
        // Start timers for connection maintenance
        startPingTimer()
        startReceiveTimer()
    }
    
    /// Closes the WebSocket connection and cleans up resources
    func disconnect() {
        // Cleanup timers
        pingTimer?.invalidate()
        pingTimer = nil
        
        receiveTimer?.invalidate()
        receiveTimer = nil
        
        // Close the WebSocket with normal closure code
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        
        // Update connection state
        isConnected = false
        appModel.connectionState = .disconnected
    }
    
    /// Downloads a 3D model from the server
    /// - Parameter path: The relative path to the model file
    /// - Returns: The binary model data
    func downloadModel(path: String) async throws -> Data {
        guard let serverBaseURL = serverBaseURL else {
            throw URLError(.badURL)
        }
        
        // Encode the path to handle special characters
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        let modelURL = serverBaseURL.appendingPathComponent("asset").appending(queryItems: [
            URLQueryItem(name: "path", value: encodedPath)
        ])
        
        // Download the model data
        let (data, response) = try await URLSession.shared.data(from: modelURL)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    // MARK: - Private Methods - Connection Maintenance
    
    /// Starts a timer to send periodic ping messages to keep the connection alive
    private func startPingTimer() {
        // Clear any existing timer
        pingTimer?.invalidate()
        
        // Create a new timer that fires every 5 seconds
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Use weak self to prevent memory leaks
            Task { [weak self] in
                await self?.sendPing()
            }
        }
    }
    
    /// Starts a timer to detect connection timeouts
    private func startReceiveTimer() {
        // Clear any existing timer
        receiveTimer?.invalidate()
        
        // Create a new timer that fires every 10 seconds
        receiveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            // If no message received within timeout period, consider connection lost
            guard let self = self else { return }
            if self.appModel.connectionState == .connecting {
                Task {
                    await self.handleDisconnection()
                }
            }
        }
    }
    
    /// Sends a WebSocket ping message to verify connection is alive
    private func sendPing() async {
        guard let socket = socket else { return }
        
        // Use continuation to bridge between completion handler and async/await
        return await withCheckedContinuation { continuation in
            socket.sendPing { error in
                if let error = error {
                    print("Error sending ping: \(error)")
                    // Connection problem detected, initiate disconnection handling
                    Task {
                        await self.handleDisconnection()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Private Methods - Message Handling
    
    /// Receives and processes WebSocket messages in a continuous loop
    private func receiveMessage() async {
        guard let socket = socket else { return }
        
        do {
            // Await the next message from the WebSocket
            let message = try await socket.receive()
            
            // Reset receive timer on successful message
            startReceiveTimer()
            
            // If this is the first successful message, update connection state
            if !isConnected {
                isConnected = true
                appModel.connectionState = .connected
            }
            
            // Process the received message based on its type
            switch message {
            case .data(let data):
                // Binary messages are MessagePack encoded
                await handleBinaryMessage(data)
            case .string(let text):
                // Text messages might contain commands or metadata
                handleTextMessage(text)
            @unknown default:
                // Handle future message types
                break
            }
            
            // Continue listening for messages (recursive async call)
            await receiveMessage()
            
        } catch {
            // Handle connection errors
            print("WebSocket receive error: \(error)")
            await handleDisconnection()
        }
    }
    
    /// Processes text messages from the WebSocket
    /// - Parameter text: The received text message
    private func handleTextMessage(_ text: String) {
        // Currently just logs text messages
        // Could be used for commands, status updates, or metadata in the future
        print("Received text message: \(text)")
    }
    
    /// Processes binary messages with MessagePack decoding
    /// - Parameter data: The received binary data
    private func handleBinaryMessage(_ data: Data) async {
        do {
            // Try to decode the MessagePack data to determine the message type
            guard let packet = try messageDecoder.decodePacket(from: data) else {
                print("Unknown packet format")
                return
            }
            
            // Process based on packet type
            switch packet {
            case let settingsPacket as XRSettingsPacket:
                print("Received settings packet")
                handleSettingsPacket(settingsPacket)
                
            case let commandPacket as XRCommandPacket:
                print("Received command packet with \(commandPacket.value.objects.count) objects")
                handleCommandPacket(commandPacket)
                
            case let assetsPacket as XRAssetsPacket:
                print("Received assets packet")
                handleAssetsPacket(assetsPacket)
                
            default:
                print("Unhandled packet type")
            }
        } catch let error as MessagePackError {
            // Handle MessagePack specific errors
            print("MessagePack error: \(error)")
            
            // Try JSON fallback if MessagePack fails
            do {
                if let packet = try messageDecoder.attemptJSONFallback(from: data) {
                    print("JSON fallback successful")
                    
                    // Process based on packet type
                    switch packet {
                    case let settingsPacket as XRSettingsPacket:
                        handleSettingsPacket(settingsPacket)
                    case let commandPacket as XRCommandPacket:
                        handleCommandPacket(commandPacket)
                    case let assetsPacket as XRAssetsPacket:
                        handleAssetsPacket(assetsPacket)
                    default:
                        break
                    }
                } else {
                    // If that fails too, try legacy approach
                    legacyHandleBinaryData(data)
                }
            } catch {
                // If JSON fallback also fails, fall back to legacy approach
                legacyHandleBinaryData(data)
            }
        } catch {
            // Handle other errors and try the legacy approach as a last resort
            print("Error handling binary message: \(error)")
            legacyHandleBinaryData(data)
        }
    }
    
    /// Legacy fallback for binary data handling
    /// - Parameter data: The raw binary data
    private func legacyHandleBinaryData(_ data: Data) {
        print("Using legacy approach for binary data")
        
        // First few bytes might help identify the format
        if data.count > 10 {
            let prefix = data.prefix(8)
            print("Data prefix: \(prefix.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        // Post the raw data as a model (legacy approach)
        NotificationCenter.default.post(
            name: AdvantageVisionXRApp.modelDataReceivedNotification,
            object: data
        )
    }
    
    /// Handles settings packet from AdvantageScope
    /// - Parameter packet: The settings packet
    private func handleSettingsPacket(_ packet: XRSettingsPacket) {
        self.latestSettings = packet.value
        
        // Notify app about settings update
        NotificationCenter.default.post(
            name: NetworkingManager.settingsReceivedNotification,
            object: packet.value
        )
    }
    
    /// Handles command packet from AdvantageScope
    /// - Parameter packet: The command packet
    private func handleCommandPacket(_ packet: XRCommandPacket) {
        self.latestCommand = packet.value
        
        // Notify app about command update
        NotificationCenter.default.post(
            name: NetworkingManager.commandReceivedNotification,
            object: packet.value
        )
    }
    
    /// Handles assets packet from AdvantageScope
    /// - Parameter packet: The assets packet
    private func handleAssetsPacket(_ packet: XRAssetsPacket) {
        self.availableAssets = packet.value
        
        // Notify app about assets update
        NotificationCenter.default.post(
            name: NetworkingManager.assetsReceivedNotification,
            object: packet.value
        )
    }
    
    /// Handles connection loss and attempts to reconnect
    private func handleDisconnection() async {
        // Prevent multiple simultaneous reconnection attempts
        if reconnecting {
            return
        }
        
        reconnecting = true
        
        // Close the current connection
        disconnect()
        
        // Wait 1 second before reconnecting
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second = 1 billion nanoseconds
        
        // Reset flag and attempt to reconnect
        reconnecting = false
        await connect()
    }
}