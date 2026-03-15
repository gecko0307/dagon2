module dagon.resource.assetmanager;

import dlib.core.ownership;

import dagon.core.application;

class AssetManager: Owner
{
    Application application;
    
    this(Application application, Owner owner)
    {
        super(owner);
    }
    
    // TODO
}
