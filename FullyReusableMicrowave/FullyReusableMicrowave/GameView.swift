//
//  ContentView.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI
import MetalKit



struct cell {
    var id: UInt64
}


// Basic Renderer class implementation
class Renderer {
    // Variables to hold Metal objects
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    var computePipelineState: MTLComputePipelineState?
    var lockGameBuffer = NSLock()
    var gameBuffer: MTLBuffer!
    var screenSizeBuffer: MTLBuffer!
    
    // Initializer which sets up the Metal device, command queue, and pipeline state
    init(metalKitView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        } // Create the default Metal device
        metalKitView.device = device // Assign the device to the MetalKit view
        commandQueue = device.makeCommandQueue() // Create a command queue
        
        let library = device.makeDefaultLibrary() // Get the default library containing shader code
        
        //render pipeline for draw
        let vertexFunction = library?.makeFunction(name: "vertex_main") // Get the vertex shader function
        let fragmentFunction = library?.makeFunction(name: "fragment_main") // Get the fragment shader function

        let pipelineDescriptor = MTLRenderPipelineDescriptor() // Create a pipeline descriptor
        pipelineDescriptor.vertexFunction = vertexFunction // Assign the vertex shader function
        pipelineDescriptor.fragmentFunction = fragmentFunction // Assign the fragment shader function
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm // Set the pixel format for color attachments
        
        //kernel update for world physics
        let kernelFunction = library?.makeFunction(name: "update_world")
        let computeDescriptor = MTLComputePipelineDescriptor()
        computeDescriptor.computeFunction = kernelFunction
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            computePipelineState = try device.makeComputePipelineState(
                descriptor: computeDescriptor,
                options: [.argumentInfo, .bufferTypeInfo],
                reflection: nil)
        } catch {
            fatalError("turds")
        }
        
        gameBuffer = device.makeBuffer(
            length: MemoryLayout<cell>.stride * 512 * 512,
            options: [ ])
        
        screenSizeBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.stride * 2,
            options: [ ])
        
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: .milliseconds(1000))
        timer.setEventHandler { self.updatePhysics() }
        timer.resume()
    }
    //make keyinput buffer
    //update on key clicks
    
    func updateSmoothPLayerLocation(){
        //update smooth player
    }
    
    func updatePhysics(){
        //get keyboard buffer state
        //process inputs
        
        //do gameboard and kernel call
        //gets called on a timer
        //lock when draw
        lockGameBuffer.lock()
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return
        }
        
        computeEncoder.setComputePipelineState(computePipelineState!)
        
        computeEncoder.setBuffer(gameBuffer, offset: 0, index: 0)
        
        let gridSize = MTLSize(width: 64, height: 64, depth: 1)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        lockGameBuffer.unlock()
    }
    
    // Method to perform drawing operations
    func draw(in view: MTKView) {
        lockGameBuffer.lock()
        //TODO: do lock stuff
        guard let drawable = view.currentDrawable, // Get the current drawable
              let renderPassDescriptor = view.currentRenderPassDescriptor, // Get the render pass descriptor
              let commandBuffer = commandQueue?.makeCommandBuffer(), // Create a command buffer
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { // Create a render command encoder
            return
        }
            
        
        renderEncoder.setRenderPipelineState(pipelineState!) // Set the pipeline state
        
        let screenSize = screenSizeBuffer.contents().assumingMemoryBound(to: Float.self)
        screenSize[0] = Float(NSApplication.shared.windows.first?.frame.width ?? 0)
        screenSize[1] = Float(NSApplication.shared.windows.first?.frame.height ?? 0)
        
        renderEncoder.setFragmentBuffer(screenSizeBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(gameBuffer, offset: 0, index: 1)
        
        //relies on constant in metal shader
        //draws a fullscreen quad
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * 2)
        
        renderEncoder.endEncoding() // End encoding
        
        commandBuffer.present(drawable) // Present the drawable
        commandBuffer.commit() // Commit the command buffer
        commandBuffer.waitUntilCompleted()
        lockGameBuffer.unlock()
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
