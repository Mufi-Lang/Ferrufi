//
//  MetalRenderer.swift
//  Ferrufi
//
//  Metal rendering foundation for high-performance UI components
//

import Foundation
import SwiftUI

#if canImport(Metal)
    import Metal
    import MetalKit
#endif

#if canImport(Metal)
    // MARK: - Metal Device Manager

    @MainActor
    public class MetalDeviceManager: ObservableObject {
        public static let shared = MetalDeviceManager()

        @Published public private(set) var device: MTLDevice?
        @Published public private(set) var commandQueue: MTLCommandQueue?
        @Published public private(set) var isInitialized = false
        @Published public private(set) var initializationError: String?
        @Published public private(set) var isLibraryLoaded = false
        public private(set) var defaultLibrary: MTLLibrary?

        private init() {
            initialize()
        }

        private func initialize() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                initializationError = "No Metal-capable device found"
                return
            }

            guard let commandQueue = device.makeCommandQueue() else {
                initializationError = "Failed to create Metal command queue"
                return
            }

            self.device = device
            self.commandQueue = commandQueue
            
            // Robust library loading
            self.defaultLibrary = loadDefaultLibrary(for: device)
            self.isLibraryLoaded = self.defaultLibrary != nil
            
            self.isInitialized = true
            logDeviceInfo(device)
        }
        
        private func loadDefaultLibrary(for device: MTLDevice) -> MTLLibrary? {
            // 1. Try standard default library
            if let lib = device.makeDefaultLibrary() { return lib }
            
            // 2. Try to find the SPM module bundle
            let bundleNames = ["Ferrufi_Ferrufi", "Ferrufi"]
            let candidates = [
                Bundle.main.resourceURL,
                Bundle(for: MetalDeviceManager.self).resourceURL,
                Bundle.main.bundleURL,
            ]
            
            for base in candidates {
                guard let baseURL = base else { continue }
                for name in bundleNames {
                    let bundleURL = baseURL.appendingPathComponent("\(name).bundle")
                    if let bundle = Bundle(url: bundleURL),
                       let path = bundle.path(forResource: "default", ofType: "metallib") {
                        print("ℹ️ Metal: Found library in bundle \(bundleURL.path)")
                        return try? device.makeLibrary(URL: URL(fileURLWithPath: path))
                    }
                }
            }
            
            // 3. Fallback: Try to load from source file (useful for local development/swift run)
            // We search for Shaders.metal in the source tree
            let fm = FileManager.default
            let currentDir = fm.currentDirectoryPath
            let shaderSourcePath = "\(currentDir)/Sources/Ferrufi/UI/Metal/Shaders.metal"
            
            if fm.fileExists(atPath: shaderSourcePath) {
                do {
                    let source = try String(contentsOfFile: shaderSourcePath, encoding: .utf8)
                    print("ℹ️ Metal: Compiling shaders from source at \(shaderSourcePath)")
                    return try device.makeLibrary(source: source, options: nil)
                } catch {
                    print("❌ Metal: Failed to compile shaders from source: \(error)")
                }
            }
            
            // 4. Last resort: search for any metallib
            let bundle = Bundle(for: MetalDeviceManager.self)
            if let url = bundle.url(forResource: nil, withExtension: "metallib") {
                return try? device.makeLibrary(URL: url)
            }
            
            print("⚠️ Metal: Could not find default.metallib or Shaders.metal source.")
            return nil
        }

        private func logDeviceInfo(_ device: MTLDevice) {
            print("Metal Device Initialized:")
            print("  Name: \(device.name)")
            if let lib = defaultLibrary {
                print("  Library: Loaded successfully (\(lib.functionNames.count) functions)")
            } else {
                print("  Library: FAILED TO LOAD")
            }
        }
    }

    // MARK: - Base Metal Renderer

    @MainActor
    public protocol MetalRenderable {
        func render(in view: MTKView, with commandBuffer: MTLCommandBuffer)
        func resize(to size: CGSize)
    }

    @MainActor
    public class BaseMetalRenderer: NSObject, MetalRenderable, ObservableObject {
        public weak var device: MTLDevice?
        public weak var commandQueue: MTLCommandQueue?

        public var viewportSize: SIMD2<Float> = SIMD2<Float>(0, 0)
        public var clearColor: MTLClearColor = MTLClearColor(
            red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        public static var vertexDescriptor: MTLVertexDescriptor {
            let descriptor = MTLVertexDescriptor()
            
            // Position
            descriptor.attributes[0].format = .float3
            descriptor.attributes[0].offset = 0
            descriptor.attributes[0].bufferIndex = 0
            
            // Color
            descriptor.attributes[1].format = .float4
            descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
            descriptor.attributes[1].bufferIndex = 0
            
            // TexCoords
            descriptor.attributes[2].format = .float2
            descriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
            descriptor.attributes[2].bufferIndex = 0
            
            // TokenType
            descriptor.attributes[3].format = .float
            descriptor.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
            descriptor.attributes[3].bufferIndex = 0
            
            descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
            descriptor.layouts[0].stepRate = 1
            descriptor.layouts[0].stepFunction = .perVertex
            
            return descriptor
        }

        public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
            self.device = device
            self.commandQueue = commandQueue
            super.init()
        }

        public func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
            // Base implementation - override in subclasses
        }

        public func resize(to size: CGSize) {
            viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
        }

        // MARK: - Utility Methods

        public func makeBuffer<T>(from data: [T], options: MTLResourceOptions = []) -> MTLBuffer? {
            guard let device = device else { return nil }
            return data.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return nil }
                return device.makeBuffer(
                    bytes: baseAddress,
                    length: MemoryLayout<T>.stride * data.count,
                    options: options
                )
            }
        }

        public func loadTexture(named name: String, bundle: Bundle = .main) -> MTLTexture? {
            guard let device = device else { return nil }

            let textureLoader = MTKTextureLoader(device: device)
            do {
                return try textureLoader.newTexture(name: name, scaleFactor: 2.0, bundle: bundle)
            } catch {
                print("Failed to load texture '\(name)': \(error)")
                return nil
            }
        }
    }

    // MARK: - Specialized Renderers

    public class EditorBackgroundRenderer: BaseMetalRenderer {
        private var pipelineState: MTLRenderPipelineState?
        private var shaderManager: ShaderManager?
        private var vertexBuffer: MTLBuffer?
        private var startTime: Date = Date()
        public var accentColor: Color = .blue

        public override init(device: MTLDevice, commandQueue: MTLCommandQueue) {
            super.init(device: device, commandQueue: commandQueue)
            if MetalDeviceManager.shared.isLibraryLoaded, let library = MetalDeviceManager.shared.defaultLibrary {
                self.shaderManager = ShaderManager(device: device, library: library)
                setupPipeline()
                setupBuffers()
            }
        }

        private func setupPipeline() {
            guard let shaderManager = shaderManager else { return }
            
            do {
                pipelineState = try shaderManager.getRenderPipeline(
                    vertexFunctionName: "vertex_simple",
                    fragmentFunctionName: "fragment_background_mesh",
                    label: "Editor Background Pipeline"
                )
            } catch {
                print("❌ Metal error: Failed to create render pipeline state: \(error)")
            }
        }

        private func setupBuffers() {
            let vertices: [Vertex] = [
                Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(0, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(1, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(-1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(0, 0), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(1, 0), tokenType: 0)
            ]
            vertexBuffer = makeBuffer(from: vertices)
        }

        public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else { return }

            if let pipelineState = pipelineState, let vertexBuffer = vertexBuffer {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                
                var time = Float(Date().timeIntervalSince(startTime))
                renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
                
                var color = SIMD4<Float>(0, 0, 0, 0)
                if let components = NSColor(accentColor).usingColorSpace(.deviceRGB) {
                    color = SIMD4<Float>(Float(components.redComponent), 
                                         Float(components.greenComponent), 
                                         Float(components.blueComponent), 
                                         Float(components.alphaComponent))
                }
                renderEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
                
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            renderEncoder.endEncoding()
        }
    }

    public class MinimapRenderer: BaseMetalRenderer {
        private var pipelineState: MTLRenderPipelineState?
        private var shaderManager: ShaderManager?
        private var vertexBuffer: MTLBuffer?
        public var accentColor: Color = .blue

        public override init(device: MTLDevice, commandQueue: MTLCommandQueue) {
            super.init(device: device, commandQueue: commandQueue)
            if MetalDeviceManager.shared.isLibraryLoaded, let library = MetalDeviceManager.shared.defaultLibrary {
                self.shaderManager = ShaderManager(device: device, library: library)
                setupPipeline()
                setupBuffers()
            }
        }

        private func setupPipeline() {
            guard let shaderManager = shaderManager else { return }
            
            do {
                pipelineState = try shaderManager.getRenderPipeline(
                    vertexFunctionName: "vertex_simple",
                    fragmentFunctionName: "fragment_minimap",
                    label: "Minimap Pipeline"
                )
            } catch {
                print("❌ Metal error: Failed to create minimap pipeline state: \(error)")
            }
        }

        private func setupBuffers() {
            let vertices: [Vertex] = [
                Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(0, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(1, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(-1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(0, 0), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), texCoords: SIMD2<Float>(1, 0), tokenType: 0)
            ]
            vertexBuffer = makeBuffer(from: vertices)
        }

        public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else { return }

            if let pipelineState = pipelineState, let vertexBuffer = vertexBuffer {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                
                var color = SIMD4<Float>(0, 0, 0, 0)
                if let components = NSColor(accentColor).usingColorSpace(.deviceRGB) {
                    color = SIMD4<Float>(Float(components.redComponent), 
                                         Float(components.greenComponent), 
                                         Float(components.blueComponent), 
                                         Float(components.alphaComponent))
                }
                renderEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            renderEncoder.endEncoding()
        }
    }

    public class MetalTextRenderer: BaseMetalRenderer {
        private var pipelineState: MTLRenderPipelineState?
        private var shaderManager: ShaderManager?
        private var atlas: GlyphAtlas?
        private var startTime: Date = Date()
        public var text: String = ""
        public var color: Color = .white

        public init(device: MTLDevice, commandQueue: MTLCommandQueue, font: NSFont) {
            super.init(device: device, commandQueue: commandQueue)
            self.atlas = GlyphAtlas(device: device, font: font)
            if MetalDeviceManager.shared.isLibraryLoaded, let library = MetalDeviceManager.shared.defaultLibrary {
                self.shaderManager = ShaderManager(device: device, library: library)
                setupPipeline()
            }
        }

        private func setupPipeline() {
            guard let shaderManager = shaderManager else { return }
            
            do {
                pipelineState = try shaderManager.getRenderPipeline(
                    vertexFunctionName: "vertex_glyph",
                    fragmentFunctionName: "fragment_token_effect",
                    label: "Text Pipeline"
                )
            } catch {
                print("❌ Metal error: Failed to create text pipeline state: \(error)")
            }
        }

        public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else { return }

            if let pipelineState = pipelineState, let atlas = atlas {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setFragmentTexture(atlas.texture, index: 0)
                
                // Add time for animations
                var time = Float(Date().timeIntervalSince(startTime))
                renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
                
                let layoutEngine = LayoutEngine()
                let state = RenderState(text: text, cursorPosition: 0)
                let glyphPositions = layoutEngine.layout(state: state, font: atlas.font)
                
                for gp in glyphPositions {
                    guard let _ = atlas.descriptor(for: gp.glyph) else { continue }
                    // ... rendering logic using gp.position and gp.tokenType ...
                }
            }
            
            renderEncoder.endEncoding()
        }
    }

    // MARK: - Metal View Wrapper

    public struct MetalView: NSViewRepresentable {
        @StateObject private var deviceManager = MetalDeviceManager.shared
        @EnvironmentObject var themeManager: ThemeManager
        @EnvironmentObject var settings: Settings

        private let renderer: MetalRenderable?
        private let enableSetNeedsDisplay: Bool

        public init(
            renderer: MetalRenderable? = nil,
            enableSetNeedsDisplay: Bool = false
        ) {
            self.renderer = renderer
            self.enableSetNeedsDisplay = enableSetNeedsDisplay
        }

        public func makeNSView(context: Context) -> MTKView {
            let mtkView = MTKView()

            guard let device = deviceManager.device else {
                print("No Metal device available")
                return mtkView
            }

            mtkView.device = device
            mtkView.delegate = context.coordinator
            
            // Configure FPS based on settings
            if settings.vsyncEnabled {
                // Try to match screen refresh rate, default to 60
                let screenRate = NSScreen.main?.maximumFramesPerSecond ?? 60
                mtkView.preferredFramesPerSecond = screenRate
            } else {
                mtkView.preferredFramesPerSecond = settings.maxFPS
            }
            print("MetalView makeNSView: VSync=\(settings.vsyncEnabled), MaxFPS=\(settings.maxFPS) -> Preferred=\(mtkView.preferredFramesPerSecond)")
            
            mtkView.enableSetNeedsDisplay = enableSetNeedsDisplay

            // Configure pixel format for better color representation
            mtkView.colorPixelFormat = .bgra8Unorm_srgb
            mtkView.depthStencilPixelFormat = .depth32Float

            // Enable multisampling for better quality
            mtkView.sampleCount = 4

            return mtkView
        }

        public func updateNSView(_ nsView: MTKView, context: Context) {
            context.coordinator.renderer = renderer
            
            // Dynamic FPS update
            let targetFPS: Int
            if settings.vsyncEnabled {
                let screenRate = NSScreen.main?.maximumFramesPerSecond ?? 60
                targetFPS = screenRate
            } else {
                targetFPS = settings.maxFPS
            }
            
            if nsView.preferredFramesPerSecond != targetFPS {
                print("MetalView updateNSView: Changing FPS from \(nsView.preferredFramesPerSecond) to \(targetFPS) (VSync=\(settings.vsyncEnabled))")
                nsView.preferredFramesPerSecond = targetFPS
            }
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(deviceManager: deviceManager, themeManager: themeManager)
        }

        public class Coordinator: NSObject, MTKViewDelegate {
            private let deviceManager: MetalDeviceManager
            private let themeManager: ThemeManager
            var renderer: MetalRenderable?

            init(deviceManager: MetalDeviceManager, themeManager: ThemeManager) {
                self.deviceManager = deviceManager
                self.themeManager = themeManager
                super.init()
            }

            public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
                renderer?.resize(to: size)
            }

            public func draw(in view: MTKView) {
                // Report frame to performance monitor with current coordinator as source
                let sourceId = ObjectIdentifier(self)
                Task { @MainActor in
                    PerformanceMonitor.shared.recordFrame(from: sourceId)
                }

                guard let commandQueue = deviceManager.commandQueue,
                    let commandBuffer = commandQueue.makeCommandBuffer(),
                    let renderPassDescriptor = view.currentRenderPassDescriptor
                else {
                    return
                }

                // Set clear color based on current appearance
                let isDark = themeManager.currentTheme.isDark
                
                if renderer != nil {
                    renderPassDescriptor.colorAttachments[0].clearColor =
                        isDark
                        ? MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
                        : MTLClearColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
                } else {
                    // Fully transparent if no renderer
                    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
                }
                
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .store

                // If renderer exists, let it encode its commands
                if let renderer = renderer {
                    renderer.render(in: view, with: commandBuffer)
                } else {
                    // Just clear the screen if no renderer
                    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
                    encoder?.endEncoding()
                }

                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
                commandBuffer.commit()
            }
        }
    }

    // MARK: - Performance Monitoring

    @MainActor
    public class MetalPerformanceMonitor: ObservableObject {
        @Published public var frameTime: Double = 0.0
        @Published public var fps: Double = 0.0
        @Published public var gpuUtilization: Double = 0.0

        private var frameStartTime: CFTimeInterval = 0.0
        private var frameCount: Int = 0
        private var lastFPSUpdate: CFTimeInterval = 0.0
        private let fpsUpdateInterval: CFTimeInterval = 0.5  // Update FPS every 500ms

        public func frameDidStart() {
            frameStartTime = CACurrentMediaTime()
        }

        public func frameDidEnd() {
            let currentTime = CACurrentMediaTime()
            frameTime = (currentTime - frameStartTime) * 1000.0  // Convert to milliseconds

            frameCount += 1

            if currentTime - lastFPSUpdate >= fpsUpdateInterval {
                fps = Double(frameCount) / (currentTime - lastFPSUpdate)
                frameCount = 0
                lastFPSUpdate = currentTime
            }
        }
    }

    // MARK: - Metal Shader Utilities

#endif

// MARK: - Vertex Structures

public struct Vertex {
    public let position: SIMD3<Float>
    public let color: SIMD4<Float>
    public let texCoords: SIMD2<Float>
    public let tokenType: Float

    public init(
        position: SIMD3<Float>, color: SIMD4<Float>, texCoords: SIMD2<Float> = SIMD2<Float>(0, 0),
        tokenType: Float = 0.0
    ) {
        self.position = position
        self.color = color
        self.texCoords = texCoords
        self.tokenType = tokenType
    }
}

// MARK: - Transform Utilities

public struct Transform {
    public var translation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    public var rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    public var scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)

    public init() {}

    public var matrix: simd_float4x4 {
        let translationMatrix = matrix_float4x4_translation(translation)
        let rotationMatrix = matrix_float4x4_rotation(rotation)
        let scaleMatrix = matrix_float4x4_scale(scale)

        return translationMatrix * rotationMatrix * scaleMatrix
    }
}

