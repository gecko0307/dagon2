module dagon.graphics.shapes;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.graphics.state;
import dagon.graphics.drawable;
import dagon.graphics.mesh;

/**
 * A simple quad (rectangle) drawable in 2D.
 *
 * Vertices and texture coordinates are defined in normalized [0,1] space.
 * Useful for screen-space rendering, post-processing, and UI.
 */
class ShapeNormQuad: Owner, Drawable
{
    GPU gpu;
    SDL_GPUBuffer* vertexBuffer;
    SDL_GPUBuffer* texcoordBuffer;
    SDL_GPUBuffer* indexBuffer;
    Vector2f[4] vertices;
    Vector2f[4] texcoords;
    ushort[3][2] indices;

    /**
     * Constructs a `ShapeQuad`.
     *
     * Params:
     *   owner = Owner object.
     */
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;

        vertices[0] = Vector2f(0, 1);
        vertices[1] = Vector2f(0, 0);
        vertices[2] = Vector2f(1, 0);
        vertices[3] = Vector2f(1, 1);

        texcoords[0] = Vector2f(0, 1);
        texcoords[1] = Vector2f(0, 0);
        texcoords[2] = Vector2f(1, 0);
        texcoords[3] = Vector2f(1, 1);

        indices[0][0] = 0;
        indices[0][1] = 1;
        indices[0][2] = 2;

        indices[1][0] = 0;
        indices[1][1] = 2;
        indices[1][2] = 3;

        vertexBuffer = gpu.createBuffer(SDL_GPU_BUFFERUSAGE_VERTEX, Vector3f.sizeof * vertices.length);
        texcoordBuffer = gpu.createBuffer(SDL_GPU_BUFFERUSAGE_VERTEX, Vector2f.sizeof * vertices.length);
        indexBuffer = gpu.createBuffer(SDL_GPU_BUFFERUSAGE_INDEX, ushort.sizeof * 3 * indices.length);

        gpu.uploadBuffer(vertices.ptr, Vector3f.sizeof * vertices.length, vertexBuffer);
        gpu.uploadBuffer(texcoords.ptr, Vector2f.sizeof * vertices.length, texcoordBuffer);
        gpu.uploadBuffer(indices.ptr, ushort.sizeof * 3 * indices.length, indexBuffer);
    }
    
    ~this()
    {
        if (vertexBuffer)
        {
            gpu.releaseBuffer(vertexBuffer);
        }
        if (texcoordBuffer)
        {
            gpu.releaseBuffer(texcoordBuffer);
        }
        if (indexBuffer)
        {
            gpu.releaseBuffer(indexBuffer);
        }
    }
    
    void render(GraphicsState* state)
    {
        auto pass = state.pass;
        pass.bindVertexBuffer(VertexAttribute.Position, vertexBuffer);
        pass.bindVertexBuffer(VertexAttribute.Texcoord, texcoordBuffer);
        pass.bindIndexBuffer(indexBuffer, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        pass.drawIndexedPrimitives(cast(uint)indices.length * 3, 1, 0, 0, 0);
    }
}

class ShapeCube: Mesh
{
    Vector3f halfExtents;
    
