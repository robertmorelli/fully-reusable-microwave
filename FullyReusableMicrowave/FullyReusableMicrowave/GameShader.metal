//
//  GameShader.metal
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/16/24.
//


#include <metal_stdlib>
using namespace metal;


typedef enum {
    air = 0,
    sand,
    vapor,
    fire,
    water
} cellType;


typedef struct {
    int id;
} cell;


kernel void update_world(device cell *gameBoard [[ buffer(0) ]], uint2 id [[thread_position_in_grid]]){
    uint index = id.y * 64 + id.x;
    gameBoard[index].id = id.x;
}


//done
vertex float4 vertex_main(device float3 *vertices [[ buffer(0) ]], uint vertexID [[ vertex_id ]]) {
    return float4(vertices[vertexID], 1);
}


fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]], device cell *gameBoard [[ buffer(1) ]], float4 fragCoord [[position]]) {
    
    float height = screenSize[1];
    float y = fragCoord.y;
    float ynorm = y / height;
    int ygrid = floor(ynorm * 64);
    
    
    float width = screenSize[0];
    float x = fragCoord.x;
    float xnorm = x / width;
    int xgrid = floor(xnorm * 64);
    
    
    int gridIndex = ygrid * 64 + xgrid;
    
    cell myCell = gameBoard[gridIndex];
    
    
                                 
    //TODO: get from game board
    //TODO: shift by world position (camera position)
    //TODO: get real ass screen size
    return half4(myCell.id  / 64.0, myCell.id  / 64.0, myCell.id  / 64.0, 1.0);
}
