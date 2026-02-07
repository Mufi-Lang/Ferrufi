import Foundation
import Metal

#if canImport(Metal)

public enum ShaderError: Error {
    case deviceNotAvailable
    case libraryCreationFailed
    case functionNotFound(String)
    case pipelineCreationFailed(Error)
}

/// Manages and caches Metal pipeline states to avoid runtime compilation overhead.
public class ShaderManager {
    private let device: MTLDevice
    private let library: MTLLibrary
    private var renderPipelineCache: [String: MTLRenderPipelineState] = [:]
    private var computePipelineCache: [String: MTLComputePipelineState] = [:]
    
    /// Initializes the manager with a device and library.
    /// - Parameters:
    ///   - device: The Metal device used for pipeline creation.
    ///   - library: The shader library containing the functions.
    public init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
    }
    
    /// Retrieves or creates a render pipeline state.
    /// - Parameters:
    ///   - vertexFunctionName: The name of the vertex function.
    ///   - fragmentFunctionName: The name of the fragment function.
    ///   - label: An optional debug label for the pipeline.
    /// - Returns: A compiled `MTLRenderPipelineState`.
    public func getRenderPipeline(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        label: String? = nil
    ) throws -> MTLRenderPipelineState {
        let cacheKey = "\(vertexFunctionName)-\(fragmentFunctionName)"
        if let cached = renderPipelineCache[cacheKey] {
            return cached
        }
        
        guard let vertexFunction = library.makeFunction(name: vertexFunctionName) else {
            throw ShaderError.functionNotFound(vertexFunctionName)
        }
        
        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else {
            throw ShaderError.functionNotFound(fragmentFunctionName)
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = label
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        
        // Default blending
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        renderPipelineCache[cacheKey] = pipelineState
        return pipelineState
    }
    
    public func getComputePipeline(functionName: String) throws -> MTLComputePipelineState {
        if let cached = computePipelineCache[functionName] {
            return cached
        }
        
        guard let function = library.makeFunction(name: functionName) else {
            throw ShaderError.functionNotFound(functionName)
        }
        
        let pipelineState = try device.makeComputePipelineState(function: function)
        computePipelineCache[functionName] = pipelineState
        return pipelineState
    }
}

#endif
