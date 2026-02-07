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
    private var glyphDescriptors: [CGGlyph: GlyphDescriptor] = [:]
    
    public struct GlyphDescriptor {
        public let textureRect: CGRect // Normalized 0..1
        public let size: CGSize
        public let offset: CGPoint
        public let advance: CGFloat
    }
    
    public init(device: MTLDevice, font: NSFont) {
        self.font = font
        
        let atlasSize: CGFloat = 1024
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
        
        // 1. Determine characters to cache (expanded set)
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:;?!()[]{}<>+-*/=%&^@#$ "
        
        // 2. Map characters to glyphs using CoreText
        let ctFont = font as CTFont
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        let chars = [UniChar](characters.utf16)
        CTFontGetGlyphsForCharacters(ctFont, chars, &glyphs, characters.count)
        
        // 3. Draw glyphs and store descriptors
        var currentX: CGFloat = 2
        var currentY: CGFloat = 2
        let padding: CGFloat = 4
        let lineHeight = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)
        
        for glyph in Set(glyphs) where glyph != 0 {
            var boundingRect = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, [glyph], &boundingRect, 1)
            
            // Advance calculation
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, [glyph], &advance, 1)
            
            if currentX + boundingRect.width + padding > atlasSize {
                currentX = 2
                currentY += lineHeight + padding
            }
            
            // Draw the glyph in the context
            let glyphOrigin = CGPoint(x: currentX - boundingRect.origin.x, y: currentY - boundingRect.origin.y)
            
            context.saveGState()
            // CoreText draws with Y-up, but our context is typically top-left origin for atlas
            // We need to be careful with coordinate systems here.
            
            var transform = CGAffineTransform(translationX: glyphOrigin.x, y: glyphOrigin.y)
            let path = CTFontCreatePathForGlyph(ctFont, glyph, &transform)
            if let path = path {
                context.addPath(path)
                context.fillPath()
            }
            context.restoreGState()
            
            glyphDescriptors[glyph] = GlyphDescriptor(
                textureRect: CGRect(x: currentX / atlasSize, 
                                   y: currentY / atlasSize, 
                                   width: boundingRect.width / atlasSize, 
                                   height: boundingRect.height / atlasSize),
                size: boundingRect.size,
                offset: boundingRect.origin,
                advance: advance.width
            )
            
            currentX += boundingRect.width + padding
        }
        
        // 4. Create Metal texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: Int(atlasSize), height: Int(atlasSize), mipmapped: false)
        textureDescriptor.usage = .shaderRead
        self.texture = device.makeTexture(descriptor: textureDescriptor)!
        
        self.texture.replace(region: MTLRegionMake2D(0, 0, Int(atlasSize), Int(atlasSize)), 
                            mipmapLevel: 0, 
                            withBytes: context.data!, 
                            bytesPerRow: Int(atlasSize))
    }
    
    public func descriptor(for glyph: CGGlyph) -> GlyphDescriptor? {
        return glyphDescriptors[glyph]
    }
}