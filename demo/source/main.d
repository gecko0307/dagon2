/*
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the software
to the public domain. We make this dedication for the benefit of the
public at large and to the detriment of our heirs and successors.
We intend this dedication to be an overt act of relinquishment in 
perpetuity of all present and future rights to this software under
copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
*/

module main;

import dagon;

class TestWorld: World
{
    MyGame game;
    OBJAsset aOBJSuzanne;
    
    T loadAsset(T)(string filename)
    {
        T asset = New!T(gpu, this);
        auto istrm = game.vfs.openForInput(filename);
        asset.load(filename, istrm, game.vfs);
        Delete(istrm);
        return asset;
    }

    this(MyGame game)
    {
        super(game);
        this.game = game;
        
        aOBJSuzanne = loadAsset!OBJAsset("data/suzanne.obj");
        
        scene = New!Scene(this);
        scene.sun.pitch(-45.0f);
        scene.sun.energy = 10.0f;
        
        auto camera = scene.addCamera();
        auto freeview = New!FreeviewController(eventManager, camera);
        freeview.setZoom(5);
        freeview.setRotation(30.0f, -45.0f, 0.0f);
        freeview.translationStiffness = 0.25f;
        freeview.rotationStiffness = 0.25f;
        freeview.zoomStiffness = 0.25f;
        scene.activeCamera = camera;
        
        auto matSuzanne = New!Material(this);
        matSuzanne.baseColor = Color4f(1.0f, 0.2f, 0.2f, 1.0f);

        auto eSuzanne = scene.addEntity();
        eSuzanne.drawable = aOBJSuzanne.mesh;
        eSuzanne.material = matSuzanne;
        eSuzanne.position = Vector3f(0.0f, 1.0f, 0.0f);
        eSuzanne.scale = Vector3f(2.0f, 2.0f, 2.0f);
        
        //auto ePlane = addEntity();
        //ePlane.drawable = New!ShapePlane(10, 10, 1, assetManager);
        
        //game.renderer.ssaoPass.ssaoShader.radius = 0.5f;
        //game.renderer.ssaoDenoisePass.active = false;
    }
    
    override void onUpdate(Time t) { }
    override void onPostUpdate(Time t) { }
    override void onKeyDown(int key) { }
    override void onKeyUp(int key) { }
    override void onTextInput(dchar code) { }
    override void onMouseButtonDown(int button) { }
    override void onMouseButtonUp(int button) { }
    override void onMouseWheel(float x, float y) { }
    //override void onControllerButtonDown(uint deviceIndex, int btn) { }
    //override void onControllerButtonUp(uint deviceIndex, int btn) { }
    //override void onControllerAxisMotion(uint deviceIndex, int axis, float value) { }
    override void onResize(int width, int height) { }
    override void onFocusLoss() { }
    override void onFocusGain() { }
    override void onDropFile(string filename) { }
    override void onKeyboardLayoutChange() { }
    override void onUserEvent(int code, void* payload) { }
    override void onQuit() { }
}

class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        TestWorld testWorld = New!TestWorld(this);
        testWorld.activate();
    }
}

void main(string[] args)
{
    MyGame game = New!MyGame(1280, 720, false, "Dagon Demo", args);
    game.run();
    Delete(game);
    debug logDebug("Leaked memory: ", allocatedMemory, " byte(s)");
}
