//
//  Shaders.metal
//  Ferrufi
//
//  Metal shaders for enhanced UI rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoords;
    float tokenType [[flat]]; // 0: Default, 1: Glow, 2: Underline
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
    float2 resolution;
};

// MARK: - Basic Vertex Shaders

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;

    out.color = in.color;
    out.texCoords = in.texCoords;
    out.tokenType = 0.0;

    return out;
}

vertex VertexOut vertex_simple(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position.xy, 0.0, 1.0);
    out.color = in.color;
    out.texCoords = in.texCoords;
    out.tokenType = 0.0;
    return out;
}

// MARK: - Fragment Shaders

fragment float4 fragment_solid(VertexOut in [[stage_in]]) {
    return in.color;
}

fragment float4 fragment_textured(VertexOut in [[stage_in]],
                                 texture2d<float> texture [[texture(0)]],
                                 sampler textureSampler [[sampler(0)]]) {
    float4 textureColor = texture.sample(textureSampler, in.texCoords);
    return textureColor * in.color;
}

// MARK: - UI Component Shaders

// Rounded rectangle with smooth edges
fragment float4 fragment_rounded_rect(VertexOut in [[stage_in]],
                                     constant float& cornerRadius [[buffer(0)]],
                                     constant float2& size [[buffer(1)]]) {
    float2 coord = in.texCoords * size;
    float2 center = size * 0.5;

    // Distance from center
    float2 d = abs(coord - center) - (size * 0.5 - cornerRadius);
    float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - cornerRadius;

    // Smooth edge
    float alpha = 1.0 - smoothstep(-1.0, 1.0, distance);

    return float4(in.color.rgb, in.color.a * alpha);
}

// Gradient background
fragment float4 fragment_gradient(VertexOut in [[stage_in]],
                                 constant float4& color1 [[buffer(0)]],
                                 constant float4& color2 [[buffer(1)]],
                                 constant float2& direction [[buffer(2)]]) {
    float t = dot(in.texCoords, normalize(direction)) * 0.5 + 0.5;
    return mix(color1, color2, t);
}

// Smooth circle/dot
fragment float4 fragment_circle(VertexOut in [[stage_in]],
                               constant float& radius [[buffer(0)]]) {
    float2 center = float2(0.5, 0.5);
    float dist = distance(in.texCoords, center);
    float alpha = 1.0 - smoothstep(radius - 0.01, radius + 0.01, dist);

    return float4(in.color.rgb, in.color.a * alpha);
}

// Text rendering with SDF
fragment float4 fragment_sdf_text(VertexOut in [[stage_in]],
                                 texture2d<float> sdfTexture [[texture(0)]],
                                 sampler textureSampler [[sampler(0)]],
                                 constant float& threshold [[buffer(0)]]) {
    float distance = sdfTexture.sample(textureSampler, in.texCoords).r;
    float alpha = smoothstep(threshold - 0.1, threshold + 0.1, distance);

    return float4(in.color.rgb, in.color.a * alpha);
}

// Advanced token effect fragment shader
fragment float4 fragment_token_effect(VertexOut in [[stage_in]],
                                     texture2d<float> atlas [[texture(0)]],
                                     sampler atlasSampler [[sampler(0)]],
                                     constant float& time [[buffer(0)]]) {
    float4 texColor = atlas.sample(atlasSampler, in.texCoords);
    float alpha = texColor.r; // Assuming R8Unorm atlas
    
    float4 baseColor = in.color;
    baseColor.a *= alpha;
    
    if (in.tokenType == 1.0) { // Glow effect
        float glow = (sin(time * 3.0) + 1.0) * 0.5;
        baseColor.rgb += baseColor.rgb * glow * 0.5;
    } else if (in.tokenType == 2.0) { // Underline effect
        float underlineY = 0.9;
        if (in.texCoords.y > underlineY) {
            baseColor = in.color;
        }
    }
    
    return baseColor;
}

// MARK: - Animation Shaders

// Pulsing effect
fragment float4 fragment_pulse(VertexOut in [[stage_in]],
                              constant float& time [[buffer(0)]],
                              constant float& frequency [[buffer(1)]]) {
    float pulse = (sin(time * frequency) + 1.0) * 0.5;
    float4 color = in.color;
    color.a *= pulse;
    return color;
}

