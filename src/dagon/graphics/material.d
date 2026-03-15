module dagon.graphics.material;

import dlib.core.ownership;
import dlib.math.vector;
import dlib.image.color;

import dagon.graphics.texture;

class Material: Owner
{
    Color4f baseColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
    float roughness = 0.5f;
    float metallic = 0.0f;
    Color4f emissionColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
    float emissionEnergy = 0.0f;
    
    Texture baseColorTexture;
    Texture normalTexture;
    Texture heightTexture;
    Texture roughnessMetallicTexture;
    Texture emissionTexture;
    Texture skyboxTexture;
    
    float opacity = 1.0f;
    float alphaClipThreshold = 0.5f;
    bool shadeless = false;
    
    this(Owner owner)
    {
        super(owner);
    }
}
