module dagon.graphics.envmap;

import std.traits;

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

/**
 * Returns the transformation matrix for a cubemap face.
 *
 * Params:
 *   cf = The cubemap face.
 * Returns:
 *   The transformation matrix.
 */
Matrix4x4f cubeFaceMatrix(CubeFace cf)
{
    switch(cf)
    {
        case CubeFace.PositiveX:
            return rotationMatrix(1, degtorad(-90.0f));
        case CubeFace.NegativeX:
            return rotationMatrix(1, degtorad(90.0f));
        case CubeFace.PositiveY:
            return rotationMatrix(0, degtorad(90.0f));
        case CubeFace.NegativeY:
            return rotationMatrix(0, degtorad(-90.0f));
        case CubeFace.PositiveZ:
            return rotationMatrix(1, degtorad(0.0f));
        case CubeFace.NegativeZ:
            return rotationMatrix(1, degtorad(180.0f));
        default:
            return Matrix4x4f.identity;
    }
}

struct CubemapGeneratorShaderVertexUniformBuffer
{
}

struct CubemapGeneratorShaderFragmentUniformBuffer
{
    Matrix4x4f pixelToWorldMatrix;
}

/**
 * Shader for converting equirectangular environment maps to cube maps.
 */
class CubemapGeneratorShader: Shader
{
   protected:
    CubemapGeneratorShaderVertexUniformBuffer vsUBO;
    CubemapGeneratorShaderFragmentUniformBuffer fsUBO;
    
   public:
    Texture envmap;
    CubeFace cubeFace;
    
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
        vertexModule.create("CubemapGenerator.vert.glsl", "data/__internal/shaders/CubemapGenerator/CubemapGenerator.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("CubemapGenerator.frag.glsl", "data/__internal/shaders/CubemapGenerator/CubemapGenerator.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create CubemapGeneratorShader");
        }
        
        fsUBO.pixelToWorldMatrix = Matrix4x4f.identity;
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
        
        pass.bindTexture(PipelineStage.Fragment, 0, envmap);
        
