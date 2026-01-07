//
//  MetalRenderer.swift
//  Iron
//
//  Metal rendering foundation for Iron knowledge management application
//

import Foundation
import Metal
import MetalKit
import SwiftUI

/// Protocol for Metal-rendered content
public protocol MetalRenderable {
    func render(in view: MTKView, with commandBuffer: MTLCommandBuffer)
    func update(deltaTime: Double)
}

/// Main Metal renderer class
@MainActor
public class MetalRenderer: NSObject, ObservableObject {

    // MARK: - Core Metal Objects
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    private var library: MTLLibrary

    // MARK: - Render Pipeline States
    private var basicPipelineState: MTLRenderPipelineState?
    private var particlePipelineState: MTLRenderPipelineState?
    private var linePipelineState: MTLRenderPipelineState?

    // MARK: - Buffers and Resources
    private var uniformBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?

    // MARK: - Performance Metrics
    @Published public private(set) var frameRate: Double = 0.0
    @Published public private(set) var frameTime: Double = 0.0
    @Published public private(set) var isPerformanceOptimal: Bool = true

    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimeHistory: [Double] = []

    // MARK: - Configuration
    public var enableVSync: Bool = true
    public var preferredFrameRate: Int = 60
    public var enablePerformanceMonitoring: Bool = true

    // MARK: - Initialization

    public init?(device: MTLDevice? = nil) {
        // Get Metal device
        if let providedDevice = device {
            self.device = providedDevice
        } else {
            guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
                print("Metal is not supported on this device")
                return nil
            }
            self.device = defaultDevice
        }

        // Create command queue
        guard let queue = self.device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = queue

        // Create shader library
        guard let defaultLibrary = self.device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return nil
        }
        self.library = defaultLibrary

        super.init()

        setupRenderPipelines()
        setupBuffers()
    }

    // MARK: - Setup Methods

    private func setupRenderPipelines() {
        setupBasicPipeline()
        setupParticlePipeline()
        setupLinePipeline()
    }

    private func setupBasicPipeline() {
        let descriptor = MTLRenderPipelineDescriptor()

        // Vertex and fragment functions
        descriptor.vertexFunction = library.makeFunction(name: "vertex_basic")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_basic")

        // Color attachment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        // Depth attachment
        descriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            basicPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create basic pipeline state: \(error)")
        }
    }

    private func setupParticlePipeline() {
        let descriptor = MTLRenderPipelineDescriptor()

        // Vertex and fragment functions for particles
        descriptor.vertexFunction = library.makeFunction(name: "vertex_particle")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_particle")

        // Color attachment with additive blending for particles
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            particlePipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create particle pipeline state: \(error)")
        }
    }

    private func setupLinePipeline() {
        let descriptor = MTLRenderPipelineDescriptor()

        // Vertex and fragment functions for lines
        descriptor.vertexFunction = library.makeFunction(name: "vertex_line")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_line")

        // Color attachment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            linePipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create line pipeline state: \(error)")
        }
    }

    private func setupBuffers() {
        // Create uniform buffer
        let uniformBufferSize = MemoryLayout<Uniforms>.size
        uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)
        uniformBuffer?.label = "UniformBuffer"

        // Create vertex buffer (will be resized as needed)
        let initialVertexBufferSize = 1024 * 1024  // 1MB
        vertexBuffer = device.makeBuffer(
            length: initialVertexBufferSize, options: .storageModeShared)
        vertexBuffer?.label = "VertexBuffer"

        // Create index buffer
        let initialIndexBufferSize = 512 * 1024  // 512KB
        indexBuffer = device.makeBuffer(length: initialIndexBufferSize, options: .storageModeShared)
        indexBuffer?.label = "IndexBuffer"
    }

    // MARK: - Rendering Methods

    public func render(in view: MTKView, renderable: MetalRenderable) {
        autoreleasepool {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.label = "RenderCommandBuffer"

            // Performance monitoring
            let frameStartTime = CACurrentMediaTime()

            // Update uniforms
            updateUniforms(for: view)

            // Let renderable perform its rendering
            renderable.render(in: view, with: commandBuffer)

            // Present drawable
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }

            // Add completion handler for performance monitoring
            if enablePerformanceMonitoring {
                commandBuffer.addCompletedHandler { _ in
                    Task { @MainActor in
                        self.updatePerformanceMetrics(frameStartTime: frameStartTime)
                    }
                }
            }

            commandBuffer.commit()
        }
    }

    private func updateUniforms(for view: MTKView) {
        guard let uniformBuffer = uniformBuffer else { return }

        let viewSize = view.drawableSize
        let uniforms = Uniforms(
            projectionMatrix: createProjectionMatrix(size: viewSize),
            viewMatrix: createViewMatrix(),
            time: Float(CACurrentMediaTime()),
            resolution: simd_float2(Float(viewSize.width), Float(viewSize.height))
        )

        let uniformPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms
    }

    // MARK: - Matrix Creation

    private func createProjectionMatrix(size: CGSize) -> simd_float4x4 {
        let aspect = Float(size.width / size.height)
        let fov: Float = 45.0 * .pi / 180.0
        let near: Float = 0.1
        let far: Float = 1000.0

        return createPerspectiveMatrix(fov: fov, aspect: aspect, near: near, far: far)
    }

    private func createViewMatrix() -> simd_float4x4 {
        let eye = simd_float3(0, 0, 5)
        let center = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        return createLookAtMatrix(eye: eye, center: center, up: up)
    }

    private func createPerspectiveMatrix(fov: Float, aspect: Float, near: Float, far: Float)
        -> simd_float4x4
    {
        let yScale = 1.0 / tan(fov * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2.0 * far * near / zRange

        return simd_float4x4(
            simd_float4(xScale, 0, 0, 0),
            simd_float4(0, yScale, 0, 0),
            simd_float4(0, 0, zScale, -1),
            simd_float4(0, 0, wzScale, 0)
        )
    }

    private func createLookAtMatrix(eye: simd_float3, center: simd_float3, up: simd_float3)
        -> simd_float4x4
    {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        let t = simd_float3(-dot(x, eye), -dot(y, eye), -dot(z, eye))

        return simd_float4x4(
            simd_float4(x.x, y.x, z.x, 0),
            simd_float4(x.y, y.y, z.y, 0),
            simd_float4(x.z, y.z, z.z, 0),
            simd_float4(t.x, t.y, t.z, 1)
        )
    }

    // MARK: - Performance Monitoring

    private func updatePerformanceMetrics(frameStartTime: CFTimeInterval) {
        let currentTime = CACurrentMediaTime()
        let frameDuration = currentTime - frameStartTime

        self.frameTime = frameDuration * 1000  // Convert to milliseconds

        // Calculate frame rate
        if self.lastFrameTime > 0 {
            let deltaTime = currentTime - self.lastFrameTime
            if deltaTime > 0 {
                self.frameRate = 1.0 / deltaTime
            }
        }
        self.lastFrameTime = currentTime

        // Update frame time history for performance analysis
        self.frameTimeHistory.append(frameDuration)
        if self.frameTimeHistory.count > 60 {  // Keep last 60 frames
            self.frameTimeHistory.removeFirst()
        }

        // Check if performance is optimal (consistent 60fps or target)
        let targetFrameTime = 1.0 / Double(self.preferredFrameRate)
        let averageFrameTime =
            self.frameTimeHistory.reduce(0, +) / Double(self.frameTimeHistory.count)
        self.isPerformanceOptimal = averageFrameTime <= targetFrameTime * 1.1  // 10% tolerance
    }

    // MARK: - Resource Management

    public func createBuffer<T>(from data: [T], usage: MTLResourceOptions = .storageModeShared)
        -> MTLBuffer?
    {
        let size = data.count * MemoryLayout<T>.stride
        return data.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: size, options: usage)
        }
    }

    public func createTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm)
        -> MTLTexture?
    {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    // MARK: - Pipeline State Access

    public var basicPipeline: MTLRenderPipelineState? { basicPipelineState }
    public var particlePipeline: MTLRenderPipelineState? { particlePipelineState }
    public var linePipeline: MTLRenderPipelineState? { linePipelineState }

    public var currentUniformBuffer: MTLBuffer? { uniformBuffer }
    public var currentVertexBuffer: MTLBuffer? { vertexBuffer }
    public var currentIndexBuffer: MTLBuffer? { indexBuffer }
}

