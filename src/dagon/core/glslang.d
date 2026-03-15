module dagon.core.glslang;

import std.conv;
import std.string;

import bindbc.loader;
import loader = bindbc.loader.sharedlib;
public import bindbc.glslang;

import dagon.core.logger;

GLSLangSupport loadGLSLang(string path = "")
{
    GLSLangSupport glslangSupport;
    if (path.length)
        glslangSupport = bindbc.glslang.loadGLSLang(toStringz(path));
    else
        glslangSupport = bindbc.glslang.loadGLSLang();
    
    if (loader.errors.length)
    {
        foreach(info; loader.errors)
        {
            logError(to!string(info.error), ": ", to!string(info.message));
        }
    }
    
    return glslangSupport;
}
