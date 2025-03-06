//
//  ToggleImmersiveSpaceButton.swift
//  AdvantageVisionXR
//
//  Created by Todd Yocum on 3/4/25.
//

import SwiftUI

/// # Toggle Immersive Space Button
///
/// A button control that toggles between showing and hiding the immersive 3D space.
/// This is a critical UI component that allows users to transition between the
/// standard 2D interface and the immersive 3D experience.
///
/// ## How it works:
/// 1. The button checks the current state of the immersive space (open/closed/transitioning)
/// 2. When pressed, it either opens or closes the immersive space
/// 3. It handles the state transitions and error cases
/// 4. It disables itself during transitions to prevent multiple activations
///
/// This component uses visionOS environment values for opening and closing spaces,
/// which are core concepts in spatial computing apps.
struct ToggleImmersiveSpaceButton: View {
    // MARK: - Properties
    
    /// Access to the shared app model
    @EnvironmentObject private var appModel: AppModel

    /// Environment access to the dismiss immersive space action
    /// This is provided by visionOS for closing immersive spaces
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    /// Environment access to the open immersive space action
    /// This is provided by visionOS for opening immersive spaces
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    // MARK: - View Body
    
    /// The button view with toggle functionality
    var body: some View {
        // Create a button that triggers immersive space transitions
        Button {
            // Use Task for asynchronous operations
            Task { @MainActor in
                // Handle different states with a switch statement
                switch appModel.immersiveSpaceState {
                    case .open:
                        // CASE: Immersive space is open, so close it
                        
                        // Set transitioning state first to prevent multiple presses
                        appModel.immersiveSpaceState = .inTransition
                        
                        // Call the system method to dismiss the immersive space
                        await dismissImmersiveSpace()
                        
                        // NOTE: We don't set the state to .closed here
                        // ImmersiveView.onDisappear() will handle that
                        // This prevents state conflicts from multiple paths

                    case .closed:
                        // CASE: Immersive space is closed, so open it
                        
                        // Set transitioning state to prevent multiple presses
                        appModel.immersiveSpaceState = .inTransition
                        
                        // Try to open the immersive space and handle various results
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                // Successfully opened
                                // NOTE: We don't set the state to .open here
                                // ImmersiveView.onAppear() will handle that
                                break

                            case .userCancelled, .error:
                                // User cancelled or error occurred
                                // In both cases, we need to reset the state
                                fallthrough
                                
                            @unknown default:
                                // Handle any future cases that might be added to the API
                                // Reset to closed state since we couldn't open the space
                                appModel.immersiveSpaceState = .closed
                        }

                    case .inTransition:
                        // CASE: Already transitioning between states
                        // This case should never happen because the button is disabled
                        // during transitions, but we handle it for completeness
                        break
                }
            }
        } label: {
            // Dynamic button text based on current state
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        // Disable the button during transitions to prevent multiple activations
        .disabled(appModel.immersiveSpaceState == .inTransition)
        // Disable animations for this value change to prevent UI glitches
        .animation(.none, value: 0)
        // Make the text stand out
        .fontWeight(.semibold)
    }
}
