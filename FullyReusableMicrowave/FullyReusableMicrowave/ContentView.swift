//
//  ContentView.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI
import MetalKit

struct MTKMapView: NSViewRepresentable {
    typealias NSViewType = MTKView;
    var internalSelf: MTKView;
    
    init(){
        self.internalSelf = MTKView();
    }
    
    func makeNSView(context: Context) -> MTKView {
        return internalSelf;
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Window!")
                .padding()
            MTKMapView() // Placeholder for the Metal view
                .frame(height: 300) // Set a height for the Metal view
        }
    }
}

#Preview {
    ContentView()
}
