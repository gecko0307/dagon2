module dagon.render.view;

import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;

import dagon.core.time;
import dagon.graphics.camera;

class View: Owner
{
    ///
    Matrix4x4f projectionMatrix;
    
    ///
    Matrix4x4f invProjectionMatrix;
    
    ///
    Matrix4x4f viewMatrix;
    
    ///
    Matrix4x4f invViewMatrix;
    
    ///
    Matrix4x4f prevViewMatrix;
    
    ///
    uint width;
    
    ///
    uint height;
    
    ///
    float aspectRatio;
    
    /// Field of view in degrees (vertical) for perspective projection.
    float fov = 60.0f;

    /// Near clipping plane distance.
    float zNear = 0.01f;

    /// Far clipping plane distance.
    float zFar = 1000.0f;
    
    ///
    Camera camera;
    
    this(uint width, uint height, Owner owner)
    {
        super(owner);
        viewMatrix = Matrix4x4f.identity;
        invViewMatrix = Matrix4x4f.identity;
        prevViewMatrix = Matrix4x4f.identity;
        resize(width, height);
    }
    
    void resize(uint width, uint height)
    {
        this.width = width;
        this.height = height;
        aspectRatio = cast(float)width / cast(float)height;
        update(Time(0.0, 0.0));
        prevViewMatrix = viewMatrix;
    }
    
    void update(Time t)
    {
        prevViewMatrix = viewMatrix;
        
        if (camera)
        {
            fov = camera.fov;
            zNear = camera.zNear;
            zFar = camera.zFar;
            projectionMatrix = camera.projectionMatrix(aspectRatio);
            viewMatrix = camera.viewMatrix;
            invViewMatrix = camera.invViewMatrix;
        }
        else
        {
            projectionMatrix = perspectiveMatrix(fov, aspectRatio, zNear, zFar);
            invViewMatrix = viewMatrix.inverse;
        }
        
        invProjectionMatrix = projectionMatrix.inverse;
    }
}
