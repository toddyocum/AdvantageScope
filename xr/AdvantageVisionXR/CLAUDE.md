# AdvantageVisionXR Development Guide

## Project Overview
AdvantageVisionXR is a visionOS app for Apple Vision Pro that extends AdvantageScope's functionality into mixed reality. The app provides both a standard 2D interface and immersive 3D spaces for data visualization.

## Key Features Implemented
- **Manual Connection Interface**: Alternative to QR code scanning, allows direct IP/hostname entry
- **Connection Management**: Save, load, and manage multiple connection profiles
- **WebSocket Communication**: Connect to AdvantageScope server (port 56328)
- **Immersive 3D Space**: View and interact with 3D models in mixed reality
- **Model Loading**: Framework for loading GLTF models from binary data

## Development Setup
- Xcode 15.3+ required for visionOS development
- Apple Developer account required for testing on Vision Pro hardware
- Vision Pro simulator can be used for basic testing

## Build Instructions
- Open `AdvantageVisionXR.xcodeproj` in Xcode
- Build with Product > Build (⌘B)
- Run on simulator with Product > Run (⌘R)
- For device testing, select your Vision Pro from the device list

## Code Organization
- **AdvantageVisionXRApp.swift**: Main app entry point and scene setup
- **AppModel.swift**: Shared state management for the app
- **ContentView.swift**: 2D window interface
- **ConnectionView.swift**: Connection settings interface
- **ImmersiveView.swift**: 3D immersive experience
- **ToggleImmersiveSpaceButton.swift**: UI for toggling immersive mode
- **NetworkingManager.swift**: WebSocket connection handling
- **ModelLoader.swift**: Loads and processes 3D models

## Architecture
- **State Management**: Using ObservableObject pattern for shared state
- **Dependency Injection**: Using EnvironmentObject for view dependencies
- **Communication**: WebSockets for real-time data transfer
- **Notifications**: NotificationCenter for cross-component messaging
- **Async/Await**: Modern Swift concurrency for network operations

## Coding Guidelines
- **SwiftUI**: Use SwiftUI for all UI components
- **RealityKit**: Use RealityKit for 3D content rendering
- **State Management**: Use ObservableObject with @Published properties
- **Naming**: Use descriptive PascalCase for types and camelCase for properties/methods
- **Comments**: Document public APIs and complex logic
- **Testing**: Write unit tests for critical functionality

## Connection Flow
1. App starts with ConnectionView sheet displayed
2. User enters server information (address and port)
3. On connect, NetworkingManager establishes WebSocket connection
4. When connection succeeds, ConnectionView is dismissed
5. Main interface shows connected status and 3D preview
6. User can toggle immersive mode to view 3D content in mixed reality

## 3D Model Processing
1. Binary data received via WebSocket
2. ModelLoader processes data and creates RealityKit Entity
3. Entity is passed to ImmersiveView via NotificationCenter
4. ImmersiveView displays the model in 3D space

## Deployment
- Archive for distribution: Product > Archive
- For TestFlight: Use App Store Connect to manage testing
- For enterprise distribution: Export for Ad Hoc distribution

## Resources
- [visionOS Programming Guide](https://developer.apple.com/visionos/planning/)
- [SwiftUI for visionOS](https://developer.apple.com/documentation/visionOS/SwiftUI)
- [RealityKit Documentation](https://developer.apple.com/documentation/RealityKit)