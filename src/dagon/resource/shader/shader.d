module dagon.resource.shader.shader;

import dlib.core.ownership;

import dagon.core.gpu;
import dagon.graphics.state;
import dagon.resource.shader.shadermodule;

abstract class Shader: Owner
{
    GPU gpu;
    ShaderModule vertexModule;
    ShaderModule fragmentModule;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
    }
    
    void bindParameters(GraphicsState* state)
    {
        //
    }
}
