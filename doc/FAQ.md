# Frequently Asked Questions

## 1. Is this a full-fledged game production suite like Unity/UE/Godot?
No, not at all. Dagon only provides a framework for building real-time applications. It abstracts a lot of complex tasks such as managing a window and handling user input, loading models and textures, doing transformations, rendering, animation, sound and physics, but currently it doesn't include any content creation tools such as a scene editor.

## 2. Why Dagon doesn't support multiple graphics APIs?
Historically, Dagon was based on OpenGL because it was the most convenient way to use the same codebase across all major desktop platforms (except macOS) without writing a complex intermediate layer that unifies different graphics APIs. After moving to SDL GPU, multi-backend architecture is now theoretically possible and is a long-term planned feature. However, it will require significant efforts to manage properly.

## 3. Why Dagon doesn't support macOS?
See Question 2.

## 4. What's the point of `New`/`Delete`? Why not just stop worrying and start using GC?
We understand that avoiding GC makes code less "D-ish". Indeed, garbage collector is not evil or something; in many cases there's no reason not to use it. But GC is not a silver bullet either. It shines in cases where the program cannot predict what and when it allocates. Games are different: their memory usage is usually deterministic, since runtime allocations are expensive and cause frame drops. That's why games typically preallocate most data in advance. In such conditions, GC brings little benefit—there are more efficient memory management strategies for this. Dagon uses dlib's ownership system and treats heap data as a tree of objects. Every object has a strictly defined lifetime and is automatically released when its owner is released. If used idiomatically, this approach lets you write applications with virtually no risk of memory leaks, while avoiding the performance pitfalls inherent in garbage collection.

## 5. Why not `@nogc`?
Dagon is heavily based on dlib, which is not `@nogc` for historical and backward compatibility reasons (core parts of dlib were written in 2011, long before `@nogc`). This is not a big deal, because Dagon itself is not a library, but an application framework.

## 6. Why is such a huge part of functionality implemented as extensions?
Extensions provide optional features, and most of them depend on additional external libraries. Dynamically linked libraries always pose challenges to manage properly in cross-platform D applications, and to keep Dagon easy to use for beginners, core dependencies are kept to a reasonable minimum. While the core engine is stable, all extensions are considered experimental and not guaranteed to work on all operating systems.

## 7. How to fix game stuttering?
The most likely cause of stuttering is VSync enabled in windowed/borderless mode. VSync (vertical synchronization) is a frame timing mode where the output is synchronized with the monitor's refresh rate to eliminate tearing. Enabling VSync limits the FPS to the monitor's refresh rate (usually 60Hz) and forces the renderer to wait for the next vertical refresh, essentially capping performance to 60, 30, or 20 FPS (refresh rate divisors). If the system cannot maintain 60 FPS, VSync forces a drop to 30 FPS, causing a perceptible, sudden jump in frame pacing.

On Windows, VSync may cause stuttering in windowed mode due to the issues in the frame presentation mechanism, even if the FPS is stable 60. All non-exclusive windows are composited by the DWM. The DWM performs a VSync for the entire desktop, regardless of the application's individual VSync settings. When a game enables its own VSync in windowed mode, it essentially creates a "double vsync" problem: buffer swapping doesn't align perfectly with the DWM's composition timing, causing a visible stutter. If you use NVIDIA graphics card, there's a workaround in driver settings: set "Vulkan/OpenGL present method" to "Prefer layered on DXGI Swapchain" in the Control Panel.

As a general rule, VSync should only be enabled if you are experiencing screen tearing, and it usually only makes sense in exclusive fullscreen mode.

## 8. How to fix input lag?
Input lag is a perceptible delay between pressing a button or moving a mouse and seeing that action happen on your screen. It can be caused by various reasons, VSync being a major one. A good trade-off between tearing and input lag is to use Mailbox mode (`vsync: 2` in settings.conf). In Dagon 2 it is on by default.

Also input lag is sometimes caused by electromagnetic interference during signal transmission from wireless peripherals. If a wireless mouse is lagging in the game, try to move other devices such as a mobile phone away from your desktop and the mouse receiver.

## 9. Why matrix-vector multiplication is inverted?
The reason behind this is an optimization under common associativity rules. Generally speaking, there is actually only multiplication of two matrices, and matrix-vector multiplication is its special case. This operation is ambiguous, since you can see the vector as Nx1 matrix (column vector) or 1xN matrix (row vector). The order of operands (and hense results) will be different in each case.

Matrix multiplication involves multiplying each row vector of one matrix by each column vector of another matrix. So in first case (Nx1) we will do `matrix * columnVector`, in second case (1xN): `rowVector * matrix`.

In dlib (and Dagon), there is only one multiplication - `matrix * columnVector`, being the most common of the two. But it is written in 'inverse' (left-associative) order: `columnVector * matrix` (defined as `opBinaryRight` overload for `Matrix` type). This goes against conventional math notation, but computationally is a lot cheaper for long chained expressions.

For example, with normal syntax, expression `m2 * m1 * v` will be evaluated as one full matrix multiplication (64 float multiplications) and then one matrix-vector multiplication (9 float multiplications in affine case). With left-associative syntax, the equivalent `v * m1 * m2` will cause only two matrix-vector multiplications (total 18 float multiplications in affine case). Without parentheses there is no way to force compiler choose optimal execution path, so left-associative syntax was preferred as more concise and requiring less caution from the programmer.

Also left-associative syntax is arguably easier to read.

## 10. Why my entity doesn't move?

Entities are static by default. To automatically recalculate model matrix on transformation updates, entity must be dynamic:

```d
eSuzanne.dynamic = true;
```
