//
//  GameShader.metal
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/16/24.
//

#define gameWidth 64
#define gameHeight 64
#define indexOf(x,y) (y) * gameWidth + (x)

#include <metal_stdlib>
using namespace metal;


typedef enum: uint64_t {
    dead = 0,
    alive = 1
} cellType;


typedef struct {
    cellType id;
} cell;


constant float3 fullscreenQuad[] = {
    float3( 1.0,  1.0, 0.0),
    float3( 1.0, -1.0, 0.0),
    float3( -1.0, 1.0, 0.0),
    
    float3( -1.0, -1.0, 0.0),
    float3( 1.0, -1.0, 0.0),
    float3( -1.0, 1.0, 0.0)
};


kernel void update_world(device cell *gameBoard [[ buffer(0) ]], uint2 id [[thread_position_in_grid]]){
    uint index = indexOf(id.x, id.y);
    if(gameBoard[index].id == alive){
        gameBoard[index].id = dead;
    }
    else{
        gameBoard[index].id = alive;
    }
}


vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}


fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]], device cell *gameBoard [[ buffer(1) ]], float4 fragCoord [[position]]) {
    
    float height = screenSize[1];
    float y = fragCoord.y;
    
    float width = screenSize[0];
    float x = fragCoord.x;
    
    //TODO: get actual cell
    cell myCell = gameBoard[0];
    
    
                                 
    //TODO: get from game board
    //TODO: shift by world position (camera position)
    //TODO: get real ass screen size
    return half4(x / width, y / height, myCell.id, 1.0);
}
