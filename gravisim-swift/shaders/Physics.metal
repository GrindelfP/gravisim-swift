//
//  Physics.metal
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

#include <metal_stdlib>
using namespace metal;

// Compute shader для расчёта сил и обновления позиций и скоростей частиц
kernel void physics_step(
    device float4 *positions [[buffer(0)]],    // Буфер с позициями
    device float4 *velocities [[buffer(1)]],   // Буфер со скоростями
    constant uint &count [[buffer(2)]],        // Кол-во частиц
    uint id [[thread_position_in_grid]]        // Индекс текущей частицы
) {
    if (id >= count) return; // Защита от выхода за пределы массива

    float G = 0.001f;        // Гравитационная постоянная (условная)
    float dt = 0.01f;        // Шаг времени

    float4 pos = positions[id];       // Позиция текущей частицы
    float4 vel = velocities[id];      // Скорость текущей частицы
    float3 acc = float3(0);           // Начальное ускорение

    // Вычисляем гравитационное ускорение от всех других тел
    for (uint i = 0; i < count; ++i) {
        if (i == id) continue; // Не считаем силу от себя

        float3 dir = positions[i].xyz - pos.xyz; // Вектор от текущей к i-той частице
        float dist = length(dir) + 0.01f;        // Расстояние + смещение для стабильности
        acc += G * dir / pow(dist, 3);           // Гравитационный закон
    }

    // Обновляем скорость с учётом ускорения
    vel.xyz += acc * dt;
    // Обновляем позицию с учётом скорости
    pos.xyz += vel.xyz * dt;

    // Записываем обновлённые значения обратно в буферы
    positions[id] = pos;
    velocities[id] = vel;
}
