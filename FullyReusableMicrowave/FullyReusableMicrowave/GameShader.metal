#define indexOf(x,y, gameWidth) ((y) * gameWidth + (x))

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


kernel void initialize_world(device cell *gameBoard [[ buffer(0) ]], device float *gameBoardSizeBuffer [[ buffer(1) ]], uint2 id [[thread_position_in_grid]], texture2d<float, access::read> levelTexture [[texture(0)]], device uchar4 *levelDataBuffer [[ buffer(2) ]]){
    
    int gameWidth = gameBoardSizeBuffer[0];
    
    uint index = indexOf(id.x, id.y, gameWidth);

    float4 color = levelTexture.read(id);
    
    //levelDataBuffer[index] = char4(color);
    
    //levelDataBuffer[index] = uchar4(color.r, color.g, color.b * 255, 255);

    gameBoard[index].id = (id.x ^ id.y) % 5 ? dead : alive;
}

kernel void update_world(device cell *gameBoard [[ buffer(0) ]], device float *gameBoardSizeBuffer [[ buffer(1) ]], uint2 id [[thread_position_in_grid]]){
    int gameWidth = gameBoardSizeBuffer[0];
    int gameHeight = gameBoardSizeBuffer[1];
    
    uint index = indexOf(id.x, id.y, gameWidth);
    
    bool leftSide = id.x > 0;
    bool rightSide = id.x < gameWidth - 1;
    bool topSide = id.y > 0;
    bool botSide = id.y < gameHeight - 1;
    
    cellType tl = (leftSide && topSide) ? gameBoard[indexOf(id.x - 1, id.y - 1, gameWidth)].id : space;
    cellType ml = leftSide ? gameBoard[indexOf(id.x - 1, id.y, gameWidth)].id : space;
    cellType bl = (leftSide && botSide) ? gameBoard[indexOf(id.x - 1, id.y + 1, gameWidth)].id : space;
    cellType mt = topSide ? gameBoard[indexOf(id.x, id.y - 1, gameWidth)].id : space;
    cellType mb = topSide ? gameBoard[indexOf(id.x, id.y + 1, gameWidth)].id : space;
    cellType tr = (rightSide && topSide) ? gameBoard[indexOf(id.x + 1, id.y - 1, gameWidth)].id : space;
    cellType mr = rightSide ? gameBoard[indexOf(id.x + 1, id.y, gameWidth)].id : space;
    cellType br = (rightSide && botSide) ? gameBoard[indexOf(id.x + 1, id.y + 1, gameWidth)].id : space;
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

fragment half4 fragment_main(
    device float *screenSize [[ buffer(0) ]],
    device cell *gameBoard [[ buffer(1) ]],
    device float *locationBuffer [[ buffer(2) ]],
    device float *zoomBuffer [[ buffer(3) ]],
    device uchar4 *levelDataBuffer [[ buffer(4) ]],
    device float *gameBoardSizeBuffer [[ buffer(5) ]],
    float4 fragCoord [[position]]
) {
    
    int gameWidth = int(gameBoardSizeBuffer[0]);
    int gameHeight = int(gameBoardSizeBuffer[1]);
    
    float x = fragCoord.x / 2;
    float y = fragCoord.y / 2;
    
    int cellX = int((x + locationBuffer[0]) / zoomBuffer[0]);
    int cellY = int((y + locationBuffer[1]) / zoomBuffer[0]);
    
    if (cellX >= gameWidth || cellY >= gameHeight || cellX < 0 || cellY < 0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    int playerX = int(locationBuffer[0] * (gameWidth - 2) + 1);
    int playerY = int(locationBuffer[1] * (gameHeight - 2) + 1);
    
    bool isPlayer = (cellX == playerX && cellY == playerY);
    
    if (isPlayer) {
        return half4(0.0, 1.0, 0.0, 1.0);
    }
    
    int index = indexOf(cellX, cellY, gameWidth);
    return half4(levelDataBuffer[index]);
}



