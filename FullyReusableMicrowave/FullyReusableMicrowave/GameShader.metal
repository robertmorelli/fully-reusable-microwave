// REPLACE REDUNDANT WIDTH AND HEIGHT VALUES VIA BUFFER
#define gameWidth 64
#define gameHeight 64
#define indexOf(x,y) ((y) * gameWidth + (x))

#include <metal_stdlib>
using namespace metal;


typedef enum: uint64_t {
    dead = 0,
    alive = 1,
    space = 3
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


kernel void initialize_world(device cell *gameBoard [[ buffer(0) ]], uint2 id [[thread_position_in_grid]]){
    uint index = indexOf(id.x, id.y);
    gameBoard[index].id = (id.x ^ id.y) % 5 ? dead : alive;
}

kernel void update_world(device cell *gameBoard [[ buffer(0) ]], uint2 id [[thread_position_in_grid]]){
    uint index = indexOf(id.x, id.y);
    
    bool leftSide = id.x > 0;
    bool rightSide = id.x < gameWidth - 1;
    bool topSide = id.y > 0;
    bool botSide = id.y < gameHeight - 1;
    
    cellType tl = (leftSide && topSide) ? gameBoard[indexOf(id.x - 1, id.y - 1)].id : space;
    cellType ml = leftSide ? gameBoard[indexOf(id.x - 1, id.y)].id : space;
    cellType bl = (leftSide && botSide) ? gameBoard[indexOf(id.x - 1, id.y + 1)].id : space;
    cellType mt = topSide ? gameBoard[indexOf(id.x, id.y - 1)].id : space;
    cellType mb = topSide ? gameBoard[indexOf(id.x, id.y + 1)].id : space;
    cellType tr = (rightSide && topSide) ? gameBoard[indexOf(id.x + 1, id.y - 1)].id : space;
    cellType mr = rightSide ? gameBoard[indexOf(id.x + 1, id.y)].id : space;
    cellType br = (rightSide && botSide) ? gameBoard[indexOf(id.x + 1, id.y + 1)].id : space;
    cellType neighbors[] = {tl,ml,bl,mt,mb,tr,mr,br};
    
    int neighborCount = 0;
    for(uint i = 0;i < 8; i++) neighborCount += neighbors[i] == alive ? 1 : 0;
    
    bool isAlive = gameBoard[index].id == alive;
    
    gameBoard[index].id =
        (isAlive && neighborCount < 2) ? dead :
        (isAlive && neighborCount >= 2 && neighborCount <= 3) ? alive :
        (isAlive && neighborCount > 3) ? dead :
        (!isAlive && neighborCount == 3) ? alive : gameBoard[index].id;
}

vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}

fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]], device cell *gameBoard [[ buffer(1) ]], device float *locationBuffer [[ buffer(2) ]],device float *zoomBuffer [[ buffer(3) ]],device float *levelDataBuffer [[ buffer(4) ]], float4 fragCoord [[position]]) {
    
    // Grab all x and y coordinates
    float x = fragCoord.x / 2;
    float y = fragCoord.y / 2;
    
    // TODO: iterate through leveldatabuffer to get colors to pass in to fragment shader
    
    // Calculate the cell coordinates
    int cellX = (x + locationBuffer[0]) / zoomBuffer[0];
    int cellY = (y + locationBuffer[1]) / zoomBuffer[0];
    
    // Ensure the coordinates are within bounds, ig clamp doesnt exist in metal
    if (cellX >= gameWidth || cellY >= gameHeight || cellX <= 0 || cellY <= 0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Get the index and retrieve the cell from the game board
    uint index = indexOf(cellX, cellY);
    
    // Determine the color based on the cell state
    float cellColor = (gameBoard[index].id == alive) ? 1.0 : 0.0;
    
    // TODO: DISPLAY PLAYER ON BOARD WITH location buffer and zoom buffer

    // Define player's position (start at the middle of the board)
    int playerX = locationBuffer[0] * (gameWidth - 2) + 1;
    int playerY = locationBuffer[1] * (gameHeight - 2) + 1;
    
    bool isPlayer = cellX == playerX && cellY == playerY;
    // Check if the current fragment is at the player's position
    return isPlayer?
        half4(0.0, 1.0, 0.0, 1.0):
        half4(cellColor, cellColor, cellColor, 1.0);
        //half4(levelDataBuffer[0], levelDataBuffer[1], levelDataBuffer[2], 1.0);
}

