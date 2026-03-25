module dagon.render.deferred.passes.csm;

import std.conv;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.crashhandler;
import dagon.core.logger;
import dagon.core.time;
import dagon.graphics.state;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.mesh;
import dagon.graphics.csm;
import dagon.resource.shader;
import dagon.render.renderer;
import dagon.render.pass;
import dagon.render.view;
import dagon.render.deferred.gbuffer;

struct CSMShaderVertexUniformBuffer
{
    Matrix4x4f modelViewMatrix;
    Matrix4x4f projectionMatrix;
}

struct CSMShaderFragmentUniformBuffer
{
}

class CSMShader: Shader
{
   protected:
    CSMShaderVertexUniformBuffer vsUBO;
    CSMShaderFragmentUniformBuffer fsUBO;
    
   public:
    ShadowArea area;
    
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("CSM.vert.glsl", "data/__internal/shaders/CSM/CSM.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("CSM.frag.glsl", "data/__internal/shaders/CSM/CSM.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create CSMShader");
        }
        
        vsUBO.modelViewMatrix = Matrix4x4f.identity;
        vsUBO.projectionMatrix = Matrix4x4f.identity;
    }
    
    override void bindParameters(GraphicsState* state)
    {
        if (area is null)
            return;
        
        auto pass = state.pass;
        auto entity = state.entity;
        auto material = state.material;
        
        vsUBO.modelViewMatrix = area.viewMatrix * entity.modelMatrix;
        vsUBO.projectionMatrix = area.projectionMatrix;
        
        pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        //pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class CSMPass: RenderPass
{
   protected:
    GPU gpu;
    GBuffer gbuffer;
    CSMShader csmShader;
    SDL_GPUDepthStencilTargetInfo shadowTargetInfo;
    
   public:
    this(Renderer renderer, GBuffer gbuffer)
    {
        super(renderer);
        this.gpu = renderer.gpu;
        this.gbuffer = gbuffer;
        csmShader = New!CSMShader(gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = csmShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = csmShader.fragmentModule.shader;
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
        
        pipelineCreateInfo.target_info.num_color_targets = 0;
        pipelineCreateInfo.target_info.color_target_descriptions = null;
        pipelineCreateInfo.target_info.depth_stencil_format = SDL_GPU_TEXTUREFORMAT_D32_FLOAT;
        pipelineCreateInfo.target_info.has_depth_stencil_target = true;
        
        pipelineCreateInfo.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pipelineCreateInfo.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
        pipelineCreateInfo.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
        pipelineCreateInfo.rasterizer_state.depth_bias_constant_factor = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_clamp = 0.0f;
        pipelineCreateInfo.rasterizer_state.depth_bias_slope_factor = 3.0f;
        pipelineCreateInfo.rasterizer_state.enable_depth_bias = true;
        pipelineCreateInfo.rasterizer_state.enable_depth_clip = false;
        
        pipelineCreateInfo.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS_OR_EQUAL;
        pipelineCreateInfo.depth_stencil_state.enable_depth_test = true;
        pipelineCreateInfo.depth_stencil_state.enable_depth_write = true;
        pipelineCreateInfo.depth_stencil_state.enable_stencil_test = false;
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(gpu.device, &pipelineCreateInfo);
        
        shadowTargetInfo.clear_depth = 1.0f;
        shadowTargetInfo.load_op = SDL_GPU_LOADOP_CLEAR;
        shadowTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        shadowTargetInfo.stencil_load_op = SDL_GPU_LOADOP_DONT_CARE;
        shadowTargetInfo.stencil_store_op = SDL_GPU_STOREOP_DONT_CARE;
        shadowTargetInfo.cycle = false;
        shadowTargetInfo.clear_stencil = 0;
        shadowTargetInfo.mip_level = 0;
        
        colorTargetsInfo = null;
        numColorTargets = 0;
        depthStencilTargetInfo = &shadowTargetInfo;
        enableDepthTarget = true;
    }
    
    ~this()
    {
    }
    
    override void update(Time t)
    {
        if (renderer.state.scene is null)
            return;
        
        CascadedShadowMap shadowMap = cast(CascadedShadowMap)renderer.state.scene.sun.shadowMap;
        if (shadowMap is null)
            return;
        
        shadowMap.camera = view.camera;
        shadowMap.update(t);
    }
    
    override void render(GraphicsState* state)
    {
        if (state.scene is null)
            return;
        
        CascadedShadowMap shadowMap = cast(CascadedShadowMap)state.scene.sun.shadowMap;
        if (shadowMap is null)
            return;
        
        //shadowMap.camera = view.camera;
        //shadowMap.update(state.time);
        
        shadowTargetInfo.texture = shadowMap.depthTexture;
        foreach(ubyte i; 0..shadowMap.area.length)
        {
            shadowTargetInfo.layer = i;
            csmShader.area = shadowMap.area[i];
            
            debug SDL_PushGPUDebugGroup(renderer.commandBuffer, "CSM");
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
                    csmShader.bindParameters(state);
                    entity.drawable.render(state);
                }
            }
            
            endPass();
            debug SDL_PopGPUDebugGroup(renderer.commandBuffer);
        }
    }
}
