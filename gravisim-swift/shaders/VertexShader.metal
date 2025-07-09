//
//  VertexFragment.metal
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

#include <metal_stdlib>
#include "VertexOut.h"
using namespace metal;

vertex VertexOut vertex_main(uint id [[vertex_id]],
                             const device float4 *positions [[buffer(0)]],
                             const device float4 *velocities [[buffer(1)]],
                             constant float4x4 &vpMatrix [[buffer(2)]]) {
    VertexOut out;
    float3 pos = positions[id].xyz;
    float3 vel = velocities[id].xyz;

    out.position = vpMatrix * float4(pos, 1.0);
    out.pointSize = 8.0 / (1.0 + length(pos)); // точки ближе — крупнее

    float maxSpeed = 2.0;
    float speedNorm = clamp(length(vel) / maxSpeed, 0.0, 1.0);
    float3 slowColor = float3(0.0, 0.3, 1.0);
    float3 fastColor = float3(1.0, 0.2, 0.0);
    float3 finalColor = mix(slowColor, fastColor, speedNorm);
    out.color = float4(finalColor, 1.0);

    return out;
}
