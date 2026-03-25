module dagon.graphics.entity;

import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.quaternion;
import dlib.math.utils;
import dlib.container.array;

import dagon.core.event;
import dagon.core.time;
import dagon.core.updateable;
import dagon.graphics.drawable;
import dagon.graphics.material;

enum EntityLayer
{
    Scene = 0,
    Background = 1,
    Foreground = 2
}

class Entity: Owner, Updateable
{
    EntityController controller;
    Matrix4x4f transformation;
    Matrix4x4f invTransformation;
    Matrix4x4f modelMatrix;
    Matrix4x4f invModelMatrix;
    Matrix4x4f prevModelMatrix;
    Vector3f position;
    Quaternionf rotation;
    Vector3f scaling;
    Drawable drawable;
    Material material;
    EntityLayer layer;
    float opacity = 1.0f;
    float motionBlurMask = 1.0f;
    bool visible = true;
    bool castShadow = true;
    bool dynamic = false;
    bool transformationValid = false;
    
    this(Owner owner)
    {
        super(owner);
        modelMatrix = Matrix4x4f.identity;
        invModelMatrix = Matrix4x4f.identity;
        prevModelMatrix = Matrix4x4f.identity;
        position = Vector3f(0.0f, 0.0f, 0.0f);
        rotation = Quaternionf.identity;
        scaling = Vector3f(1.0f, 1.0f, 1.0f);
        update(Time(0.0, 0.0));
    }
    
    void update()
    {
        update(Time(0.0, 0.0));
    }
    
    void update(Time t)
    {
        if (controller)
            controller.update(t);
        else
        {
            prevModelMatrix = modelMatrix;
            //if (!transformationValid)
            //{
                //transformationValid = !dynamic;
                
                transformation =
                    translationMatrix(position) *
                    rotation.toMatrix4x4 *
                    scaleMatrix(scaling);
                //trsMatrix(position, rotation, scaling);
                invTransformation = transformation.inverse;
                
                // TODO: parent-child relation
                modelMatrix = transformation;
                invModelMatrix = invTransformation;
            //}
        }
    }
    
    Vector3f positionAbsolute()
    {
        return modelMatrix.translation;
    }
    
    /// Returns the absolute rotation of the entity.
    Quaternionf rotationAbsolute()
    {
        //if (parent)
        //    return parent.rotationAbsolute * rotation;
        //else
            return rotation;
    }
    
    Vector3f direction()
    {
        return transformation.forward;
    }
    
    Vector3f directionAbsolute()
    {
        return modelMatrix.forward;
    }
    
    Vector3f right()
    {
        return transformation.right;
    }
    
    Vector3f rightAbsolute()
    {
        return modelMatrix.right;
    }
    
    Vector3f up()
    {
        return transformation.up;
    }
    
    Vector3f upAbsolute()
    {
        return modelMatrix.up;
    }
    
    /// Translates the entity by the given vector.
    void translate(Vector3f v)
    {
        position += v;
    }

    /// Translates the entity by the given vector components.
    void translate(float vx, float vy, float vz)
    {
        position += Vector3f(vx, vy, vz);
    }

    /// Moves the entity forward by the given speed.
    void move(float speed)
    {
        position += transformation.forward * speed;
    }
    
    /// Strafes (moves to the right) by the given speed.
    void strafe(float speed)
    {
        position += transformation.right * speed;
    }

    /// Lifts (moves up) by the given speed.
    void lift(float speed)
    {
        position += transformation.up * speed;
    }
    
    /// Rotates the entity by the given Euler angles (degrees).
    void rotate(Vector3f v)
    {
        auto r =
            rotationQuaternion!float(Axis.x, degtorad(v.x)) *
            rotationQuaternion!float(Axis.y, degtorad(v.y)) *
            rotationQuaternion!float(Axis.z, degtorad(v.z));
        rotation *= r;
    }
    
    /// Rotates the entity by the given Euler angles (degrees).
    void rotate(float x, float y, float z)
    {
        rotate(Vector3f(x, y, z));
    }
    
    /// Rotates the entity around the local X axis.
    void pitch(float angle)
    {
        rotation *= rotationQuaternion!float(Axis.x, degtorad(angle));
    }

    /// Rotates the entity around the local Y axis.
    void turn(float angle)
    {
        rotation *= rotationQuaternion!float(Axis.y, degtorad(angle));
    }

    /// Rotates the entity around the local Z axis.
    void roll(float angle)
    {
        rotation *= rotationQuaternion!float(Axis.z, degtorad(angle));
    }

    /// Scales the entity uniformly.
    void scale(float s)
    {
        scaling += Vector3f(s, s, s);
    }

    /// Scales the entity non-uniformly by the given vector.
    void scale(Vector3f s)
    {
        scaling += s;
    }
}

abstract class EntityController: EventListener, Updateable
{
    Entity entity;
    
    this(EventManager eventManager, Entity entity)
    {
        super(eventManager, entity);
        this.entity = entity;
        entity.controller = this;
    }
    
    void update(Time t)
    {
        //
    }
}

class PositionSync: EntityController
{
    Entity targetEntity;
    
    this(EventManager eventManager, Entity entity, Entity targetEntity)
    {
        super(eventManager, entity);
        this.targetEntity = targetEntity;
    }
    
    override void update(Time t)
    {
        entity.transformation = trsMatrix(targetEntity.positionAbsolute, entity.rotation, entity.scaling);
        entity.invTransformation = entity.transformation.inverse;
        entity.prevModelMatrix = entity.modelMatrix;
        entity.modelMatrix = entity.transformation;
        entity.invModelMatrix = entity.invTransformation;
    }
}

/**
 * Constructs a transformation matrix from translation, rotation, and scaling.
 *
 * Params:
 *   t = Translation vector.
 *   r = Rotation quaternion.
 *   s = Scaling vector.
 * Returns:
 *   The resulting transformation matrix.
 */
Matrix4x4f trsMatrix(Vector3f t, Quaternionf r, Vector3f s)
{
    Matrix4x4f res = Matrix4x4f.identity;
    Matrix3x3f rm = r.toMatrix3x3;
    res.a11 = rm.a11 * s.x; res.a12 = rm.a12 * s.x; res.a13 = rm.a13 * s.x;
    res.a21 = rm.a21 * s.y; res.a22 = rm.a22 * s.y; res.a23 = rm.a23 * s.y;
    res.a31 = rm.a31 * s.z; res.a32 = rm.a32 * s.z; res.a33 = rm.a33 * s.z;
    res.a14 = t.x;
    res.a24 = t.y;
    res.a34 = t.z;
    return res;
}