// MARK: - Matrix Math Extensions

extension simd_float4x4 {
    public init(
        perspectiveProjectionFov fovRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float
    ) {
        let ys = 1 / tanf(fovRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)

        self.init(
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, nearZ * zs),
            SIMD4<Float>(0, 0, -1, 0)
        )
    }

    public init(
        orthographicProjectionLeft left: Float, right: Float, bottom: Float, top: Float,
        nearZ: Float, farZ: Float
    ) {
        let xs = 2 / (right - left)
        let ys = 2 / (top - bottom)
        let zs = 1 / (nearZ - farZ)

        self.init(
            SIMD4<Float>(xs, 0, 0, (left + right) / (left - right)),
            SIMD4<Float>(0, ys, 0, (top + bottom) / (bottom - top)),
            SIMD4<Float>(0, 0, zs, nearZ / (nearZ - farZ)),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}

public func matrix_float4x4_translation(_ translation: SIMD3<Float>) -> simd_float4x4 {
    return simd_float4x4(
        SIMD4<Float>(1, 0, 0, translation.x),
        SIMD4<Float>(0, 1, 0, translation.y),
        SIMD4<Float>(0, 0, 1, translation.z),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

public func matrix_float4x4_rotation(_ rotation: SIMD3<Float>) -> simd_float4x4 {
    let rotationX = matrix_float4x4_rotation_x(rotation.x)
    let rotationY = matrix_float4x4_rotation_y(rotation.y)
    let rotationZ = matrix_float4x4_rotation_z(rotation.z)

    return rotationX * rotationY * rotationZ
}

public func matrix_float4x4_scale(_ scale: SIMD3<Float>) -> simd_float4x4 {
    return simd_float4x4(
        SIMD4<Float>(scale.x, 0, 0, 0),
        SIMD4<Float>(0, scale.y, 0, 0),
        SIMD4<Float>(0, 0, scale.z, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

public func matrix_float4x4_rotation_x(_ radians: Float) -> simd_float4x4 {
    let cos = cosf(radians)
    let sin = sinf(radians)

    return simd_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, cos, -sin, 0),
        SIMD4<Float>(0, sin, cos, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

public func matrix_float4x4_rotation_y(_ radians: Float) -> simd_float4x4 {
    let cos = cosf(radians)
    let sin = sinf(radians)

    return simd_float4x4(
        SIMD4<Float>(cos, 0, sin, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(-sin, 0, cos, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

public func matrix_float4x4_rotation_z(_ radians: Float) -> simd_float4x4 {
    let cos = cosf(radians)
    let sin = sinf(radians)

    return simd_float4x4(
        SIMD4<Float>(cos, -sin, 0, 0),
        SIMD4<Float>(sin, cos, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}
