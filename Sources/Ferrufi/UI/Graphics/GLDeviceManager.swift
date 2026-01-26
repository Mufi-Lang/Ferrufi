#if os(Linux)
    //
    //  GLDeviceManager.swift
    //  Ferrufi
    //
    //  Lightweight OpenGL / EGL detection helper for Linux.
    //
    //  This file provides a small, conservative detection shim that the rest of
    //  the codebase can query to decide whether an OpenGL-based backend is
    //  available. Actual GL context creation and rendering integration should be
    //  performed by the GUI toolkit (GTK GLArea, GLFW, etc.) when integrating the
    //  Linux UI.
    //

    import Foundation
    import Combine
    import Glibc

    /// Error cases for GLDeviceManager operations.
    public enum GLDeviceError: Error, LocalizedError {
        case libraryNotFound
        case contextCreationNotImplemented
        case contextCreationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .libraryNotFound:
                return "OpenGL/EGL library not found"
            case .contextCreationNotImplemented:
                return "Context creation is not implemented in this shim"
            case .contextCreationFailed(let reason):
                return "Failed to create GL context: \(reason)"
            }
        }
    }

    /// Simple, main-actor isolated manager that detects OpenGL/EGL availability on Linux.
    /// The detection performed here is intentionally conservative: it checks for commonly
    /// available GL vendor libraries and reports availability. Actual context creation is
    /// left to the UI integration layer (GTK/GLArea or GLFW) so that windowing and
    /// surfaces are created in the right environment.
    @MainActor
    public final class GLDeviceManager: ObservableObject {
        public static let shared = GLDeviceManager()

        /// True when a GL/EGL library was detected on the host.
        @Published public private(set) var isAvailable: Bool = false

        /// True when a minimal initialization has been performed.
        /// Note: this does not guarantee a functional onscreen GL context; that must be
        /// established by the GUI layer.
        @Published public private(set) var isInitialized: Bool = false

        /// When detection or initialization fails, this field may contain a brief reason.
        @Published public private(set) var initializationError: String?

        private init() {
            detectLibraries()
        }

        // MARK: - Detection

        /// Probe for common GL/EGL libraries on the system (libGL, libEGL, libGLX).
        /// This uses `dlopen` to test for the presence of the runtime library.
        private func detectLibraries() {
            // Conservative list of common shared libs to try
            let candidates = [
                "libGL.so.1",  // most common (mesa, nvidia, etc.)
                "libGL.so",
                "libEGL.so.1",
                "libEGL.so",
                "libGLX.so.0",
                "libGLX.so",
            ]

            for name in candidates {
                let found = name.withCString { cstr -> Bool in
                    // Try to open the library for symbol resolution; don't keep it open.
                    if let handle = dlopen(cstr, RTLD_NOW) {
                        dlclose(handle)
                        return true
                    }
                    return false
                }
                if found {
                    isAvailable = true
                    initializationError = nil
                    return
                }
            }

            isAvailable = false
            initializationError = "OpenGL/EGL libraries not found (tried common lib names)"
        }

        // MARK: - Initialization (stub)

        /// Attempt a minimal initialization. This is a best-effort placeholder that
        /// indicates readiness for higher-level UI toolkits to create real contexts.
        /// Returns `true` when the manager believes a GL backend is usable.
        @discardableResult
        public func tryInitialize() -> Bool {
            guard isAvailable else {
                initializationError = "OpenGL not available"
                return false
            }

            // NOTE:
            // A functional GL context typically requires creating a surface/context via
            // GLX / EGL / the windowing toolkit (GTK GLArea, GLFW). Implementing an
            // offscreen context here is possible but out of scope for a small shim.
            // For now, mark the manager as initialized so callers that only require
            // nominal availability can proceed; UI integrations should create true
            // contexts as needed.
            isInitialized = true
            initializationError = nil
            return true
        }

        /// Create a real GL context. Not implemented in the shim — UI layer must
        /// implement context creation using the chosen toolkit (GTK + GLArea, EGL, etc).
        /// Calling this will return a not-implemented error.
        public func createContext() throws {
            throw GLDeviceError.contextCreationNotImplemented
        }

        /// Re-run detection and reset initialization state.
        public func refresh() {
            isInitialized = false
            initializationError = nil
            isAvailable = false
            detectLibraries()
        }
    }
#endif
