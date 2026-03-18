module dagon.resource.cache;

import std.path;
import std.datetime;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.core.stream;
import dlib.container.dict;
import dlib.filesystem.filesystem;
import dlib.filesystem.stdfs;
import dlib.text.str;

import dagon.core.application;
import dagon.core.logger;
import dagon.core.vfs;

enum ResourceType: uint
{
    Shader = 0,
    Texture = 1
}

alias ResourceSaveCallback = bool function(string path, OutputStream output, void* data);
alias ResourceLoadCallback = bool function(string path, InputStream output, void* data);

class ResourceCacheStorage: Owner
{
    ///
    ResourceCache cache;
    
    ///
    string directory;
    
    ///
    string extension;
    
    /// Standard filesystem interface.
    StdFileSystem fs;
    
    this(ResourceCache cache, string directory, string extension)
    {
        super(cache);
        this.cache = cache;
        this.directory = directory;
        this.extension = extension;
        fs = cache.application.vfs.stdfs;
        fs.createDir(directory, true);
    }
    
    bool isFileValid(string name, SysTime compareToTimestamp)
    {
        string dirSeparator;
        version(Windows) dirSeparator = "\\";
        version(Posix) dirSeparator = "/";
        
        String path = String(directory);
        path ~= "/";
        path ~= name;
        path ~= extension;
        
        bool res = false;
        
        FileStat currentStat;
        if (fs.stat(path, currentStat))
        {
            res = currentStat.modificationTimestamp >= compareToTimestamp;
        }
        
        path.free();
        return res;
    }
    
    void saveFile(string name, ubyte[] data)
    {
        string dirSeparator;
        version(Windows) dirSeparator = "\\";
        version(Posix) dirSeparator = "/";
        
        String path = String(directory);
        path ~= "/";
        path ~= name;
        path ~= extension;
        
        logDebug("[Cache]", " Saving ", path, "...");
        OutputStream strm = fs.openForOutput(path, FileSystem.create);
        strm.writeArray(data);
        Delete(strm);
        
        path.free();
    }
    
    void saveFile(string name, ResourceSaveCallback saveCallback, void* userData)
    {
        string dirSeparator;
        version(Windows) dirSeparator = "\\";
        version(Posix) dirSeparator = "/";
        
        String path = String(directory);
        path ~= "/";
        path ~= name;
        path ~= extension;
        
        logDebug("[Cache]", " Saving ", path, "...");
        OutputStream strm = fs.openForOutput(path, FileSystem.create);
        saveCallback(path, strm, userData);
        Delete(strm);
        
        path.free();
    }
    
    ubyte[] loadFile(string name)
    {
        ubyte[] data;
        
        String path = String(directory);
        path ~= "/";
        path ~= name;
        path ~= extension;
        
        FileStat s;
        if (fs.stat(path, s))
        {
            size_t size = cast(size_t)s.sizeInBytes;
            if (size > 0)
            {
                logDebug("[Cache]", " Loading ", path, "...");
                auto istrm = fs.openForInput(path);
                data = New!(ubyte[])(size);
                istrm.fillArray(data);
                Delete(istrm);
            }
        }
        
        path.free();
        
        return data;
    }
    
    ubyte[] loadFile(string name, ResourceLoadCallback loadCallback, void* userData)
    {
        ubyte[] data;
        
        String path = String(directory);
        path ~= "/";
        path ~= name;
        path ~= extension;
        
        FileStat s;
        if (fs.stat(path, s))
        {
            size_t size = cast(size_t)s.sizeInBytes;
            if (size > 0)
            {
                logDebug("[Cache]", " Loading ", path, "...");
                auto istrm = fs.openForInput(path);
                data = New!(ubyte[])(size);
                istrm.fillArray(data);
                Delete(istrm);
                ArrayStream astrm = New!ArrayStream(data, data.length);
                loadCallback(path, astrm, userData);
                Delete(astrm);
            }
        }
        
        path.free();
        
        return data;
    }
}

class ResourceCache: Owner
{
    Application application;
    Dict!(ResourceCacheStorage, uint) cacheStorage;
    
    this(Application application, Owner owner = null)
    {
        super(owner);
        this.application = application;
        cacheStorage = dict!(ResourceCacheStorage, uint)();
    }
    
    ResourceCacheStorage addStorage(uint resourceType, string cachedFileExtension, string directory)
    {
        ResourceCacheStorage rcs = New!ResourceCacheStorage(this, directory, cachedFileExtension);
        cacheStorage[resourceType] = rcs;
        return rcs;
    }
    
    ResourceCacheStorage getStorage(uint resourceType)
    {
        if (resourceType in cacheStorage)
            return cacheStorage[resourceType];
        else
            return null;
    }
    
    void save(uint resourceType, string name, ubyte[] data)
    {
        ResourceCacheStorage rcs = getStorage(resourceType);
        if (rcs is null)
            return;
        rcs.saveFile(name, data);
    }
    
    void save(uint resourceType, string name, ResourceSaveCallback saveCallback, void* userData)
    {
        ResourceCacheStorage rcs = getStorage(resourceType);
        if (rcs is null)
            return;
        rcs.saveFile(name, saveCallback, userData);
    }
    
    ubyte[] load(uint resourceType, string name, string srcPath)
    {
        ubyte[] res;
        
        ResourceCacheStorage rcs = getStorage(resourceType);
        if (rcs is null)
            return res;
        
        FileStat s;
        if (rcs.fs.stat(srcPath, s))
        {
            if (rcs.isFileValid(name, s.modificationTimestamp))
                res = rcs.loadFile(name);
        }
        
        return res;
    }
    
    ubyte[] load(uint resourceType, string name, string srcPath, ResourceLoadCallback loadCallback, void* userData)
    {
        ubyte[] res;
        
        ResourceCacheStorage rcs = getStorage(resourceType);
        if (rcs is null)
            return res;
        
        FileStat s;
        if (rcs.fs.stat(srcPath, s))
        {
            if (rcs.isFileValid(name, s.modificationTimestamp))
                res = rcs.loadFile(name, loadCallback, userData);
        }
        
        return res;
    }
    
    ~this()
    {
        Delete(cacheStorage);
    }
}
