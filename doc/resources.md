# Resources
This guide covers asset loading and management, and the resource caching system in Dagon.

Resources, also known as assets, are the data loaded by the game from external files. These can be 3D models, textures, or any custom data the game depends on. Most assets use some widely-recongnized format, for example, textures are stored in standard image file formats (PNG, JPEG) or in specialized container formats (DDS, KTX). 

Loading assets from disk and decoding them are huge performance bottlenecks, and data formats vary widely. Some formats are very GPU-friendly and can be used directly, with little to no pre-processing, but some are rather quirky to load. Dagon hides almost all complexity of the asset pipeline under the hood, providing great support for many kinds of asset formats. It also allows for efficient transcoding and caching to reduce subsequent loading times.
