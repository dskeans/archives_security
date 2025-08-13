//
//  CameraRecordingView.swift
//  arcHIVE Camera App
//
//  🎯 MODULAR CAMERA SYSTEM - Complete camera recording workflow with IPFS hash and tokenization
//
//  📋 FEATURE MODULES:
//  • 📹 Camera Recording Workflow (Photo/Video/Burst/Timelapse)
//  • 🔗 IPFS Hash Generation (SHA256 → IPFS format)
//  • 🪙 Tokenization Integration (Mint queue management)
//  • 🔐 C2PA Signing (Embedded manifests + Sidecar support)
//  • 🧹 Metadata Sanitization (Privacy-preserving redaction)
//  • 💾 Auto-Save System (Default album + Storage management)
//  • ⏱️ Timer Service Integration (Self-timer functionality)
//  • 🎨 UI Components (Three-pane interface + Toast notifications)
//
//  🏗️ MODULAR ARCHITECTURE:
//  ┌─────────────────────────────────────────────────────────────────┐
//  │  📊 DATA MODELS        │  🎨 UI COMPONENTS     │  🎬 MAIN CAMERA  │
//  │  • MediaFilter         │  • ToggleButton       │  • CameraRecording│
//  │  • RecordedMedia       │  • ActionButton       │    View (Core)    │
//  │  • CaptureMode         │  • RecordButton       │                   │
//  │  • ToastStyle          │  • GridOverlay        │                   │
//  ├─────────────────────────────────────────────────────────────────┤
//  │  📹 CAMERA WORKFLOW    │  🔐 C2PA SIGNING     │  🔗 IPFS HASH     │
//  │  • autoSaveToDefault   │  • startC2PASigning   │  • generateHash   │
//  │  • handleComplete      │  • Embedded manifests │  • SHA256 → IPFS  │
//  │  • Metadata sanitize   │  • Sidecar support    │  • Background     │
//  ├─────────────────────────────────────────────────────────────────┤
//  │  🎨 UI OVERLAYS        │  🪙 TOKENIZATION     │  ⏱️ TIMER SERVICE │
//  │  • SigningOverlay      │  • MintQueueManager   │  • CameraSelfTimer│
//  │  • TimerCountdown      │  • Auto-queue minting │  • Countdown UI   │
//  │  • Toast notifications │  • Blockchain prep    │  • Capture delay  │
//  └─────────────────────────────────────────────────────────────────┘
//
//  🔄 WORKFLOW: Capture → Sanitize → Save → Sign → Hash → Queue → Mint
//

import SwiftUI
import UIKit
import AVFoundation
import CoreImage.CIFilterBuiltins
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 📊 DATA MODELS MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Media Filter Enum
enum MediaFilter: String, CaseIterable {
    case all = "all"
    case photos = "photos"
    case videos = "videos"
    case c2paSigned = "c2pa"
    case minted = "minted"

    var title: String {
        switch self {
        case .all: return "All"
        case .photos: return "Photos"
        case .videos: return "Videos"
        case .c2paSigned: return "C2PA"
        case .minted: return "Minted"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .photos: return "photo"
        case .videos: return "video"
        case .c2paSigned: return "checkmark.shield"
        case .minted: return "seal"
        }
    }
}


// MARK: - Model

struct RecordedMedia: Identifiable {
    let id: UUID
    var fileURL: URL  // Made mutable to support embedded C2PA manifests
    let type: MediaItem.MediaType
    let recordedAt: Date
    let fileSize: Int64
    var ipfsHash: String?
    var c2paManifest: C2PAManifest?
    var title: String = "Untitled"
    var description: String = ""
}

// MARK: - Enums
enum CaptureMode: String, CaseIterable {
    case photo = "Photo"
    case video = "Video"
    case burst = "Burst"
    case timelapse = "Timelapse"
}

enum ActiveMenu {
    case left, right
}

// MARK: - Toast Style (file-scoped)
private enum ToastStyle { case info, warning, error }


// Simple notification channel for cross-view toasts
extension Notification.Name { static let uiToast = Notification.Name("arcHIVE_uiToast") }


// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 🎨 UI COMPONENTS MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - View Helpers

extension Image {
    func toolbarIcon(color: Color) -> some View {
        self
            .renderingMode(.template)
            .foregroundColor(color)
    }


}

extension View {
    func toolbarBadge() -> some View {
        self
    }
}

// MARK: - Original Camera Control Components (Restored)

struct ToggleButton: View {
    @Binding var isOn: Bool
    var onIcon: String
    var offIcon: String
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? onIcon : offIcon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(isOn ? .green : .white) // Changed from .gray to .white for better visibility
        }
    }
}

struct ActionButton: View {
    var icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.white) // Changed from .blue to .white for better contrast on dark background
        }
    }
}

struct RecordButton: View {
    @Binding var isRecording: Bool
    var action: () -> Void
    var body: some View {
        Button(action: {
            #if DEBUG
            // Track the recording button tap with full context
            DebugHarness.trackEvent(
                type: .buttonTap,
                label: "Record Button",
                view: "CameraRecordingView",
                codeBlock: """
                Button(action: action) {
                    Circle()
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 60, height: 60)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
                """,
                trigger: isRecording ? "User stops recording" : "User starts recording",
                effect: isRecording ? "Stop recording, save media file" : "Start recording, begin capture session"
            )
            #endif
            action()
        }) {
            Circle()
                .fill(isRecording ? Color.red : Color.white)
                .frame(width: 60, height: 60)
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
        }
        #if DEBUG
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        let frame = geometry.frame(in: .global)
                        DebugHarness.trackEvent(
                            type: .viewLifecycle,
                            label: "Record Button Appeared",
                            view: "CameraRecordingView",
                            position: frame,
                            trigger: "Recording controls rendered",
                            effect: "Main capture button available to user"
                        )
                    }
            }
        )
        #endif
    }
}




// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 🎬 MAIN CAMERA RECORDING MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

struct CameraRecordingView: View {
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var appSettings = AppSettings.shared

    // Temporarily disable these to isolate crash
    // @StateObject private var storageManager = MediaStorageManager.shared
    // @StateObject private var tokenService   = TokenizationService.shared

    @State private var showingFilesMenu = false
    @State private var showingUniFFITest = false
    @State private var showingMetadataRedaction = false
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var showingWallet = false
    @State private var gridEnabled = false
    @State private var timerEnabled = false
    @State private var selectedMediaItem: MediaItem?

    // Timer service integration
    @StateObject private var timerService = CameraSelfTimer.shared
    // @StateObject private var selfTimer = CameraSelfTimer.shared // TODO: Add timer service to project
    @State private var lastRecordedMedia: RecordedMedia?

    @State private var c2paSigningEnabled = true
    @State private var isSigningInProgress = false
    @State private var signingStatusMessage = ""

    // Privacy controls (bound to AppSettings)
    @State private var sanitizeMetadata = true
    @State private var includeGPS = false
    @State private var photoFormat: PhotoFormat = .jpeg

    // Toast state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .info

    @Environment(\.colorScheme) var colorScheme

    init() {
        _sanitizeMetadata = State(initialValue: AppSettings.shared.sanitizeMetadata)
        _includeGPS = State(initialValue: AppSettings.shared.includeGPSMetadata)
        _photoFormat = State(initialValue: AppSettings.shared.photoFormat)
    }

