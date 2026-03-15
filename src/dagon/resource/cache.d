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
        
        logInfo("[Cache]", " Saving ", path, "...");
        OutputStream strm = fs.openForOutput(path, FileSystem.create);
        strm.writeArray(data);
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
                logInfo("[Cache]", " Loading ", path, "...");
                auto istrm = fs.openForInput(path);
                data = New!(ubyte[])(size);
                istrm.fillArray(data);
                Delete(istrm);
            }
        }
        
        path.free();
        
        return data;
    }
}

class ResourceCache: Owner
{
    Application application;
    Dict!(ResourceCacheStorage, string) cacheStorage;
    
    this(Application application, Owner owner = null)
    {
        super(owner);
        this.application = application;
        cacheStorage = dict!(ResourceCacheStorage, string)();
    }
    
    ResourceCacheStorage addStorage(string srcFileExtension, string cachedFileExtension, string directory)
    {
        ResourceCacheStorage rcs = New!ResourceCacheStorage(this, directory, cachedFileExtension);
        cacheStorage[srcFileExtension] = rcs;
        return rcs;
    }
    
    ResourceCacheStorage getStorage(string srcFileExtension)
    {
        if (srcFileExtension in cacheStorage)
            return cacheStorage[srcFileExtension];
        else
            return null;
    }
    
    void save(string name, ubyte[] data)
    {
        ResourceCacheStorage rcs = getStorage(name.extension);
        if (rcs is null)
            return;
        rcs.saveFile(name, data);
    }
    
    ubyte[] load(string name, string srcPath)
    {
        ubyte[] res;
        
        ResourceCacheStorage rcs = getStorage(name.extension);
        if (rcs is null)
            return res;
        
        FileStat s;
        if (rcs.fs.stat(srcPath, s))
        {
            if (rcs.isFileValid(name, s.modificationTimestamp))
                res = rcs.loadFile(name);
        }
        else
        {
            res = rcs.loadFile(name);
        }
        
        return res;
    }
    
    ~this()
    {
        Delete(cacheStorage);
    }
}
