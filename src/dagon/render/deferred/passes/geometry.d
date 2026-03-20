module dagon.render.deferred.passes.geometry;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.crashhandler;
import dagon.graphics.state;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.mesh;
import dagon.resource.shader;
import dagon.render.renderer;
import dagon.render.pass;
import dagon.render.view;
import dagon.render.deferred.gbuffer;

struct GeometryShaderVertexUniformBuffer
{
    Matrix4x4f modelViewMatrix;
    Matrix4x4f normalMatrix;
    Matrix4x4f projectionMatrix;
}

struct GeometryShaderFragmentUniformBuffer
{
    Color4f baseColor;
    Vector4f roughnessMetallic;
    Color4f emission;
    Vector4f alphaOptions;
    uint[4] flags;
    float[4] fparams;
}

enum GeometryFlags
{
    Texture = 0,
    Output = 1
}

enum GeometryTextureFlags: uint
{
    HasBaseColorTexture = 1 << 0,
    HasNormalTexture = 1 << 1,
    HasHeightTexture = 1 << 2,
    HasRoughnessMetallicTexture = 1 << 3,
    HasEmissionTexture = 1 << 4,
    HasSkyboxTexture = 1 << 5
}

enum GeometryOutputFlags: uint
{
    Depth = 1 << 0
}

class GeometryShader: Shader
{
   protected:
    GeometryShaderVertexUniformBuffer vsUBO;
    GeometryShaderFragmentUniformBuffer fsUBO;
    
   public:
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("Geometry.vert.glsl", "data/__internal/shaders/Geometry/Geometry.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("Geometry.frag.glsl", "data/__internal/shaders/Geometry/Geometry.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create GeometryShader");
        }
        
        fsUBO.baseColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        fsUBO.roughnessMetallic = Vector4f(0.0f, 0.5f, 0.0f, 0.0f);
        fsUBO.emission = Color4f(0.0f, 0.0f, 0.0f, 0.0f);
        fsUBO.alphaOptions = Vector4f(0.5f, 1.0f, 1.0f, 1.0f);
        
