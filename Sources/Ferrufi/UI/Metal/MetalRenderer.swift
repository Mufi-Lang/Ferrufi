//
//  MetalRenderer.swift
//  Ferrufi
//
//  Metal rendering foundation for high-performance UI components
//

import Foundation
import Metal
import MetalKit
import SwiftUI

// MARK: - Metal Device Manager

@MainActor
public class MetalDeviceManager: ObservableObject {
    public static let shared = MetalDeviceManager()

    @Published public private(set) var device: MTLDevice?
    @Published public private(set) var commandQueue: MTLCommandQueue?
    @Published public private(set) var isInitialized = false
    @Published public private(set) var initializationError: String?

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
        self.isInitialized = true

        logDeviceInfo(device)
    }

    private func logDeviceInfo(_ device: MTLDevice) {
        print("Metal Device Initialized:")
        print("  Name: \(device.name)")
        print("  Low Power: \(device.isLowPower)")
        print("  Removable: \(device.isRemovable)")
        print("  Registry ID: \(device.registryID)")

        if #available(macOS 11.0, *) {
            print("  Supports Family Mac2: \(device.supportsFamily(.mac2))")
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
public class BaseMetalRenderer: NSObject, MetalRenderable {
    public weak var device: MTLDevice?
    public weak var commandQueue: MTLCommandQueue?

    public var viewportSize: SIMD2<Float> = SIMD2<Float>(0, 0)
    public var clearColor: MTLClearColor = MTLClearColor(
        red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

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

// MARK: - Metal View Wrapper

public struct MetalView: NSViewRepresentable {
    @StateObject private var deviceManager = MetalDeviceManager.shared

    private let renderer: MetalRenderable?
    private let preferredFramesPerSecond: Int
    private let enableSetNeedsDisplay: Bool

    public init(
        renderer: MetalRenderable? = nil,
        preferredFramesPerSecond: Int = 60,
        enableSetNeedsDisplay: Bool = false
    ) {
        self.renderer = renderer
        self.preferredFramesPerSecond = preferredFramesPerSecond
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
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
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
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(deviceManager: deviceManager)
    }

    public class Coordinator: NSObject, MTKViewDelegate {
        private let deviceManager: MetalDeviceManager
        var renderer: MetalRenderable?

        init(deviceManager: MetalDeviceManager) {
            self.deviceManager = deviceManager
            super.init()
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.resize(to: size)
        }

        public func draw(in view: MTKView) {
            guard let commandQueue = deviceManager.commandQueue,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let renderPassDescriptor = view.currentRenderPassDescriptor,
                let drawable = view.currentDrawable
            else {
                return
            }

            // Set clear color based on current appearance
            if #available(macOS 10.14, *) {
                let isDark = NSApp.effectiveAppearance.name == .darkAqua
                renderPassDescriptor.colorAttachments[0].clearColor =
                    isDark
                    ? MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                    : MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
            }

            // Render content
            renderer?.render(in: view, with: commandBuffer)

            commandBuffer.present(drawable)
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

public enum MetalShaderError: Error, LocalizedError {
    case deviceNotAvailable
    case libraryCreationFailed
    case functionNotFound(String)
    case pipelineCreationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Metal device not available"
        case .libraryCreationFailed:
            return "Failed to create Metal library"
        case .functionNotFound(let name):
            return "Metal function '\(name)' not found"
        case .pipelineCreationFailed(let error):
            return "Failed to create Metal pipeline: \(error.localizedDescription)"
        }
    }
}

public class MetalShaderManager {
    private let device: MTLDevice
    private let library: MTLLibrary
    private var pipelineCache: [String: MTLRenderPipelineState] = [:]

    public init(device: MTLDevice) throws {
        self.device = device

        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw MetalShaderError.libraryCreationFailed
        }
        self.library = defaultLibrary
    }

    public func makeRenderPipelineState(
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    ) throws -> MTLRenderPipelineState {

        let cacheKey = "\(vertexFunction)_\(fragmentFunction)_\(pixelFormat.rawValue)"

        if let cached = pipelineCache[cacheKey] {
            return cached
        }

        guard let vertexFunc = library.makeFunction(name: vertexFunction) else {
            throw MetalShaderError.functionNotFound(vertexFunction)
        }

        guard let fragmentFunc = library.makeFunction(name: fragmentFunction) else {
            throw MetalShaderError.functionNotFound(fragmentFunction)
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        // Enable blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            pipelineCache[cacheKey] = pipelineState
            return pipelineState
        } catch {
            throw MetalShaderError.pipelineCreationFailed(error)
        }
    }

    public func makeComputePipelineState(function: String) throws -> MTLComputePipelineState {
        guard let computeFunc = library.makeFunction(name: function) else {
            throw MetalShaderError.functionNotFound(function)
        }

        do {
            return try device.makeComputePipelineState(function: computeFunc)
        } catch {
            throw MetalShaderError.pipelineCreationFailed(error)
        }
    }
}

// MARK: - Vertex Structures

public struct Vertex {
    public let position: SIMD3<Float>
    public let color: SIMD4<Float>
    public let texCoords: SIMD2<Float>

    public init(
        position: SIMD3<Float>, color: SIMD4<Float>, texCoords: SIMD2<Float> = SIMD2<Float>(0, 0)
    ) {
        self.position = position
        self.color = color
        self.texCoords = texCoords
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