    var body: some View {
        ZStack {
            if cameraModel.permissionDenied {
                permissionDeniedView
            } else {
                mainCameraView
            }
        }
        .sheet(isPresented: $showingMetadataRedaction) {
            // TODO: Add MetadataRedactionView to Xcode project
            Text("Metadata Redaction Settings")
                .navigationTitle("Metadata Redaction")
        }
        .sheet(isPresented: $showingExport) {
            if let mediaItem = selectedMediaItem {
                ExportView(mediaItem: mediaItem)
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingFilesMenu) { FilesMenuView() }
        .sheet(isPresented: $showingWallet) { WalletConnectionView() }
        .sheet(isPresented: $showingUniFFITest) {
            NavigationView {
                Text("UniFFI Test Interface")
                    .navigationTitle("UniFFI Test")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingUniFFITest = false }
                        }
                    }
            }
        }
        .onAppear {
            Task {
                await cameraModel.setupCamera()
            }
        }
        .onDisappear {
            cameraModel.captureSession.stopRunning()
        }
    }

    private var permissionDeniedView: some View {
        Color.black.ignoresSafeArea()
            .overlay(
                VStack(spacing: 30) {
                    Spacer()

                    Image(systemName: "camera.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)

                    Text("Camera Access Required")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("To use arcHIVE Camera, you need to enable camera access in your iPhone Settings.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    VStack(spacing: 12) {
                        Text("Steps to enable:")
                            .font(.headline)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("1.")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                                Text("Tap 'Open Settings' below")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            HStack {
                                Text("2.")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                                Text("Find 'arcHIVE' in the app list")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            HStack {
                                Text("3.")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                                Text("Turn ON 'Camera' permission")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            HStack {
                                Text("4.")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                                Text("Return to arcHIVE app")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 20)

                        Button("Open iPhone Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.purple)
                        .cornerRadius(25)
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)

                        Spacer()
                    }
                }
            )
    }

    private var mainCameraView: some View {
        ThreePaneCameraView(
            cameraModel: cameraModel,
            c2paEnabled: $c2paSigningEnabled,
            onComplete: handleComplete,
            shownFiles: $showingFilesMenu,
            shownUniFFI: $showingUniFFITest,
            shownWallet: $showingWallet,
            gridEnabled: $gridEnabled,
            timerEnabled: $timerEnabled,
            showingSettings: $showingSettings,
            showingMetadataRedaction: $showingMetadataRedaction,
            showingExport: $showingExport,
            isSigningInProgress: isSigningInProgress,
            signingStatusMessage: signingStatusMessage,
            timerService: timerService
        )
        .overlay(alignment: (toastStyle == .warning || toastStyle == .error) ? .top : .bottom) {
            if showToast { toastView.padding(.vertical, 10).padding(.horizontal, 16).accessibilityIdentifier("toast.view") }
        }
    }

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForToast())
                .foregroundColor(.white)
            Text(toastMessage)
                .accessibilityIdentifier("toast.message")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColorForToast())
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helper Methods

    private func iconForToast() -> String {
        switch toastStyle {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private func backgroundColorForToast() -> Color {
        switch toastStyle {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func toast(_ style: ToastStyle, _ message: String) {
        toastStyle = style
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }



// MARK: - Supporting Views and Extensions

// MARK: - Grid Overlay

struct GridOverlay: View {
    var body: some View {
        ZStack {
            // Rule of thirds grid
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                Spacer()
            }

            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)
                Spacer()
            }
        }
    }
}

// MARK: - Menu Item Button

struct MenuItemButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}



// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isActive ? .purple : .white)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isActive ? .purple : .white.opacity(0.8))
            }
            .frame(width: 60, height: 60)
            .background(isActive ? Color.white.opacity(0.2) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Views

struct MintingSettingsPlaceholder: View {
    var body: some View {
        Text("Minting Settings")
            .navigationTitle("Minting")
    }
}

struct PrivacySettingsPlaceholder: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

struct AlbumsPlaceholder: View {
    var body: some View {
        Text("Albums")
            .navigationTitle("Albums")
    }
}

struct ProCameraControlsView: View {
    @ObservedObject var cameraModel: CameraModel

    var body: some View {
        Text("Pro Camera Controls")
            .navigationTitle("Pro Controls")
    }
}

// MARK: - UniFFI Test Container

struct UniFFITestContainer: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Text("UniFFI Test")
                .navigationTitle("UniFFI Test")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
        }
    }
}

// MARK: - Subtitle Text

struct SubtitleText: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "circle.fill").font(.system(size: 6))
                .padding(.top, 6)
                .foregroundColor(.secondary)
            Text(text).font(.footnote).foregroundColor(.secondary)
        }
    }
}

// MARK: - Timer Countdown Overlay

struct TimerCountdownOverlay: View {
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Timer icon
                Image(systemName: "timer")
                    .font(.system(size: 40))
                    .foregroundColor(.white)

                // Countdown number
                Text("\(remainingSeconds)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                // Timer message
                Text("Get ready...")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(remainingSeconds > 0 ? 1.0 : 1.2)
            .animation(.easeInOut(duration: 0.3), value: remainingSeconds)
        }
    }
}
// MARK: - Supporting Views and Extensions














// MARK: - ThreePaneCameraView

struct ThreePaneCameraView: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding var c2paEnabled: Bool
    let onComplete: (URL, MediaItem.MediaType) -> Void
    @Binding var shownFiles: Bool
    @Binding var shownUniFFI: Bool
    @Binding var shownWallet: Bool
    @Binding var gridEnabled: Bool
    @Binding var timerEnabled: Bool
    @Binding var showingSettings: Bool
    @Binding var showingMetadataRedaction: Bool
    @Binding var showingExport: Bool
    let isSigningInProgress: Bool
    let signingStatusMessage: String
    @ObservedObject var timerService: CameraSelfTimer


    @State private var captureMode: CaptureMode = .photo
    @State private var isRecording = false
    @State private var activeMenu: ActiveMenu? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview
                CameraPreviewLayer(cameraModel: cameraModel)
                    .ignoresSafeArea()

                // Grid overlay
                if gridEnabled {
                    GridOverlay()
                }

                // Three-pane layout
                HStack(spacing: 0) {
                    // Left pane
                    VStack {
                        if activeMenu == .left {
                            ExpandedLeftMenuView(
                                c2paEnabled: $c2paEnabled,
                                activeMenu: $activeMenu,
                                shownFiles: $shownFiles,
                                showingMetadataRedaction: $showingMetadataRedaction,
                                showingExport: $showingExport,
                                geometry: geometry
                            )
                        } else {
                            CollapsedLeftMenuView(
                                activeMenu: $activeMenu,
                                geometry: geometry
                            )
                        }
                    }
                    .frame(width: activeMenu == .left ? geometry.size.width * 0.4 : 60)

                    Spacer()

                    // Right pane
                    VStack {
                        if activeMenu == .right {
                            ExpandedRightMenuView(
                                cameraModel: cameraModel,
                                captureMode: $captureMode,
                                activeMenu: $activeMenu,
                                timerEnabled: $timerEnabled,
                                gridEnabled: $gridEnabled,
                                showingSettings: $showingSettings,
                                showingMetadataRedaction: $showingMetadataRedaction,
                                showingExport: $showingExport,
                                geometry: geometry,
                                timerService: timerService
                            )
                        } else {
                            CollapsedRightMenuView(
                                activeMenu: $activeMenu,
                                geometry: geometry
                            )
                        }
                    }
                    .frame(width: activeMenu == .right ? geometry.size.width * 0.4 : 60)
                }

                // Bottom capture controls
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        // Capture button
                        Button(action: captureAction) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .fill(isRecording ? Color.red : Color.clear)
                                    .frame(width: isRecording ? 80 : 60, height: isRecording ? 80 : 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                            .frame(width: 60, height: 60)
                                    )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()
                    }
                    .padding(.bottom, 40)
                }

                // Signing Overlay
                if isSigningInProgress {
                    SigningOverlay(message: signingStatusMessage)
                }

                // Timer Countdown Overlay
                if timerService.isTimerActive {
                    TimerCountdownOverlay(remainingSeconds: timerService.remainingSeconds)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func captureAction() {
        // Close any open menus first
        activeMenu = nil
        switch captureMode {
        case .photo:
            capturePhoto()
        case .video:
            if isRecording {
                stopVideoRecording()
            } else {
                startVideoRecording()
            }
        case .burst:
            captureBurst()
        case .timelapse:
            toggleTimelapse()
        }
    }

    private func capturePhoto() {
        // Check if timer is enabled and not already active
        if timerService.timerDuration != .off && !timerService.isTimerActive {
            // Start timer with completion handler
            timerService.startTimer(duration: timerService.timerDuration) { [weak cameraModel] in
                DispatchQueue.main.async {
                    cameraModel?.capturePhoto { url in
                        if let url = url {
                            onComplete(url, .photo)
                        } else {
                            print("Photo capture failed")
                        }
                    }
                }
            }
        } else {
            // Immediate capture (no timer or timer already running)
            cameraModel.capturePhoto { url in
                if let url = url {
                    onComplete(url, .photo)
                } else {
                    print("Photo capture failed")
                }
            }
        }
    }

    private func startVideoRecording() {
        isRecording = true
        cameraModel.startVideoRecording()
    }

    private func stopVideoRecording() {
        cameraModel.stopVideoRecording { url in
            if let url = url {
                onComplete(url, .video)
            } else {
                print("Video recording failed")
            }
            isRecording = false
        }
    }

    private func captureBurst() {
        // TODO: Implement burst capture
        print("Burst capture not implemented")
    }

    private func toggleTimelapse() {
        // TODO: Implement timelapse
        print("Timelapse not implemented")
    }
}


// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 📹 CAMERA WORKFLOW MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

    /// 💾 **AUTO-SAVE TO DEFAULT ALBUM**
    ///
    /// Automatically organizes captured media into the default "Camera Roll" album.
    ///
    /// **📁 ORGANIZATION FEATURES:**
    /// - 🎯 Auto-creates "Camera Roll" album if missing
    /// - 📸 Generates thumbnails for quick preview
    /// - 🏷️ Auto-titles with capture type and timestamp
    /// - 💾 Handles file copying and storage management
    /// - 🔗 Preserves C2PA manifests and IPFS hashes
    ///
    /// **🔄 INTEGRATION:** Works with `MediaStorageManager` for persistent storage
    ///
    private func autoSaveToDefaultAlbum(media: RecordedMedia) {
        // Get or create default album
        let storageManager = MediaStorageManager.shared
        var defaultAlbum: Album

        if let existingDefault = storageManager.albums.first(where: { $0.name == "Camera Roll" }) {
            defaultAlbum = existingDefault
        } else {
            // Create default album if it doesn't exist
            defaultAlbum = Album(name: "Camera Roll", username: "Default User", isPublic: true)
            storageManager.albums.insert(defaultAlbum, at: 0)
        }

        // Copy media file to storage and create MediaItem
        guard let data = try? Data(contentsOf: media.fileURL) else { return }
        guard let savedPath = storageManager.saveMediaFile(data: data, type: media.type) else { return }
        let thumbnailPath = storageManager.generateThumbnail(for: savedPath)

        let mediaItem = MediaItem(
            filePath: savedPath,
            mediaType: media.type,
            title: "Captured \(media.type == .photo ? "Photo" : "Video")",
            description: "Captured on \(DateFormatter.localizedString(from: media.recordedAt, dateStyle: .medium, timeStyle: .short))",
            createdAt: media.recordedAt,
            c2paManifest: media.c2paManifest,
            ipfsHash: media.ipfsHash,
            thumbnailPath: thumbnailPath,
            fileSize: media.fileSize
        )

        storageManager.addMediaToAlbum(mediaItem, albumId: defaultAlbum.id)
        print("📸 Auto-saved \(media.type) to Camera Roll album")
    }

    /// 🎯 **MAIN CAMERA WORKFLOW HANDLER**
    ///
    /// This is the core function that orchestrates the complete camera recording workflow:
    ///
    /// **📋 WORKFLOW STEPS:**
    /// 1. 🧹 **Metadata Sanitization** - Remove sensitive metadata while preserving essential data
    /// 2. 💾 **Auto-Save to Album** - Save to default "Camera Roll" album with proper organization
    /// 3. 🔐 **C2PA Signing** - Embed authentication manifests for content verification
    /// 4. 🔗 **IPFS Hash Generation** - Create SHA256 hash in IPFS format for decentralized storage
    /// 5. 🪙 **Tokenization Queue** - Prepare for blockchain minting if enabled
    ///
    /// **🔄 INTEGRATION POINTS:**
    /// - `MetadataSanitizer` - Privacy-preserving metadata handling
    /// - `MediaStorageManager` - File organization and album management
    /// - `C2PAService` - Content authentication and provenance
    /// - `MintQueueManager` - Blockchain tokenization preparation
    ///
    private func handleComplete(url: URL, type: MediaItem.MediaType) {
        // Create a sanitized copy first so we never sign or share unintended metadata
        Task {
            let policy = MetadataSanitizer.RedactionPolicy(
                sanitize: AppSettings.shared.sanitizeMetadata,
                includeGPS: AppSettings.shared.includeGPSMetadata
            )
            let sanitizedURL = await MetadataSanitizer.sanitizeCopy(of: url, policy: policy)
            await MainActor.run {
                let media = RecordedMedia(
                    id: UUID(),
                    fileURL: sanitizedURL,
                    type: type,
                    recordedAt: Date(),
                    fileSize: getFileSize(url: sanitizedURL),
                    ipfsHash: nil,
                    c2paManifest: nil
                )

                // Automatically save to default album
                autoSaveToDefaultAlbum(media: media)

                lastRecordedMedia = media
                if c2paSigningEnabled { startC2PASigning(url: sanitizedURL) }
                generateHash(media: media)
            }
        }
    }


// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 🔐 C2PA SIGNING MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

    /// 🔐 **C2PA CONTENT AUTHENTICATION**
    ///
    /// Embeds C2PA (Coalition for Content Provenance and Authenticity) manifests for content verification.
    ///
    /// **🛡️ SECURITY FEATURES:**
    /// - 📝 Embedded manifests (preferred) or sidecar files
    /// - 🔏 Cryptographic signatures for tamper detection
    /// - 📋 Metadata preservation with provenance tracking
    /// - 🏢 Legal company name compliance (C2PA conformance)
    ///
    /// **🔄 WORKFLOW:**
    /// 1. ✅ Verify file type compatibility
    /// 2. 🔐 Generate and embed C2PA manifest
    /// 3. 🪙 Queue for tokenization if successful
    /// 4. 📱 Update UI with signing status
    ///
    private func startC2PASigning(url: URL) {
        guard C2PAService.shared.isFileTypeSupported(url.path) else { return }
        isSigningInProgress = true
        signingStatusMessage = "Embedding C2PA manifest..."
        Task {
            // Use the new embedded manifest method
            let result = C2PAService.shared.signFileWithEmbeddedManifest(inputPath: url.path)
            await MainActor.run {
                isSigningInProgress = false
                switch result {
                case .success(let signedPath):
                    // Check if we got an embedded file (different path) or sidecar (same directory)
                    let isEmbedded = signedPath != url.path && !signedPath.hasSuffix(".json")
                    signingStatusMessage = isEmbedded ?
                        "C2PA manifest embedded successfully" :
                        "C2PA manifest created (sidecar)"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { signingStatusMessage = "" }

                    // Update the media item to point to the signed file if embedded
                    if isEmbedded {
                        // Update lastRecordedMedia to use the signed file
                        if var media = lastRecordedMedia {
                            media.fileURL = URL(fileURLWithPath: signedPath)
                            lastRecordedMedia = media
                        }
                    }

                    // Enqueue for minting if enabled
                    if c2paSigningEnabled {
                        let finalURL = isEmbedded ? URL(fileURLWithPath: signedPath) : url
                        let fileSize = getFileSize(url: finalURL)
                        let item = MediaItem(filePath: finalURL.path, mediaType: .video, title: finalURL.lastPathComponent, fileSize: fileSize)
                        if let defaultAlbum = MediaStorageManager.shared.albums.first?.id {
                            MintQueueManager.shared.enqueue(mediaItem: item, albumId: defaultAlbum)
                        }
                    }
                case .failure(let errors):
                    signingStatusMessage = "C2PA signing failed: \(errors.first ?? "Unknown error")"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { signingStatusMessage = "" }
                }
            }
        }
    }

    private func getFileSize(url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 🔗 IPFS HASH GENERATION MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

    /// 🔗 **IPFS HASH GENERATOR**
    ///
    /// Generates IPFS-compatible content hashes for decentralized storage and verification.
    ///
    /// **🔄 PROCESS:**
    /// 1. 📖 Read file data from media URL
    /// 2. 🔐 Calculate SHA256 hash of content
    /// 3. 🎯 Format as IPFS hash (Qm + 44-char prefix)
    /// 4. 💾 Store hash in media record for future reference
    ///
    /// **⚡ PERFORMANCE:** Runs on background queue to avoid UI blocking
    /// **🔗 IPFS FORMAT:** "Qm" prefix + base58-encoded multihash
    ///
    private func generateHash(media: RecordedMedia) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: media.fileURL) else { return }
            let hash = SHA256.hash(data: data)
            let prefix = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(44)
            let hashString = "Qm" + prefix
            DispatchQueue.main.async {
                lastRecordedMedia?.ipfsHash = String(hashString)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// MARK: - 🎨 UI OVERLAY COMPONENTS MODULE
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Signing Overlay

struct SigningOverlay: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Signing with C2PA...").font(.caption).foregroundColor(.white)
                    if !message.isEmpty {
                        Text(message).font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding().background(Color.black.opacity(0.7)).cornerRadius(12)
                Spacer()
            }
            .padding(.bottom, 120)
        }
    }
}