        fsUBO.pixelToWorldMatrix = cubeFaceMatrix(cubeFace);
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class CubemapGeneratorPass: RenderPass
{
    CubemapGeneratorShader cubemapGeneratorShader;
    Texture inputEnvmap;
    Texture outputCubemap;
    CubeFace outputCubemapFace;
    SDL_GPUColorTargetDescription colorTargetDescription;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, SDL_GPUTextureFormat outputFormat)
    {
        super(renderer);
        
        cubemapGeneratorShader = New!CubemapGeneratorShader(renderer.gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = cubemapGeneratorShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = cubemapGeneratorShader.fragmentModule.shader;
        pipelineCreateInfo.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
        
        SDL_GPUVertexBufferDescription[2] vbDescriptions;
        
        vbDescriptions[0].slot = VertexAttribute.Position;
        vbDescriptions[0].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[0].instance_step_rate = 0;
        vbDescriptions[0].pitch = Vector2f.sizeof;
        
        vbDescriptions[1].slot = VertexAttribute.Texcoord;
        vbDescriptions[1].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[1].instance_step_rate = 0;
        vbDescriptions[1].pitch = Vector2f.sizeof;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_buffers = vbDescriptions.length;
        pipelineCreateInfo.vertex_input_state.vertex_buffer_descriptions = vbDescriptions.ptr;
        
        SDL_GPUVertexAttribute[2] vertexAttributes;
        
        // Position
        vertexAttributes[0].buffer_slot = VertexAttribute.Position;
        vertexAttributes[0].location = VertexAttribute.Position;
        vertexAttributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[0].offset = 0;
        
        // Texcoords
        vertexAttributes[1].buffer_slot = VertexAttribute.Texcoord;
        vertexAttributes[1].location = VertexAttribute.Texcoord;
        vertexAttributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[1].offset = 0;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_attributes = vertexAttributes.length;
        pipelineCreateInfo.vertex_input_state.vertex_attributes = vertexAttributes.ptr;
        
        SDL_GPUColorTargetBlendState blendState = {
            src_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            color_blend_op: SDL_GPU_BLENDOP_ADD,
            src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            alpha_blend_op: SDL_GPU_BLENDOP_ADD,
            color_write_mask: 0,
            enable_blend: false,
            enable_color_write_mask: false
        };
        colorTargetDescription.format = outputFormat;
        colorTargetDescription.blend_state = blendState;
        
        pipelineCreateInfo.target_info.num_color_targets = 1;
        pipelineCreateInfo.target_info.color_target_descriptions = &colorTargetDescription;
        pipelineCreateInfo.target_info.has_depth_stencil_target = false;
        
        pipelineCreateInfo.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pipelineCreateInfo.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
        pipelineCreateInfo.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
        pipelineCreateInfo.rasterizer_state.depth_bias_constant_factor = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_clamp = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_slope_factor = 1.0f;
        pipelineCreateInfo.rasterizer_state.enable_depth_bias = false;
        pipelineCreateInfo.rasterizer_state.enable_depth_clip = false;
        
        pipelineCreateInfo.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS;
        pipelineCreateInfo.depth_stencil_state.enable_depth_test = false;
        pipelineCreateInfo.depth_stencil_state.enable_depth_write = false;
        pipelineCreateInfo.depth_stencil_state.enable_stencil_test = false;
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(renderer.gpu.device, &pipelineCreateInfo);
        
        colorTargetInfo.clear_color = SDL_FColor(1.0f, 0.0f, 0.0f, 1.0f);
        colorTargetInfo.load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    override void render(GraphicsState* state)
    {
        colorTargetInfo.texture = outputCubemap.texture;
        colorTargetInfo.mip_level = 0;
        colorTargetInfo.layer_or_depth_plane = outputCubemapFace;
        
        beginPass();
        
        cubemapGeneratorShader.envmap = inputEnvmap;
        cubemapGeneratorShader.cubeFace = outputCubemapFace;
        cubemapGeneratorShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
    }
}

struct CubemapPrefilterShaderVertexUniformBuffer
{
}

struct CubemapPrefilterShaderFragmentUniformBuffer
{
    Vector4f resolution;
    Vector4f fparams;
    uint[4] iparams;
}

class CubemapPrefilterShader: Shader
{
   protected:
    CubemapPrefilterShaderVertexUniformBuffer vsUBO;
    CubemapPrefilterShaderFragmentUniformBuffer fsUBO;
    
   public:
    Texture cubemap;
    CubeFace cubeFace;
    Vector2f resolution = Vector2f(0.0f, 0.0f);
    float roughness = 0.5f;
    float inputMipLevel = 0.0f;
    float inputThreshold = 100.0f;
    float inputScale = 1.0f;
    
    /**
     * Constructs a cube map radiance prefiltering shader.
     *
     * Params:
     *   owner  = Owner object.
     */
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("CubemapPrefilter.vert.glsl", "data/__internal/shaders/CubemapPrefilter/CubemapPrefilter.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("CubemapPrefilter.frag.glsl", "data/__internal/shaders/CubemapPrefilter/CubemapPrefilter.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create CubemapPrefilterShader");
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

class CubemapPrefilterPass: RenderPass
{
    CubemapPrefilterShader cubemapPrefilterShader;
    Texture inputCubemap;
    Texture outputCubemap;
    CubeFace outputCubemapFace;
    uint outputCubemapMipLevel;
    SDL_GPUColorTargetDescription colorTargetDescription;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, SDL_GPUTextureFormat outputFormat)
    {
        super(renderer);
        
        cubemapPrefilterShader = New!CubemapPrefilterShader(renderer.gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = cubemapPrefilterShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = cubemapPrefilterShader.fragmentModule.shader;
        pipelineCreateInfo.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
        
        SDL_GPUVertexBufferDescription[2] vbDescriptions;
        
        vbDescriptions[0].slot = VertexAttribute.Position;
        vbDescriptions[0].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[0].instance_step_rate = 0;
        vbDescriptions[0].pitch = Vector2f.sizeof;
        
        vbDescriptions[1].slot = VertexAttribute.Texcoord;
        vbDescriptions[1].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[1].instance_step_rate = 0;
        vbDescriptions[1].pitch = Vector2f.sizeof;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_buffers = vbDescriptions.length;
        pipelineCreateInfo.vertex_input_state.vertex_buffer_descriptions = vbDescriptions.ptr;
        
        SDL_GPUVertexAttribute[2] vertexAttributes;
        
        // Position
        vertexAttributes[0].buffer_slot = VertexAttribute.Position;
        vertexAttributes[0].location = VertexAttribute.Position;
        vertexAttributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[0].offset = 0;
        
        // Texcoords
        vertexAttributes[1].buffer_slot = VertexAttribute.Texcoord;
        vertexAttributes[1].location = VertexAttribute.Texcoord;
        vertexAttributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[1].offset = 0;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_attributes = vertexAttributes.length;
        pipelineCreateInfo.vertex_input_state.vertex_attributes = vertexAttributes.ptr;
        
        SDL_GPUColorTargetBlendState blendState = {
            src_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            color_blend_op: SDL_GPU_BLENDOP_ADD,
            src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            alpha_blend_op: SDL_GPU_BLENDOP_ADD,
            color_write_mask: 0,
            enable_blend: false,
            enable_color_write_mask: false
        };
        colorTargetDescription.format = outputFormat;
        colorTargetDescription.blend_state = blendState;
        
        pipelineCreateInfo.target_info.num_color_targets = 1;
        pipelineCreateInfo.target_info.color_target_descriptions = &colorTargetDescription;
        pipelineCreateInfo.target_info.has_depth_stencil_target = false;
        
        pipelineCreateInfo.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pipelineCreateInfo.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
        pipelineCreateInfo.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
        pipelineCreateInfo.rasterizer_state.depth_bias_constant_factor = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_clamp = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_slope_factor = 1.0f;
        pipelineCreateInfo.rasterizer_state.enable_depth_bias = false;
        pipelineCreateInfo.rasterizer_state.enable_depth_clip = false;
        
        pipelineCreateInfo.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS;
        pipelineCreateInfo.depth_stencil_state.enable_depth_test = false;
        pipelineCreateInfo.depth_stencil_state.enable_depth_write = false;
        pipelineCreateInfo.depth_stencil_state.enable_stencil_test = false;
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(renderer.gpu.device, &pipelineCreateInfo);
        
        colorTargetInfo.clear_color = SDL_FColor(1.0f, 0.0f, 0.0f, 1.0f);
        colorTargetInfo.load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    override void render(GraphicsState* state)
    {
        colorTargetInfo.texture = outputCubemap.texture;
        colorTargetInfo.mip_level = outputCubemapMipLevel;
        colorTargetInfo.layer_or_depth_plane = outputCubemapFace;
        
        beginPass();
        
        cubemapPrefilterShader.cubemap = inputCubemap;
        cubemapPrefilterShader.cubeFace = outputCubemapFace;
        cubemapPrefilterShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
    }
}

struct CubemapIrradiancePrefilterShaderVertexUniformBuffer
{
}

struct CubemapIrradiancePrefilterShaderFragmentUniformBuffer
{
    Vector4f resolution;
    uint[4] iparams;
}

class CubemapIrradiancePrefilterShader: Shader
{
   protected:
    CubemapIrradiancePrefilterShaderVertexUniformBuffer vsUBO;
    CubemapIrradiancePrefilterShaderFragmentUniformBuffer fsUBO;
    
   public:
    Texture cubemap;
    CubeFace cubeFace;
    Vector2f resolution = Vector2f(0.0f, 0.0f);
    
    /**
     * Constructs a cube map irradiance prefiltering shader.
     *
     * Params:
     *   owner  = Owner object.
     */
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("CubemapPrefilter.vert.glsl", "data/__internal/shaders/CubemapPrefilter/CubemapPrefilter.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("CubemapPrefilterIrradiance.frag.glsl", "data/__internal/shaders/CubemapPrefilter/CubemapPrefilterIrradiance.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create CubemapIrradiancePrefilterShader");
        }
        
        fsUBO.resolution = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);
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
        fsUBO.iparams[0] = cubeFace;
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class CubemapIrradiancePrefilterPass: RenderPass
{
    CubemapIrradiancePrefilterShader cubemapIrradiancePrefilterShader;
    Texture inputCubemap;
    Texture outputCubemap;
    CubeFace outputCubemapFace;
    SDL_GPUColorTargetDescription colorTargetDescription;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, SDL_GPUTextureFormat outputFormat)
    {
        super(renderer);
        
        cubemapIrradiancePrefilterShader = New!CubemapIrradiancePrefilterShader(renderer.gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = cubemapIrradiancePrefilterShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = cubemapIrradiancePrefilterShader.fragmentModule.shader;
        pipelineCreateInfo.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
        
        SDL_GPUVertexBufferDescription[2] vbDescriptions;
        
        vbDescriptions[0].slot = VertexAttribute.Position;
        vbDescriptions[0].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[0].instance_step_rate = 0;
        vbDescriptions[0].pitch = Vector2f.sizeof;
        
        vbDescriptions[1].slot = VertexAttribute.Texcoord;
        vbDescriptions[1].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[1].instance_step_rate = 0;
        vbDescriptions[1].pitch = Vector2f.sizeof;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_buffers = vbDescriptions.length;
        pipelineCreateInfo.vertex_input_state.vertex_buffer_descriptions = vbDescriptions.ptr;
        
        SDL_GPUVertexAttribute[2] vertexAttributes;
        
        // Position
        vertexAttributes[0].buffer_slot = VertexAttribute.Position;
        vertexAttributes[0].location = VertexAttribute.Position;
        vertexAttributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[0].offset = 0;
        
        // Texcoords
        vertexAttributes[1].buffer_slot = VertexAttribute.Texcoord;
        vertexAttributes[1].location = VertexAttribute.Texcoord;
        vertexAttributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[1].offset = 0;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_attributes = vertexAttributes.length;
        pipelineCreateInfo.vertex_input_state.vertex_attributes = vertexAttributes.ptr;
        
        SDL_GPUColorTargetBlendState blendState = {
            src_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            color_blend_op: SDL_GPU_BLENDOP_ADD,
            src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
            alpha_blend_op: SDL_GPU_BLENDOP_ADD,
            color_write_mask: 0,
            enable_blend: false,
            enable_color_write_mask: false
        };
        colorTargetDescription.format = outputFormat;
        colorTargetDescription.blend_state = blendState;
        
        pipelineCreateInfo.target_info.num_color_targets = 1;
        pipelineCreateInfo.target_info.color_target_descriptions = &colorTargetDescription;
        pipelineCreateInfo.target_info.has_depth_stencil_target = false;
        
        pipelineCreateInfo.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pipelineCreateInfo.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
        pipelineCreateInfo.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
        pipelineCreateInfo.rasterizer_state.depth_bias_constant_factor = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_clamp = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_slope_factor = 1.0f;
        pipelineCreateInfo.rasterizer_state.enable_depth_bias = false;
        pipelineCreateInfo.rasterizer_state.enable_depth_clip = false;
        
        pipelineCreateInfo.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS;
        pipelineCreateInfo.depth_stencil_state.enable_depth_test = false;
        pipelineCreateInfo.depth_stencil_state.enable_depth_write = false;
        pipelineCreateInfo.depth_stencil_state.enable_stencil_test = false;
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(renderer.gpu.device, &pipelineCreateInfo);
        
        colorTargetInfo.clear_color = SDL_FColor(1.0f, 0.0f, 0.0f, 1.0f);
        colorTargetInfo.load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    override void render(GraphicsState* state)
    {
        colorTargetInfo.texture = outputCubemap.texture;
        colorTargetInfo.mip_level = 0;
        colorTargetInfo.layer_or_depth_plane = outputCubemapFace;
        
        beginPass();
        
        cubemapIrradiancePrefilterShader.cubemap = inputCubemap;
        cubemapIrradiancePrefilterShader.cubeFace = outputCubemapFace;
        cubemapIrradiancePrefilterShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
    }
}

class CubemapRenderer: Renderer
{
    CubemapGeneratorPass cubemapGeneratorPass;
    CubemapPrefilterPass cubemapPrefilterPass;
    CubemapIrradiancePrefilterPass cubemapIrradiancePrefilterPass;
    
    this(GPU gpu, EventManager eventManager, SDL_GPUTextureFormat format)
    {
        super(gpu, eventManager);
        cubemapGeneratorPass = New!CubemapGeneratorPass(this, format);
        cubemapPrefilterPass = New!CubemapPrefilterPass(this, format);
        cubemapIrradiancePrefilterPass = New!CubemapIrradiancePrefilterPass(this, format);
    }
    
    /**
     * Creates a cube map texture from an equirectangular environment map using the GPU.
     *
     * Params:
     *   inputEnvmap   = Input texture.
     *   outputCubemap = Output cube map to write the result to.
     */
    void generateCubemap(Texture inputEnvmap, Texture outputCubemap)
    {
        view.resize(outputCubemap.buffer.size.width, outputCubemap.buffer.size.height);
        
        state.reset();
        
        commandBuffer = SDL_AcquireGPUCommandBuffer(gpu.device);
        
        state.pass = cubemapGeneratorPass;
        cubemapGeneratorPass.inputEnvmap = inputEnvmap;
        cubemapGeneratorPass.outputCubemap = outputCubemap;
        foreach(faceIndex, face; EnumMembers!CubeFace)
        {
            cubemapGeneratorPass.outputCubemapFace = face;
            cubemapGeneratorPass.render(&state);
        }
        
        SDL_GenerateMipmapsForGPUTexture(commandBuffer, outputCubemap.texture);
        
        SDL_SubmitGPUCommandBuffer(commandBuffer);
    }
    
    void prefilterCubemap(Texture inputCubemap, Texture outputCubemap)
    {
        view.resize(outputCubemap.buffer.size.width, outputCubemap.buffer.size.height);
        
        state.reset();
        
        commandBuffer = SDL_AcquireGPUCommandBuffer(gpu.device);
        
        state.pass = cubemapPrefilterPass;
        auto shader = cubemapPrefilterPass.cubemapPrefilterShader;
        shader.inputMipLevel = 0;
        cubemapPrefilterPass.inputCubemap = inputCubemap;
        cubemapPrefilterPass.outputCubemap = outputCubemap;
        foreach(faceIndex, face; EnumMembers!CubeFace)
        {
            cubemapPrefilterPass.outputCubemapFace = face;
            
            for(int mipLevel = 0; mipLevel < outputCubemap.mipLevels; mipLevel++)
            {
                uint levelWidth = outputCubemap.buffer.size.width >> mipLevel;
                uint levelHeight = outputCubemap.buffer.size.height >> mipLevel;
                if (levelWidth < 1) levelWidth = 1;
                if (levelHeight < 1) levelHeight = 1;
                
                shader.resolution = Vector2f(levelWidth, levelHeight);
                float roughness = cast(float)mipLevel / (cast(float)outputCubemap.mipLevels - 1.0f);
                roughness = min2(1.0f, roughness * roughness);
                shader.roughness = roughness;
                
                cubemapPrefilterPass.outputCubemapMipLevel = mipLevel;
                
                cubemapPrefilterPass.render(&state);
            }
        }
        
        SDL_SubmitGPUCommandBuffer(commandBuffer);
    }
    
    void prefilterCubemapIrradiance(Texture inputCubemap, Texture outputCubemap)
    {
        view.resize(outputCubemap.buffer.size.width, outputCubemap.buffer.size.height);
        
        state.reset();
        
        commandBuffer = SDL_AcquireGPUCommandBuffer(gpu.device);
        
        state.pass = cubemapIrradiancePrefilterPass;
        auto shader = cubemapIrradiancePrefilterPass.cubemapIrradiancePrefilterShader;
        cubemapIrradiancePrefilterPass.inputCubemap = inputCubemap;
        cubemapIrradiancePrefilterPass.outputCubemap = outputCubemap;
        foreach(faceIndex, face; EnumMembers!CubeFace)
        {
            cubemapIrradiancePrefilterPass.outputCubemapFace = face;
            
            uint width = outputCubemap.buffer.size.width;
            uint height = outputCubemap.buffer.size.height;
            shader.resolution = Vector2f(width, height);
            cubemapIrradiancePrefilterPass.render(&state);
        }
        
        SDL_SubmitGPUCommandBuffer(commandBuffer);
    }
}
