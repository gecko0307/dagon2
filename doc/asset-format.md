# Dagon 2 Asset Format (DAF)

DAF is a binary serialization format for meshes and associated data, introduced in Dagon 2.0. The format's main goals are:
- Storing data in a form suitable for direct uploading to video memory with zero overhead. Unlike glTF, in DAF vertex buffers have a fixed format consistent with the engine pipeline, requiring no conversion.
- Maximum deserialization efficiency. glTF requires JSON parsing and dynamic construction of fairly complex objects in memory (lists, dictionaries), while loading DAF is simply reinterpretation of byte buffer slices into arrays of POD structures. DAF saves memory and reduces the risk of memory leaks because it doesn't require much allocations.
- Partial deserialization. The decoder can read only the data it needs from DAF without decoding the rest.
- All-in-one format. A DAF file can store both a single model and a scene. All format structures support user properties, allowing editor metadata to be stored in DAF. In fact, DAF can be used as a simple NoSQL database for various purposes.
- Data semantics support. All objects have a list of classes, allowing the engine to group them for game logic purposes. All textures are tagged as baseColor, normal, height, roughness-metallic, and emission, so the engine can select the optimal BCn compression format.
- Storing physics and collision detection data.

DAF is an extensible format in which any additional data structures and even dynamic properties can be declared without breaking backward compatibility.

## Header

At the beginning of the file there is 4-byte magic string that should be `DAF\0`. Then goes the header:

```
struct DAFHeader
{
    uint formatVersion; // Must be 100 (version 1.0.0)
    uint flags; // Bit flags (reserved)
    uint fileSize; // Total file size, including the header
    uint chunkTableOffset; // Offset of the chunk table relative to the beginning of the file
    uint chunkCount; // Number of chunks (DAFChunk structures)
    uint stringTableOffset; // Offset of the string table relative to the beginning of the file
    uint stringTableSize; // Size of the string table
    uint buffersOffset; // Offset of the buffer section relative to the beginning of the file
    uint buffersSize; // Size of the buffer section
}
```

## Chunk Table

Data in DAF is stored as arrays of structures (each structure must be aligned to the multiple of 4 bytes). Each such array is called a chunk. The element structures of a chunk encode asset objects. The core format defines several standard chunks: Entities, Meshes, Materials, etc. All chunks are optional. Objects in chunks can reference other objects by indices.

The chunk table is the global scene index, an array of DAFChunk structures. Each DAFChunk points to the location of a chunk in the file.

```
enum DAFChunkType
{
    Entities = 0,
    Meshes = 1,
    Materials = 2,
    Skeletons = 3,
    Poses = 4,
    PoseTables = 5
}

struct DAFChunk
{
    uint type; // Chunk type
    uint offset; // Offset of the first element in the chunk relative to the beginning of the file
    uint count; // Number of elements in the chunk
    uint stride; // Size of each element in the chunk
}
```

## Strings

Text data in DAF is stored as a string table—a list of zero-terminated UTF-8 strings separated by a null character:

```
[\0string1\0string2\0string3\0...]
```

Null-terminated strings are introduced for direct compatibility with C libraries. The string array size must be aligned to the multiple of 4 bytes.

In chunk structures, string references are stored as a slice of this array:

```
struct DAFString
{
    uint stringOffset; // offset relative to the start of the string table
    uint stringSize; // string length in bytes (not number of characters!)
}
```

An empty string is encoded as `DAFString(0, 0)`.

## Buffers

Binary data, including that uploaded to the GPU, is stored as buffers in a buffer file section. Each buffer must be aligned to the multiple of 4 bytes.

## Entities

A standard chunk that stores a list of scene objects (Entity).

```
struct DAFEntity
{
    DAFString name; // name
    uint classList; // offset to the start of the class buffer (relative to DAFHeader.buffersOffset)
    uint numClasses; // number of classes. If 0, then classList must also be 0 and is ignored.
    uint flags; // bit flags
    int parent; // index of the parent Entity, or -1 if no parent
    float[3] position; // local position
    float[4] rotation; // local rotation
    float[3] scale; // local scale
    int mesh; // mesh index in the mesh chunk, or -1 if there is no mesh
    int poseTable; // pose table index in the pose table chunk, or -1 if there is no pose table
    uint userDataBuffer; // offset to the start of the user property buffer (relative to DAFHeader.buffersOffset)
    uint userDataSize; // size of the user property buffer, or 0 if the Entity has no properties (in this case, userDataBuffer should also be 0)
}
```

## Meshes

Standard chunk storing a list of meshes.

