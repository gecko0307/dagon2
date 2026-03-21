module dagon.render.deferred.passes.ssao;

//import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.crashhandler;
import dagon.graphics.state;
import dagon.graphics.mesh;
import dagon.graphics.shapes;
import dagon.resource.shader;
import dagon.render.renderer;
import dagon.render.pass;
import dagon.render.view;
import dagon.render.deferred.gbuffer;

struct SSAOShaderVertexUniformBuffer
{
}

struct SSAOShaderFragmentUniformBuffer
{
    Matrix4x4f viewMatrix;
    Matrix4x4f invViewMatrix;
    Matrix4x4f invProjectionMatrix;
    Vector4f resolution;
}

class SSAOShader: Shader
{
   protected:
    SSAOShaderVertexUniformBuffer vsUBO;
    SSAOShaderFragmentUniformBuffer fsUBO;
    
   public:
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("SSAO.vert.glsl", "data/__internal/shaders/SSAO/SSAO.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("SSAO.frag.glsl", "data/__internal/shaders/SSAO/SSAO.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create SSAOShader");
        }
        
        fsUBO.viewMatrix = Matrix4x4f.identity;
        fsUBO.invViewMatrix = Matrix4x4f.identity;
        fsUBO.invProjectionMatrix = Matrix4x4f.identity;
        fsUBO.resolution = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        auto view = pass.view;
        
        fsUBO.resolution.x = view.width / 2;
        fsUBO.resolution.x = view.height / 2;
        
        fsUBO.viewMatrix = view.viewMatrix;
        fsUBO.invViewMatrix = view.invViewMatrix;
        fsUBO.invProjectionMatrix = view.invProjectionMatrix;
        
        pass.bindInputBuffer(PipelineStage.Fragment, 0, &state.depthBuffer);
        pass.bindInputBuffer(PipelineStage.Fragment, 1, &state.normalBuffer);
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class SSAOPass: RenderPass
{
    GPU gpu;
    GBuffer gbuffer;
    SSAOShader ssaoShader;
    
    SDL_GPUColorTargetDescription colorTargetDescription;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, GBuffer gbuffer)
    {
        super(renderer);
        this.gpu = renderer.gpu;
        this.gbuffer = gbuffer;
        ssaoShader = New!SSAOShader(gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = ssaoShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = ssaoShader.fragmentModule.shader;
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
        colorTargetDescription.format = SDL_GPU_TEXTUREFORMAT_R16_FLOAT;
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
        
        graphicsPipeline = SDL_CreateGPUGraphicsPipeline(gpu.device, &pipelineCreateInfo);
        
        colorTargetInfo.clear_color = SDL_FColor(1.0f, 1.0f, 1.0f, 1.0f);
        colorTargetInfo.load_op = SDL_GPU_LOADOP_DONT_CARE;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        colorTargetInfo.texture = gbuffer.occlusionBuffer1;
        
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    ~this()
    {
    }
    
    override void render(GraphicsState* state)
    {
        if (state.scene is null)
            return;
        
        colorTargetInfo.texture = gbuffer.occlusionBuffer1;
        
        beginPass();
        
        state.depthBuffer = InputBuffer(gbuffer.depthBuffer, gbuffer.depthSampler);
        state.colorBuffer = InputBuffer(gbuffer.colorBuffer, gbuffer.colorSampler);
        state.normalBuffer = InputBuffer(gbuffer.normalBuffer, gbuffer.colorSampler);
        state.roughnessMetallicBuffer = InputBuffer(gbuffer.roughnessMetallicBuffer, gbuffer.colorSampler);
        state.emissionBuffer = InputBuffer(gbuffer.emissionBuffer, gbuffer.colorSampler);
        state.velocityBuffer = InputBuffer(gbuffer.velocityBuffer, gbuffer.colorSampler);
        state.radianceBuffer = InputBuffer(gbuffer.radianceBuffer, gbuffer.colorSampler);
        state.entity = null;
        ssaoShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
    }
}
