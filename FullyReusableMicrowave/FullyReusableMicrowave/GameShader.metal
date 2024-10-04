#include <metal_stdlib>

using namespace metal;


typedef enum: uint64_t {
    dead = 0,
    alive = 1,
    space = 3,
    bound = 4
} cellType;

typedef struct {
    cellType id;
} cell;

typedef struct {
    int width;
    int height;
} gameSize;


constant float3 fullscreenQuad[] = {
    float3( 1.0,  1.0, 0.0),
    float3( 1.0, -1.0, 0.0),
    float3( -1.0, 1.0, 0.0),
    
    float3( -1.0, -1.0, 0.0),
    float3( 1.0, -1.0, 0.0),
    float3( -1.0, 1.0, 0.0)
};


kernel void initialize_world(device cell* gameBufferFrom [[buffer(0)]],
                             device cell* gameBufferTo [[buffer(1)]],
                             device gameSize* size [[buffer(2)]],
                             uint id [[thread_position_in_grid]]){
    //write red to a random selection
    int hash = id;
    hash ^= (hash << 13);
    hash ^= (hash >> 17);
    hash ^= (hash << 5);
    if (hash %3) {
        gameBufferFrom[id].id = alive;
        gameBufferTo[id].id = dead;
    } else {
        gameBufferFrom[id].id = dead;
        gameBufferTo[id].id = alive;
    }
}

kernel void update_world(device cell* gameBufferFrom [[buffer(0)]],
                         device cell* gameBufferTo [[buffer(1)]],
                         device gameSize* size [[buffer(2)]],
                         uint id [[thread_position_in_grid]]){
    //do nothing for now
    cellType temp = gameBufferFrom[id].id;
    gameBufferFrom[id].id = gameBufferTo[id].id;
    gameBufferTo[id].id = temp;
    }

vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}

fragment half4 fragment_main(device float *screenSize [[ buffer(0) ]],
                             device float *locationBuffer [[ buffer(2) ]],
                             device float *zoomBuffer [[ buffer(3) ]],
                             device cell* gameBufferTo [[buffer(4)]],
                             device gameSize* size [[buffer(5)]],
                             float4 fragCoord [[position]]) {
    float x = fragCoord.x / 2;
    float y = fragCoord.y / 2;
    
    int cellX = int((x + locationBuffer[0]) / zoomBuffer[0]);
    int cellY = int((y + locationBuffer[1]) / zoomBuffer[0]);
    
    if (cellX >= size[0].width || cellY >= size[0].height || cellX < 0 || cellY < 0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    int playerX = int(locationBuffer[0] * (size[0].width - 2) + 1);
    int playerY = int(locationBuffer[1] * (size[0].height - 2) + 1);
    
    bool isPlayer = (cellX == playerX && cellY == playerY);
    
    if (isPlayer) {
        return half4(0.0, 1.0, 0.0, 1.0);
    }
    
    cellType type = gameBufferTo[cellY * size[0].width + cellX].id;
    return type == alive ? half4(0.0, 1.0, 1.0, 1.0) : half4(0.0, 0.0, 0.0, 0.0);
}
