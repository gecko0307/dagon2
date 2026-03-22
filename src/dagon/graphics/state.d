module dagon.graphics.state;

import dagon.core.sdl3;
import dagon.core.time;
import dagon.render.pass;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.texture;
import dagon.graphics.scene;

struct InputBuffer
{
    SDL_GPUTexture* texture;
    SDL_GPUSampler* sampler;
}

struct GraphicsState
{
    Time time;
    InputBuffer depthBuffer;
    InputBuffer colorBuffer;
    InputBuffer normalBuffer;
    InputBuffer roughnessMetallicBuffer;
    InputBuffer emissionBuffer;
    InputBuffer velocityBuffer;
    InputBuffer occlusionBuffer;
    InputBuffer radianceBuffer;
    RenderPass pass;
    Scene scene;
    Entity entity;
    Material material;
    Texture brdfLUT;
    bool brdfLUTEnabled = false;
    
    // TODO: other data
    
    void reset()
    {
        depthBuffer = InputBuffer.init;
        colorBuffer = InputBuffer.init;
        normalBuffer = InputBuffer.init;
        roughnessMetallicBuffer = InputBuffer.init;
        emissionBuffer = InputBuffer.init;
        velocityBuffer = InputBuffer.init;
        occlusionBuffer = InputBuffer.init;
        radianceBuffer = InputBuffer.init;
    }
}
