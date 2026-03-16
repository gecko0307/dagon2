module dagon.render.postprocessing.passes.present;

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
import dagon.render.postprocessing.context;

struct PresentShaderVertexUniformBuffer
{
    // TODO
}

struct PresentShaderFragmentUniformBuffer
{
    // TODO
}

class PresentShader: Shader
{
   protected:
    PresentShaderVertexUniformBuffer vsUBO;
    PresentShaderFragmentUniformBuffer fsUBO;
    
   public:
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("Present.vert.glsl", "data/__internal/shaders/Present/Present.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("Present.frag.glsl", "data/__internal/shaders/Present/Present.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create PresentShader");
        }
    }
    
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        
        pass.bindInputBuffer(PipelineStage.Fragment, 0, &state.radianceBuffer);
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        //pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class PresentPass: RenderPass
{
    GPU gpu;
    GBuffer gbuffer;
    PostProcessingContext ppContext;
    PresentShader presentShader;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, PostProcessingContext ppContext)
    {
        super(renderer);
        this.gpu = renderer.gpu;
        this.gbuffer = ppContext.gbuffer;
        this.ppContext = ppContext;
        
        presentShader = New!PresentShader(gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = presentShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = presentShader.fragmentModule.shader;
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
        
        SDL_GPUColorTargetDescription colorTargetDescription;
        colorTargetDescription.format = gpu.swapchainTextureFormat;
        colorTargetDescription.blend_state.enable_blend = false;
        colorTargetDescription.blend_state.color_blend_op = SDL_GPU_BLENDOP_ADD;
        colorTargetDescription.blend_state.alpha_blend_op = SDL_GPU_BLENDOP_ADD;
        colorTargetDescription.blend_state.src_color_blendfactor = SDL_GPU_BLENDFACTOR_SRC_ALPHA;
        colorTargetDescription.blend_state.dst_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
        colorTargetDescription.blend_state.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_SRC_ALPHA;
        colorTargetDescription.blend_state.dst_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
        
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
        
        colorTargetInfo.clear_color = SDL_FColor(0.0f, 0.0f, 0.0f, 0.0f);
        colorTargetInfo.load_op = SDL_GPU_LOADOP_DONT_CARE;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    override void render(GraphicsState* state)
    {
        if (state.scene is null)
            return;
        
        SDL_GPUTexture* swapchainTexture;
        uint width, height;
        SDL_WaitAndAcquireGPUSwapchainTexture(
            renderer.commandBuffer,
            renderer.gpu.application.window,
            &swapchainTexture,
            &width,
            &height);
        colorTargetInfo.texture = swapchainTexture;
        
        beginPass();
        
        state.radianceBuffer = InputBuffer(ppContext.currentTarget, ppContext.targetSampler);
        state.entity = null;
        presentShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
    }
}
