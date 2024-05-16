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
    // Variables to hold Metal objects
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    
    // Initializer which sets up the Metal device, command queue, and pipeline state
    init(metalKitView: MTKView) {
        self.device = MTLCreateSystemDefaultDevice() // Create the default Metal device
        metalKitView.device = self.device // Assign the device to the MetalKit view
        self.commandQueue = device?.makeCommandQueue() // Create a command queue
        setupPipeline() // Set up the rendering pipeline
    }
    
    // Method to set up the rendering pipeline
    func setupPipeline() {
        let library = device?.makeDefaultLibrary() // Get the default library containing shader code
        let vertexFunction = library?.makeFunction(name: "vertex_main") // Get the vertex shader function
        let fragmentFunction = library?.makeFunction(name: "fragment_main") // Get the fragment shader function
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor() // Create a pipeline descriptor
        pipelineDescriptor.vertexFunction = vertexFunction // Assign the vertex shader function
        pipelineDescriptor.fragmentFunction = fragmentFunction // Assign the fragment shader function
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm // Set the pixel format for color attachments
        
        do {
            // Try to create the pipeline state
            pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            // Print the error if pipeline state creation fails
            print(error)
        }
    }
    
    // Method to perform drawing operations
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, // Get the current drawable
              let renderPassDescriptor = view.currentRenderPassDescriptor, // Get the render pass descriptor
              let commandBuffer = commandQueue?.makeCommandBuffer(), // Create a command buffer
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { // Create a render command encoder
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState!) // Set the pipeline state
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3) // Draw a triangle
        renderEncoder.endEncoding() // End encoding
        
        commandBuffer.present(drawable) // Present the drawable
        commandBuffer.commit() // Commit the command buffer
    }
}

// Custom MTKView class for the game
class GameView: MTKView {
    var renderer: Renderer!
    
    // Initializer to set up the view and renderer
    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice()) // Initialize with default device
        self.colorPixelFormat = .bgra8Unorm // Set the pixel format
        self.renderer = Renderer(metalKitView: self) // Create the renderer
        self.delegate = self // Set the delegate to self
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0) // Set the background color
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented") // Not implemented
    }
}

// Extension to conform to MTKViewDelegate protocol
extension GameView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size change if needed
    }
    
    func draw(in view: MTKView) {
        renderer.draw(in: view) // Delegate drawing to the renderer
    }
}

// SwiftUI representation of the GameView for preview
struct GameViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        return GameView() // Create and return the GameView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update the view if needed
    }
}

// SwiftUI preview provider
#Preview {
    GameViewRepresentable() // Provide a preview of the GameView
}
