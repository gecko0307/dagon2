module dagon.render.pass;

import dlib.core.ownership;

import dagon.core.sdl3;
import dagon.core.time;
import dagon.graphics.texture;
import dagon.graphics.state;
import dagon.resource.shader.shadermodule;
import dagon.render.renderer;
import dagon.render.view;

abstract class RenderPass: Owner
{
   public:
    Renderer renderer;
    View view;
    bool active = true;
    
   protected:
    SDL_GPURenderPass* renderPass;
    SDL_GPUColorTargetInfo* colorTargetsInfo;
    uint numColorTargets;
    SDL_GPUDepthStencilTargetInfo* depthStencilTargetInfo = null;
    bool enableDepthTarget = false;
    SDL_GPUGraphicsPipeline* graphicsPipeline;
    
   public:
    this(Renderer renderer)
    {
        super(renderer);
        this.renderer = renderer;
        renderer.addRenderPass(this);
    }
    
    ~this()
    {
        if (graphicsPipeline)
            SDL_ReleaseGPUGraphicsPipeline(renderer.gpu.device, graphicsPipeline);
    }
    
    protected void beginPass()
    {
        renderPass = SDL_BeginGPURenderPass(
            renderer.commandBuffer,
            colorTargetsInfo,
            numColorTargets,
            depthStencilTargetInfo);
        
        if (graphicsPipeline)
            SDL_BindGPUGraphicsPipeline(renderPass, graphicsPipeline);
    }
    
    protected void endPass()
    {
        if (renderPass)
            SDL_EndGPURenderPass(renderPass);
    }
    
    void bindDefaultTexture(PipelineStage stage, uint binding)
    {
        auto samplerBinding = SDL_GPUTextureSamplerBinding(renderer.gpu.defaultTexture, renderer.gpu.defaultSampler);
        
        if (stage == PipelineStage.Vertex)
            SDL_BindGPUVertexSamplers(renderPass, binding, &samplerBinding, 1);
        else if (stage == PipelineStage.Fragment)
            SDL_BindGPUFragmentSamplers(renderPass, binding, &samplerBinding, 1);
    }
    
    void bindTexture(PipelineStage stage, uint binding, SDL_GPUTexture* texture, SDL_GPUSampler* sampler)
    {
        auto samplerBinding = SDL_GPUTextureSamplerBinding(texture, sampler);
        
        if (stage == PipelineStage.Vertex)
            SDL_BindGPUVertexSamplers(renderPass, binding, &samplerBinding, 1);
        else if (stage == PipelineStage.Fragment)
            SDL_BindGPUFragmentSamplers(renderPass, binding, &samplerBinding, 1);
    }
    
    void bindInputBuffer(PipelineStage stage, uint binding, InputBuffer* buffer)
    {
        auto samplerBinding = SDL_GPUTextureSamplerBinding(buffer.texture, buffer.sampler);
        
        if (stage == PipelineStage.Vertex)
            SDL_BindGPUVertexSamplers(renderPass, binding, &samplerBinding, 1);
        else if (stage == PipelineStage.Fragment)
            SDL_BindGPUFragmentSamplers(renderPass, binding, &samplerBinding, 1);
    }
    
    void bindTexture(PipelineStage stage, uint binding, Texture texture)
    {
        auto samplerBinding = SDL_GPUTextureSamplerBinding(texture.texture, texture.sampler);
        
        if (stage == PipelineStage.Vertex)
            SDL_BindGPUVertexSamplers(renderPass, binding, &samplerBinding, 1);
        else if (stage == PipelineStage.Fragment)
            SDL_BindGPUFragmentSamplers(renderPass, binding, &samplerBinding, 1);
    }
    
    void bindUniformBuffer(PipelineStage stage, uint binding, void* data, uint size)
    {
        if (stage == PipelineStage.Vertex)
            SDL_PushGPUVertexUniformData(renderer.commandBuffer, binding, data, size);
        else if (stage == PipelineStage.Fragment)
            SDL_PushGPUFragmentUniformData(renderer.commandBuffer, binding, data, size);
    }
    
    void bindUniformBuffer(T)(PipelineStage stage, uint binding, T* uniformStruct) if (isStd140Compliant!T)
    {
        if (stage == PipelineStage.Vertex)
            SDL_PushGPUVertexUniformData(renderer.commandBuffer, binding, uniformStruct, cast(uint)T.sizeof);
        else if (stage == PipelineStage.Fragment)
            SDL_PushGPUFragmentUniformData(renderer.commandBuffer, binding, uniformStruct, cast(uint)T.sizeof);
    }
    
    // TODO: VertexBuffer class
    void bindVertexBuffer(uint slot, SDL_GPUBuffer* vertexBuffer)
    {
        SDL_GPUBufferBinding bufferBinding;
        bufferBinding.buffer = vertexBuffer;
        bufferBinding.offset = 0;
        SDL_BindGPUVertexBuffers(renderPass, slot, &bufferBinding, 1);
    }
    
    void bindIndexBuffer(SDL_GPUBuffer* indexBuffer, SDL_GPUIndexElementSize elementSize)
    {
        SDL_GPUBufferBinding bufferBinding;
        bufferBinding.buffer = indexBuffer;
        bufferBinding.offset = 0;
        SDL_BindGPUIndexBuffer(renderPass, &bufferBinding, elementSize);
    }
    
    void drawPrimitives(uint numVertices, uint numInstances, uint firstVertex, uint firstInstance)
    {
        SDL_DrawGPUPrimitives(renderPass, numVertices, numInstances, firstVertex, firstInstance);
    }
    
    void drawIndexedPrimitives(uint numIndices, uint numInstances, uint firstIndex, int vertexOffset, uint firstInstance)
    {
        SDL_DrawGPUIndexedPrimitives(renderPass, numIndices, numInstances, firstIndex, vertexOffset, firstInstance);
    }
    
    void update(Time t)
    {
        //
    }
    
    void render(GraphicsState* state)
    {
        //
    }
    
    void resize(uint width, uint height)
    {
        //
    }
}
