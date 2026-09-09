# Math

Dagon comes with a powerful and highly efficient vector math library, `dlib.math`. It implements all algebraic objects necessary for real-time graphics:
- 2D, 3D and 4D vectors
- 2x2, 3x3 and 4x4 transformation matrices
- Quaternions.

## Vectors

Mathematical apparatus of 3D graphics relies on the notion of a vector space. In linear algebra, a vector is a generalization of a number for an arbitrary number of dimensions.

The simplest space is 1D space, the usual set of real numbers (scalars).

2D and 3D Euclidean vector spaces are also rather intuitive; they represent real-world spaces that we deal with in everyday life. In Dagon, they are represented by `Vector2f` and `Vector3f` types. The number denotes dimensionality, and the letter hints numeric precision: `f` stands for `float`. If you prefer, you can use the short form that omits precision symbol: `vec2`, `vec3`. There are also double-precision and integer vectors, but they are rarely used.

Vectors are value types: they are copied by value unless the programmer explicitly uses pointers or reference semantic.

Vectors can be accessed like arrays, using the indexing syntax:

```d
Vector3f v = Vector3f(1, 2, 3);
float x = v[0];
v[1] = 4;
```

Alternatively, vectors can be accessed like structures, by symbolic fields. dlib supports `xyzw`, `rgba`, and `stpq` notations, which address the same four elements. `xyzw` is used for points and directions; `rgba` is used for colors; `stpq` is used for texture coordinates.

```d
Vector3f v = Vector3f(1, 2, 3);
float x = v.x;
v.y = 4;
```

Vector swizzling is supported. Swizzling is a syntactic sugar that allows to construct a new vector from the arbitrary elements of another vector using symbolic access:

```d
Vector3f v1 = Vector3f(1, 2, 3);
Vector3f v2 = v1.xxy; // will be (1, 1, 2)
```

Vectors support per-component arithmetic: they can be added, subtracted, multiplied and divided.

```d
Vector3f v3 = v1 + v2;
```

You can also use scalars in vector arithmetic, in which cases scalars are implicitly widened to the corresponding dimensionality:

```d
Vector3f v3 = v1 + 10;
```

## Matrices

TODO

## Quaternions

TODO
