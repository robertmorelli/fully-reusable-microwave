//
//  ContentView.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI
import MetalKit

// Basic Renderer class implementation
class Renderer {
    var device: MTLDevice?
    
    init(metalKitView: NSView) {
        self.device = MTLCreateSystemDefaultDevice()
        // Initialize other Metal components as needed
    }
}

class GameView: NSView {
    var renderer: Renderer!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupMetal()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupMetal()
    }
    
    private func setupMetal() {
        self.wantsLayer = true
        let metalLayer = CAMetalLayer()
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        self.layer = metalLayer
        self.renderer = Renderer(metalKitView: self)
    }
}

struct GameViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> GameView {
        return GameView(frame: .zero)
    }
    
    func updateNSView(_ nsView: GameView, context: Context) {
        // Update the view
    }
}

#Preview {
    GameViewRepresentable()
}