// Ripple effect
fragment float4 fragment_ripple(VertexOut in [[stage_in]],
                               constant float& time [[buffer(0)]],
                               constant float2& center [[buffer(1)]],
                               constant float& speed [[buffer(2)]]) {
    float2 coord = in.texCoords;
    float dist = distance(coord, center);
    float ripple = sin(dist * 20.0 - time * speed) * 0.5 + 0.5;

    float4 color = in.color;
    color.rgb += ripple * 0.2;
    return color;
}

// MARK: - Performance Optimized Shaders

// Fast blur (approximate)
fragment float4 fragment_fast_blur(VertexOut in [[stage_in]],
                                  texture2d<float> texture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant float2& texelSize [[buffer(0)]]) {
    float4 color = float4(0.0);

    // Simple 5x5 blur kernel
    for (int x = -2; x <= 2; ++x) {
        for (int y = -2; y <= 2; ++y) {
            float2 offset = float2(x, y) * texelSize;
            color += texture.sample(textureSampler, in.texCoords + offset);
        }
    }

    return color / 25.0;
}

// High-performance glyph rendering
vertex VertexOut vertex_glyph(VertexIn in [[stage_in]],
                             constant float4x4& projectionMatrix [[buffer(1)]],
                             constant float2& offset [[buffer(2)]],
                             constant float& tokenType [[buffer(3)]]) {
    VertexOut out;
    
    // Position the glyph quad and apply offset
    float4 pos = float4(in.position.xy + offset, 0.0, 1.0);
    out.position = projectionMatrix * pos;
    
    out.color = in.color;
    out.texCoords = in.texCoords;
    out.tokenType = tokenType;
    
    return out;
}

// High-performance line rendering
vertex VertexOut vertex_line(VertexIn in [[stage_in]],
                            constant float& lineWidth [[buffer(1)]],
                            constant float2& resolution [[buffer(2)]]) {
    VertexOut out;

    // Convert line width to NDC space
    float2 ndc_width = lineWidth / resolution;

    // Offset vertices for line thickness
    float2 offset = in.texCoords * ndc_width;
    out.position = float4(in.position.xy + offset, 0.0, 1.0);
    out.color = in.color;
    out.texCoords = in.texCoords;
    out.tokenType = 0.0;

    return out;
}

