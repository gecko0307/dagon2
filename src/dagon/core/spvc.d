module dagon.core.spvc;

import std.conv;
import std.string;

import bindbc.loader;
import loader = bindbc.loader.sharedlib;
public import bindbc.spirvcross;

import dagon.core.logger;

SPVCSupport loadSPVC(string path = "")
{
    SPVCSupport spvcSupport;
    if (path.length)
        spvcSupport = bindbc.spirvcross.loadSPVC(toStringz(path));
    else
        spvcSupport = bindbc.spirvcross.loadSPVC();
    
    if (loader.errors.length)
    {
        foreach(info; loader.errors)
        {
            logError(to!string(info.error), ": ", to!string(info.message));
        }
    }
    
    return spvcSupport;
}
