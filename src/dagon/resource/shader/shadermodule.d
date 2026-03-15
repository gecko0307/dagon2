module dagon.resource.shader.shadermodule;

import std.stdio;
import std.file;
import std.conv;

import dlib.core.memory;
import dlib.core.ownership;

import dagon.core.application;
import dagon.core.logger;
import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.spvc;
import dagon.resource.shader.glsl;

enum PipelineStage
{
    Vertex = 0,
    Fragment = 1
}

enum ShaderSourceType
{
    Buffer = 0,
    File = 1
}

enum ShaderLanguage
{
    GLSL = 0
}

class ShaderUniform: Owner
{
    string name;
    uint set;
    uint binding;
    
    this(string name, uint set, uint binding, Owner owner)
    {
        super(owner);
        this.name = name;
        this.set = set;
        this.binding = binding;
    }
}

class ShaderSampler: ShaderUniform
{
    this(string name, uint set, uint binding, Owner owner)
    {
        super(name, set, binding, owner);
    }
}

class ShaderStorageBuffer: ShaderUniform
{
    this(string name, uint set, uint binding, Owner owner)
    {
        super(name, set, binding, owner);
    }
}

class ShaderStorageTexture: ShaderUniform
{
    this(string name, uint set, uint binding, Owner owner)
    {
        super(name, set, binding, owner);
    }
}

class ShaderUniformBuffer: ShaderUniform
{
    this(string name, uint set, uint binding, Owner owner)
    {
        super(name, set, binding, owner);
    }
}

/**
 * Checks if all fields of a struct are aligned to the specified number of bytes.
 *
 * Params:
 *   T = Struct type to check.
 *   numBytes = Alignment in bytes.
 *
 * Returns:
 *   true if all fields are aligned, false otherwise.
 */
bool isFieldsOffsetAligned(T, alias numBytes)()
{
    static if (is(T == struct))
    {
        static foreach(f; T.tupleof)
        {
            static if (f.offsetof % numBytes != 0)
                return false;
        }
        
        return true;
    }
    else return false;
}

/// Alias for checking std140 alignment compliance for a struct.
alias isStd140Compliant(T) = isFieldsOffsetAligned!(T, 16);

///
class ShaderModule: Owner
{
   protected:
    ubyte[] spirvInternal;
    
   public:
    GPU gpu;
    SDL_GPUShader* shader;
    
    string name;
    uint[] spirv;
    PipelineStage pipelineStage;
    bool valid = false;
    
