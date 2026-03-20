module dagon.graphics.scene;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;
import dlib.image.color;

import dagon.graphics.entity;
import dagon.graphics.camera;
import dagon.graphics.light;
import dagon.graphics.texture;

class Scene: Owner
{
    Array!Entity entities;
    Camera activeCamera;
    Light sun;
    Color4f ambientColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);
    Texture radianceTexture;
    Texture irradianceTexture;
    Texture brdfLUT;
    bool brdfLUTEnabled = true;
    float ambientEnergy = 1.0f;
    
    this(Owner owner)
    {
        super(owner);
        sun = New!Light(LightType.Sun, this);
        entities.append(sun);
    }
    
    ~this()
    {
        entities.free();
    }
    
    Entity addEntity(Entity parent = null)
    {
        Entity e = New!Entity(this);
        entities.append(e);
        return e;
    }
    
    Camera addCamera(Entity parent = null)
    {
        Camera c = New!Camera(this);
        entities.append(c);
        return c;
    }
}
