//
//  GameShader.metal
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/16/24.
//



#include <metal_stdlib>
using namespace metal;


typedef enum {
    air,
    sand,
    vapor,
    fire,
    water
} cellType;


typedef struct {
    cellType type;
} cell;


kernel void update_world(){
    
}


kernel void game_logic_step2(){
    
}


kernel void game_logic_step3(){
    
}


//done
vertex float4 vertex_main(device float3 *vertices [[ buffer(0) ]], uint vertexID [[ vertex_id ]]) {
    return float4(vertices[vertexID], 1);
}


fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]],float4 fragCoord [[position]]) {
    float x = fragCoord.x;
    float y = fragCoord.y;
    //TODO: get from game board
    //TODO: shift by world position (camera position)
    //TODO: get real ass screen size
    return half4(x / screenSize[0], y / screenSize[1], 0.0, 1.0);
}
