//
//  FragmentShader.metal
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

#include <metal_stdlib>
#include "VertexOut.h"
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
    float2 center = float2(0.5, 0.5);
    float dist = distance(pointCoord, center);
    if (dist > 0.5) discard_fragment();

    return in.color; // Используем цвет из вершины
}
