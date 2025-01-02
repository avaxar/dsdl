/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.gl;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.window;

import core.memory : GC;
import std.conv : to;
import std.string : toStringz;

/++
 + Wraps `SDL_GL_LoadLibrary` which loads OpenGL from the given path of the library
 +
 + Params:
 +   path = path to the OpenGL library; `null` to load the default
 + Throws: `dsdl.SDLException` if unable to load the library
 +/
void loadGL(string path = null) @trusted {
    if (SDL_GL_LoadLibrary(path is null ? null : path.toStringz()) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_GL_GetProcAddress` which gets the pointer to a certain OpenGL function
 +
 + Params:
 +   proc = symbol name of the requested OpenGL function
 + Returns: function pointer of the requested OpenGL function, otherwise `null` if not found
 +/
void* getGLProcAddress(string proc) @system {
    return SDL_GL_GetProcAddress(proc.toStringz());
}

/++
 + Wraps `SDL_GL_UnloadLibrary` which unloads the loaded OpenGL library from `dsdl.loadGL`
 +/
void unloadGL() @trusted {
    SDL_GL_UnloadLibrary();
}

/++
 + Wraps `SDL_GL_ExtensionSupported` which checks whether an OpenGL extension is supported
 +
 + Params:
 +   extension = name of the OpenGL extension
 + Returns: `true` if the extension is supported, otherwise `false`
 +/
bool isGLExtensionSupported(string extension) @trusted {
    return SDL_GL_ExtensionSupported(extension.toStringz()) == SDL_TRUE;
}

/++
 + D enum that wraps `SDL_GLattr` defining OpenGL initialization attributes
 +/
enum GLAttribute {
    /++
     + Wraps `SDL_GL_*` enumeration constants for `SDL_GLattr`
     +/
    redSize = SDL_GL_RED_SIZE,
    greenSize = SDL_GL_GREEN_SIZE, /// ditto
    blueSize = SDL_GL_BLUE_SIZE, /// ditto
    alphaSize = SDL_GL_ALPHA_SIZE, /// ditto
    bufferSize = SDL_GL_BUFFER_SIZE, /// ditto
    doubleBuffer = SDL_GL_DOUBLEBUFFER, /// ditto
    depthSize = SDL_GL_DEPTH_SIZE, /// ditto
    stencilSize = SDL_GL_STENCIL_SIZE, /// ditto
    accumRedSize = SDL_GL_ACCUM_RED_SIZE, /// ditto
    accumGreenSize = SDL_GL_ACCUM_GREEN_SIZE, /// ditto
    accumBlueSize = SDL_GL_ACCUM_BLUE_SIZE, /// ditto
    accumAlphaSize = SDL_GL_ACCUM_ALPHA_SIZE, /// ditto
    stereo = SDL_GL_STEREO, /// ditto
    multiSampleBuffers = SDL_GL_MULTISAMPLEBUFFERS, /// ditto
    multiSampleSamples = SDL_GL_MULTISAMPLESAMPLES, /// ditto
    acceleratedVisual = SDL_GL_ACCELERATED_VISUAL, /// ditto
    contextMajorVersion = SDL_GL_CONTEXT_MAJOR_VERSION, /// ditto
    contextMinorVersion = SDL_GL_CONTEXT_MINOR_VERSION, /// ditto
    // contextFlags = SDL_GL_CONTEXT_FLAGS, /// ditto
    contextProfileMask = SDL_GL_CONTEXT_PROFILE_MASK, /// ditto
    shareWithCurrentContext = SDL_GL_SHARE_WITH_CURRENT_CONTEXT /// ditto
    // framebufferSRGBCapable = SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, /// ditto
    // contextReleaseBehavior = SDL_GL_CONTEXT_RELEASE_BEHAVIOR /// ditto
}

/++
 + D enum that wraps `SDL_GLprofile` defining OpenGL profiles
 +/
enum GLProfile : uint {
    /++
     + Wraps `SDL_GL_CONTEXT_*` enumeration constants
     +/
    core = SDL_GL_CONTEXT_PROFILE_CORE,
    compatibility = SDL_GL_CONTEXT_PROFILE_COMPATIBILITY, /// ditto
    es = SDL_GL_CONTEXT_PROFILE_ES /// ditto
}

/++
 + Wraps `SDL_GL_SetAttribute` which sets OpenGL attributes for initialization
 +
 + Params:
 +   attribute = the `dsdl.GLAttribute` to set
 +   value = requested value for the attribute to be set as
 + Throws: `dsdl.SDLException` if unable to set the attribute
 +/
void setGLAttribute(GLAttribute attribute, uint value) @trusted {
    if (SDL_GL_SetAttribute(attribute, value.to!int) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_GL_GetAttribute` which gets previously set OpenGL attributes for initialization
 +
 + Params:
 +   attribute = the `dsdl.GLAttribute` whose value to get
 + Returns: value of the requested attribute
 + Throws: `dsdl.SDLException` if unable to get the attribute
 +/
uint getGLAttribute(GLAttribute attribute) @trusted {
    uint value = void;
    if (SDL_GL_GetAttribute(attribute, cast(int*)&value) != 0) {
        throw new SDLException;
    }

    return value;
}

static if (sdlSupport >= SDLSupport.v2_0_2) {
    /++
     + Wraps `SDL_GL_ResetAttributes` (from SDL 2.0.2) which resets all OpenGL attributes previously set to default
     +/
    void resetGLAttributes() @trusted
    in {
        assert(getVersion() >= Version(2, 0, 2));
    }
    do {
        SDL_GL_ResetAttributes();
    }
}

/++
 + Wraps `SDL_GL_GetCurrentWindow` which gets the current target window for OpenGL
 +
 + This function is marked as `@system` due to the potential of referencing invalid memory.
 +
 + Returns: `dsdl.Window` proxy to the target window for OpenGL
 + Throws: `dsdl.SDLException` if unable to get the window
 +/
Window getCurrentGLWindow() @system {
    if (SDL_Window* sdlWindow = SDL_GL_GetCurrentWindow()) {
        return new Window(sdlWindow, false);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_GL_GetCurrentContext` which gets the current OpenGL context used by SDL
 +
 + This function is marked as `@system` due to the potential of referencing invalid memory.
 +
 + Returns: `dsdl.GLContext` proxy to the OpenGL context used by SDL
 + Throws: `dsdl.SDLException` if unable to get the context
 +/
GLContext getCurrentGLContext() @system {
    if (SDL_GLContext sdlGLContext = SDL_GL_GetCurrentContext()) {
        return new GLContext(sdlGLContext, false);
    }
    else {
        throw new SDLException;
    }
}

/++
 + D enum that defines swap intervals for OpenGL
 +/
enum GLSwapInterval {
    immediate = 0, /// No vertical retrace synchronization
    syncWithVerticalRetrace = 1, /// The buffer swap is synchronized with the vertical retrace
    adaptiveVSync = -1 /// Late swaps happen immediately instead of waiting for the next retrace
}

/++
 + Wraps `SDL_GL_SetSwapInterval` which gets the swap interval method for OpenGL
 +
 + Params:
 +   interval = the `dsdl.GLSwapInterval` method to use
 + Throws: `dsdl.SDLException` if unable to set the swap interval
 +/
void setGLSwapInterval(GLSwapInterval interval) @trusted {
    if (SDL_GL_SetSwapInterval(cast(int) interval) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_GL_GetSwapInterval` which gets the currently-used swap interval method for OpenGL
 +
 + Returns: the currently-used `dsdl.GLSwapInterval` method
 + Throws: `dsdl.SDLException` if unable to get the swap interval
 +/
GLSwapInterval getGLSwapInterval() @trusted {
    // NOTE: This function is able to return an error. But the docs aren't clear when.
    return cast(GLSwapInterval) SDL_GL_GetSwapInterval();
}

/++
 + D class that wraps `SDL_GLContext` enclosing an OpenGL context used for SDL
 +/
class GLContext {
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_GLContext sdlGLContext = null; /// Internal `SDL_GLContext`

    /++
     + Constructs a `dsdl.GLContext` from a vanilla `SDL_GLContext` from bindbc-sdl
     +
     + Params:
     +   sdlGLContext = the `SDL_GLContext` to manage
     +   isOwner = whether the instance owns the given `SDL_GLContext` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_GLContext sdlGLContext, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlGLContext !is null);
    }
    do {
        this.sdlGLContext = sdlGLContext;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Creates an OpenGL context to use by SDL, which wraps `SDL_GL_CreateContext`
     +
     + Params:
     +   window = the default OpenGL `dsdl.Window` to be set current as the rendering target for the context
     + Throws: `dsdl.SDLException` if OpenGL context creation failed
     +/
    this(Window window) @trusted
    in {
        assert(window !is null);
    }
    do {
        this.sdlGLContext = SDL_GL_CreateContext(window.sdlWindow);
        if (this.sdlGLContext is null) {
            throw new SDLException;
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_GL_DeleteContext(this.sdlGLContext);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlGLContext !is null);
    }

    /++
     + Wraps `SDL_GL_MakeCurrent` which makes a window current as the rendering target for OpenGL rendering
     +
     + Params:
     +   window = new OpenGL `dsdl.Window` to be set current as the rendering target for the context
     + Throws: `dsdl.SDLException` if failed to set the new window current
     +/
    void makeCurrent(Window window) @trusted
    in {
        assert(window !is null);
    }
    do {
        if (SDL_GL_MakeCurrent(window.sdlWindow, this.sdlGLContext) != 0) {
            throw new SDLException;
        }
    }
}
