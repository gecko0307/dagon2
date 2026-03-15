module dagon.graphics.light;

import dlib.core.ownership;
import dlib.math.vector;
import dlib.image.color;

import dagon.graphics.entity;

enum LightType
{
    Sun = 0
}

class Light: Entity
{
    LightType type;
    Color4f color = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
    float energy = 1.0f;
    
    this(LightType type, Owner owner)
    {
        super(owner);
        this.type = type;
    }
}
