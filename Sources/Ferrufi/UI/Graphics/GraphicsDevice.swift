//
//  GraphicsDevice.swift
//  Ferrufi
//
//  Cross-platform graphics device detection and convenience shim.
//
//  This file provides a small runtime helper that exposes the available GPU
//  backend on the current platform. It prefers a user-selected backend when
//  specified; otherwise it probes available backends (Metal on macOS, OpenGL on
//  Linux) and falls back to software rendering.
//
//  The intent is to keep the rest of the codebase loosely-coupled to a simple
//  `GraphicsDevice` runtime check while we incrementally introduce platform-
//  specific renderers (Metal, GL) and their implementations.
//

import Combine
import Foundation

/// Preferred or resolved backend for GPU-related rendering/acceleration.
public enum GraphicsBackend: String, Codable, Sendable {
    /// Let the runtime choose the best backend available.
    case auto

    /// Apple Metal (macOS / iOS / tvOS)
    case metal

    /// OpenGL / GLX / EGL (Linux)
    case opengl

    /// Software fallback (no GPU acceleration)
    case software
}

/// Simple, MainActor-isolated singleton that determines which graphics backend
/// is available and provides convenience helpers for runtime checks.
///
/// Note: this is intentionally small. Concrete rendering implementations should
/// register themselves or expose more detailed device objects (e.g. Metal device,
/// GL context) via their own manager classes.
@MainActor
public final class GraphicsDevice: ObservableObject {
    public static let shared = GraphicsDevice()

    /// User preference for backend. Defaults to `.auto` (runtime chooses).
    @Published public var preferredBackend: GraphicsBackend = .auto

    private init() {}

    /// The backend that will be used given the current preference and available
    /// platform capabilities.
    public var resolvedBackend: GraphicsBackend {
        switch preferredBackend {
        case .auto:
            // Prefer Metal on platforms with Metal available, otherwise OpenGL.
            if isMetalAvailable { return .metal }
            if isOpenGLAvailable { return .opengl }
            return .software
        case .metal:
            return isMetalAvailable ? .metal : .software
        case .opengl:
            return isOpenGLAvailable ? .opengl : .software
        case .software:
            return .software
        }
    }

    /// Whether we have any GPU backend available (Metal or OpenGL).
    public var isGPUAvailable: Bool {
        let b = resolvedBackend
        return (b == .metal || b == .opengl)
    }

    // MARK: - Platform probes

    /// True when a usable Metal backend is available (macOS).
    public var isMetalAvailable: Bool {
        #if canImport(Metal)
            // MetalDeviceManager is defined in the Metal renderer module and is only
            // available when Metal can be imported; call into it safely from the
            // main actor.
            return MetalDeviceManager.shared.isInitialized
        #else
            return false
        #endif
    }

    /// True when a usable OpenGL backend is available (Linux).
    public var isOpenGLAvailable: Bool {
        #if os(Linux)
            return GLDeviceManager.shared.isAvailable
        #else
            return false
        #endif
    }

    // MARK: - Helpers

    /// Force a refresh / re-evaluation of runtime checks. This is lightweight
    /// and simply notifies observers that computed properties may have changed.
    public func refresh() {
        // A coarse-grained refresh is sufficient for now; concrete managers
        // (Metal/GL) should publish more detailed state when needed.
        objectWillChange.send()
    }
}

// Backwards-compatible convenience: allow code to use `ui.gpuAccelerationEnabled`
// while the on-disk config still stores `metalAccelerationEnabled`.
extension UIConfiguration {
    /// Backwards-compatible alias for `metalAccelerationEnabled`.
    public var gpuAccelerationEnabled: Bool {
        get { metalAccelerationEnabled }
        set { metalAccelerationEnabled = newValue }
    }
}
