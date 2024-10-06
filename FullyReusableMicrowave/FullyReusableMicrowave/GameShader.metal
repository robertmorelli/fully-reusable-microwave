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


inline uint sepBy2Only14Bits(uint n) {
    uint a = n & 1108;
    uint b = n & 4353;
    uint c = n & 10760;
    uint d = n & 162;
    return ((a * a) | (b * b) | (c * c) | (d * d)) & 0x55555555555555;
}

// Morton code function to interlace bits from x and y
inline int mortonCode(uint x, uint y) {
    // Interlace bits of x and y using sepBy2Only10Bits
    return (sepBy2Only14Bits(x) << 1) | sepBy2Only14Bits(y);
}

inline int index(uint2 id, gameSize size, int xOffset, int yOffset) {
    int x = max(0, min((int)id[0] + xOffset, size.width - 1));
    int y = max(0, min((int)id[1] + yOffset, size.height - 1));
    return mortonCode(x, y);
}


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
                             uint2 id [[thread_position_in_grid]]){
    //write red to a random selection
    int hash = (id[0] << 14) | id[1];
    hash ^= (hash << 13);
    hash ^= (hash >> 17);
    hash ^= (hash << 5);
    if (hash %3) {
        gameBufferFrom[mortonCode(id[0], id[1])].id = alive;
        gameBufferTo[mortonCode(id[0], id[1])].id = dead;
    } else {
        gameBufferFrom[mortonCode(id[0], id[1])].id = dead;
        gameBufferTo[mortonCode(id[0], id[1])].id = alive;
    }
}

kernel void update_world(device cell* gameBufferFrom [[buffer(0)]],
                         device cell* gameBufferTo [[buffer(1)]],
                         device gameSize* size [[buffer(2)]],
                         uint2 id [[thread_position_in_grid]]){
    
    // Get the current cell's state
    bool isAlive = gameBufferFrom[index(id, *size, 0, 0)].id == alive;

    // Calculate the number of alive neighbors
    uint neighborCount =
        (gameBufferFrom[index(id, *size, -1, -1)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, 0, -1)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, 1, -1)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, -1, 0)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, 1, 0)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, -1, 1)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, 0, 1)].id == alive ? 1 : 0) +
        (gameBufferFrom[index(id, *size, 1, 1)].id == alive ? 1 : 0);

    // Update the cell state based on the number of alive neighbors
    gameBufferTo[index(id, *size, 0, 0)].id =
        isAlive ?
            ((neighborCount == 2 || neighborCount == 3) ? alive : dead):
            ((neighborCount == 3) ? alive : dead);
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
    float x = fragCoord.x * 0.5;
    float y = fragCoord.y * 0.5;
    
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
    
    cellType type = gameBufferTo[mortonCode(cellX, cellY)].id;
    return type == alive ? half4(0.0, 1.0, 1.0, 1.0) : half4(0.0, 0.0, 0.0, 0.0);
}
