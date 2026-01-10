//
//  SmoothScrollView.swift
//  Ferrufi
//
//  Metal-accelerated smooth scrolling view for enhanced performance
//

import Combine
import Metal
import MetalKit
import SwiftUI

// MARK: - Smooth Scroll Configuration

public struct SmoothScrollConfiguration {
    public var friction: Float = 0.95
    public var springStiffness: Float = 0.8
    public var springDamping: Float = 0.7
    public var velocityThreshold: Float = 0.1
    public var maxVelocity: Float = 50.0
    public var enableMomentum: Bool = true
    public var enableBounce: Bool = true
    public var bounceStiffness: Float = 0.3

    public init() {}
}

// MARK: - Smooth Scroll Renderer

@MainActor
public class SmoothScrollRenderer: BaseMetalRenderer {
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?

    private var scrollOffset: SIMD2<Float> = SIMD2<Float>(0, 0)
    public var velocity: SIMD2<Float> = SIMD2<Float>(0, 0)
    private var targetOffset: SIMD2<Float> = SIMD2<Float>(0, 0)

    public var configuration = SmoothScrollConfiguration()
    public var contentSize: SIMD2<Float> = SIMD2<Float>(0, 0)
    public var visibleSize: SIMD2<Float> = SIMD2<Float>(0, 0)

    // Performance monitoring
    private let performanceMonitor = MetalPerformanceMonitor()

    public override init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        super.init(device: device, commandQueue: commandQueue)
        setupPipeline()
        setupGeometry()
    }

    private func setupPipeline() {
        guard let device = device else { return }

        do {
            let shaderManager = try MetalShaderManager(device: device)
            pipelineState = try shaderManager.makeRenderPipelineState(
                vertexFunction: "vertex_simple",
                fragmentFunction: "fragment_solid"
            )
        } catch {
            print("Failed to setup scroll renderer pipeline: \(error)")
        }
    }

    private func setupGeometry() {
        // Create a simple quad for rendering scrollable content
        let vertices: [Vertex] = [
            Vertex(
                position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1),
                texCoords: SIMD2<Float>(0, 1)),
            Vertex(
                position: SIMD3<Float>(1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1),
                texCoords: SIMD2<Float>(1, 1)),
            Vertex(
                position: SIMD3<Float>(1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1),
                texCoords: SIMD2<Float>(1, 0)),
            Vertex(
                position: SIMD3<Float>(-1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1),
                texCoords: SIMD2<Float>(0, 0)),
        ]

        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]

        vertexBuffer = device?.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: [])

        indexBuffer = device?.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: [])
    }

    public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
        performanceMonitor.frameDidStart()

        guard let pipelineState = pipelineState,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else {
            return
        }

        // Update physics
        updateScrollPhysics()

        // Set render state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Render content with scroll offset
        if let indexBuffer = indexBuffer {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        }

        renderEncoder.endEncoding()

        performanceMonitor.frameDidEnd()
    }

    private func updateScrollPhysics() {
        let deltaTime: Float = 1.0 / 60.0  // Assume 60 FPS

        if configuration.enableMomentum {
            // Spring physics towards target
            let displacement = targetOffset - scrollOffset
            let springForce = displacement * configuration.springStiffness
            let dampingForce = velocity * -configuration.springDamping

            velocity += (springForce + dampingForce) * deltaTime

            // Apply friction
            velocity *= configuration.friction

            // Clamp velocity
            let speed = length(velocity)
            if speed > configuration.maxVelocity {
                velocity = normalize(velocity) * configuration.maxVelocity
            }

            // Update position
            scrollOffset += velocity * deltaTime

            // Apply bounds with bounce
            if configuration.enableBounce {
                applyBounceConstraints()
            } else {
                applyHardConstraints()
            }

            // Stop when velocity is very small
            if speed < configuration.velocityThreshold {
                velocity = SIMD2<Float>(0, 0)
            }
        } else {
            // Direct scrolling without momentum
            scrollOffset = targetOffset
            applyHardConstraints()
        }
    }

    private func applyBounceConstraints() {
        let maxOffset = contentSize - visibleSize

        // Horizontal bounds
        if scrollOffset.x < 0 {
            let overshoot = -scrollOffset.x
            velocity.x += overshoot * configuration.bounceStiffness
            scrollOffset.x = 0
        } else if scrollOffset.x > maxOffset.x {
            let overshoot = scrollOffset.x - maxOffset.x
            velocity.x -= overshoot * configuration.bounceStiffness
            scrollOffset.x = maxOffset.x
        }

        // Vertical bounds
        if scrollOffset.y < 0 {
            let overshoot = -scrollOffset.y
            velocity.y += overshoot * configuration.bounceStiffness
            scrollOffset.y = 0
        } else if scrollOffset.y > maxOffset.y {
            let overshoot = scrollOffset.y - maxOffset.y
            velocity.y -= overshoot * configuration.bounceStiffness
            scrollOffset.y = maxOffset.y
        }
    }

    private func applyHardConstraints() {
        let maxOffset = contentSize - visibleSize
        scrollOffset.x = max(0, min(maxOffset.x, scrollOffset.x))
        scrollOffset.y = max(0, min(maxOffset.y, scrollOffset.y))
    }

    // MARK: - Public Interface

    public func setScrollOffset(_ offset: SIMD2<Float>, animated: Bool = true) {
        if animated {
            targetOffset = offset
        } else {
            scrollOffset = offset
            targetOffset = offset
            velocity = SIMD2<Float>(0, 0)
        }
    }

    public func addScrollDelta(_ delta: SIMD2<Float>) {
        targetOffset += delta
    }

    public func getCurrentOffset() -> SIMD2<Float> {
        return scrollOffset
    }

    public func getVelocity() -> SIMD2<Float> {
        return velocity
    }

    public func setContentSize(_ size: CGSize) {
        contentSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    public func setVisibleSize(_ size: CGSize) {
        visibleSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }
}

