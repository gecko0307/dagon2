module dagon.graphics.scene;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;
import dlib.image.color;

import dagon.core.gpu;
import dagon.graphics.entity;
import dagon.graphics.camera;
import dagon.graphics.light;
import dagon.graphics.texture;

class Scene: Owner
{
    GPU gpu;
    Array!Entity entities;
    Camera activeCamera;
    Light sun;
    Color4f ambientColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);
    Texture specularTexture;
    Texture irradianceTexture;
    Texture brdfLUT;
    bool brdfLUTEnabled = true;
    float ambientEnergy = 1.0f;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        sun = New!Light(gpu, LightType.Sun, this);
        sun.shadowEnabled = true;
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
        if (parent)
            parent.addChild(e);
        return e;
    }
    
    Camera addCamera(Entity parent = null)
    {
        Camera c = New!Camera(this);
        entities.append(c);
        if (parent)
            parent.addChild(c);
        return c;
    }
}
