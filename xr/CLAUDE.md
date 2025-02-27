# AdvantageScopeXR Development Guide

## Setup and Building
- Open `AdvantageScopeXR.xcodeproj` in Xcode
- Build for physical iOS/iPadOS device (AR requires hardware, not simulator)
- Requires iOS/iPadOS 16.0+ device with ARKit support
- Test with AdvantageScope desktop application on same network

## Development Environment
- Primary language: Swift
- AR framework: ARKit
- Rendering: Metal
- Network: WebSockets (Starscream library)
- Dependencies managed via Swift Package Manager

## Code Style Guidelines
- **Swift**: Follow Apple's Swift API Design Guidelines
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Project Structure**: 
  - AR functionality in ARRenderer.swift
  - Networking in WebSocketManager.swift
  - UI in ContentView.swift and related files
- **Error Handling**: Use Swift's try/catch and optional unwrapping patterns

## Testing
- Hardware testing required (iOS device + AdvantageScope desktop)
- Test all three calibration modes: Miniature, Full-Size Blue, Full-Size Red
- Verify streaming in both Smooth and Low Latency modes