# GScript3 Overview

GScript3 is a concurrent dynamically-typed scripting language for D aimed at easy embedding and extending. Dagon 2 includes GScript3 virtual machine as part of the `BaseGame` class. It only executes bytecode; the engine currently doesn't provide GScript3 compiler. You have to compile your scripts with `gs`, a command line tool to run or build scripts:

`gs -c -i script.gs`

## Why GScript3?
Most popular scripting engines are too cumbersome for embedding in languages other than C/C++. They also come with lots of architectural quirks, heavy runtimes and verbose APIs. GScript3 is designed to be:
- **Simple** - easy to embed into any D application with minimal effort, as well as to "compile" into standalone executables;
- **Lightweight** - a minimalistic VM with no hidden GC costs;
- **Concurrent** - built-in green threads/coroutines;
- **Extensible** - enables host applications to expose their functions and define specialized runtime objects;
- **Familiar** - concise, JavaScript-like syntax.
