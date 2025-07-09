//
//  VertexFragment.metal
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

#include <metal_stdlib>
using namespace metal;

// Структура выходных данных вершины
struct VertexOut {
    float4 position [[position]]; // Позиция вершины в clip space
    float pointSize [[point_size]]; // Размер точки в пикселях
    float4 color;                 // Цвет вершины
};

// Вершинный шейдер — получает индекс вершины и позиции
vertex VertexOut vertex_main(uint id [[vertex_id]],
                             const device float4 *positions [[buffer(0)]]) {
    VertexOut out;

    out.position = positions[id]; // Прямо передаём позицию как clip space (уже в -1..1)
    out.pointSize = 15.0;         // Размер точки (делаем крупной, чтоб видеть)
    out.color = float4(1.0, 1.0, 1.0, 1.0); // Белый цвет

    return out;
}