// MARK: - Supporting Structures

public struct Uniforms {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var time: Float
    var resolution: simd_float2

    public init(
        projectionMatrix: simd_float4x4, viewMatrix: simd_float4x4, time: Float,
        resolution: simd_float2
    ) {
        self.projectionMatrix = projectionMatrix
        self.viewMatrix = viewMatrix
        self.time = time
        self.resolution = resolution
    }
}

public struct Vertex {
    var position: simd_float3
    var color: simd_float4
    var texCoord: simd_float2

    public init(
        position: simd_float3, color: simd_float4 = simd_float4(1, 1, 1, 1),
        texCoord: simd_float2 = simd_float2(0, 0)
    ) {
        self.position = position
        self.color = color
        self.texCoord = texCoord
    }
}

// MARK: - Metal View Coordinator

public class MetalViewCoordinator: NSObject, MTKViewDelegate {
    public let renderer: MetalRenderer
    public var renderable: MetalRenderable?

    public init(renderer: MetalRenderer) {
        self.renderer = renderer
        super.init()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle drawable size changes
    }

    public func draw(in view: MTKView) {
        guard let renderable = renderable else { return }
        renderer.render(in: view, renderable: renderable)
    }
}

// MARK: - SwiftUI Integration

public struct MetalView: NSViewRepresentable {
    public let renderer: MetalRenderer
    public let renderable: MetalRenderable

    public init(renderer: MetalRenderer, renderable: MetalRenderable) {
        self.renderer = renderer
        self.renderable = renderable
    }

    public func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = renderer.device
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = renderer.preferredFrameRate
        metalView.enableSetNeedsDisplay = !renderer.enableVSync
        metalView.isPaused = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)

        context.coordinator.renderable = renderable

        return metalView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderable = renderable
    }

    public func makeCoordinator() -> MetalViewCoordinator {
        MetalViewCoordinator(renderer: renderer)
    }
}

// MARK: - Error Handling

public enum MetalRendererError: Error, LocalizedError {
    case deviceNotAvailable
    case pipelineCreationFailed(String)
    case bufferCreationFailed
    case textureCreationFailed

    public var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Metal device is not available"
        case .pipelineCreationFailed(let details):
            return "Failed to create render pipeline: \(details)"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        }
    }
}