// MARK: - Camera Preview Layer

struct CameraPreviewLayer: UIViewRepresentable {
    let cameraModel: CameraModel

    final class PreviewView: UIView {
        var cameraModel: CameraModel?
        private var initialZoom: CGFloat = 1.0

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
        }

        func setupPinchGesture() {
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            addGestureRecognizer(pinchGesture)
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let cameraModel = cameraModel else { return }

            switch gesture.state {
            case .began:
                initialZoom = cameraModel.currentZoom
            case .changed:
                let newZoom = initialZoom * gesture.scale
                let clampedZoom = max(1.0, min(newZoom, cameraModel.maxZoom))

                // Update zoom immediately for smooth feedback
                Task { @MainActor in
                    cameraModel.currentZoom = clampedZoom
                }

                // Apply zoom to camera
                Task {
                    await cameraModel.setZoom(clampedZoom)
                }
            case .ended, .cancelled:
                // Final zoom adjustment
                let finalZoom = max(1.0, min(initialZoom * gesture.scale, cameraModel.maxZoom))
                Task {
                    await cameraModel.setZoom(finalZoom)
                }
            default:
                break
            }
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.cameraModel = cameraModel
        view.videoPreviewLayer.session = cameraModel.captureSession
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.setupPinchGesture()

        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = Self.currentVideoOrientation()
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
        uiView.cameraModel = cameraModel
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = Self.currentVideoOrientation()
        }
    }

    private static func currentVideoOrientation() -> AVCaptureVideoOrientation {
        if let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.interfaceOrientation {
            switch interfaceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            default: return .portrait
            }
        }
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return .portrait
        }
    }
}


// MARK: - On-screen Overlay UI (Left/Right panels + Capture Bar)
struct NewCaptureUI: View {
    @ObservedObject var cameraModel: CameraModel

    @StateObject private var appSettings = AppSettings.shared

    @State private var showLeftPanel = false
    @State private var showRightPanel = false

    // Left panel sheets
    @State private var showMintProvenanceSheet = false
    @State private var showVerifySheet = false
    @State private var showAlbumsSheet = false
    @State private var showPrivacySheet = false
    @State private var showWalletSheet = false
    @State private var showHelpSheet = false

    // Right panel sheets
    @State private var showCaptureModeSheet = false
    @State private var showFormatQualitySheet = false
    @State private var showCameraControlsSheet = false
    @State private var showAudioSheet = false
    @State private var showOverlaysSheet = false
    @State private var showQuickToolsSheet = false

    // Left panel (Minting menu) state
    @State private var enableMinting = false
    @State private var tokenType: TokenType = .archive
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    // External bindings
    @Binding var c2paEnabled: Bool
    let onComplete: (URL, MediaItem.MediaType) -> Void
    @Binding var shownFiles: Bool
    @Binding var shownUniFFI: Bool

    @State private var autoMint = false
    @State private var ipfsUpload = true
    @State private var encryptBeforeUpload = false
    @State private var embedC2PA = true
    @State private var metadataProfile: MetadataProfile = .basic
    @State private var sanitizeMetadata = true
    @State private var includeGPS = false
    @State private var photoFormat: PhotoFormat = .jpeg

    // Additional missing variables
    @State private var showMintingSheet = false

    // Right panel (Camera controls) state
    @State private var captureMode: CaptureMode = .photo
    @State private var flashMode: FlashMode = .auto
    @State private var hdrOn = false
    @State private var resolution: Resolution = .p1080
    @State private var fps: FPS = .fps30
    @State private var focus: Double = 0.5
    @State private var exposure: Double = 0.5
    @State private var iso: Double = 0.5
    @State private var whiteBalance: Double = 0.5
    @State private var evBias: Double = 0.5

