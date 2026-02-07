import Foundation
import Metal
import MetalKit
import SwiftUI

#if canImport(Metal)

@MainActor
public class MetalEditorRenderer: BaseMetalRenderer {
    private var shaderManager: ShaderManager?
    private var atlas: GlyphAtlas?
    
    // Animation state
    private var previousCursorPos: CGPoint = .zero
    private var targetCursorPos: CGPoint = .zero
    private var animationStartTime: Date?
    private let animationDuration: TimeInterval = 0.15
    
    private var startTime: Date = Date()
    
    public var renderState: RenderState? {
        didSet {
            updateAnimationState()
        }
    }
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue, font: NSFont) {
        super.init(device: device, commandQueue: commandQueue)
        self.atlas = GlyphAtlas(device: device, font: font)
        
        if MetalDeviceManager.shared.isLibraryLoaded, let library = MetalDeviceManager.shared.defaultLibrary {
            self.shaderManager = ShaderManager(device: device, library: library)
        }
    }
    
    private func updateAnimationState() {
        guard let state = renderState, let atlas = atlas else { return }
        
        let layoutEngine = LayoutEngine()
        let newRect = layoutEngine.rect(for: state.cursorPosition, state: state, font: atlas.font)
        let newPos = newRect.origin
        
        if newPos != targetCursorPos {
            previousCursorPos = currentAnimatedCursorPos()
            targetCursorPos = newPos
            animationStartTime = Date()
        }
    }
    
    private func currentAnimatedCursorPos() -> CGPoint {
        guard let startTime = animationStartTime else { return targetCursorPos }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / animationDuration, 1.0)
        
        // Simple linear interpolation
        let x = previousCursorPos.x + (targetCursorPos.x - previousCursorPos.x) * CGFloat(progress)
        let y = previousCursorPos.y + (targetCursorPos.y - previousCursorPos.y) * CGFloat(progress)
        
        return CGPoint(x: x, y: y)
    }
    
    public override func render(in view: MTKView, with commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let shaderManager = shaderManager,
              let state = renderState else { return }
        
        let viewportSize = view.drawableSize
        var projectionMatrix = simd_float4x4(
            orthographicProjectionLeft: 0, 
            right: Float(viewportSize.width), 
            bottom: Float(viewportSize.height), 
            top: 0, 
            nearZ: -1, farZ: 1
        )
        
        var time = Float(Date().timeIntervalSince(startTime))
        renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)

        // 1. Render Selection
        if let range = state.selectionRange, !range.isEmpty {
            renderSelection(in: view, encoder: renderEncoder, range: range, projectionMatrix: &projectionMatrix, shaderManager: shaderManager)
        }
        
        // 2. Render Text
        renderText(in: view, encoder: renderEncoder, state: state, projectionMatrix: &projectionMatrix, shaderManager: shaderManager)
        
        // 3. Render Cursor
        renderCursor(in: view, encoder: renderEncoder, projectionMatrix: &projectionMatrix, shaderManager: shaderManager)
        
        renderEncoder.endEncoding()
    }
    
    private func renderText(in view: MTKView, encoder: MTLRenderCommandEncoder, state: RenderState, projectionMatrix: inout simd_float4x4, shaderManager: ShaderManager) {
        guard let atlas = atlas else { return }
        
        do {
            encoder.setRenderPipelineState(try shaderManager.getRenderPipeline(
                vertexFunctionName: "vertex_glyph",
                fragmentFunctionName: "fragment_token_effect",
                label: "Text Layer"
            ))
            
            encoder.setFragmentTexture(atlas.texture, index: 0)
            encoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)
            
            let layoutEngine = LayoutEngine()
            let glyphPositions = layoutEngine.layout(state: state, font: atlas.font)
            
            var allVertices: [Vertex] = []
            
            for gp in glyphPositions {
                guard let desc = atlas.descriptor(for: gp.glyph) else { continue }
                
                let x = Float(gp.position.x)
                let y = Float(gp.position.y)
                let w = Float(desc.size.width)
                let h = Float(desc.size.height)
                
                let tx1 = Float(desc.textureRect.minX)
                let ty1 = Float(desc.textureRect.minY)
                let tx2 = Float(desc.textureRect.maxX)
                let ty2 = Float(desc.textureRect.maxY)
                
                let tokenType = Float(gp.tokenType)
                let color = SIMD4<Float>(1, 1, 1, 1)
                
                // Quad as two triangles (triangle strip)
                // We use vertex_glyph which adds an offset, but we can bake it into the position
                // and set offset to (0,0)
                allVertices.append(contentsOf: [
                    Vertex(position: SIMD3<Float>(x, y, 0), color: color, texCoords: SIMD2<Float>(tx1, ty1), tokenType: tokenType),
                    Vertex(position: SIMD3<Float>(x + w, y, 0), color: color, texCoords: SIMD2<Float>(tx2, ty1), tokenType: tokenType),
                    Vertex(position: SIMD3<Float>(x, y + h, 0), color: color, texCoords: SIMD2<Float>(tx1, ty2), tokenType: tokenType),
                    Vertex(position: SIMD3<Float>(x + w, y + h, 0), color: color, texCoords: SIMD2<Float>(tx2, ty2), tokenType: tokenType)
                ])
            }
            
            if !allVertices.isEmpty {
                var zeroOffset = SIMD2<Float>(0, 0)
                encoder.setVertexBytes(&zeroOffset, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
                
                // For a strip of quads, we can't easily use one draw call without degenerate triangles 
                // or using an index buffer. For this optimization, we'll use .triangle and 6 vertices per quad.
                
                var indexedVertices: [Vertex] = []
                for i in stride(from: 0, to: allVertices.count, by: 4) {
                    let v = Array(allVertices[i..<i+4])
                    // 0, 1, 2, 2, 1, 3
                    indexedVertices.append(contentsOf: [v[0], v[1], v[2], v[2], v[1], v[3]])
                }
                
                encoder.setVertexBytes(indexedVertices, length: MemoryLayout<Vertex>.stride * indexedVertices.count, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: indexedVertices.count)
            }
        } catch {
            print("❌ Metal error rendering text: \(error)")
        }
    }
    
    private func renderSelection(in view: MTKView, encoder: MTLRenderCommandEncoder, range: Range<Int>, projectionMatrix: inout simd_float4x4, shaderManager: ShaderManager) {
        guard let atlas = atlas, let state = renderState else { return }
        
        do {
            encoder.setRenderPipelineState(try shaderManager.getRenderPipeline(
                vertexFunctionName: "vertex_simple",
                fragmentFunctionName: "fragment_selection",
                label: "Selection Layer"
            ))
            
            encoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)
            
            let layoutEngine = LayoutEngine()
            let startRect = layoutEngine.rect(for: range.lowerBound, state: state, font: atlas.font)
            let endRect = layoutEngine.rect(for: range.upperBound, state: state, font: atlas.font)
            
            let selectionRect = CGRect(
                x: startRect.origin.x,
                y: startRect.origin.y,
                width: endRect.origin.x - startRect.origin.x,
                height: startRect.height
            )
            
            let selectionColor = SIMD4<Float>(0.0, 0.5, 1.0, 0.5) // Selection color
            
            let vertices: [Vertex] = [
                Vertex(position: SIMD3<Float>(Float(selectionRect.minX), Float(selectionRect.minY), 0), color: selectionColor, tokenType: 0),
                Vertex(position: SIMD3<Float>(Float(selectionRect.maxX), Float(selectionRect.minY), 0), color: selectionColor, tokenType: 0),
                Vertex(position: SIMD3<Float>(Float(selectionRect.minX), Float(selectionRect.maxY), 0), color: selectionColor, tokenType: 0),
                Vertex(position: SIMD3<Float>(Float(selectionRect.maxX), Float(selectionRect.maxY), 0), color: selectionColor, tokenType: 0)
            ]
            encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
        } catch {
            print("❌ Metal error rendering selection: \(error)")
        }
    }
    
    private func renderCursor(in view: MTKView, encoder: MTLRenderCommandEncoder, projectionMatrix: inout simd_float4x4, shaderManager: ShaderManager) {
        guard let startTime = animationStartTime, let atlas = atlas else { return }
        
        let elapsed = Float(Date().timeIntervalSince(startTime))
        var progress = min(elapsed / Float(animationDuration), 1.0)
        
        do {
            encoder.setRenderPipelineState(try shaderManager.getRenderPipeline(
                vertexFunctionName: "vertex_cursor",
                fragmentFunctionName: "fragment_cursor",
                label: "Cursor Layer"
            ))
            
            var start = SIMD2<Float>(Float(previousCursorPos.x), Float(previousCursorPos.y))
            var target = SIMD2<Float>(Float(targetCursorPos.x), Float(targetCursorPos.y))
            var size = SIMD2<Float>(2.0, Float(atlas.font.pointSize))
            
            encoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)
            encoder.setVertexBytes(&start, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
            encoder.setVertexBytes(&target, length: MemoryLayout<SIMD2<Float>>.size, index: 3)
            encoder.setVertexBytes(&progress, length: MemoryLayout<Float>.size, index: 4)
            encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.size, index: 5)
            
            let vertices: [Vertex] = [
                Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, -1, 0), color: SIMD4<Float>(1, 1, 1, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(-1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), tokenType: 0),
                Vertex(position: SIMD3<Float>(1, 1, 0), color: SIMD4<Float>(1, 1, 1, 1), tokenType: 0)
            ]
            encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
        } catch {
            print("❌ Metal error rendering cursor: \(error)")
        }
    }
}

#endif