    ShaderSampler[] samplers;
    ShaderStorageBuffer[] storageBuffers;
    ShaderStorageTexture[] storageTextures;
    ShaderUniformBuffer[] uniformBuffers;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        this.valid = false;
    }
    
    ~this()
    {
        if (samplers.length)
            Delete(samplers);
        
        if (storageBuffers.length)
            Delete(storageBuffers);
        
        if (storageTextures.length)
            Delete(storageTextures);
        
        if (uniformBuffers.length)
            Delete(uniformBuffers);
        
        if (spirvInternal.length)
            Delete(spirvInternal);
    }
    
    bool create(string name, string source, ShaderSourceType sourceType, ShaderLanguage sourceLanguage, PipelineStage pipelineStage)
    {
        this.name = name;
        this.pipelineStage = pipelineStage;
        
        if (sourceLanguage == ShaderLanguage.GLSL)
        {
            bool compilationNeeded = true;
            string sourceString;
            if (sourceType == ShaderSourceType.File)
            {
                string filename = source;
                ubyte[] data = globalResourceCache.load(name, filename);
                if (data.length)
                {
                    compilationNeeded = false;
                    valid = true;
                    spirvInternal = data;
                    uint* ubytePtr = cast(uint*)spirvInternal.ptr;
                    spirv = ubytePtr[0..spirvInternal.length / 4];
                }
                else
                {
                    // TODO: shader preprocessor
                    sourceString = readText(filename);
                }
            }
            else
            {
                // TODO: shader preprocessor
                sourceString = source;
            }
            
            if (compilationNeeded)
            {
                ShaderCompilationResult res = compileGLSLtoSPIRV(sourceString, pipelineStage);
                if (res.success)
                {
                    spirv = res.spirv;
                    valid = true;
                    globalResourceCache.save(name, spirvAsBytes);
                }
                else
                {
                    valid = false;
                    writefln("%s: shader compilation failed", name);
                }
            }
        }
        else
        {
            valid = false;
        }
        
        if (valid)
        {
            // TODO: SPIR-V introspection cache
            valid = analyze();
            
            valid = createSDLShader();
        }
        
        return valid;
    }
    
    bool create(string name, uint[] spirv, PipelineStage pipelineStage)
    {
        this.name = name;
        this.spirv = spirv;
        this.pipelineStage = pipelineStage;
        this.valid = true;
        
        if (valid)
        {
            valid = analyze();
            valid = createSDLShader();
        }
        
        return valid;
    }
    
    ubyte[] spirvAsBytes() const
    {
        if (spirv.length)
        {
            ubyte* ubytePtr = cast(ubyte*)spirv.ptr;
            return ubytePtr[0..spirv.length * 4];
        }
        else
            return [];
    }
    
    protected bool analyze()
    {
        if (!valid)
            return false;
        
        spvc_parsed_ir spvcIR;
        if (spvc_context_parse_spirv(gpu.application.spvcContext, spirv.ptr, spirv.length, &spvcIR) != SPVC_SUCCESS)
        {
            logError("ShaderModule.analyze: failed to parse SPIR-V module");
            return false;
        }
        
        spvc_compiler spvcCompiler;
        if (spvc_context_create_compiler(gpu.application.spvcContext, SPVC_BACKEND_GLSL, spvcIR, SPVC_CAPTURE_MODE_COPY, &spvcCompiler) != SPVC_SUCCESS)
        {
            logError("ShaderModule.analyze: failed to create compiler");
            return false;
        }
        
        spvc_compiler_options spvcCompilerOptions;
        if (spvc_compiler_create_compiler_options(spvcCompiler, &spvcCompilerOptions) != SPVC_SUCCESS)
        {
            logError("ShaderModule.analyze: failed to create compiler options");
            return false;
        }
        
        /*
        spvc_compiler_options_set_uint(spvcCompilerOptions, SPVC_COMPILER_OPTION_GLSL_VERSION, 400);
        spvc_compiler_options_set_bool(spvcCompilerOptions, SPVC_COMPILER_OPTION_GLSL_EMIT_UNIFORM_BUFFER_AS_PLAIN_UNIFORMS, true);
        spvc_compiler_options_set_bool(spvcCompilerOptions, SPVC_COMPILER_OPTION_GLSL_VULKAN_SEMANTICS, false);
        */
        spvc_compiler_install_compiler_options(spvcCompiler, spvcCompilerOptions);
        
        spvc_resources resources;
        spvc_compiler_create_shader_resources(spvcCompiler, &resources);
        
        // Enumerate sampled images
        {
            const(spvc_reflected_resource)* rSamplers;
            size_t numSamplers;
            spvc_resources_get_resource_list_for_type(resources, SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, &rSamplers, &numSamplers);
            
            samplers = New!(ShaderSampler[])(numSamplers);
            for (size_t i = 0; i < numSamplers; i++)
            {
                string name = rSamplers[i].name.to!string;
                uint set = spvc_compiler_get_decoration(spvcCompiler, rSamplers[i].id, SpvDecoration.DescriptorSet);
                uint binding = spvc_compiler_get_decoration(spvcCompiler, rSamplers[i].id, SpvDecoration.Binding);
                samplers[i] = New!ShaderSampler(name, set, binding, this);
            }
        }
        
        // Enumerate storage buffers
        {
            const(spvc_reflected_resource)* rStorageBuffers;
            size_t numStorageBuffers;
            spvc_resources_get_resource_list_for_type(
                resources, SPVC_RESOURCE_TYPE_STORAGE_BUFFER, &rStorageBuffers, &numStorageBuffers);
            
            storageBuffers = New!(ShaderStorageBuffer[])(numStorageBuffers);
            for (size_t i = 0; i < numStorageBuffers; i++)
            {
                string name = rStorageBuffers[i].name.to!string;
                uint set = spvc_compiler_get_decoration(spvcCompiler, rStorageBuffers[i].id, SpvDecoration.DescriptorSet);
                uint binding = spvc_compiler_get_decoration(spvcCompiler, rStorageBuffers[i].id, SpvDecoration.Binding);
                storageBuffers[i] = New!ShaderStorageBuffer(name, set, binding, this);
            }
        }
        
        // Enumerate storage images
        {
            const(spvc_reflected_resource)* rStorageTextures;
            size_t numStorageTextures;
            spvc_resources_get_resource_list_for_type(
                resources, SPVC_RESOURCE_TYPE_STORAGE_IMAGE, &rStorageTextures, &numStorageTextures);
            
            storageTextures = New!(ShaderStorageTexture[])(numStorageTextures);
            for (size_t i = 0; i < numStorageTextures; i++)
            {
                string name = rStorageTextures[i].name.to!string;
                uint set = spvc_compiler_get_decoration(spvcCompiler, rStorageTextures[i].id, SpvDecoration.DescriptorSet);
                uint binding = spvc_compiler_get_decoration(spvcCompiler, rStorageTextures[i].id, SpvDecoration.Binding);
                storageTextures[i] = New!ShaderStorageTexture(name, set, binding, this);
            }
        }
        
        // Enumerate uniform buffers
        {
            const(spvc_reflected_resource)* rUniformBuffers;
            size_t numUniformBuffers;
            spvc_resources_get_resource_list_for_type(
                resources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &rUniformBuffers, &numUniformBuffers);
            
            uniformBuffers = New!(ShaderUniformBuffer[])(numUniformBuffers);
            for (size_t i = 0; i < numUniformBuffers; i++)
            {
                string name = rUniformBuffers[i].name.to!string;
                uint set = spvc_compiler_get_decoration(spvcCompiler, rUniformBuffers[i].id, SpvDecoration.DescriptorSet);
                uint binding = spvc_compiler_get_decoration(spvcCompiler, rUniformBuffers[i].id, SpvDecoration.Binding);
                uniformBuffers[i] = New!ShaderUniformBuffer(name, set, binding, this);
            }
        }
        
        spvc_context_release_allocations(gpu.application.spvcContext);
        
        return true;
    }
    
    protected bool createSDLShader()
    {
        if (!valid)
            return false;
        
        ubyte[] vsSPIRVBytes = spirvAsBytes;
        
        SDL_GPUShaderCreateInfo info;
        info.code = vsSPIRVBytes.ptr;
        info.code_size = vsSPIRVBytes.length;
        info.entrypoint = "main"; // get from shader?
        info.format = SDL_GPU_SHADERFORMAT_SPIRV;
        if (pipelineStage == PipelineStage.Vertex)
            info.stage = SDL_GPU_SHADERSTAGE_VERTEX;
        else if (pipelineStage == PipelineStage.Fragment)
            info.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
        else
            return false;
        info.num_samplers = cast(uint)samplers.length;
        info.num_storage_buffers = cast(uint)storageBuffers.length;
        info.num_storage_textures = cast(uint)storageTextures.length;
        info.num_uniform_buffers = cast(uint)uniformBuffers.length;
        
        shader = SDL_CreateGPUShader(gpu.device, &info);
        
        if (shader)
            return true;
        else
            return false;
    }
    
    protected void releaseSDLShader()
    {
        if (shader)
            SDL_ReleaseGPUShader(gpu.device, shader);
    }
    
    /*
    void printUniforms()
    {
        foreach(s; samplers)
        {
            writefln("%s shader sampler \"%s\": set %s, binding %s", pipelineStage, s.name, s.set, s.binding);
        }
        
        foreach(ssbo; storageBuffers)
        {
            writefln("%s shader storage buffer \"%s\": set %s, binding %s", pipelineStage, ssbo.name, ssbo.set, ssbo.binding);
        }
        
        foreach(ubo; uniformBuffers)
        {
            writefln("%s shader uniform buffer \"%s\": set %s, binding %s", pipelineStage, ubo.name, ubo.set, ubo.binding);
        }
    }
    */
}
