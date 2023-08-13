/++
 + Authors: Avaxar <avaxar@nekkl.org>
 + Copyright: Copyright © 2023, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl2.display;
@safe:

import bindbc.sdl;
import dsdl2.sdl;
import dsdl2.pixels;
import dsdl2.rect;

import std.array : uninitializedArray;
import std.conv : to;
import std.format : format;
import std.string : toStringz;
import std.typecons : Tuple, tuple;

/++
 + D struct that wraps `SDL_DisplayMode` containing display mode information
 +/
struct DisplayMode {
    PixelFormat pixelFormat; /// Pixel format used
    uint[2] size; /// Size in pixels
    uint refreshRate; /// Refresh rate per second
    void* driverData; /// Internal driver data

    this() @disable;

    /++
     + Contructs a `dsdl2.DisplayMode` from a vanilla `SDL_DisplayMode` from bindbc-sdl
     +
     + Params:
     +     sdlDisplayMode = the `SDL_DisplayMode` struct
     +/
    this(SDL_DisplayMode sdlDisplayMode) {
        this.pixelFormat = new PixelFormat(sdlDisplayMode.format);
        this.size = [sdlDisplayMode.w.to!uint, sdlDisplayMode.h.to!uint];
        this.refreshRate = sdlDisplayMode.refresh_rate.to!uint;
        this.driverData = sdlDisplayMode.driverdata;
    }

    /++
     + Constructs a `dsdl2.DisplayMode` by feeding it its attributes
     +
     + Params:
     +   pixelFormat = pixel format
     +   size        = size in pixels
     +   refreshRate = refresh rate per second
     +   driverData  = internal driver data
     +/
    this(const PixelFormat pixelFormat, uint[2] size, uint refreshRate, void* driverData = null)
    in {
        assert(pixelFormat !is null);
        assert(!pixelFormat.isIndexed);
    }
    do {
        this.pixelFormat = new PixelFormat(pixelFormat.sdlPixelFormatEnum);
        this.size = size;
        this.refreshRate = refreshRate;
        this.driverData = driverData;
    }

    invariant {
        assert(pixelFormat !is null);
    }

