# GScript3 Overview

GScript3 is a concurrent dynamically-typed scripting language for D aimed at easy embedding and extending. Dagon 2 includes GScript3 virtual machine as part of the `BaseGame` class. It only executes bytecode; the engine doesn't provide GScript3 compiler. You have to compile your scripts with `gs`, a command line tool to run or build scripts:

`gs -c -i script.gs`

## Why GScript3?
Most popular scripting engines are too cumbersome for embedding in languages other than C/C++. They also come with lots of architectural quirks, heavy runtimes and verbose APIs. GScript3 is designed to be:
- **Simple** - easy to embed into any D application with minimal effort, as well as to "compile" into standalone executables;
- **Lightweight** - a minimalistic VM with no hidden GC costs;
- **Concurrent** - built-in green threads/coroutines;
- **Extensible** - enables host applications to expose their functions and define specialized runtime objects;
- **Familiar** - concise, JavaScript-like syntax.

## Main Changes from GScript2
- `let` istead of `var`
- `const` support
- Vector type support
- Global execution context (instead of mandatory `main` function)
- Direct access to global variables, without `global`. `global` object is still there, for imports and externally defined properties
- JS-like object literals istead of prototype functions; see below
- Prototype inheritance instead of shallow-copy; see below
- New module system; see below
- New variadic arguments system; see below
- Implicit function referencing. Function reference is created without `ref` keyword
- Array length is now returned by the built-in `length` property instead of a global `length` function
- Spawning functions as threads/coroutines; see below
- Math intrinsics
- AST macros; see below.

Architecture improvements:
- Fast VM with a more efficient ISA
- VM-level preemptive multithreading ("green threads"). Threads are first-class citizens integrated into the prototype inheritance model
- Host-defined synchronization primitives
- Arena heap instead of the GC for internal allocations. VM is fully GC-free (compiler is not yet)
- Bytecode can now be serialized into a binary buffer, significantly speeding up the launch of compiled scripts
- Flexible exposing and integration with the D object system. Any D object that inherits from `GsObject` and implements get/set semantics for its properties can be registered in the VM. This gives scripts secure access to the application's internal state
- Dynamic linking of external bytecode libraries.
