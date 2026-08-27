# Camera Controller and Drivers

Dagon 2 provides a new flexible camera control system based on camera states, camera drivers, and a camera controller. The system separates the logic responsible for calculating a camera's position and orientation from the logic that applies the resulting state to the camera entity. This makes it possible to keep multiple independent camera states and smoothly transition between them, which allows for complex in-game transitions and cutscene animations.

## CameraState

A `CameraState` structure represents the transformation state of a camera:

```d
struct CameraState
{
    Vector3f position;
    Quaternionf rotation;
    float fov;
}
```

## CameraDriver

A `CameraDriver` is an interface for an object that calculates a camera state for the current frame:

```d
interface CameraDriver
{
    void update(Time t, Camera camera, CameraState* outState);
}
```

A driver does not modify the camera directly. It calculates the state that the camera should have and writes it to `outState`.

## CameraController

`CameraController` connects a `Camera` with a `CameraDriver`. It maintains the currently active driver and, when necessary, a target driver used for animated transitions. The controller is responsible for combining and applying camera states, while drivers are responsible for producing those states. As a result, camera control can range from a simple static position to a complex hierarchy of procedural animation, keyframes, easing functions, and gameplay-driven transitions without coupling those systems to the camera entity itself.

A controller can be initialized with a driver:

```d
auto cameraController = New!CameraController(eventManager, camera, firstPersonDriver);
```

The driver then provides the camera state on every update. The controller converts the resulting state into the camera's transformation.

## Transitions Between Drivers

A camera controller can smoothly transition from one driver to another using `transitionTo()`:

```d
cameraController.transitionTo(thirdPersonDriver, 1.0f);
```

The first argument specifies the target driver, while the second specifies the transition duration in seconds. During the transition, both drivers are evaluated and their resulting states are interpolated.

## Easing Functions

Transitions can optionally use an easing function:

```d
cameraController.transitionTo(thirdPersonDriver, 1.0f, Easing.EaseInOutQuad);
```

The available easing modes are:

```d
enum Easing
{
    Linear,
    EaseInQuad,
    EaseOutQuad,
    EaseInOutQuad,
    EaseInBack,
    EaseOutBack,
    EaseInOutBack,
    EaseOutBounce,
    EaseOutElastic
}
```

## Interrupting a Transition

A transition can be interrupted by starting another transition before the previous one has finished.

For example:

```d
cameraController.transitionTo(driverB, 2.0f);
```

followed shortly afterwards by:

```d
cameraController.transitionTo(driverC, 2.0f);
```

The second transition starts from the camera's current state, rather than from the original state of the first transition. `CameraController` stores this intermediate state internally, which prevents visible jumps when a transition is interrupted.
