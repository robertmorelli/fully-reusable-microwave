//
//  ContentView.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI
import MetalKit

let gameWidth = 512;
let gameHeight = 512;

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
    var timer: DispatchSourceTimer!
    
    // Variables for framerate calculation
    var frameCount: Int = 0
    var lastUpdateTime: CFTimeInterval = 0
    var currentFramerate: Double = 0
    
    // Initializer which sets up the Metal device, command queue, and pipeline state
    init(metalKitView: MTKView) {
        // metalKitView.preferredFramesPerSecond = 120 // TODO: uncapped framerate
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        metalKitView.device = device
        commandQueue = device.makeCommandQueue()
        
        let library = device.makeDefaultLibrary()
        
        // Render pipeline for draw
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Kernel update for world physics
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
            fatalError("Error creating pipeline states")
        }
        
        gameBuffer = device.makeBuffer(
            length: MemoryLayout<cell>.stride * gameWidth * gameHeight,
            options: [ .storageModePrivate ])
        
        screenSizeBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.stride * 2,
            options: [ ])
        
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(500))
        timer.setEventHandler {
            self.updatePhysics()
        }
        timer.resume()
    }
    
    // Method to update the framerate
    func updateFramerate() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - lastUpdateTime
        
        if elapsedTime > 1 {
            currentFramerate = Double(frameCount) / elapsedTime
            frameCount = 0
            lastUpdateTime = currentTime
            print("Framerate: \(currentFramerate) fps")
            
            NotificationCenter.default.post(name: .didUpdateFramerate, object: nil, userInfo: ["framerate": currentFramerate])
        }
    }
    
    func updatePhysics() {
        lockGameBuffer.lock()
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        computeEncoder.setComputePipelineState(computePipelineState!)
        computeEncoder.setBuffer(gameBuffer, offset: 0, index: 0)
        
        let gridSize = MTLSize(width: gameWidth, height: gameHeight, depth: 1)
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
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState!)
        
        let screenSize = screenSizeBuffer.contents().assumingMemoryBound(to: Float.self)
        screenSize[0] = Float(NSApplication.shared.windows.first?.frame.width ?? 0)
        screenSize[1] = Float(NSApplication.shared.windows.first?.frame.height ?? 0)
        
        renderEncoder.setFragmentBuffer(screenSizeBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(gameBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * 2)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        lockGameBuffer.unlock()
        
        // Update the framerate after rendering
        updateFramerate()
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


// For now, Display framerate in console
extension Notification.Name {
    static let didUpdateFramerate = Notification.Name("didUpdateFramerate")
}

struct ContentView: View {
    @State private var framerate: Double = 0.0
    
    var body: some View {
        VStack {
            GameViewRepresentable()
            Text(String(format: "Framerate: %.2f fps", framerate))
                .padding()
                .onReceive(NotificationCenter.default.publisher(for: .didUpdateFramerate)) { notification in
                    if let userInfo = notification.userInfo,
                       let framerate = userInfo["framerate"] as? Double {
                        self.framerate = framerate
                    }
                }
        }
    }
}


// SwiftUI preview provider
#Preview {
    GameViewRepresentable() // Provide a preview of the GameView
}
