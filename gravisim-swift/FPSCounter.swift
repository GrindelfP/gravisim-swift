//
//  FPSCounter.swift
//  gravisim-swift
//
//  Created by Gregory Shipunov on 7/9/25.
//

import SwiftUI

class FPSCounter: ObservableObject {
    @Published var fps: Int = 0

    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = CACurrentMediaTime()

    func frameCompleted() {
        frameCount += 1
        let now = CACurrentMediaTime()
        if now - lastTimestamp >= 1.0 {
            fps = frameCount
            frameCount = 0
            lastTimestamp = now
        }
    }
}
