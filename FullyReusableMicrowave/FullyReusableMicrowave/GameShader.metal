//
//  GameShader.metal
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/16/24.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 vertex_main(uint vertexID [[vertex_id]]) {
    // Triangle Vertices
    float4 vertices[3] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4( 0.0,  1.0, 0.0, 1.0)
    };
    return vertices[vertexID];
}

fragment half4 fragment_main() {
    // Imaginary Techinque, Purple
    return half4(0.8, 0.6, 0.8, 1.0);
}