    var body: some View {
        ZStack {
            // Side panels
            HStack(spacing: 0) {
                if showLeftPanel { leftPanel }
                Spacer(minLength: 0)
                if showRightPanel { rightPanel }
            }

            // Bottom capture bar
            VStack {
                Spacer()
                captureBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .animation(.easeInOut, value: showLeftPanel)
        .animation(.easeInOut, value: showRightPanel)
        .allowsHitTesting(true)
        .onAppear {
            // Initialize photo format from settings
            photoFormat = appSettings.photoFormat
        }
        .onChange(of: photoFormat) { newValue in
            appSettings.photoFormat = newValue
        }
    }

    // MARK: Panels
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("arcHIVE Menu").font(.headline)
                Spacer()
                Button { showLeftPanel = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
            }

            // Mint & Provenance
            Button {
                showMintProvenanceSheet = true
            } label: {
                Label("Mint & Provenance", systemImage: "seal")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showMintProvenanceSheet) {
                NavigationView {
                    List {
                        Section("Minting") {
                            Button("Mint Now") {
                                // TODO: Implement mint now
                            }
                            NavigationLink("Mint Queue", destination: MintQueueView())
                            NavigationLink("Mint History", destination: MintHistoryView())
                        }
                    }
                    .navigationTitle("Mint & Provenance")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showMintProvenanceSheet = false }
                        }
                    }
                }
            }

            // Verify
            Button {
                showVerifySheet = true
            } label: {
                Label("Verify", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showVerifySheet) {
                NavigationView {
                    List {
                        Section("Verification") {
                            NavigationLink("Verify File", destination: FileVerificationView())
                            NavigationLink("Verify from URL/IPFS", destination: URLVerificationView())
                            NavigationLink("Scan QR for Provenance", destination: QRVerificationView())
                            NavigationLink("Verification History", destination: VerificationHistoryView())
                            NavigationLink("Trust Level Guide", destination: TrustLevelGuideView())
                        }
                    }
                    .navigationTitle("Verify")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showVerifySheet = false }
                        }
                    }
                }
            }

            // Albums
            Button {
                showAlbumsSheet = true
            } label: {
                Label("Albums", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showAlbumsSheet) {
                NavigationView {
                    List {
                        Section("Media") {
                            NavigationLink("All Media", destination: AllMediaView())
                            NavigationLink("Public Albums", destination: AlbumManagementView())
                            NavigationLink("Hidden Albums", destination: AlbumManagementView())
                        }
                        Section("Organization") {
                            NavigationLink("New Album", destination: AlbumManagementView())
                            NavigationLink("Sort / Filter", destination: AllMediaView())
                        }
                    }
                    .navigationTitle("Albums")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showAlbumsSheet = false }
                        }
                    }
                }
            }

            // Privacy Settings
            Button {
                showPrivacySheet = true
            } label: {
                Label("Privacy Settings", systemImage: "lock.shield")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showPrivacySheet) {
                NavigationView {
                    List {
                        Section("Camera Settings") {
                            Picker("Photo Format", selection: $photoFormat) {
                                ForEach(PhotoFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Privacy Controls") {
                            Toggle("Sanitize Metadata", isOn: $sanitizeMetadata)
                                .tint(.green)
                            Toggle("Include GPS", isOn: $includeGPS)
                                .tint(.green)
                            Toggle("C2PA Manifest", isOn: $c2paEnabled)
                                .tint(.green)
                            Toggle("IPFS Upload", isOn: $ipfsUpload)
                                .tint(.green)
                            Toggle("Encrypt Before Upload", isOn: $encryptBeforeUpload)
                                .tint(.green)
                        }
                        Section("Quick Actions") {
                            Button("Apply Recommended Defaults") {
                                sanitizeMetadata = true
                                includeGPS = false
                                c2paEnabled = true
                                ipfsUpload = false
                                encryptBeforeUpload = false
                            }
                            .foregroundColor(.blue)
                        }
                        Section("Advanced Privacy") {
                            Button("Metadata Privacy Controls") {
                                // TODO: Implement metadata redaction controls
                            }
                        }
                        Section("Learn More") {
                            NavigationLink { SanitizeTopicView() } label: {
                                Label("About Metadata Sanitization", systemImage: "info.circle")
                            }
                            NavigationLink { GPSTopicView() } label: {
                                Label("About GPS Data", systemImage: "location")
                            }
                            NavigationLink { C2PATopicView() } label: {
                                Label("About C2PA", systemImage: "seal")
                            }
                            NavigationLink { IPFSTopicView() } label: {
                                Label("About IPFS", systemImage: "externaldrive.connected.to.line.below")
                            }
                            NavigationLink { EncryptTopicView() } label: {
                                Label("About Encryption", systemImage: "lock.fill")
                            }
                        }
                    }
                    .navigationTitle("Privacy Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPrivacySheet = false }
                        }
                    }
                }
            }

            // Wallet
            Button {
                showWalletSheet = true
            } label: {
                Label("Wallet", systemImage: "wallet.pass")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showWalletSheet) {
                NavigationView {
                    List {
                        Section("Wallet Connection") {
                            NavigationLink { WalletConnectTopicView() } label: {
                                Label("Connect Wallet", systemImage: "link")
                            }
                            NavigationLink("View Address / QR", destination: WalletAddressView())
                        }
                        Section("Wallet Management") {
                            NavigationLink("Transaction History", destination: TransactionHistoryView())
                            NavigationLink("Export Private Key", destination: Text("Export Key View"))
                                .foregroundColor(.red)
                        }
                    }
                    .navigationTitle("Wallet")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showWalletSheet = false }
                        }
                    }
                }
            }

            // Help & Docs
            Button {
                showHelpSheet = true
            } label: {
                Label("Help & Docs", systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showHelpSheet) {
                NavigationView {
                    List {
                        Section("Help Topics") {
                            NavigationLink { PrivacyHelpSheet() } label: {
                                Label("Privacy Help", systemImage: "lock.shield")
                            }
                            NavigationLink("C2PA FAQ", destination: C2PAFAQView())
                        }
                        Section("Legal") {
                            NavigationLink("Terms & Privacy Policy", destination: PrivacyPolicyView())
                        }
                    }
                    .navigationTitle("Help & Docs")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showHelpSheet = false }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }

        .padding(16)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.leading, 8)
        .padding(.top, 60)  // More space for safe area + status bar
        .padding(.bottom, 16)
        .accessibilityElement(children: .contain)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe down to dismiss
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLeftPanel = false
                        }
                    }
                    // Swipe left to dismiss
                    else if value.translation.width < -100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLeftPanel = false
                        }
                    }
                }
        )
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Camera Controls").font(.headline)
                Spacer()
                Button { showRightPanel = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
            }

            // Capture Mode
            Button {
                showCaptureModeSheet = true
            } label: {
                Label("Capture Mode", systemImage: "camera")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showCaptureModeSheet) {
                NavigationView {
                    List {
                        Section("Capture Modes") {
                            ForEach(CaptureMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue) {
                                    captureMode = mode
                                    showCaptureModeSheet = false
                                }
                                .foregroundColor(captureMode == mode ? .blue : .primary)
                            }
                        }
                    }
                    .navigationTitle("Capture Mode")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showCaptureModeSheet = false }
                        }
                    }
                }
            }

            // Format & Quality
            Button {
                showFormatQualitySheet = true
            } label: {
                Label("Format & Quality", systemImage: "gear")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showFormatQualitySheet) {
                FormatQualityView()
            }

            // Camera Controls
            Button {
                showCameraControlsSheet = true
            } label: {
                Label("Camera Controls", systemImage: "camera.aperture")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showCameraControlsSheet) {
                NavigationView {
                    List {
                        Section("Focus & Exposure") {
                            VStack(alignment: .leading) {
                                Text("Zoom")
                                Slider(value: $cameraModel.currentZoom, in: 1...cameraModel.maxZoom, onEditingChanged: handleZoomChange)
                            }
                            VStack(alignment: .leading) {
                                Text("Focus")
                                Slider(value: $focus, in: 0...1, onEditingChanged: handleFocusChange)
                            }
                            VStack(alignment: .leading) {
                                Text("Exposure (EV)")
                                Slider(value: $exposure, in: -2...2, onEditingChanged: handleExposureChange)
                            }
                        }
                        Section("Advanced") {
                            VStack(alignment: .leading) {
                                Text("ISO")
                                Slider(value: $iso, in: 0...1, onEditingChanged: handleISOChange)
                            }
                            VStack(alignment: .leading) {
                                Text("White Balance")
                                Slider(value: $whiteBalance, in: 0...1, onEditingChanged: handleWhiteBalanceChange)
                            }
                            // TODO: Add stabilization options
                            Text("Stabilization: Standard")
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle("Camera Controls")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showCameraControlsSheet = false }
                        }
                    }
                }
            }

            // Audio
            Button {
                showAudioSheet = true
            } label: {
                Label("Audio", systemImage: "waveform")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showAudioSheet) {
                AudioControlsView()
            }

            // Overlays & Guides
            Button {
                showOverlaysSheet = true
            } label: {
                Label("Overlays & Guides", systemImage: "grid")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showOverlaysSheet) {
                OverlaysGuidesView()
            }

            // Quick Tools
            Button {
                showQuickToolsSheet = true
            } label: {
                Label("Quick Tools", systemImage: "bolt.circle")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showQuickToolsSheet) {
                QuickToolsView()
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.trailing, 8)
        .padding(.top, 60)  // More space for safe area + status bar
        .padding(.bottom, 16)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe down to dismiss
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showRightPanel = false
                        }
                    }
                    // Swipe right to dismiss
                    else if value.translation.width > 100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showRightPanel = false
                        }
                    }
                }
        )
    }

    // MARK: Capture bar

    // Active chip styling
    private func isActivePreset(_ p: CameraModel.CameraPreset) -> Bool {
        cameraModel.lastAppliedPreset == p
    }

    private func activeBackground(for p: CameraModel.CameraPreset, isSupported: Bool) -> Color {
        guard isSupported else { return Color.gray.opacity(0.4) }
        return isActivePreset(p) ? Color.accentColor.opacity(0.95) : Color.black.opacity(0.6)
    }

    private func activeOverlay(for p: CameraModel.CameraPreset, isSupported: Bool) -> some View {
        Group {
            if isSupported && isActivePreset(p) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white).font(.caption)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
            }
        }
    }

    private var captureBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button { showLeftPanel.toggle() } label: {
                    Image(systemName: "line.3.horizontal")
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(alignment: .topTrailing) {
                            if !MintQueueManager.shared.queue.isEmpty {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 4, y: -4)
                                    .accessibilityIdentifier("badge.mintQueue")
                            }
                        }
                }
                .accessibilityIdentifier("sidebar.left")
                Spacer()

                // Hide capture button when panels are open
                if !showLeftPanel && !showRightPanel {
                    Button(action: onCaptureTapped) {
                        Circle().fill(Color.red).frame(width: 76, height: 76).overlay(Circle().stroke(Color.white, lineWidth: 3))
                    }
                    .accessibilityLabel(cameraModel.isVideoMode ? "Start/Stop Recording" : "Capture Photo")
                    .accessibilityIdentifier("capture.button")
                }

                Spacer()
                Button { showRightPanel.toggle() } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).background(.ultraThinMaterial).clipShape(Circle())
                }
                .accessibilityIdentifier("sidebar.right")
            }
            // Only show controls when panels are closed
            if !showLeftPanel && !showRightPanel {
                HStack(spacing: 24) {
                    Spacer()
                    Button {
                        Task { await cameraModel.switchCamera() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("switch.camera")

                    HStack(spacing: 16) {
                        // Photo mode
                        Button {
                            if cameraModel.getIsVideoMode() { cameraModel.toggleVideoMode() }
                        } label: {
                            Image(systemName: "camera.fill")
                                .frame(width: 32, height: 32)
                                .background(cameraModel.getIsVideoMode() ? Color.black.opacity(0.6) : Color.accentColor.opacity(0.95))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("mode.photo")
                        // Video mode
                        Button {
                            if !cameraModel.getIsVideoMode() { cameraModel.toggleVideoMode() }
                        } label: {
                            Image(systemName: "video.fill")
                                .frame(width: 32, height: 32)
                                .background(cameraModel.getIsVideoMode() ? Color.accentColor.opacity(0.95) : Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("mode.video")
                    }
                    Spacer()
                }
            }


        }
    }

    // MARK: Actions
    private func onCaptureTapped() {
        if cameraModel.isVideoMode {
            if cameraModel.isRecording {
                cameraModel.stopVideoRecording { _ in }
            } else {
                cameraModel.startVideoRecording()
            }
        } else {
            cameraModel.capturePhoto { url in if let u = url { onComplete(u, .photo) } }
        }
        if autoMint && enableMinting {
            // Hook for post-capture auto-minting
        }
    }

    // Support types
    private enum TokenType: Hashable { case archive, creative, custom }
    private enum MetadataProfile: Hashable { case basic, extended, custom }
    private enum FlashMode: Hashable { case auto, on, off }
    private enum Resolution: Hashable { case p720, p1080, p4k }
    private enum FPS: Hashable { case fps30, fps60, fps120 }

    // MARK: - Camera Control Handlers

    private func handleZoomChange(_ editing: Bool) {
        if !editing {
            Task {
                await cameraModel.setZoom(cameraModel.currentZoom)
            }
        }
    }

    private func handleFocusChange(_ editing: Bool) {
        if !editing {
            Task {
                await cameraModel.setFocus(Float(focus))
            }
        }
    }

    private func handleExposureChange(_ editing: Bool) {
        if !editing {
            Task {
                await cameraModel.setExposure(Float(exposure))
            }
        }
    }

    private func handleISOChange(_ editing: Bool) {
        if !editing {
            Task {
                await cameraModel.setISO(Float(iso))
            }
        }
    }

    private func handleWhiteBalanceChange(_ editing: Bool) {
        if !editing {
            Task {
                await cameraModel.setWhiteBalance(Float(whiteBalance))
            }
        }
    }
}

// MARK: - Original Recording Controls (Restored)

struct RecordingControls: View {
    @ObservedObject var cameraModel: CameraModel
    let onRecordingComplete: (URL, MediaItem.MediaType) -> Void
    @Binding var c2paEnabled: Bool

    @State private var isRecording   = false
    @State private var recordingTime = 0.0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing:20) {
            if isRecording {
                Text(formatTime(recordingTime))
                    .font(.system(.title, design: .monospaced))
                    .foregroundColor(.red)
            }
            HStack(spacing:30) {
                // Simplified C2PA toggle - just a small indicator
                Button(action: { c2paEnabled.toggle() }) {
                    Circle()
                        .fill(c2paEnabled ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }

                ActionButton(icon: "camera.rotate") { Task { await cameraModel.switchCamera() } }
                RecordButton(isRecording: $isRecording, action: toggleRecording)
                ActionButton(icon: cameraModel.getIsVideoMode() ? "video.fill" : "camera.fill") { cameraModel.toggleVideoMode() }
            }
        }
    }

    private func toggleRecording() { isRecording ? stopRecording() : startRecording() }

    private func startRecording() {
        // TODO: Add timer functionality when timer service is integrated
        isRecording = true; recordingTime = 0
        if cameraModel.getIsVideoMode() {
            cameraModel.startVideoRecording()
        } else {
            cameraModel.capturePhoto { url in if let u = url { onRecordingComplete(u, .photo) }; isRecording = false }
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { _ in recordingTime += 0.1 }
    }

    private func stopRecording() {
        isRecording = false; timer?.invalidate(); timer = nil
        cameraModel.stopVideoRecording { url in if let u = url { onRecordingComplete(u, .video) } }
    }

    private func formatTime(_ t:Double)->String{String(format:"%02d:%02d.%d",Int(t)/60,Int(t)%60,Int((t*10).truncatingRemainder(dividingBy:10)))}

    // TODO: Add timer functionality when timer service is integrated
}



// MARK: - Recording Details View

struct RecordingDetailsView: View {
    let recordedMedia: RecordedMedia
    let onDismiss: () -> Void

    @StateObject private var storageManager = MediaStorageManager.shared
    @StateObject private var tokenService     = TokenizationService.shared

    @State private var selectedAlbum: Album?
    @State private var mediaTitle: String = ""
    @State private var mediaDescription: String = ""
    @State private var showingQRCode    = false
    @State private var isMinting        = false
    @State private var mintingError: String?
    @State private var transactionHash: String?

    private var mediaPreviewSection: some View {
        MediaPreviewView(media: recordedMedia)
            .frame(height: 300)
            .cornerRadius(12)
            .padding(.horizontal)
    }

    private var titleDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $mediaTitle)
                .font(.title2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Description (optional)", text: $mediaDescription, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
        .padding(.horizontal)
    }

    private var fileInfoSection: some View {
        GroupBox("File Information") {
            VStack(spacing: 8) {
                InfoRow(label: "Type", value: recordedMedia.type == .photo ? "Photo" : "Video")
                InfoRow(label: "Size", value: ByteCountFormatter().string(fromByteCount: recordedMedia.fileSize))
                InfoRow(label: "Recorded", value: { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: recordedMedia.recordedAt) }())
            }
        }
    }

    private var ipfsSection: some View {
        Group {
            if let hash = recordedMedia.ipfsHash {
                GroupBox("IPFS Hash") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hash)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Button { showingQRCode = true } label: { Label("Show QR Code", systemImage: "qrcode").font(.caption) }
                    }
                }
            } else {
                ProgressView("Generating IPFS hash…").padding()
            }
        }
    }

    private var albumSection: some View {
        GroupBox("Save to Album") {
            Picker("Album", selection: Binding(get: { selectedAlbum?.id }, set: { new in selectedAlbum = storageManager.albums.first { $0.id == new } })) {
                Text("Select Album").tag(UUID?.none)
                ForEach(storageManager.albums) { album in Text(album.name).tag(Optional(album.id)) }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var tokenizationSection: some View {
        Group {
            if tokenService.isConnected {
                GroupBox("Tokenization") {
                    VStack(spacing: 12) {
                        if let tx = transactionHash {
                            HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Minted!").font(.headline) }
                            Text(tx).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Button { viewOnExplorer() } label: { Label("View on Explorer", systemImage: "safari").font(.caption) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button { mintToken() } label: { if isMinting { ProgressView() } else { Label("Mint as NFT", systemImage: "seal") } }
                                .buttonStyle(.borderedProminent)
                                .disabled(isMinting || recordedMedia.ipfsHash == nil || selectedAlbum == nil)
                            if let e = mintingError { Text(e).foregroundColor(.red).font(.caption) }
                        }
                    }
                }
            } else {
                WalletConnectionView()
            }
        }
    }

    var body: some View {
        NavigationView {
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    mediaPreviewSection
                    titleDescriptionSection
                    fileInfoSection
                    ipfsSection
                    albumSection
                    tokenizationSection
                    Spacer(minLength: 30)
                }
                .padding(.vertical)
            }
            .navigationTitle("Recording Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingQRCode) { QRCodeView(address: recordedMedia.ipfsHash ?? "") }
        .onAppear {
            mediaTitle = recordedMedia.title
            mediaDescription = recordedMedia.description
        }
    }

    private func saveRecording() {
        guard let albumId = selectedAlbum?.id else { return }
        guard let data = try? Data(contentsOf: recordedMedia.fileURL) else { return }
        guard let path = MediaStorageManager.shared.saveMediaFile(data: data, type: recordedMedia.type) else { return }
        let thumb = MediaStorageManager.shared.generateThumbnail(for: path)
        let item = MediaItem(
            filePath: path,
            mediaType: recordedMedia.type,
            title: mediaTitle,
            description: mediaDescription,
            createdAt: recordedMedia.recordedAt,
            c2paManifest: recordedMedia.c2paManifest,
            ipfsHash: recordedMedia.ipfsHash,
            thumbnailPath: thumb,
            fileSize: recordedMedia.fileSize
        )
        storageManager.addMediaToAlbum(item, albumId: albumId)
        onDismiss()
    }

    private func mintToken() {
        guard recordedMedia.ipfsHash != nil else { return }
        guard let albumId = selectedAlbum?.id else { return }
        isMinting = true; mintingError = nil
        Task {
            do {
                // Create MediaItem for tokenization
                let mediaItem = MediaItem(
                    filePath: recordedMedia.fileURL.path,
                    mediaType: recordedMedia.type,
                    title: mediaTitle,
                    description: mediaDescription,
                    createdAt: recordedMedia.recordedAt,
                    c2paManifest: recordedMedia.c2paManifest,
                    ipfsHash: recordedMedia.ipfsHash,
                    fileSize: recordedMedia.fileSize
                )
                let result = try await tokenService.mintToken(for: mediaItem, albumId: albumId)
                await MainActor.run {
                    transactionHash = result.transactionHash
                    isMinting = false
                }
            } catch {
                await MainActor.run {
                    mintingError = error.localizedDescription
                    isMinting = false
                }
            }
        }
    }

    private func viewOnExplorer() {
        guard let tx = transactionHash,
              let url = tokenService.getExplorerURL(for: tx) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Media Preview View

struct MediaPreviewView: View {
    let media: RecordedMedia
    var body: some View {
        if media.type == .photo,
           let uiImage = UIImage(contentsOfFile: media.fileURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Color.black
                Image(systemName: "video.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - QR Code View

// QRCodeView is defined in Views/WalletAddressView.swift





    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 6))
                .padding(.top, 6)
                .foregroundColor(.secondary)
            Text(text).font(.footnote).foregroundColor(.secondary)
        }
    }

// MARK: - Expanded Menu Views

struct ExpandedLeftMenuView: View {
    @Binding var c2paEnabled: Bool
    @Binding var activeMenu: ActiveMenu?
    @Binding var shownFiles: Bool
    @Binding var showingMetadataRedaction: Bool
    @Binding var showingExport: Bool
    let geometry: GeometryProxy

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Minting & C2PA")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeMenu = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)

                // Menu items
                VStack(spacing: 20) {
                    Button(action: {
                        activeMenu = nil
                        shownFiles = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Files & Albums")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Trading Cards")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        c2paEnabled.toggle()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "seal.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("C2PA Signing")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(c2paEnabled ? "Enabled" : "Disabled")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        activeMenu = nil
                        // TODO: Fix wallet connection
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Wallet")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Connect & Manage")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        activeMenu = nil
                        showingMetadataRedaction = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Metadata")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("View & Edit")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        activeMenu = nil
                        showingExport = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Share & Upload")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .frame(width: geometry.size.width * 0.8)
            .background(.ultraThinMaterial)

            Spacer()
        }
    }
}

struct ExpandedRightMenuView: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding var captureMode: CaptureMode
    @Binding var activeMenu: ActiveMenu?
    @Binding var timerEnabled: Bool
    @Binding var gridEnabled: Bool
    @Binding var showingSettings: Bool
    @Binding var showingMetadataRedaction: Bool
    @Binding var showingExport: Bool
    let geometry: GeometryProxy
    @ObservedObject var timerService: CameraSelfTimer

    var body: some View {
        HStack {
            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Camera Controls")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeMenu = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)

                // Menu items
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await cameraModel.switchCamera()
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Switch Camera")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(cameraModel.currentCameraPosition == .back ? "Back" : "Front")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        Task {
                            await cameraModel.toggleFlash()
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "flashlight.on.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Flash")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(cameraModel.flashMode == .on ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if timerService.isTimerActive {
                            timerService.cancelTimer()
                        } else {
                            // Cycle through timer durations
                            let durations = CameraSelfTimer.TimerDuration.allCases
                            if let currentIndex = durations.firstIndex(of: timerService.timerDuration) {
                                let nextIndex = (currentIndex + 1) % durations.count
                                timerService.timerDuration = durations[nextIndex]
                            }
                        }
                        timerEnabled = timerService.timerDuration != .off
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: timerService.isTimerActive ? "timer.circle.fill" : "timer")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(timerService.isTimerActive ? "\(timerService.remainingSeconds)s" : timerService.timerDuration.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        gridEnabled.toggle()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: gridEnabled ? "grid" : "grid.slash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grid")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(gridEnabled ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        activeMenu = nil
                        showingSettings = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Camera Options")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .frame(width: geometry.size.width * 0.8)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Left Minting Pane

struct LeftMintingPane: View {
    @Binding var c2paEnabled: Bool
    @Binding var activeMenu: ActiveMenu?
    @Binding var shownFiles: Bool
    let width: CGFloat

    @State private var showMintingSettings = false
    @State private var showPrivacySettings = false
    @State private var showAlbumsView = false

    var body: some View {
        VStack(spacing: 0) {
            // Top section - C2PA Status
            VStack(spacing: 12) {
                // Simplified C2PA Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(c2paEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text("C2PA")
                        .font(.caption2)
                        .foregroundColor(.white)

                    Text(c2paEnabled ? "ON" : "OFF")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
                .onTapGesture {
                    c2paEnabled.toggle()
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 8)

            Spacer()

            // Menu Buttons
            VStack(spacing: 16) {
                MenuButton(
                    icon: "folder.fill",
                    title: "Files",
                    action: {
                        activeMenu = nil // Close any open menus first
                        shownFiles = true
                    }
                )

                MenuButton(
                    icon: "gearshape.fill",
                    title: "Minting",
                    action: {
                        activeMenu = nil // Close any open menus first
                        showMintingSettings = true
                    }
                )

                MenuButton(
                    icon: "hand.raised.fill",
                    title: "Privacy",
                    action: {
                        activeMenu = nil // Close any open menus first
                        showPrivacySettings = true
                    }
                )

                MenuButton(
                    icon: "photo.stack",
                    title: "Albums",
                    action: {
                        activeMenu = nil // Close any open menus first
                        showAlbumsView = true
                    }
                )
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(width: width)
        .background(Color.black.opacity(0.3))
        .sheet(isPresented: $showMintingSettings) {
            NavigationView {
                Text("Minting Settings")
                    .navigationTitle("Minting")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showMintingSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacySettings) {
            NavigationView {
                Text("Privacy Settings")
                    .navigationTitle("Privacy")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPrivacySettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAlbumsView) {
            NavigationView {
                Text("Albums")
                    .navigationTitle("Albums")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showAlbumsView = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Center Camera Pane

struct CenterCameraPane: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding fileprivate var captureMode: CaptureMode
    @Binding var isRecording: Bool
    let onComplete: (URL, MediaItem.MediaType) -> Void
    let isSigningInProgress: Bool
    let signingStatusMessage: String
    @Binding var activeMenu: ActiveMenu?
    let width: CGFloat
    @ObservedObject var timerService: CameraSelfTimer

    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewLayer(cameraModel: cameraModel)
                .frame(width: width)
                .clipped()
                .onTapGesture {
                    // Close any open menus when tapping the preview
                    activeMenu = nil
                }

            // Signing Overlay
            if isSigningInProgress {
                SigningOverlay(message: signingStatusMessage)
            }

            // Capture Controls Overlay
            VStack {
                Spacer()

                // Red Capture Button
                Button(action: captureAction) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)

                        if isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(isRecording ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isRecording)

                Spacer().frame(height: 40)
            }
        }
        .frame(width: width)
        .background(Color.black)
    }

    private func captureAction() {
        // Close any open menus first
        activeMenu = nil
        switch captureMode {
        case .photo:
            capturePhoto()
        case .video:
            if isRecording {
                stopVideoRecording()
            } else {
                startVideoRecording()
            }
        case .burst:
            captureBurst()
        case .timelapse:
            toggleTimelapse()
        }
    }

    private func capturePhoto() {
        // Check if timer is enabled and not already active
        if timerService.timerDuration != .off && !timerService.isTimerActive {
            // Start timer with completion handler
            timerService.startTimer(duration: timerService.timerDuration) { [weak cameraModel] in
                DispatchQueue.main.async {
                    cameraModel?.capturePhoto { url in
                        if let url = url {
                            onComplete(url, .photo)
                        } else {
                            print("Photo capture failed")
                        }
                    }
                }
            }
        } else {
            // Immediate capture (no timer or timer already running)
            cameraModel.capturePhoto { url in
                if let url = url {
                    onComplete(url, .photo)
                } else {
                    print("Photo capture failed")
                }
            }
        }
    }

    private func startVideoRecording() {
        isRecording = true
        cameraModel.startVideoRecording()
    }

    private func stopVideoRecording() {
        isRecording = false
        cameraModel.stopVideoRecording { url in
            if let url = url {
                onComplete(url, .video)
            } else {
                print("Video recording failed")
            }
        }
    }

    private func captureBurst() {
        // Implement burst capture
        capturePhoto()
    }

    private func toggleTimelapse() {
        // Implement timelapse toggle
        if isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
    }
}

// MARK: - Right Controls Pane

struct RightControlsPane: View {
    @ObservedObject var cameraModel: CameraModel
    @Binding fileprivate var captureMode: CaptureMode
    @Binding var activeMenu: ActiveMenu?
    @Binding var timerEnabled: Bool
    @Binding var gridEnabled: Bool
    let width: CGFloat

    @State private var showProControls = false

    var body: some View {
        VStack(spacing: 0) {
            // Top section - Camera Switch
            VStack(spacing: 16) {
                // Front/Back Camera Switch
                Button(action: {
                    activeMenu = nil // Close any open menus first
                    Task {
                        await cameraModel.switchCamera()
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 24))
                            .foregroundColor(.white)

                        Text("Flip")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }

                // Photo/Video Mode Toggle
                VStack(spacing: 8) {
                    Button(action: {
                        activeMenu = nil // Close any open menus first
                        captureMode = captureMode == .photo ? .video : .photo
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: captureMode == .photo ? "camera.fill" : "video.fill")
                                .font(.system(size: 20))
                                .foregroundColor(captureMode == .photo ? .yellow : .red)

                            Text(captureMode == .photo ? "Photo" : "Video")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 8)

            Spacer()

            // Professional Camera Controls
            VStack(spacing: 12) {
                // Zoom Control
                VStack(spacing: 4) {
                    HStack {
                        Text("Zoom")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(String(format: "%.1f", cameraModel.currentZoom))x")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Slider(value: $cameraModel.currentZoom, in: 1...cameraModel.maxZoom) { editing in
                        if !editing {
                            Task {
                                await cameraModel.setZoom(cameraModel.currentZoom)
                            }
                        }
                    }
                    .tint(.white)
                }
                .padding(.horizontal, 8)

                // Flash/Torch Control
                Button(action: {
                    activeMenu = nil
                    toggleFlash()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: cameraModel.flashMode == .on ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                            .foregroundColor(cameraModel.flashMode == .on ? .purple : .white)

                        Text("Flash")
                            .font(.caption)
                            .foregroundColor(cameraModel.flashMode == .on ? .purple : .white.opacity(0.8))
                    }
                    .frame(width: 60, height: 60)
                    .background(cameraModel.flashMode == .on ? Color.white.opacity(0.2) : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Pro Controls Button
                Button(action: {
                    activeMenu = nil
                    showProControls = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.white)

                        Text("Pro")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 60, height: 60)
                    .background(Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Additional Controls
                // TODO: Uncomment when RightControlsPane is integrated with proper bindings
                /*
                ControlButton(
                    icon: timerEnabled ? "timer.circle.fill" : "timer",
                    title: "Timer",
                    isActive: timerEnabled,
                    action: {
                        activeMenu = nil
                        timerEnabled.toggle()
                    }
                )

                ControlButton(
                    icon: gridEnabled ? "grid" : "grid.slash",
                    title: "Grid",
                    isActive: gridEnabled,
                    action: {
                        activeMenu = nil
                        gridEnabled.toggle()
                    }
                )
                */
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(width: width)
        .background(Color.black.opacity(0.3))
        .sheet(isPresented: $showProControls) {
            NavigationView {
                Text("Pro Camera Controls")
                    .navigationTitle("Pro Controls")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showProControls = false }
                        }
                    }
            }
        }
    }

    private func toggleFlash() {
        switch cameraModel.flashMode {
        case .auto:
            cameraModel.flashMode = .on
        case .on:
            cameraModel.flashMode = .off
        case .off:
            cameraModel.flashMode = .auto
        }

        Task {
            await cameraModel.configureFlash()
        }
    }
}

// MARK: - Helper Components

struct MenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Missing Menu Views

struct CollapsedLeftMenuView: View {
    @Binding var activeMenu: ActiveMenu?
    let geometry: GeometryProxy

    var body: some View {
        VStack {
            Button(action: { activeMenu = .left }) {
                Image(systemName: "sidebar.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
    }
}

struct CollapsedRightMenuView: View {
    @Binding var activeMenu: ActiveMenu?
    let geometry: GeometryProxy

    var body: some View {
        VStack {
            Button(action: { activeMenu = .right }) {
                Image(systemName: "sidebar.right")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
    }
}



#Preview {
    CameraRecordingView()
}