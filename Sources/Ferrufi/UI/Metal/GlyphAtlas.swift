//
//  GlyphAtlas.swift
//  Ferrufi
//
//  Manages a texture atlas of pre-rendered font glyphs for Metal rendering.
//

import AppKit
import Metal
import CoreText

public final class GlyphAtlas {
    public let texture: MTLTexture
    public let font: NSFont
    private var glyphDescriptors: [Character: GlyphDescriptor] = [:]
    
    public struct GlyphDescriptor {
        public let textureRect: CGRect // Normalized 0..1
        public let size: CGSize
        public let advance: CGFloat
    }
    
    public init(device: MTLDevice, font: NSFont) {
        self.font = font
        
        // Define characters to include in atlas
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:;?!()[]{}<>+-*/=%&^@#$ "
        let atlasSize: CGFloat = 512
        
        // 1. Create a context to draw glyphs
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        let context = CGContext(data: nil, 
                               width: Int(atlasSize), 
                               height: Int(atlasSize), 
                               bitsPerComponent: 8, 
                               bytesPerRow: Int(atlasSize), 
                               space: colorSpace, 
                               bitmapInfo: bitmapInfo)!
        
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: atlasSize, height: atlasSize))
        context.setFillColor(gray: 1, alpha: 1)
        
        // 2. Draw glyphs and store descriptors
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let padding: CGFloat = 2
        
        for char in characters {
            let nsChar = String(char) as NSString
            let size = nsChar.size(withAttributes: [.font: font])
            
            if currentX + size.width + padding > atlasSize {
                currentX = 0
                currentY += font.pointSize + padding
            }
            
            let rect = CGRect(x: currentX, y: currentY, width: size.width, height: size.height)
            nsChar.draw(in: rect, withAttributes: [.font: font, .foregroundColor: NSColor.white])
            
            glyphDescriptors[char] = GlyphDescriptor(
                textureRect: CGRect(x: currentX / atlasSize, 
                                   y: currentY / atlasSize, 
                                   width: size.width / atlasSize, 
                                   height: size.height / atlasSize),
                size: size,
                advance: size.width
            )
            
            currentX += size.width + padding
        }
        
        // 3. Create Metal texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: Int(atlasSize), height: Int(atlasSize), mipmapped: false)
        textureDescriptor.usage = .shaderRead
        self.texture = device.makeTexture(descriptor: textureDescriptor)!
        
        self.texture.replace(region: MTLRegionMake2D(0, 0, Int(atlasSize), Int(atlasSize)), 
                            mipmapLevel: 0, 
                            withBytes: context.data!, 
                            bytesPerRow: Int(atlasSize))
    }
    
    public func descriptor(for char: Character) -> GlyphDescriptor? {
        return glyphDescriptors[char]
    }
}
