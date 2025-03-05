# AdvantageVisionXR Development Guide

## Project Overview
AdvantageVisionXR is a visionOS app for Apple Vision Pro that extends AdvantageScope's functionality into mixed reality. The app provides both a standard 2D interface and immersive 3D spaces for data visualization.

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
- **ImmersiveView.swift**: 3D immersive experience
- **ToggleImmersiveSpaceButton.swift**: UI for toggling immersive mode
- **RealityKitContent package**: Contains 3D assets and RealityKit components

## Coding Guidelines
- **SwiftUI**: Use SwiftUI for all UI components
- **RealityKit**: Use RealityKit for 3D content rendering
- **State Management**: Use the Observable macro and environment objects
- **Naming**: Use descriptive PascalCase for types and camelCase for properties/methods
- **Comments**: Document public APIs and complex logic
- **Testing**: Write unit tests for critical functionality

## Deployment
- Archive for distribution: Product > Archive
- For TestFlight: Use App Store Connect to manage testing
- For enterprise distribution: Export for Ad Hoc distribution

## Resources
- [visionOS Programming Guide](https://developer.apple.com/visionos/planning/)
- [SwiftUI for visionOS](https://developer.apple.com/documentation/visionOS/SwiftUI)
- [RealityKit Documentation](https://developer.apple.com/documentation/RealityKit)