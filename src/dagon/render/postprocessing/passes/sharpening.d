module dagon.render.postprocessing.passes.sharpening;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.crashhandler;
import dagon.core.logger;
import dagon.graphics.state;
import dagon.graphics.mesh;
import dagon.graphics.shapes;
import dagon.resource.shader;
import dagon.render.renderer;
import dagon.render.pass;
import dagon.render.view;
import dagon.render.deferred.gbuffer;
import dagon.render.postprocessing.context;

struct SharpeningShaderVertexUniformBuffer
{
    // TODO
}

struct SharpeningShaderFragmentUniformBuffer
{
    Vector4f viewSize;
    Vector4f params;
}

class SharpeningShader: Shader
{
   protected:
    SharpeningShaderVertexUniformBuffer vsUBO;
    SharpeningShaderFragmentUniformBuffer fsUBO;
    
   public:
    float strength = 0.5f;
    
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("Sharpening.vert.glsl", "data/__internal/shaders/Sharpening/Sharpening.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("Sharpening.frag.glsl", "data/__internal/shaders/Sharpening/Sharpening.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create SharpeningShader");
        }
        
        fsUBO.viewSize = Vector4f(
            gpu.application.drawableWidth,
            gpu.application.drawableHeight,
            0.0f, 0.0f);
        fsUBO.params = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        
        fsUBO.viewSize.x = gpu.application.drawableWidth;
        fsUBO.viewSize.y = gpu.application.drawableHeight;
        
        fsUBO.params[0] = strength;
        
        pass.bindInputBuffer(PipelineStage.Fragment, 0, &state.radianceBuffer);
        //pass.bindInputBuffer(PipelineStage.Fragment, 1, &state.depthBuffer);
        
        //pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}

class SharpeningPass: RenderPass
{
    GPU gpu;
    GBuffer gbuffer;
    PostProcessingContext ppContext;
    SharpeningShader sharpeningShader;
    SDL_GPUColorTargetInfo colorTargetInfo;
    
    this(Renderer renderer, PostProcessingContext ppContext)
    {
        super(renderer);
        this.gpu = renderer.gpu;
        this.gbuffer = ppContext.gbuffer;
        this.ppContext = ppContext;
        
        sharpeningShader = New!SharpeningShader(gpu, this);
        
        SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
        pipelineCreateInfo.vertex_shader = sharpeningShader.vertexModule.shader;
        pipelineCreateInfo.fragment_shader = sharpeningShader.fragmentModule.shader;
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
        colorTargetDescription.format = ppContext.bufferFormat;
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
        colorTargetInfo.load_op = SDL_GPU_LOADOP_LOAD;
        colorTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        colorTargetInfo.texture = ppContext.writeBuffer;
        
        colorTargetsInfo = &colorTargetInfo;
        numColorTargets = 1;
        depthStencilTargetInfo = null;
        enableDepthTarget = false;
    }
    
    override void render(GraphicsState* state)
    {
        if (state.scene is null)
            return;
        
        colorTargetInfo.texture = ppContext.writeBuffer;
        
        beginPass();
        
        state.depthBuffer = InputBuffer(gbuffer.depthBuffer, gbuffer.depthSampler);
        state.colorBuffer = InputBuffer(gbuffer.colorBuffer, gbuffer.colorSampler);
        state.normalBuffer = InputBuffer(gbuffer.normalBuffer, gbuffer.colorSampler);
        state.roughnessMetallicBuffer = InputBuffer(gbuffer.roughnessMetallicBuffer, gbuffer.colorSampler);
        state.emissionBuffer = InputBuffer(gbuffer.emissionBuffer, gbuffer.colorSampler);
        state.velocityBuffer = InputBuffer(gbuffer.velocityBuffer, gbuffer.colorSampler);
        state.radianceBuffer = InputBuffer(ppContext.readBuffer, ppContext.bufferSampler);
        state.entity = null;
        sharpeningShader.bindParameters(state);
        
        renderer.renderScreenQuad(state);
        
        endPass();
        
        ppContext.swapTargets();
    }
}