```
struct DAFMesh
{
    DAFString name; // name
    uint classList; // offset to the start of the class buffer (relative to DAFHeader.buffersOffset)
    uint numClasses; // number of classes. If 0, then classList must also be 0 and is ignored.
    uint flags; // bit flags
    uint vertexBuffer; // offset to the start of the vertex buffer (relative to DAFHeader.buffersOffset)
    uint normalBuffer; // offset to the start of the normal buffer (relative to DAFHeader.buffersOffset)
    uint texcoordBuffer; // offset to the start of the texture coordinate buffer (relative to DAFHeader.buffersOffset)
    uint bonesBuffer; // offset of the bone buffer start (relative to DAFHeader.buffersOffset)
    uint boneWeightsBuffer; // offset of the bone weights buffer start (relative to DAFHeader.buffersOffset)
    uint numVertices; // number of vertices
    uint indicesBuffer; // index buffer
    uint numTrangles; // total number of triangles
    uint faceGroupBuffer; // offset of the facegroup buffer start (relative to DAFHeader.buffersOffset)
    uint numFaceGroups; // number of facegroups
    uint userDataBuffer; // offset of the user property buffer start (relative to DAFHeader.buffersOffset)
    uint userDataSize; // size of the user property buffer, or 0 if the mesh has no properties (in this case, userDataBuffer should also be 0)
}
```

Bit Flags:

- `DAF_MESH_FLAG_ANIMATED = 0x01`. If this bit is set, the mesh is animated (bone and weight buffers must be read). Otherwise, the mesh is static (`bonesBuffer` and `boneWeightsBuffer` are ignored).

The vertex buffer consists of three-component vectors:

```
struct DAFVertex
{
    float x, y, z;
}
```

The normal buffer consists of three-component unit vectors:

```
struct DAFNormal
{
    float x, y, z;
}
```

The texture coordinate buffer consists of two-component vectors:

```
struct DAFTexcoord
{
    float x, y;
}
```

The bone buffer consists of four-component integer vectors (bone indices):

```
struct DAFVertexBones
{
    uint b1, b2, b3, b4;
}
```

The bone weight buffer consists of four-component vectors:

```
struct DAFBoneWeights
{
    float w1, w2, w3, w4;
}
```

A facegroup is a group of triangles sharing a common material (thus, different materials can be assigned to different parts of the mesh). The facegroup buffer is an array of DAFFaceGroup structures:

```
struct DAFFaceGroup
{
    int material; // index of the material in the material chunk, or -1 if there is no material (in this case, the engine uses the default material)
    uint firstTriangle; // offset of the first triangle (relative to DAFMesh.indicesBuffer)
    uint numTriangles; // number of triangles
}
```

## Materials

```
enum BlendMode: uint
{
    Opaque = 0,
    Transparent = 1
}

struct DAFMaterial
{
    DAFString name;
    uint classList; // offset to the start of the class buffer (relative to DAFHeader.buffersOffset)
    uint numClasses; // number of classes. If 0, then classList must also be 0 and is ignored.
    uint flags; // bit flags
    float[4] baseColor;
    float roughness;
    float metallic;
    float[4] emissionColor;
    float emissionEnergy;
    float ior;
    float iorLevel;
    float subsurfaceScattering;
    float opacity;
    float alphaClipThreshold;
    uint shadeless;
    BlendMode blendMode;
    int baseColorTexture;
    int normalTexture;
    int heightTexture;
    int roughnessMetallicTexture;
    int emissionTexture;
    uint userDataBuffer; // offset of the user property buffer start (relative to DAFHeader.buffersOffset)
    uint userDataSize; // size of the user property buffer, or 0 if the mesh has no properties (in this case, userDataBuffer should also be 0)
}
```

## User Data

Buffer storing a key-value pair:

```
enum DPropType: uint
{
    Undefined = 0,
    Number = 1,
    Vector = 2
    String = 3
}

struct DAFUserDataEntry
{
    DPropType type;
    DAFString name;
    DAFString value;
}
```

The value string must store textual data supported by the standard Dagon Properties mechanism, namely:
- Real numbers - for example, 10, 0.5
- Boolean values ​​- true, false
- Strings - for example, "some string" (quotation marks must be present)
- Vectors and matrices - for example, [0.5, 1.0, 1.0] (square brackets must be present, elements are separated by commas). Vectors of 2, 3, and 4 elements are supported. A vector of 9 elements is interpreted as a 3x3 matrix, while a vector of 16 elements is interpreted as a 4x4 matrix.

The meaning of User Data properties is application-dependent.
