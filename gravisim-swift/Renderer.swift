//
//  Renderer.swift
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

// MARK: RENDERING

import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let computePipeline: MTLComputePipelineState
    let depthStencilState: MTLDepthStencilState
    let particleCount = 1024 * 5

    var positionsBuffer: MTLBuffer
    var velocitiesBuffer: MTLBuffer
    var matrixBuffer: MTLBuffer
    var fpsCounter: FPSCounter? = nil
    
    init(mtkView: MTKView) {
        device = mtkView.device!
        commandQueue = device.makeCommandQueue()!

        let library = device.makeDefaultLibrary()!
        let vertex = library.makeFunction(name: "vertex_main")!
        let fragment = library.makeFunction(name: "fragment_main")!
        let compute = library.makeFunction(name: "physics_step")!

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertex
        pipelineDesc.fragmentFunction = fragment
        pipelineDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)

        computePipeline = try! device.makeComputePipelineState(function: compute)

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)!

        positionsBuffer = device.makeBuffer(length: MemoryLayout<vector_float4>.stride * particleCount, options: [])!
        velocitiesBuffer = device.makeBuffer(length: MemoryLayout<vector_float4>.stride * particleCount, options: [])!
        matrixBuffer = device.makeBuffer(length: MemoryLayout<matrix_float4x4>.stride, options: [])!

        // Инициализация частиц
        let posPtr = positionsBuffer.contents().bindMemory(to: vector_float4.self, capacity: particleCount)
        let velPtr = velocitiesBuffer.contents().bindMemory(to: vector_float4.self, capacity: particleCount)
        for i in 0..<particleCount {
            posPtr[i] = [Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1), 1]
            velPtr[i] = [0, 0, 0, 0]
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        let commandBuffer = commandQueue.makeCommandBuffer()!

        // --- Compute Pass ---
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipeline)
            computeEncoder.setBuffer(positionsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(velocitiesBuffer, offset: 0, index: 1)
            var count = UInt32(particleCount)
            computeEncoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 2)

            let gridSize = MTLSize(width: particleCount, height: 1, depth: 1)
            let threadGroupSize = MTLSize(width: min(computePipeline.maxTotalThreadsPerThreadgroup, particleCount), height: 1, depth: 1)
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
        }

        // --- Update Camera Matrix ---
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projection = perspectiveMatrix(fovyRadians: .pi / 3, aspect: aspect, nearZ: 0.1, farZ: 100)
        let viewMatrix = lookAtMatrix(eye: [0, 0, 5], center: [0, 0, 0], up: [0, 1, 0])
        var vpMatrix = projection * viewMatrix
        memcpy(matrixBuffer.contents(), &vpMatrix, MemoryLayout<matrix_float4x4>.stride)

        // --- Render Pass ---
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setDepthStencilState(depthStencilState)

            renderEncoder.setVertexBuffer(positionsBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(velocitiesBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)

            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
            renderEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Отметим, что кадр завершён
        fpsCounter?.frameCompleted()
    }
}

// MARK: MATH UTILS

func perspectiveMatrix(fovyRadians fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = farZ - nearZ
    let zScale = -(farZ + nearZ) / zRange
    let wzScale = -2 * farZ * nearZ / zRange

    return matrix_float4x4(columns: (
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    ))
}

func lookAtMatrix(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)

    let translate = SIMD3<Float>(
        -dot(x, eye),
        -dot(y, eye),
        -dot(z, eye)
    )

    return matrix_float4x4(columns: (
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(translate.x, translate.y, translate.z, 1)
    ))
}
