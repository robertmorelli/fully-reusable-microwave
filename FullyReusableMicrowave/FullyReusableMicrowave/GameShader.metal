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
    gameBoard[index].id = (id.x ^ id.y) % 2 ? dead : alive;
}

vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}

fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]], device cell *gameBoard [[ buffer(1) ]], device float *locationBuffer [[ buffer(2) ]],device float *zoomBuffer [[ buffer(3) ]], float4 fragCoord [[position]]) {
    
    // Grab all x and y coordinates
    float x = fragCoord.x / 2;
    float y = fragCoord.y / 2;
    
    // Calculate the cell coordinates
    int cellX = (x + locationBuffer[0]) / zoomBuffer[0];
    int cellY = (y + locationBuffer[1])  / zoomBuffer[0];
    
    // Ensure the coordinates are within bounds, ig clamp doesnt exist in metal
    if (cellX >= gameWidth || cellY >= gameHeight || cellX <= 0 || cellY <= 0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Get the index and retrieve the cell from the game board
    uint index = indexOf(cellX, cellY);
    
    // Determine the color based on the cell state
    float cellColor = (gameBoard[index].id == alive) ? 1.0 : 0.0;
    
    // TODO: DISPLAY PLAYER ON BOARD WITH location buffer and zoom buffer

    // Define player's position
    float playerX = gameBoard[gameHeight].id + locationBuffer[0];
    float playerY = gameBoard[gameWidth].id + locationBuffer[1];
    
    // Check if the current fragment is at the player's position
    if (cellX == int(playerX) && cellY == int(playerY)) {
        return half4(0.0, 1.0, 0.0, 1.0); // Green color for player
    }
    
    return half4(cellColor, cellColor, cellColor, 1.0);
}
