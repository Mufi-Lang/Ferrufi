//
//  Shaders.metal
//  Iron
//
//  Basic Metal shaders for Iron knowledge management application
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniform Structures

struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float time;
    float2 resolution;
};

struct Vertex {
    float3 position;
    float4 color;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
    float pointSize [[point_size]];
};

// MARK: - Basic Vertex Shader

vertex VertexOut vertex_basic(uint vertexID [[vertex_id]],
                             constant Vertex* vertices [[buffer(0)]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    float4 worldPosition = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.color = in.color;
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Basic Fragment Shader

fragment float4 fragment_basic(VertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Particle Vertex Shader

vertex VertexOut vertex_particle(uint vertexID [[vertex_id]],
                                constant Vertex* vertices [[buffer(0)]],
                                constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    // Add some animation based on time
    float3 animatedPosition = in.position;
    animatedPosition.y += sin(uniforms.time * 2.0 + in.position.x) * 0.1;

    float4 worldPosition = float4(animatedPosition, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.color = in.color;
    out.texCoord = in.texCoord;

    // Animate point size
    out.pointSize = 5.0 + sin(uniforms.time * 3.0) * 2.0;

    return out;
}

// MARK: - Particle Fragment Shader

fragment float4 fragment_particle(VertexOut in [[stage_in]]) {
    // Create circular particles
    float2 center = float2(0.5, 0.5);
    float2 uv = in.texCoord - center;
    float distance = length(uv);

    // Smooth falloff for circular shape
    float alpha = smoothstep(0.5, 0.3, distance);

    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Line Vertex Shader

vertex VertexOut vertex_line(uint vertexID [[vertex_id]],
                            constant Vertex* vertices [[buffer(0)]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    float4 worldPosition = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.color = in.color;
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Line Fragment Shader

fragment float4 fragment_line(VertexOut in [[stage_in]]) {
    // Anti-aliased line rendering
    float2 uv = in.texCoord;
    float lineWidth = 0.02;

    // Calculate distance from line center
    float distance = abs(uv.y - 0.5);
    float alpha = smoothstep(lineWidth, lineWidth * 0.5, distance);

    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Graph Node Vertex Shader

vertex VertexOut vertex_graph_node(uint vertexID [[vertex_id]],
                                  constant Vertex* vertices [[buffer(0)]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    // Scale nodes based on screen resolution for consistent sizing
    float scale = min(uniforms.resolution.x, uniforms.resolution.y) / 1000.0;
    float3 scaledPosition = in.position * scale;

    float4 worldPosition = float4(scaledPosition, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.color = in.color;
    out.texCoord = in.texCoord;

    // Dynamic point size based on importance/connections
    out.pointSize = 8.0 + in.color.a * 12.0; // Use alpha as size multiplier

    return out;
}

// MARK: - Graph Node Fragment Shader

fragment float4 fragment_graph_node(VertexOut in [[stage_in]],
                                   float2 pointCoord [[point_coord]]) {
    // Create circular nodes with border
    float2 center = float2(0.5, 0.5);
    float2 uv = pointCoord - center;
    float distance = length(uv);

    // Outer ring (border)
    float outerAlpha = smoothstep(0.5, 0.45, distance);
    // Inner fill
    float innerAlpha = smoothstep(0.45, 0.35, distance);

    // Border color (slightly darker)
    float3 borderColor = in.color.rgb * 0.7;

    // Mix border and fill
    float3 finalColor = mix(borderColor, in.color.rgb, innerAlpha);
    float finalAlpha = max(outerAlpha * 0.8, innerAlpha) * in.color.a;

    return float4(finalColor, finalAlpha);
}

// MARK: - Graph Edge Vertex Shader

vertex VertexOut vertex_graph_edge(uint vertexID [[vertex_id]],
                                  constant Vertex* vertices [[buffer(0)]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    float4 worldPosition = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;

    // Edge color with fade effect
    float alpha = in.color.a * (0.3 + 0.7 * sin(uniforms.time * 0.5 + in.position.x) * 0.5 + 0.5);
    out.color = float4(in.color.rgb, alpha);
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Graph Edge Fragment Shader

fragment float4 fragment_graph_edge(VertexOut in [[stage_in]]) {
    // Simple edge rendering with gradient
    float gradient = smoothstep(0.0, 1.0, in.texCoord.x);
    float alpha = in.color.a * gradient * (1.0 - gradient) * 4.0; // Peaked in the middle

    return float4(in.color.rgb, alpha);
}

// MARK: - Text Rendering Vertex Shader

vertex VertexOut vertex_text(uint vertexID [[vertex_id]],
                            constant Vertex* vertices [[buffer(0)]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    // Text should be rendered in screen space for pixel-perfect appearance
    float4 screenPosition = float4(in.position.xy / uniforms.resolution * 2.0 - 1.0, 0.0, 1.0);
    screenPosition.y = -screenPosition.y; // Flip Y for screen coordinates

    out.position = screenPosition;
    out.color = in.color;
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Text Rendering Fragment Shader

fragment float4 fragment_text(VertexOut in [[stage_in]],
                             texture2d<float> fontTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    // Sample the font texture
    float alpha = fontTexture.sample(textureSampler, in.texCoord).r;

    // Apply text color
    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Blur Effect Vertex Shader

vertex VertexOut vertex_blur(uint vertexID [[vertex_id]],
                            constant Vertex* vertices [[buffer(0)]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;

    Vertex in = vertices[vertexID];

    out.position = float4(in.position.xy, 0.0, 1.0);
    out.color = in.color;
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Blur Effect Fragment Shader

fragment float4 fragment_blur(VertexOut in [[stage_in]],
                             texture2d<float> inputTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    float3 result = float3(0.0);

    // Simple 5x5 Gaussian blur
    const int radius = 2;
    const float weights[5] = {0.06136, 0.24477, 0.38774, 0.24477, 0.06136};

    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            float2 offset = float2(float(i), float(j)) * texelSize;
            float weight = weights[i + radius] * weights[j + radius];
            result += inputTexture.sample(textureSampler, in.texCoord + offset).rgb * weight;
        }
    }

    return float4(result, 1.0);
}
