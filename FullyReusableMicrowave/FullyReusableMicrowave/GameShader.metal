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


kernel void initialize_world(uint2 id [[thread_position_in_grid]], texture2d<float, access::read_write> levelTexture [[texture(0)]]){
    float4 self = levelTexture.read(uint2(id.x,id.y));
    if (self.a < 0.2) {
        levelTexture.write(float4(0,0,0,0), uint2(id.x,id.y));
    }
    
}

kernel void update_world(uint2 id [[thread_position_in_grid]], texture2d<float, access::read_write> levelTexture [[texture(0)]]){
    bool leftSide = id.x > 0;
    bool rightSide = id.x < levelTexture.get_width() - 1;
    bool topSide = id.y > 0;
    bool botSide = id.y < levelTexture.get_height() - 1;
    
    bool tl = topSide && leftSide && any(levelTexture.read(uint2(id.x - 1,id.y - 1)) > float4(0,0,0,0));
    bool ml = leftSide && any(levelTexture.read(uint2(id.x - 1,id.y)) > float4(0,0,0,0));
    bool bl = botSide && leftSide && any(levelTexture.read(uint2(id.x - 1,id.y + 1)) > float4(0,0,0,0));
    
    bool tm = topSide && any(levelTexture.read(uint2(id.x,id.y - 1)) > float4(0,0,0,0));
    bool mm = any(levelTexture.read(uint2(id.x,id.y)) > float4(0,0,0,0));
    bool bm = botSide && any(levelTexture.read(uint2(id.x,id.y + 1)) > float4(0,0,0,0));
    
    bool tr = topSide && rightSide && any(levelTexture.read(uint2(id.x + 1,id.y - 1)) > float4(0,0,0,0));
    bool mr = topSide && rightSide && any(levelTexture.read(uint2(id.x + 1,id.y)) > float4(0,0,0,0));
    bool br = topSide && rightSide && any(levelTexture.read(uint2(id.x + 1,id.y + 1)) > float4(0,0,0,0));
    
    bool neighbors[] = {tl,ml,bl,tm,bm,tr,mr,br};
    
    int neighborCount = 0;
    for(uint i = 0;i < 8; i++)
        if(neighbors[i])
            neighborCount ++;
    
    if(mm && (neighborCount < 2 || neighborCount > 3)) levelTexture.write(float4(0,0,0,0), uint2(id.x,id.y));
    else if(!mm && (neighborCount == 2)) levelTexture.write(float4(1,0,1,1), uint2(id.x,id.y));
}

vertex float4 vertex_main(uint vertexID [[ vertex_id ]]) {
    return float4(fullscreenQuad[vertexID], 1);
}

fragment half4 fragment_main(
    device float *screenSize [[ buffer(0) ]],
    device float *locationBuffer [[ buffer(2) ]],
    device float *zoomBuffer [[ buffer(3) ]],
    texture2d<float, access::read> levelTexture [[texture(0)]],
    float4 fragCoord [[position]]
) {
    
    
    float x = fragCoord.x / 2;
    float y = fragCoord.y / 2;
    
    int cellX = int((x + locationBuffer[0]) / zoomBuffer[0]);
    int cellY = int((y + locationBuffer[1]) / zoomBuffer[0]);
    
    if (cellX >= int(levelTexture.get_width()) || cellY >= int(levelTexture.get_height()) || cellX < 0 || cellY < 0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    int playerX = int(locationBuffer[0] * (levelTexture.get_width() - 2) + 1);
    int playerY = int(locationBuffer[1] * (levelTexture.get_height() - 2) + 1);
    
    bool isPlayer = (cellX == playerX && cellY == playerY);
    
    if (isPlayer) {
        return half4(0.0, 1.0, 0.0, 1.0);
    }
    
    float4 text = levelTexture.read(uint2(cellX, cellY));
    return half4(text);
}



