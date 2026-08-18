# dagon2:physfs

PhysFS-based virtual filesystem extension. Allows to use archives in Dagon's VFS.

## Usage

```d
import dagon.ext.physfs;

class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        
        PhysFS pfs = New!PhysFS();
        pfs.addSearchPath("./data");
        pfs.addSearchPath("data.zip");
        vfs.mount(pfs);
    }
}
```
