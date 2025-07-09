//
//  NBodyMetal.swift
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

import SwiftUI
import MetalKit

@main
struct NBodyApp: App {
    @StateObject var fpsCounter = FPSCounter()

    
    var body: some Scene {
            WindowGroup {
                ZStack(alignment: .topTrailing) {
                    MetalView(fpsCounter: fpsCounter)
                        .ignoresSafeArea()

                    Text("FPS: \(fpsCounter.fps)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
}

// Для macOS — используем NSViewRepresentable, чтобы встроить MTKView в SwiftUI
struct MetalView: NSViewRepresentable {
    @ObservedObject var fpsCounter: FPSCounter

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float

        let renderer = Renderer(mtkView: view)
        renderer.fpsCounter = fpsCounter
        view.delegate = renderer
        context.coordinator.renderer = renderer

        // Устанавливаем делегат окна, когда оно появится
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = context.coordinator
            }
        }

        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var renderer: Renderer?

        func windowWillClose(_ notification: Notification) {
            // Останавливаем рендерер или освобождаем ресурсы, если нужно
            // Например, принудительно завершаем процесс:
            NSApplication.shared.terminate(nil)
        }
    }
}
