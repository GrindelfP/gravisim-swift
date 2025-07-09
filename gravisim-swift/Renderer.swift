//
//  Renderer.swift
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice           // GPU устройство
    let commandQueue: MTLCommandQueue // Очередь команд для GPU
    let pipelineState: MTLRenderPipelineState // Конвейер для отрисовки
    let computePipeline: MTLComputePipelineState // Конвейер для вычислений (compute shader)
    let depthStencilState: MTLDepthStencilState // Настройка теста глубины
    let particleCount = 1024 * 2      // Кол-во тел в симуляции
    var positionsBuffer: MTLBuffer  // Буфер с позициями частиц (x,y,z,w)
    var velocitiesBuffer: MTLBuffer // Буфер с скоростями частиц
    var fpsCounter: FPSCounter? = nil  // Добавим ссылку на FPS-счётчик

    init(mtkView: MTKView) {
        device = mtkView.device!              // Получаем устройство из вью
        commandQueue = device.makeCommandQueue()! // Создаём очередь команд

        // Загружаем шейдеры из библиотеки по умолчанию (файлы .metal)
        let library = device.makeDefaultLibrary()!
        let vertex = library.makeFunction(name: "vertex_main")!       // Вершинный шейдер
        let fragment = library.makeFunction(name: "fragment_main")!   // Фрагментный шейдер
        let compute = library.makeFunction(name: "physics_step")!     // Compute шейдер

        // Настраиваем графический конвейер рендеринга
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertex // Назначаем вершины
        pipelineDesc.fragmentFunction = fragment // Назначаем фрагменты
        pipelineDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat // Формат цвета
        pipelineDesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat // Формат глубины
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)

        // Настраиваем конвейер вычислений (compute shader)
        computePipeline = try! device.makeComputePipelineState(function: compute)

        // Настройка теста глубины для 3D отрисовки
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less     // Отрисовывать, если ближе к камере
        depthDesc.isDepthWriteEnabled = true       // Записывать глубину в буфер
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)!

        // Создаём буферы для позиций и скоростей частиц
        positionsBuffer = device.makeBuffer(length: MemoryLayout<vector_float4>.stride * particleCount, options: [])!
        velocitiesBuffer = device.makeBuffer(length: MemoryLayout<vector_float4>.stride * particleCount, options: [])!

        // Инициализируем позиции случайными значениями в кубе [-1..1]
        let ptr = positionsBuffer.contents().bindMemory(to: vector_float4.self, capacity: particleCount)
        for i in 0..<particleCount {
            ptr[i] = [Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1), 1]
        }

        // Инициализируем скорости нулями (покоящиеся частицы)
        let vptr = velocitiesBuffer.contents().bindMemory(to: vector_float4.self, capacity: particleCount)
        for i in 0..<particleCount {
            vptr[i] = [0, 0, 0, 0]
        }
    }

    // Вызывается при изменении размера окна
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    // Основной метод отрисовки кадра
    func draw(in view: MTKView) {
        // Получаем текущий drawable (текстуру для вывода) и рендер-пассы
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        // Создаём буфер команд
        let commandBuffer = commandQueue.makeCommandBuffer()!

        // --- Вычислительный проход (Physics compute shader) ---
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipeline)  // Устанавливаем compute pipeline
            computeEncoder.setBuffer(positionsBuffer, offset: 0, index: 0)   // Передаём позиции
            computeEncoder.setBuffer(velocitiesBuffer, offset: 0, index: 1)  // Передаём скорости

            // Передаём число частиц как константу
            var count = UInt32(particleCount)
            computeEncoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 2)

            // Задаём размер рабочей группы и количество потоков
            let gridSize = MTLSize(width: particleCount, height: 1, depth: 1)
            let threadGroupSize = MTLSize(width: min(computePipeline.maxTotalThreadsPerThreadgroup, particleCount), height: 1, depth: 1)

            // Запускаем compute shader
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
        }

        // --- Рендеринг частиц ---
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.setRenderPipelineState(pipelineState) // Устанавливаем pipeline рендеринга
            renderEncoder.setDepthStencilState(depthStencilState) // Включаем тест глубины
            renderEncoder.setVertexBuffer(positionsBuffer, offset: 0, index: 0) // Передаём позиции в вершины
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount) // Рисуем точки
            renderEncoder.endEncoding()
        }

        // Показываем готовый drawable
        commandBuffer.present(drawable)
        // Отправляем команды на GPU
        commandBuffer.commit()
        
        // Отметим, что кадр завершён
        fpsCounter?.frameCompleted()
    }
}