// Smooth line fragment shader
fragment float4 fragment_smooth_line(VertexOut in [[stage_in]]) {
    // Create smooth edges for the line
    float alpha = 1.0 - abs(in.texCoords.y * 2.0 - 1.0);
    alpha = smoothstep(0.0, 1.0, alpha);

    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Graph Rendering Shaders

// Node rendering with glow effect
fragment float4 fragment_graph_node(VertexOut in [[stage_in]],
                                   constant float& radius [[buffer(0)]],
                                   constant float& glowIntensity [[buffer(1)]]) {
    float2 center = float2(0.5, 0.5);
    float dist = distance(in.texCoords, center);

    // Main node
    float nodeAlpha = 1.0 - smoothstep(radius - 0.02, radius, dist);

    // Glow effect
    float glowRadius = radius + 0.2;
    float glowAlpha = exp(-dist * dist / (glowRadius * glowRadius)) * glowIntensity;

    float totalAlpha = max(nodeAlpha, glowAlpha);

    return float4(in.color.rgb, in.color.a * totalAlpha);
}

// Edge/connection rendering
fragment float4 fragment_graph_edge(VertexOut in [[stage_in]],
                                   constant float& strength [[buffer(0)]]) {
    // Fade edges based on connection strength
    float alpha = in.color.a * strength;

    // Add subtle gradient along the edge
    float gradient = 1.0 - abs(in.texCoords.y - 0.5) * 2.0;
    alpha *= smoothstep(0.0, 1.0, gradient);

    return float4(in.color.rgb, alpha);
}

// MARK: - Compute Shaders for Syntax Highlighting

// Token types for lexing
// 0: Default, 1: Keyword, 2: Type, 3: String, 4: Comment, 5: Number
kernel void lex_mufi(device const uint16_t* chars [[buffer(0)]],
                    device uint8_t* attributes [[buffer(1)]],
                    constant uint& length [[buffer(2)]],
                    uint index [[thread_position_in_grid]]) {
    if (index >= length) return;
    
    // Default to plain text
    attributes[index] = 0;
    
    uint16_t c = chars[index];
    
    // Simple number detection
    if (c >= '0' && c <= '9') {
        attributes[index] = 5;
        return;
    }
    
    // Simple comment detection (starts with //)
    if (index + 1 < length && chars[index] == '/' && chars[index+1] == '/') {
        // This is a naive implementation; a real one would use a state machine
        for (uint i = index; i < length && chars[i] != '\n'; i++) {
            // Note: In a real parallel lexer, we'd use a prefix sum or global state
            // For now, we'll mark the start
        }
    }
}

// MARK: - Compute Shaders for Text Layout

kernel void compute_text_layout(device float4* positions [[buffer(0)]],
                               device float4* glyphData [[buffer(1)]],
                               constant float2& startPosition [[buffer(2)]],
                               constant float& lineHeight [[buffer(3)]],
                               uint index [[thread_position_in_grid]]) {

    float4 glyph = glyphData[index];
    float x = glyph.x; // Character width
    float y = glyph.y; // Character height
    float advance = glyph.z;

    // Calculate position for this character
    positions[index] = float4(
        startPosition.x + advance * index,
        startPosition.y,
        x, y
    );
}

// MARK: - Navigation Shaders

// Code minimap shader
fragment float4 fragment_minimap(VertexOut in [[stage_in]],
                                constant float4& accentColor [[buffer(0)]]) {
    float2 uv = in.texCoords;
    
    // Simulate code structure with blocks
    float line_width = fract(uv.y * 50.0) > 0.3 ? 1.0 : 0.0;
    float indent = step(0.1 + 0.2 * sin(floor(uv.y * 50.0)), uv.x);
    float length = step(uv.x, 0.4 + 0.5 * cos(floor(uv.y * 50.0)));
    
    float alpha = line_width * indent * length * 0.3;
    
    return float4(accentColor.rgb, alpha);
}

// MARK: - Special Effect Shaders

// Animated mesh gradient background
fragment float4 fragment_background_mesh(VertexOut in [[stage_in]],
                                        constant float& time [[buffer(0)]],
                                        constant float4& accentColor [[buffer(1)]]) {
    float2 uv = in.texCoords;
    
    // Create multiple moving centers for the gradient
    float2 p1 = float2(0.5 + 0.3 * sin(time * 0.5), 0.5 + 0.3 * cos(time * 0.3));
    float2 p2 = float2(0.5 + 0.3 * cos(time * 0.4), 0.5 + 0.3 * sin(time * 0.6));
    
    float d1 = distance(uv, p1);
    float d2 = distance(uv, p2);
    
    // Calculate color based on distance to moving points
    float intensity = (sin(d1 * 10.0 - time) + 1.0) * 0.5;
    intensity += (cos(d2 * 12.0 + time * 0.8) + 1.0) * 0.5;
    intensity *= 0.2; // Keep it subtle
    
    float4 baseColor = accentColor;
    baseColor.a = 0.03 + intensity * 0.05; // Very subtle transparency
    
    return baseColor;
}

// Shimmer effect for loading states
fragment float4 fragment_shimmer(VertexOut in [[stage_in]],
                                constant float& time [[buffer(0)]],
                                constant float& speed [[buffer(1)]]) {
    float shimmer = sin((in.texCoords.x + time * speed) * 3.14159) * 0.5 + 0.5;
    shimmer = pow(shimmer, 4.0); // Make it more focused

    float4 color = in.color;
    color.rgb += shimmer * 0.3;

    return color;
}

// Particle system for dynamic effects
struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float4 color;
};

kernel void update_particles(device Particle* particles [[buffer(0)]],
                           constant float& deltaTime [[buffer(1)]],
                           constant float2& gravity [[buffer(2)]],
                           uint index [[thread_position_in_grid]]) {

    Particle particle = particles[index];

    // Update physics
    particle.velocity += gravity * deltaTime;
    particle.position += particle.velocity * deltaTime;
    particle.life -= deltaTime;

    // Fade out over time
    particle.color.a = max(0.0, particle.life);

    particles[index] = particle;
}