    /++
     + Formats the `dsdl2.DisplayMode` into its construction representation:
     + `"dsdl2.DisplayMode(<pixelFormat>, <size>, <refreshRate>, <driverData>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl2.DisplayMode(%s, [%d, %d], %d, %p)".format(this.pixelFormat.to!string, this.width,
            this.height, this.refreshRate, this.driverData);
    }

    /++
     + Gets the internal `SDL_DisplayMode` representation
     +
     + Returns: `SDL_DisplayMode` with all of the attributes
     +/
    inout(SDL_DisplayMode) sdlDisplayMode() inout @property {
        return inout SDL_DisplayMode(this.pixelFormat.sdlPixelFormatEnum, this.width.to!int, this.height.to!int,
            this.refreshRate.to!int, this.driverData);
    }

    /++
     + Proxy to the width of the `dsdl2.DisplayMode`
     +
     + Returns: width of the `dsdl2.DisplayMode`
     +/
    ref inout(uint) width() return inout @property {
        return this.size[0];
    }

    /++
     + Proxy to the height of the `dsdl2.DisplayMode`
     +
     + Returns: height of the `dsdl2.DisplayMode`
     +/
    ref inout(uint) height() return inout @property {
        return this.size[1];
    }
}

static if (sdlSupport >= SDLSupport.v2_0_9) {
    /++
     + D enum that wraps `SDL_DisplayOrientation` defining orientation of displays
     +/
    enum DisplayOrientation {
        /++
         + Wraps `SDL_ORIENTATION_*` enumeration constants
         +/
        unknown = SDL_ORIENTATION_UNKNOWN,
        landscape = SDL_ORIENTATION_LANDSCAPE, /// ditto
        flippedLandscape = SDL_ORIENTATION_LANDSCAPE_FLIPPED, /// ditto
        portrait = SDL_ORIENTATION_PORTRAIT, /// ditto
        flippedPortrait = SDL_ORIENTATION_PORTRAIT_FLIPPED /// ditto
    }
}

/++
 + D class that acts as a proxy for a display from a display index
 +/
class Display {
    const uint sdlDisplayIndex; /// Display index from SDL

    this() @disable;

    private this(uint sdlDisplayIndex) {
        this.sdlDisplayIndex = sdlDisplayIndex;
    }

    /++
     + Formats the `dsdl2.Display` showing its internal information: `"dsdl2.PixelFormat(<sdlDisplayIndex>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl2.Display(%d)".format(this.sdlDisplayIndex);
    }

    /++
     + Wraps `SDL_GetDisplayName` which gets the display's name
     +
     + Returns: `string` of the display's name
     + Throws: `dsdl2.SDLException` if failed to get the display name
     +/
    string name() const @property @trusted {
        if (const(char)* name = SDL_GetDisplayName(this.sdlDisplayIndex)) {
            return name.to!string.idup;
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GetDisplayBounds` which gets the display's bounding rectangle
     +
     + Returns: `dsdl2.Rect` of the display's bounding rectangle
     + Throws: `dsdl2.SDLException` if failed to get the display bounds
     +/
    Rect bounds() const @property @trusted {
        Rect rect = void;
        if (SDL_GetDisplayBounds(this.sdlDisplayIndex, &rect.sdlRect) != 0) {
            throw new SDLException;
        }

        return rect;
    }

    /++
     + Gets the width of the display
     + Wraps in pixels
     +
     + Returns: width of the display in pixels
     +/
    uint width() const @property @trusted {
        return this.bounds.width;
    }

    /++
     + Gets the height of the display in pixels
     +
     + Returns: height of the display in pixels
     +/
    uint height() const @property @trusted {
        return this.bounds.height;
    }

    /++
     + Wraps `SDL_GetNumDisplayModes` and `SDL_GetDisplayMode` which get return a list of the available
     + display modes of the display
     +
     + Returns: array of the `dsdl2.DisplayMode`s
     + Throws: `dsdl2.SDLException` if failed to get the display modes
     +/
    DisplayMode[] displayModes() const @property @trusted {
        int numModes = SDL_GetNumDisplayModes(this.sdlDisplayIndex);
        if (numModes <= 0) {
            throw new SDLException;
        }

        SDL_DisplayMode[] sdlModes = new SDL_DisplayMode[](numModes);
        foreach (i; 0 .. numModes) {
            if (SDL_GetDisplayMode(this.sdlDisplayIndex, i, &sdlModes[i]) != 0) {
                throw new SDLException;
            }
        }

        DisplayMode[] modes = uninitializedArray!(DisplayMode[])(numModes);
        foreach (i, SDL_DisplayMode sdlMode; sdlModes) {
            modes[i] = DisplayMode(sdlMode);
        }

        return modes;
    }

    /++
     + Wraps `SDL_GetDesktopDisplayMode` which gets the desktop display mode of the display
     +
     + Returns: the desktop `dsdl2.DisplayMode`
     + Throws: `dsdl2.SDLException` if failed to get the desktop display mode
     +/
    DisplayMode desktopDisplayMode() const @property @trusted {
        SDL_DisplayMode sdlMode = void;
        if (SDL_GetDesktopDisplayMode(this.sdlDisplayIndex, &sdlMode) != 0) {
            throw new SDLException;
        }

        return DisplayMode(sdlMode);
    }

    /++
     + Wraps `SDL_GetCurrentDisplayMode` which gets the current display mode for the display
     +
     + Returns: the current `dsdl2.DisplayMode`
     + Throws: `dsdl2.SDLException` if failed to get the current display mode
     +/
    DisplayMode currentDisplayMode() const @property @trusted {
        SDL_DisplayMode sdlMode = void;
        if (SDL_GetCurrentDisplayMode(this.sdlDisplayIndex, &sdlMode) != 0) {
            throw new SDLException;
        }

        return DisplayMode(sdlMode);
    }

    /++
     + Wraps `SDL_GetClosestDisplayMode` which gets the closest display mode of the display to the desired mode
     +
     + Params:
     +   desiredMode = the desired `dsdl2.DisplayMode`
     + Returns: the closest available `dsdl2.DisplayMode` of the display
     + Throws: `dsdl2.SDLException` if failed to get the closest display mode
     +/
    DisplayMode getClosestDisplayMode(DisplayMode desiredMode) const @trusted {
        SDL_DisplayMode sdlDesiredMode = desiredMode.sdlDisplayMode;
        SDL_DisplayMode sdlClosestMode = void;

        if (SDL_GetClosestDisplayMode(this.sdlDisplayIndex.to!int, &sdlDesiredMode, &sdlClosestMode) is null) {
            throw new SDLException;
        }

        return DisplayMode(sdlClosestMode);
    }

    static if (sdlSupport >= SDLSupport.v2_0_4) {
        private alias DisplayDPI = Tuple!(float, "ddpi", float, "hdpi", float, "vdpi");

        /++
         + Wraps `SDL_GetDisplayDPI` (from SDL 2.0.4) which gets the display's DPI information
         +
         + Returns: named tuple of `ddpi`, `hdpi`, and `vdpi`
         + Throws: `dsdl2.SDLException` if failed to get the display's DPI information
         +/
        DisplayDPI displayDPI() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 4));
        }
        do {
            DisplayDPI dpi = void;
            if (SDL_GetDisplayDPI(this.sdlDisplayIndex, &dpi.ddpi, &dpi.hdpi, &dpi.vdpi) != 0) {
                throw new SDLException;
            }

            return dpi;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_9) {
        /++
         + Wraps `SDL_GetDisplayOrientation` (from SDL 2.0.9) which gets the display's orientation
         +
         + Returns: `dsdl2.DisplayOrientation` of the display
         +/
        DisplayOrientation orientation() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 9));
        }
        do {
            return cast(DisplayOrientation) SDL_GetDisplayOrientation(this.sdlDisplayIndex);
        }
    }
}

/++
 + Gets `dsdl2.Display` proxy instances of the available displays in the system
 +
 + Returns: array of available proxy `dsdl2.Display`s
 + Throws: `dsdl2.SDLException` if failed to get the available displays
 +/
Display[] getDisplays() @trusted {
    int numDisplays = SDL_GetNumVideoDisplays();
    if (numDisplays <= 0) {
        throw new SDLException;
    }

    static Display[] displays;
    if (displays !is null) {
        displays.length = numDisplays;
        if (numDisplays > displays.length) {
            foreach (i; displays.length .. numDisplays) {
                displays[i] = new Display(i.to!uint);
            }
        }

        return displays;
    }
    displays = new Display[](numDisplays);

    foreach (i; 0 .. numDisplays) {
        displays[i] = new Display(i);
    }

    return displays;
}
