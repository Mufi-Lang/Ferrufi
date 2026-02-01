//
//  MufiComputeHighlighter.swift
//  Ferrufi
//
//  GPU-accelerated syntax highlighter using Metal Compute Shaders.
//

import AppKit
import Metal
import Foundation

/// A high-performance syntax highlighter that offloads tokenization to the GPU.
@MainActor
public final class MufiComputeHighlighter {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState?
    
    private let theme: IronTheme
    
    public init?(theme: IronTheme) {
        self.theme = theme
        
        // Initialize Metal from shared manager
        guard let device = MetalDeviceManager.shared.device,
              let queue = MetalDeviceManager.shared.commandQueue else {
            print("❌ Metal error: Metal not initialized.")
            return nil
        }
        
        self.device = device
        self.commandQueue = queue
        
        guard let library = MetalDeviceManager.shared.defaultLibrary else {
            // Error already printed by manager
            return nil
        }
        
        guard let function = library.makeFunction(name: "lex_mufi") else {
            print("❌ Metal error: Could not find lex_mufi function.")
            return nil
        }
        
        do {
            self.computePipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ Metal error: Failed to create compute pipeline state: \(error)")
            return nil
        }
    }
    
    public func highlight(in storage: NSTextStorage) {
        let text = storage.string
        let utf16Chars = Array(text.utf16)
        let length = utf16Chars.count
        guard length > 0 else { return }
        
        // 1. Prepare Buffers
        let charBuffer = device.makeBuffer(bytes: utf16Chars, length: length * MemoryLayout<UInt16>.stride, options: .storageModeShared)
        let attrBuffer = device.makeBuffer(length: length * MemoryLayout<UInt8>.stride, options: .storageModeShared)
        
        // 2. Dispatch Compute
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineState else { return }
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(charBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(attrBuffer, offset: 0, index: 1)
        
        var uintLength = UInt32(length)
        computeEncoder.setBytes(&uintLength, length: MemoryLayout<UInt32>.size, index: 2)
        
        let threadGroupSize = MTLSize(width: min(length, pipelineState.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (length + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // 3. Apply Attributes back to NSTextStorage
        let attributes = attrBuffer?.contents().assumingMemoryBound(to: UInt8.self)
        
        storage.beginEditing()
        // Reset
        storage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: length))
        storage.addAttribute(.foregroundColor, value: NSColor(theme.colors.foreground), range: NSRange(location: 0, length: length))
        
        // Apply token colors based on GPU results
        for i in 0..<length {
            let type = attributes?[i] ?? 0
            if type == 5 { // Number
                storage.addAttribute(.foregroundColor, value: NSColor(theme.colors.warning), range: NSRange(location: i, length: 1))
            }
            // More types would be handled here
        }
        storage.endEditing()
    }
}
