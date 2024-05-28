//
//  ContentView.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI
import MetalKit
import AppKit
import ImageIO
import Metal
// import MetalPerformanceShaders maybe?? :)


// keys
let leftArrowKey: UInt16 = 123
let rightArrowKey: UInt16 = 124
let downArrowKey: UInt16 = 125
let upArrowKey: UInt16 = 126
let escapeKey: UInt16 = 53

// Cell definition to pass struct to buffer
struct cell {
    var id: UInt64
}

// Set data structure to hold key presses
var pressedKeys = Set<KeyEquivalent>()

// Basic Renderer class implementation
class Renderer {
    
    // Variables to hold Metal objects
    var commandQueue: MTLCommandQueue?
    var renderPipelineState: MTLRenderPipelineState?
    var updateWorldPipelineState: MTLComputePipelineState?
    var initializeWorldPipelineState: MTLComputePipelineState?
    var lockGameBuffer = NSLock()
    var screenSizeBuffer: MTLBuffer!
    var zoomBuffer: MTLBuffer!
    var locationBuffer: MTLBuffer!
    var levelDataBuffer: MTLBuffer!
    var slowPhysicsTimer: DispatchSourceTimer!
    var fastPhysicsTimer: DispatchSourceTimer!
    
    var levelTexture: MTLTexture!
    
    // Variables for framerate calculation
    var frameCount: Int = 0
    var lastUpdateTime: CFTimeInterval = 0
    var currentFramerate: Double = 0
    
    
    // Initializer which sets up the Metal device, command queue, and pipeline state
    init(metalKitView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        metalKitView.device = device
        commandQueue = device.makeCommandQueue()
        
        let library = device.makeDefaultLibrary()
        
        // Render pipeline for draw
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Kernel update for world physics
        let updateKernelFunction = library?.makeFunction(name: "update_world")
        let updatePipelineDescriptor = MTLComputePipelineDescriptor()
        updatePipelineDescriptor.computeFunction = updateKernelFunction
        
        
        // Kernel update for world physics
        let initializeKernelFunction = library?.makeFunction(name: "initialize_world")
        let initializePipelineDescriptor = MTLComputePipelineDescriptor()
        initializePipelineDescriptor.computeFunction = initializeKernelFunction
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            updateWorldPipelineState = try device.makeComputePipelineState(
                descriptor: updatePipelineDescriptor,
                options: [.argumentInfo, .bufferTypeInfo],
                reflection: nil)
            initializeWorldPipelineState = try device.makeComputePipelineState(
                descriptor: initializePipelineDescriptor,
                options: [.argumentInfo, .bufferTypeInfo],
                reflection: nil)
        } catch {
            fatalError("Error creating pipeline states")
        }
        
        
        zoomBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.stride * 1,
            options: [ ])
        
        locationBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.stride * 2,
            options: [ ])
        
        let playerPos = locationBuffer.contents().assumingMemoryBound(to: Float.self)
        playerPos[0] = 0.5;
        playerPos[1] = 0.5;
        
        initializeWorld(device: device)
        
        slowPhysicsTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        slowPhysicsTimer.schedule(deadline: .now(), repeating: .milliseconds(100))
        slowPhysicsTimer.setEventHandler {
            self.updatePhysics()
        }
        slowPhysicsTimer.resume()
        
        fastPhysicsTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        fastPhysicsTimer.schedule(deadline: .now(), repeating: .milliseconds(5))
        fastPhysicsTimer.setEventHandler {
            self.updateSmoothPhysics()
        }
        fastPhysicsTimer.resume()
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
            
            NotificationCenter.default.post(name: .didUpdateFramerate, object: nil, userInfo: ["framerate": currentFramerate])
        }
    }
    
    func updateSmoothPhysics() {
        for keyCode in pressedKeys {
            switch keyCode{
            case KeyEquivalent.leftArrow:
                modPlayerPosX(x: -0.001)
            case KeyEquivalent.rightArrow:
                modPlayerPosX(x: 0.001)
            case KeyEquivalent.upArrow:
                modPlayerPosY(y: -0.001)
            case KeyEquivalent.downArrow:
                modPlayerPosY(y: 0.001)
            default:
                continue
            }
        }
    }

    func initializeWorld(device: MTLDevice) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        computeEncoder.setComputePipelineState(initializeWorldPipelineState!)
        
        let options: [MTKTextureLoader.Option : NSNumber] = [
            MTKTextureLoader.Option.textureUsage:
                NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue)
        ]
        
        levelTexture = try? MTKTextureLoader(device: device)
            .newTexture(
                data: Data(
                    contentsOf: URL(
                        fileURLWithPath:
                            Bundle.main.path(forResource: "level1", ofType: "png")!
                    )
                ),
                options: options
            )
        
        computeEncoder.setTexture(levelTexture, index: 0)
        
        let gridSize = MTLSize(width: levelTexture.width, height: levelTexture.height, depth: 1)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    
    func updatePhysics() {
        lockGameBuffer.lock()
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        computeEncoder.setComputePipelineState(updateWorldPipelineState!)
        computeEncoder.setTexture(levelTexture, index: 0)
        
        let gridSize = MTLSize(width: levelTexture.width, height: levelTexture.height, depth: 1)
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
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState!)
        
        setZoomBuffer()
        
        renderEncoder.setFragmentBuffer(screenSizeBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(locationBuffer, offset: 0, index: 2)
        renderEncoder.setFragmentBuffer(zoomBuffer, offset: 0, index: 3)
        renderEncoder.setFragmentBuffer(levelDataBuffer, offset: 0, index: 4)
        renderEncoder.setFragmentTexture(levelTexture, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * 2)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        lockGameBuffer.unlock()
        
        // Update the framerate after rendering
        updateFramerate()
    }
    
    func modPlayerPosX(x: Float){
        let playerPos = locationBuffer.contents().assumingMemoryBound(to: Float.self)
        playerPos[0] = max(0,min(1, playerPos[0] + x));
        
    }
    
    func modPlayerPosY(y: Float){
        let playerPos = locationBuffer.contents().assumingMemoryBound(to: Float.self)
        playerPos[1] = max(0,min(1, playerPos[1] + y));
    }
    
    
    func setZoomBuffer(){
        let zoom = zoomBuffer.contents().assumingMemoryBound(to: Float.self)
        zoom[0] = 4.0;
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
            Text(String(format: "Version 0.0.2 - %.2f FPS", framerate))
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