    this(Vector3f halfExtents, GPU gpu, Owner owner)
    {
        super(gpu, owner);
        this.halfExtents = halfExtents;
        
        vertices = New!(Vector3f[])(24);
        normals = New!(Vector3f[])(24);
        texcoords = New!(Vector2f[])(24);
        indices = New!(uint[3][])(12);

        Vector3f pmax = +halfExtents;
        Vector3f pmin = -halfExtents;

        texcoords[0] = Vector2f(1, 0); normals[0] = Vector3f(0,0,1); vertices[0] = Vector3f(pmax.x, pmax.y, pmax.z);
        texcoords[1] = Vector2f(0, 0); normals[1] = Vector3f(0,0,1); vertices[1] = Vector3f(pmin.x, pmax.y, pmax.z);
        texcoords[2] = Vector2f(0, 1); normals[2] = Vector3f(0,0,1); vertices[2] = Vector3f(pmin.x, pmin.y, pmax.z);
        texcoords[3] = Vector2f(1, 1); normals[3] = Vector3f(0,0,1); vertices[3] = Vector3f(pmax.x, pmin.y, pmax.z);
        indices[0][0] = 0; indices[0][1] = 1; indices[0][2] = 2;
        indices[1][0] = 2; indices[1][1] = 3; indices[1][2] = 0;

        texcoords[4] = Vector2f(0, 0); normals[4] = Vector3f(1,0,0); vertices[4] = Vector3f(pmax.x, pmax.y, pmax.z);
        texcoords[5] = Vector2f(0, 1); normals[5] = Vector3f(1,0,0); vertices[5] = Vector3f(pmax.x, pmin.y, pmax.z);
        texcoords[6] = Vector2f(1, 1); normals[6] = Vector3f(1,0,0); vertices[6] = Vector3f(pmax.x, pmin.y, pmin.z);
        texcoords[7] = Vector2f(1, 0); normals[7] = Vector3f(1,0,0); vertices[7] = Vector3f(pmax.x, pmax.y, pmin.z);
        indices[2][0] = 4; indices[2][1] = 5; indices[2][2] = 6;
        indices[3][0] = 6; indices[3][1] = 7; indices[3][2] = 4;

        texcoords[8] = Vector2f(1, 1); normals[8] = Vector3f(0,1,0); vertices[8] = Vector3f(pmax.x, pmax.y, pmax.z);
        texcoords[9] = Vector2f(1, 0); normals[9] = Vector3f(0,1,0); vertices[9] = Vector3f(pmax.x, pmax.y, pmin.z);
        texcoords[10] = Vector2f(0, 0); normals[10] = Vector3f(0,1,0); vertices[10] = Vector3f(pmin.x, pmax.y, pmin.z);
        texcoords[11] = Vector2f(0, 1); normals[11] = Vector3f(0,1,0); vertices[11] = Vector3f(pmin.x, pmax.y, pmax.z);
        indices[4][0] = 8; indices[4][1] = 9; indices[4][2] = 10;
        indices[5][0] = 10; indices[5][1] = 11; indices[5][2] = 8;

        texcoords[12] = Vector2f(1, 0); normals[12] = Vector3f(-1,0,0); vertices[12] = Vector3f(pmin.x, pmax.y, pmax.z);
        texcoords[13] = Vector2f(0, 0); normals[13] = Vector3f(-1,0,0); vertices[13] = Vector3f(pmin.x, pmax.y, pmin.z);
        texcoords[14] = Vector2f(0, 1); normals[14] = Vector3f(-1,0,0); vertices[14] = Vector3f(pmin.x, pmin.y, pmin.z);
        texcoords[15] = Vector2f(1, 1); normals[15] = Vector3f(-1,0,0); vertices[15] = Vector3f(pmin.x, pmin.y, pmax.z);
        indices[6][0] = 12; indices[6][1] = 13; indices[6][2] = 14;
        indices[7][0] = 14; indices[7][1] = 15; indices[7][2] = 12;

        texcoords[16] = Vector2f(0, 1); normals[16] = Vector3f(0,-1,0); vertices[16] = Vector3f(pmin.x, pmin.y, pmin.z);
        texcoords[17] = Vector2f(1, 1); normals[17] = Vector3f(0,-1,0); vertices[17] = Vector3f(pmax.x, pmin.y, pmin.z);
        texcoords[18] = Vector2f(1, 0); normals[18] = Vector3f(0,-1,0); vertices[18] = Vector3f(pmax.x, pmin.y, pmax.z);
        texcoords[19] = Vector2f(0, 0); normals[19] = Vector3f(0,-1,0); vertices[19] = Vector3f(pmin.x, pmin.y, pmax.z);
        indices[8][0] = 16; indices[8][1] = 17; indices[8][2] = 18;
        indices[9][0] = 18; indices[9][1] = 19; indices[9][2] = 16;

        texcoords[20] = Vector2f(0, 1); normals[20] = Vector3f(0,0,-1); vertices[20] = Vector3f(pmax.x, pmin.y, pmin.z);
        texcoords[21] = Vector2f(1, 1); normals[21] = Vector3f(0,0,-1); vertices[21] = Vector3f(pmin.x, pmin.y, pmin.z);
        texcoords[22] = Vector2f(1, 0); normals[22] = Vector3f(0,0,-1); vertices[22] = Vector3f(pmin.x, pmax.y, pmin.z);
        texcoords[23] = Vector2f(0, 0); normals[23] = Vector3f(0,0,-1); vertices[23] = Vector3f(pmax.x, pmax.y, pmin.z);
        indices[10][0] = 20; indices[10][1] = 21; indices[10][2] = 22;
        indices[11][0] = 22; indices[11][1] = 23; indices[11][2] = 20;
        
        dataReady = true;
        
        prepareBuffers();
    }

    ~this()
    {
        if (vertices)
            Delete(vertices);
        if (normals)
            Delete(normals);
        if (texcoords)
            Delete(texcoords);
        if (indices)
            Delete(indices);
    }
}
