# Physics

Dagon integrates the Jolt Physics engine for realistic collision detection and dynamics simulation. [Jolt Physics](https://github.com/jrouwe/JoltPhysics) is a robust and performant Open Source real-time physics engine written by Jorrit Rouwe of Guerrilla Games. Battle-tested in AAA production, Jolt is gaining popularity and is used by major free game engines such as Godot, NeoAxis, GDevelop, Gaijin Entertainment's Dagor, and many others.

Jolt integration in Dagon 2 provides:
- **Rigid body dynamics**
- **Constraints** (connections between bodies)
- **Character controller**

## Usage

### World

The engine is controlled via the `JoltPhysicsWorld` object. Before accessing the API, `joltInit` should be called to load the library.

```d
class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        
        if (!joltInit())
            exit();
        
        MyWorld world = New!MyWorld(this);
        world.activate();
    }
    
    ~this()
    {
        joltShutdown();
    }
}

class MyWorld: Scene
{
    MyGame game;
    JoltPhysicsWorld physicsWorld;

    this(MyGame game)
    {
        super(game);
        this.game = game;
        
        physicsWorld = New!JoltPhysicsWorld(eventManager, this);
    }
}
```

### Shapes

A shape is a geometric data that is attached to a rigid body and used for collision detection. All shapes are specializations of an abstract base class. Jolt supports the following shapes:

- `JoltSphereShape`
- `JoltBoxShape`
- `JoltPlaneShape`
- `JoltCapsuleShape`
- `JoltTaperedCapsuleShape`
- `JoltCylinderShape`
- `JoltTaperedCylinderShape`
- `JoltConeShape`
- `JoltMeshShape`
- `JoltConvexHullShape`
- `JoltCompoundShape`
- `JoltMutableCompoundShape`
- `JoltHeightmapShape`
- `JoltRotatedTranslatedShape`
- `JoltScaledShape`

Shape creation example:

```d
JoltBoxShape boxShape = New!JoltBoxShape(Vector3f(1.0f, 1.0f, 1.0f), physicsWorld);
```

`JoltBoxShape` accepts half-extents of the box, analogous to Dagon's built-in `ShapeBox`.

### Rigid Bodies

A rigid body is a main building block in a physical simulation. It represents a 6-DOF object that reacts to collisions and external forces which make it move and rotate. Bodies can be static and dynamic.

Bodies are attached to entities via the controller mechanism. Body controllers for entities are created using `JoltPhysicsWorld.addStaticBody` and `JoltPhysicsWorld.addDynamicBody`:

```d
Entity eBox = scene.addEntity();
const float boxMass = 10.0f;
JoltRigidBody boxBody = physicsWorld.addDynamicBody(eBox, boxShape, boxMass);
```

### Constraints

Constraints are special objects that restrict bodies' degrees of freedom in a specific way. Think of them as virtual analogues of real joints which are used to build complex mechanical structures from simple parts. Jolt supports the following constraints:

- `JoltFixedConstraint`
- `JoltPointConstraint`
- `JoltDistanceConstraint`
- `JoltHingeConstraint`
- `JoltSliderConstraint`
- `JoltConeConstraint`
- `JoltSixDOFConstraint`

### Character Controller

TODO

### Raycasting

TODO
