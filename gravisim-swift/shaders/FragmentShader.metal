//
//  FragmentShader.metal
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

#include <metal_stdlib>
using namespace metal;

// Фрагментный шейдер с маской круга для рендера точек как шаров
fragment float4 fragment_main(float2 pointCoord [[point_coord]]) {
    // pointCoord — координаты пикселя внутри точки (0..1 по x и y)

    float2 center = float2(0.5, 0.5);            // Центр точки
    float dist = distance(pointCoord, center);   // Расстояние от центра

    if (dist > 0.5) {
        discard_fragment(); // Отбрасываем пиксели вне круга (прозрачные)
    }

    return float4(1, 1, 1, 1); // Белый цвет для круга
}