// MARK: - SwiftUI Integration

public struct SmoothScrollView<Content: View>: View {
    @StateObject private var deviceManager = MetalDeviceManager.shared
    @State private var scrollRenderer: SmoothScrollRenderer?
    @State private var configuration = SmoothScrollConfiguration()

    private let content: Content
    private let contentSize: CGSize
    private let onScroll: ((CGPoint) -> Void)?

    public init(
        contentSize: CGSize,
        configuration: SmoothScrollConfiguration = SmoothScrollConfiguration(),
        onScroll: ((CGPoint) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.contentSize = contentSize
        self._configuration = State(initialValue: configuration)
        self.onScroll = onScroll
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Metal-accelerated scroll layer
                MetalView(renderer: scrollRenderer)
                    .allowsHitTesting(false)

                // Content overlay
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        content
                            .frame(width: contentSize.width, height: contentSize.height)
                    }
                    .scrollIndicators(.hidden)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                handleScrollGesture(value)
                            }
                            .onEnded { value in
                                handleScrollEnd(value)
                            }
                    )
                }
            }
        }
        .onAppear {
            setupRenderer(size: contentSize)
        }
        .onChange(of: contentSize) { _, newSize in
            scrollRenderer?.setContentSize(newSize)
        }
    }

    private func setupRenderer(size: CGSize) {
        guard let device = deviceManager.device,
            let commandQueue = deviceManager.commandQueue
        else {
            return
        }

        let renderer = SmoothScrollRenderer(device: device, commandQueue: commandQueue)
        renderer.configuration = configuration
        renderer.setContentSize(size)

        self.scrollRenderer = renderer
    }

    private func handleScrollGesture(_ value: DragGesture.Value) {
        let delta = SIMD2<Float>(
            -Float(value.translation.width),
            -Float(value.translation.height)
        )

        scrollRenderer?.addScrollDelta(delta * 0.01)  // Scale factor

        if let onScroll = onScroll {
            let currentOffset = scrollRenderer?.getCurrentOffset() ?? SIMD2<Float>(0, 0)
            onScroll(CGPoint(x: CGFloat(currentOffset.x), y: CGFloat(currentOffset.y)))
        }
    }

    private func handleScrollEnd(_ value: DragGesture.Value) {
        // Add momentum based on gesture velocity
        if configuration.enableMomentum {
            let velocity =
                SIMD2<Float>(
                    -Float(value.predictedEndTranslation.width - value.translation.width),
                    -Float(value.predictedEndTranslation.height - value.translation.height)
                ) * 0.001  // Scale factor

            scrollRenderer?.velocity = velocity
        }
    }
}

// MARK: - Enhanced Scroll View with Text Rendering

public struct EnhancedTextScrollView: View {
    @State private var textRenderer: MetalTextRenderer?
    @StateObject private var deviceManager = MetalDeviceManager.shared

    private let text: String
    private let font: NSFont
    private let configuration: SmoothScrollConfiguration

    public init(
        text: String,
        font: NSFont = .systemFont(ofSize: 14),
        configuration: SmoothScrollConfiguration = SmoothScrollConfiguration()
    ) {
        self.text = text
        self.font = font
        self.configuration = configuration
    }

    public var body: some View {
        MetalView(renderer: textRenderer)
            .onAppear {
                setupTextRenderer()
            }
    }

    private func setupTextRenderer() {
        guard let device = deviceManager.device,
            let commandQueue = deviceManager.commandQueue
        else {
            return
        }

        let renderer = MetalTextRenderer(device: device, commandQueue: commandQueue)
        renderer.setText(text, font: font)

        self.textRenderer = renderer
    }
}

// MARK: - Metal Text Renderer

@MainActor
public class MetalTextRenderer: BaseMetalRenderer {
    private var textTexture: MTLTexture?
    private var pipelineState: MTLRenderPipelineState?

    private var text: String = ""
    private var font: NSFont = .systemFont(ofSize: 14)

    public override init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        super.init(device: device, commandQueue: commandQueue)
        setupPipeline()
    }

    private func setupPipeline() {
        guard let device = device else { return }

        do {
            let shaderManager = try MetalShaderManager(device: device)
            pipelineState = try shaderManager.makeRenderPipelineState(
                vertexFunction: "vertex_simple",
                fragmentFunction: "fragment_textured"
            )
        } catch {
            print("Failed to setup text renderer pipeline: \(error)")
        }
    }

    public func setText(_ text: String, font: NSFont) {
        self.text = text
        self.font = font
        generateTextTexture()
    }

    private func generateTextTexture() {
        guard let device = device else { return }

        // Create attributed string
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Calculate text size
        let textSize = attributedString.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        // Create bitmap context
        let width = Int(ceil(textSize.width))
        let height = Int(ceil(textSize.height))

        guard width > 0 && height > 0 else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else { return }

        // Clear context
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw text
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        attributedString.draw(at: CGPoint(x: 0, y: 0))

        NSGraphicsContext.restoreGraphicsState()

        // Create Metal texture
        guard let data = context.data else { return }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return }

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: width * 4
        )

        self.textTexture = texture
    }

    public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
        guard let pipelineState = pipelineState,
            let textTexture = textTexture,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(textTexture, index: 0)

        // Render text quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
