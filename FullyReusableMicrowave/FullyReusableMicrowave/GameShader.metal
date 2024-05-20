#define gameWidth 64
#define gameHeight 64
#define indexOf(x,y) ((y) * gameWidth + (x))

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
    
    // make every other cell dead
    gameBoard[index].id = index % 3 == 0 ? dead : alive;
}

vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}

fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]], device cell *gameBoard [[ buffer(1) ]], float4 fragCoord [[position]]) {
    
    // Grab the screen size
    float height = screenSize[1];
    float width = screenSize[0];
    
    // Grab all x and y coordinates
    float x = fragCoord.x;
    float y = fragCoord.y;
    
    // Calculate the cell coordinates
    uint cellX = uint(x / width * gameWidth);
    uint cellY = uint(y / height * gameHeight);
    
    // THIS IS FUCKING UPPPPPPPP
    // Ensure the coordinates are within bounds, ig clamp doesnt exist in metal
    cellX = min(cellX, (uint)(gameWidth - 1));
    cellY = min(cellY, (uint)(gameHeight - 1));
    
    // Get the index and retrieve the cell from the game board
    uint index = indexOf(cellX, cellY);
    
    // Determine the color based on the cell state
    float cellColor = (gameBoard[index].id == alive) ? 1.0 : 0.0;
    
    //TODO: shift by world position (camera position)
    
    return half4(cellColor, cellColor, cellColor, 1.0);
}

                                

