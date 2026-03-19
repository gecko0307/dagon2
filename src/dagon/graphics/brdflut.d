module dagon.graphics.brdflut;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.utils;

import dagon.core.logger;
import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.crashhandler;
import dagon.core.event;
import dagon.graphics.mesh;
import dagon.graphics.texture;
import dagon.graphics.state;
import dagon.resource.shader;
import dagon.render.renderer;
import dagon.render.pass;

struct BRDFLUTShaderVertexUniformBuffer
{
}

struct BRDFLUTShaderFragmentUniformBuffer
{
    Vector4f resolution;
    Vector4f fparams;
    uint[4] iparams;
}

class BRDFLUTShader: Shader
{
   protected:
    BRDFLUTShaderVertexUniformBuffer vsUBO;
    BRDFLUTShaderFragmentUniformBuffer fsUBO;
    
   public:
    Texture cubemap;
    CubeFace cubeFace;
    Vector2f resolution = Vector2f(0.0f, 0.0f);
    float roughness = 0.5f;
    float inputMipLevel = 0.0f;
    float inputThreshold = 10.0f;
    float inputScale = 2.0f;
    
    /**
     * Constructs a cube map generation shader.
     *
     * Params:
     *   owner  = Owner object.
     */
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("BRDFLUT.vert.glsl", "data/__internal/shaders/BRDFLUT/BRDFLUT.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("BRDFLUT.frag.glsl", "data/__internal/shaders/BRDFLUT/BRDFLUT.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create BRDFLUTShader");
        }
        
        fsUBO.resolution = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);
        fsUBO.fparams = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    /**
     * Binds shader parameters and input textures for rendering.
     *
     * Params:
     *   state = Pointer to the current graphics state.
     */
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        
        pass.bindTexture(PipelineStage.Fragment, 0, cubemap);
        
        fsUBO.resolution.x = resolution.x;
        fsUBO.resolution.y = resolution.y;
        fsUBO.fparams = Vector4f(
            inputMipLevel, roughness, inputThreshold, inputScale
        );
        fsUBO.iparams[0] = cubeFace;
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}