        fsUBO.fparams[0] = 0.0f;
        fsUBO.fparams[1] = 0.0f;
        fsUBO.fparams[2] = 0.0f;
        fsUBO.fparams[3] = 0.0f;
    }
    
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        auto entity = state.entity;
        auto material = state.material;
        
        vsUBO.modelViewMatrix = pass.view.viewMatrix * entity.modelMatrix;
        vsUBO.normalMatrix = vsUBO.modelViewMatrix.inverse.transposed;
        vsUBO.projectionMatrix = pass.view.projectionMatrix;
        
        fsUBO.flags[GeometryFlags.Texture] = 0;
        fsUBO.flags[GeometryFlags.Output] = 0;
        fsUBO.flags[2] = 0;
        fsUBO.flags[3] = 0;
        fsUBO.baseColor = material.baseColor;
        
        if (material.outputDepth)
            fsUBO.flags[GeometryFlags.Output] |= GeometryOutputFlags.Depth;
        
        fsUBO.roughnessMetallic.g = material.roughness;
        fsUBO.roughnessMetallic.b = material.metallic;
        
        fsUBO.emission = material.emissionColor * material.emissionEnergy;
        
        fsUBO.alphaOptions.x = material.alphaClipThreshold;
        fsUBO.alphaOptions.y = cast(float)!material.shadeless;
        fsUBO.alphaOptions.z = entity.motionBlurMask;
        fsUBO.alphaOptions.w = entity.opacity * material.opacity;
        
        fsUBO.fparams[0] = material.skyboxTextureMipLevel;
        
        if (material.baseColorTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 0, material.baseColorTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasBaseColorTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 0);
        
        if (material.normalTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 1, material.normalTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasNormalTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 1);
        
        if (material.heightTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 2, material.heightTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasHeightTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 2);
        
        if (material.roughnessMetallicTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 3, material.roughnessMetallicTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasRoughnessMetallicTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 3);
        
        if (material.emissionTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 4, material.emissionTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasEmissionTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 4);
        
        if (material.skyboxTexture)
        {
            pass.bindTexture(PipelineStage.Fragment, 5, material.skyboxTexture);
            fsUBO.flags[GeometryFlags.Texture] |= GeometryTextureFlags.HasSkyboxTexture;
        }
        else
            pass.bindDefaultTexture(PipelineStage.Fragment, 5);
        
        pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class GeometryPass: RenderPass
{
   protected:
    GPU gpu;
    GBuffer gbuffer;
    GeometryShader geometryShader;
    
   public:
    this(Renderer renderer, GBuffer gbuffer)
    {
        super(renderer);
        this.gpu = renderer.gpu;
        this.gbuffer = gbuffer;
        geometryShader = New!GeometryShader(gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = geometryShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = geometryShader.fragmentModule.shader;
        pipelineCreateInfo.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
        
        SDL_GPUVertexBufferDescription[3] vbDescriptions;
        
        vbDescriptions[0].slot = 0;
        vbDescriptions[0].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[0].instance_step_rate = 0;
        vbDescriptions[0].pitch = Vector3f.sizeof;
        
        vbDescriptions[1].slot = 1;
        vbDescriptions[1].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[1].instance_step_rate = 0;
        vbDescriptions[1].pitch = Vector2f.sizeof;
        
        vbDescriptions[2].slot = 2;
        vbDescriptions[2].input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
        vbDescriptions[2].instance_step_rate = 0;
        vbDescriptions[2].pitch = Vector3f.sizeof;

        pipelineCreateInfo.vertex_input_state.num_vertex_buffers = vbDescriptions.length;
        pipelineCreateInfo.vertex_input_state.vertex_buffer_descriptions = vbDescriptions.ptr;
        
        SDL_GPUVertexAttribute[3] vertexAttributes;
    
        // Position
        vertexAttributes[0].buffer_slot = VertexAttribute.Position;
        vertexAttributes[0].location = VertexAttribute.Position;
        vertexAttributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3;
        vertexAttributes[0].offset = 0;
        
        // Texcoords
        vertexAttributes[1].buffer_slot = VertexAttribute.Texcoord;
        vertexAttributes[1].location = VertexAttribute.Texcoord;
        vertexAttributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
        vertexAttributes[1].offset = 0;
        
        // Normals
        vertexAttributes[2].buffer_slot = VertexAttribute.Normal;
        vertexAttributes[2].location = VertexAttribute.Normal;
        vertexAttributes[2].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3;
        vertexAttributes[2].offset = 0;
        
        pipelineCreateInfo.vertex_input_state.num_vertex_attributes = vertexAttributes.length;
        pipelineCreateInfo.vertex_input_state.vertex_attributes = vertexAttributes.ptr;
        
        pipelineCreateInfo.target_info.num_color_targets = gbuffer.colorTargetsDescription.length;
        pipelineCreateInfo.target_info.color_target_descriptions = gbuffer.colorTargetsDescription.ptr;
        pipelineCreateInfo.target_info.depth_stencil_format = SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT;
        pipelineCreateInfo.target_info.has_depth_stencil_target = true;
        
        pipelineCreateInfo.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pipelineCreateInfo.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_BACK;
        pipelineCreateInfo.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
        pipelineCreateInfo.rasterizer_state.depth_bias_constant_factor = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_clamp = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_slope_factor = 1.0f;
        pipelineCreateInfo.rasterizer_state.enable_depth_bias = false;
        pipelineCreateInfo.rasterizer_state.enable_depth_clip = false;
        
        pipelineCreateInfo.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS_OR_EQUAL;
        pipelineCreateInfo.depth_stencil_state.enable_depth_test = true;
        pipelineCreateInfo.depth_stencil_state.enable_depth_write = true;
        pipelineCreateInfo.depth_stencil_state.enable_stencil_test = false;
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(gpu.device, &pipelineCreateInfo);
        
        colorTargetsInfo = gbuffer.colorTargetsInfo.ptr;
        numColorTargets = cast(uint)gbuffer.colorTargetsInfo.length;
        depthStencilTargetInfo = &gbuffer.depthStencilTargetInfo;
        enableDepthTarget = true;
    }
    
    ~this()
    {
    }
    
    override void render(GraphicsState* state)
    {
        if (state.scene is null)
            return;
        
        beginPass();
        
        foreach(entity; state.scene.entities)
        {
            if (entity.layer == EntityLayer.Scene && entity.drawable)
            {
                state.entity = entity;
                if (entity.material)
                    state.material = entity.material;
                else
                    state.material = renderer.defaultMaterial;
                geometryShader.bindParameters(state);
                entity.drawable.render(state);
            }
        }
        
        endPass();
    }
}
