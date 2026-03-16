module dagon.resource.texture;

import std.string;
import std.path;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.core.stream;
import dlib.filesystem.filesystem;

import dagon.core.gpu;
import dagon.core.dxt;
import dagon.core.logger;
import dagon.graphics.texturebuffer;
import dagon.graphics.texture;
import dagon.resource.image;
import dagon.resource.dds;

class TextureAsset: Owner
{
    ///
    GPU gpu;
    
    ///
    TextureBuffer buffer;
    
    ///
    Texture texture;
    
    ///
    ImageConversionOptions conversion;
    
    ///
    bool generateMipmaps = true;
    
    ///
    bool repeatUV = true;
    
    ///
    bool compress = false;
    
    ///
    bool persistent = false;
    
    ///
    bool loaded = false;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        conversion.width = 0;
        conversion.height = 0;
        conversion.hint = 0;
    }
    
    ~this()
    {
        releaseBuffer();
    }
    
    protected void releaseBuffer()
    {
        if (buffer.data.length)
        {
            Delete(buffer.data);
            buffer.data = [];
        }
    }
    
    bool load(string filename, InputStream istrm, ReadOnlyFileSystem fs)
    {
        debug logInfo("Loading ", filename, "...");
        
        string extension = filename.extension.toLower;
        
        if (extension == ".dds")
        {
            loaded = loadDDS(istrm, &buffer);
        }
        else if (isSupportedImageFormat(extension))
        {
            loaded = loadImage(istrm, extension, &buffer, &conversion);
        }
        // TODO: custom loaders
        
        //logInfo("Decoded ", filename);
        
        if (!loaded)
        {
            if (!persistent)
                releaseBuffer();
            return false;
        }
        
        if (compress)
        {
            // TODO: compression
        }
        
        texture = New!Texture(gpu, this);
        TextureCreationOptions options = {
            generateMipmaps: generateMipmaps,
            repeatUV: repeatUV
        };
        loaded = texture.create(&buffer, &options);
        
        //logInfo("Uploaded ", filename);
        
        if (!persistent)
            releaseBuffer();
        
        return loaded;
    }
}
