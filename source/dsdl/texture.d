/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.texture;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.blend;
import dsdl.rect;
import dsdl.frect;
import dsdl.pixels;
import dsdl.renderer;
import dsdl.surface;

import core.memory : GC;
import std.conv : to;
import std.format : format;

/++
 + D enum that wraps `SDL_TextureAccess` in specifying texture access mode
 +/
enum TextureAccess {
    /++
     + Wraps `SDL_TEXTUREACCESS_*` enumeration constants
     +/
    static_ = SDL_TEXTUREACCESS_STATIC,
    streaming = SDL_TEXTUREACCESS_STREAMING, /// ditto
    target = SDL_TEXTUREACCESS_TARGET /// ditto
}

static if (sdlSupport >= SDLSupport.v2_0_12) {
    /++
     + D enum that wraps `SDL_ScaleMode` in specifying mode of texture scaling
     +/
    enum ScaleMode {
        /++
         + Wraps `SDL_ScaleMode*` enumeration constants
         +/
        nearest = SDL_ScaleModeNearest,
        linear = SDL_ScaleModeLinear, /// ditto
        best = SDL_ScaleModeBest /// ditto
    }
}

/++
 + D class that wraps `SDL_Texture` storing textures in the VRAM
 +
 + `dsdl.Texture` stores a 2D image out of pixels with a `width` and `height`, where each pixel stored in the
 + GPU RAM (VRAM) according to its defined `dsdl.PixelFormat`. A `dsdl.Texture` is associated with its
 + `dsdl.Renderer`, and can only be operated with/by it.
 +
 + Example:
 + ---
 + auto renderer = new dsdl.Renderer(...);
 + auto surface = new dsdl.Surface(...);
 +
 + auto texture = new dsdl.Texture(renderer, surface);
 + ---
 +/
final class Texture {
    private PixelFormat pixelFormatProxy = null;
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_Texture* sdlTexture; /// Internal `SDL_Texture` pointer

    /++
     + Constructs a `dsdl.Texture` from a vanilla `SDL_Texture*` from bindbc-sdl
     +
     + Params:
     +   sdlTexture = the `SDL_Texture` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_Texture*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_Texture* sdlTexture, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlTexture !is null);
    }
    do {
        this.sdlTexture = sdlTexture;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Creates a blank `dsdl.Texture` in the VRAM, which wraps `SDL_CreateTexture`
     +
     + Params:
     +   renderer = `dsdl.Renderer` the texture belongs to
     +   pixelFormat = `dsdl.PixelFormat` that the texture pixel data is stored as
     +   access = `dsdl.TextureAccess` enumeration which indicates its access rule
     +   size = the size of the texture (width and height)
     + Throws: `dsdl.SDLException` if creation failed
     +/
    this(Renderer renderer, PixelFormat pixelFormat, TextureAccess access, uint[2] size) @trusted
    in {
        assert(renderer !is null);
        assert(pixelFormat !is null);
    }
    do {
        this.sdlTexture = SDL_CreateTexture(renderer.sdlRenderer, pixelFormat.sdlPixelFormatEnum,
                access, size[0].to!int, size[1].to!int);
        if (this.sdlTexture is null) {
            throw new SDLException;
        }
    }

    /++
     + Creates a `dsdl.Texture` in the VRAM from a `dsdl.Surface`, which wraps `SDL_CreateTextureFromSurface`
     +
     + Params:
     +   renderer = `dsdl.Renderer` the texture belongs to
     +   surface = `dsdl.Surface` for its pixel data to be copied over to the texture
     + Throws: `dsdl.SDLException` if creation failed
     +/
    this(Renderer renderer, Surface surface) @trusted
    in {
        assert(renderer !is null);
        assert(surface !is null);
    }
    do {
        this.sdlTexture = SDL_CreateTextureFromSurface(renderer.sdlRenderer, surface.sdlSurface);
        if (this.sdlTexture is null) {
            throw new SDLException;
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_DestroyTexture(this.sdlTexture);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlTexture !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Texture rhs) const @trusted {
        return this.sdlTexture is rhs.sdlTexture;
    }

    /++
     + Gets the hash of the `dsdl.Texture`
     +
     + Returns: unique hash for the instance being the pointer of the internal `SDL_Texture` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.sdlTexture;
    }

    /++
     + Formats the `dsdl.Texture` into its construction representation: `"dsdl.Texture(<sdlTexture>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.Texture(0x%x)".format(this.sdlTexture);
    }

    /++
     + Wraps `SDL_QueryTexture` which gets the `dsdl.PixelFormat` of the `dsdl.Texture`
     +
     + Returns: `const` proxy to the `dsdl.PixelFormat` of the `dsdl.Texture`
     + Throws: `dsdl.SDLException` if failed to query the information
     +/
    const(PixelFormat) pixelFormat() const @property @trusted {
        uint sdlPixelFormatEnum = void;
        if (SDL_QueryTexture(cast(SDL_Texture*) this.sdlTexture, &sdlPixelFormatEnum, null, null, null) != 0) {
            throw new SDLException;
        }

        // If the actual pixel format happens to change, rewire the proxy.
        if (this.pixelFormatProxy.sdlPixelFormatEnum != sdlPixelFormatEnum) {
            (cast(Texture) this).pixelFormatProxy = new PixelFormat(sdlPixelFormatEnum);
        }

        return this.pixelFormatProxy;
    }

    /++
     + Wraps `SDL_QueryTexture` which gets the `dsdl.TextureAccess` of the `dsdl.Texture`
     +
     + Returns: `dsdl.TextureAccess` of the `dsdl.Texture`
     + Throws: `dsdl.SDLException` if failed to query the information
     +/
    TextureAccess access() const @property @trusted {
        TextureAccess texAccess = void;
        if (SDL_QueryTexture(cast(SDL_Texture*) this.sdlTexture, null, cast(int*) texAccess, null, null) != 0) {
            throw new SDLException;
        }

        return texAccess;
    }

    /++
     + Wraps `SDL_QueryTexture` which gets the width of the `dsdl.Texture` in pixels
     +
     + Returns: width of the `dsdl.Texture` in pixels
     + Throws: `dsdl.SDLException` if failed to query the information
     +/
    uint width() const @property @trusted {
        uint w = void;
        if (SDL_QueryTexture(cast(SDL_Texture*) this.sdlTexture, null, null, cast(int*)&w, null) != 0) {
            throw new SDLException;
        }

        return w;
    }

    /++
     + Wraps `SDL_QueryTexture` which gets the height of the `dsdl.Texture` in pixels
     +
     + Returns: height of the `dsdl.Texture` in pixels
     + Throws: `dsdl.SDLException` if failed to query the information
     +/
    uint height() const @property @trusted {
        uint h = void;
        if (SDL_QueryTexture(cast(SDL_Texture*) this.sdlTexture, null, null, null, cast(int*)&h) != 0) {
            throw new SDLException;
        }

        return h;
    }

    /++
     + Wraps `SDL_QueryTexture` which gets the size of the `dsdl.Texture` in pixels
     +
     + Returns: array of width and height of the `dsdl.Texture` in pixels
     + Throws: `dsdl.SDLException` if failed to query the information
     +/
    uint[2] size() const @property @trusted {
        uint[2] wh = void;
        if (SDL_QueryTexture(cast(SDL_Texture*) this.sdlTexture, null, null, cast(int*)&wh[0], cast(int*)&wh[1]) != 0) {
            throw new SDLException;
        }

        return wh;
    }

    /++
     + Gets the color and alpha multipliers of the `dsdl.Texture` that wraps `SDL_GetTextureColorMod` and
     + `SDL_GetTextureAlphaMod`
     +
     + Returns: color and alpha multipliers of the `dsdl.Texture`
     +/
    Color mod() const @property @trusted {
        Color multipliers = void;
        SDL_GetTextureColorMod(cast(SDL_Texture*) this.sdlTexture, &multipliers.sdlColor.r,
                &multipliers.sdlColor.g, &multipliers.sdlColor.b);
        SDL_GetTextureAlphaMod(cast(SDL_Texture*) this.sdlTexture, &multipliers.sdlColor.a);
        return multipliers;
    }

    /++
     + Sets the color and alpha multipliers of the `dsdl.Texture` that wraps `SDL_SetTextureColorMod` and
     + `SDL_SetTextureAlphaMod`
     +
     + Params:
     +   newMod = `dsdl.Color` with `.r`, `.g`, `.b` as the color multipliers, and `.a` as the alpha multiplier
     +/
    void mod(Color newMod) @property @trusted {
        SDL_SetTextureColorMod(this.sdlTexture, newMod.r, newMod.g, newMod.b);
        SDL_SetTextureAlphaMod(this.sdlTexture, newMod.a);
    }

    /++
     + Wraps `SDL_GetTextureColorMod` which gets the color multipliers of the `dsdl.Texture`
     +
     + Returns: color multipliers of the `dsdl.Texture`
     +/
    ubyte[3] colorMod() const @property @trusted {
        ubyte[3] rgbMod = void;
        SDL_GetTextureColorMod(cast(SDL_Texture*) this.sdlTexture, &rgbMod[0], &rgbMod[1], &rgbMod[2]);
        return rgbMod;
    }

    /++
     + Wraps `SDL_SetTextureColorMod` which sets the color multipliers of the `dsdl.Texture`
     +
     + Params:
     +   newColorMod = an array of `ubyte`s representing red, green, and blue multipliers (each 0-255)
     +/
    void colorMod(ubyte[3] newColorMod) @property @trusted {
        SDL_SetTextureColorMod(this.sdlTexture, newColorMod[0], newColorMod[1], newColorMod[2]);
    }

    /++
     + Wraps `SDL_GetTextureAlphaMod` which gets the alpha multiplier of the `dsdl.Texture`
     +
     + Returns: alpha multiplier of the `dsdl.Texture`
     +/
    ubyte alphaMod() const @property @trusted {
        ubyte aMod = void;
        SDL_GetTextureAlphaMod(cast(SDL_Texture*) this.sdlTexture, &aMod);
        return aMod;
    }

    /++
     + Wraps `SDL_SetTextureAlphaMod` which sets the alpha multiplier of the `dsdl.Texture`
     +
     + Params:
     +   newAlphaMod = alpha multiplier (0-255)
     +/
    void alphaMod(ubyte newAlphaMod) @property @trusted {
        SDL_SetTextureAlphaMod(this.sdlTexture, newAlphaMod);
    }

    /++
     + Wraps `SDL_GetTextureBlendMode` which gets the `dsdl.Texture`'s `dsdl.BlendMode` defining drawing
     +
     + Returns: `dsdl.BlendMode` of the `dsdl.Texture`
     + Throws: `dsdl.SDLException` if `dsdl.BlendMode` unable to get
     +/
    BlendMode blendMode() const @property @trusted {
        BlendMode mode = void;
        if (SDL_GetTextureBlendMode(cast(SDL_Texture*) this.sdlTexture, &mode.sdlBlendMode) != 0) {
            throw new SDLException;
        }

        return mode;
    }

    /++
     + Wraps `SDL_SetTextureBlendMode` which sets the `dsdl.Texture`'s `dsdl.BlendMode` defining drawing
     +
     + Params:
     +   newMode = `dsdl.BlendMode` to set
     + Throws: `dsdl.SDLException` if `dsdl.BlendMode` unable to set
     +/
    void blendMode(BlendMode newMode) @property @trusted {
        if (SDL_SetTextureBlendMode(this.sdlTexture, newMode.sdlBlendMode) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_UpdateTexture` which updates the entire `dsdl.Texture`'s pixel data
     +
     + Params:
     +   pixels = array of pixels for the entire `dsdl.Texture`'s pixels to be replaced with
     +   pitch = skips in bytes per line/row of the `pixels`
     + Throws: `dsdl.SDLException` if failed to update the texture pixel data
     +/
    void update(const void[] pixels, size_t pitch) @trusted
    in {
        assert(pitch * 8 >= this.width * this.pixelFormat.bitsPerPixel);
        assert(pixels.length == pitch * this.height);
    }
    do {
        if (SDL_UpdateTexture(this.sdlTexture, null, pixels.ptr, pitch.to!int) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_UpdateTexture` which updates the `dsdl.Texture`'s pixel data at a certain `dsdl.Rect` boundary
     +
     + Params:
     +   rect = `dsdl.Rect` boundary marking the part of the texture whose pixels are to be updated
     +   pixels = array of pixels for the `dsdl.Texture`'s `rect` pixels to be replaced with
     +   pitch = skips in bytes per line/row of the `pixels`
     + Throws: `dsdl.SDLException` if failed to update the texture pixel data
     +/
    void update(Rect rect, void[] pixels, size_t pitch) @trusted
    in {
        assert(pitch * 8 >= rect.width * this.pixelFormat.bitsPerPixel);
        assert(pixels.length == pitch * rect.height);
    }
    do {
        if (SDL_UpdateTexture(this.sdlTexture, &rect.sdlRect, pixels.ptr, pitch.to!int) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GL_BindTexture` which binds the texture in OpenGL
     +
     + Returns: texture width and height in OpenGL
     + Throws: `dsdl.SDLException` if failed to bind
     +/
    float[2] bindGL() @trusted {
        float[2] size = void;
        if (SDL_GL_BindTexture(this.sdlTexture, &size[0], &size[1]) != 0) {
            throw new SDLException;
        }

        return size;
    }

    /++
     + Wraps `SDL_GL_UnbindTexture` which unbinds the texture in OpenGL
     +
     + Throws: `dsdl.SDLException` if failed to unbind
     +/
    void unbindGL() @trusted {
        if (SDL_GL_UnbindTexture(this.sdlTexture) != 0) {
            throw new SDLException;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_12) {
        /++
         + Wraps `SDL_GetTextureScaleMode` (from SDL 2.0.12) which gets the texture's scaling mode
         +
         + Returns: `dsdl.ScaleMode` of the texture
         +/
        ScaleMode scaleMode() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 12));
        }
        do {
            SDL_ScaleMode sdlScaleMode = void;
            if (SDL_GetTextureScaleMode(cast(SDL_Texture*) this.sdlTexture, &sdlScaleMode) != 0) {
                throw new SDLException;
            }

            return cast(ScaleMode) sdlScaleMode;
        }

        /++
         + Wraps `SDL_SetTextureScaleMode` (from SDL 2.0.12) which sets the texture's scaling mode
         +
         + Params:
         +   newMode = new `dsdl.ScaleMode` set
         +/
        void scaleMode(ScaleMode newMode) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 12));
        }
        do {
            if (SDL_SetTextureScaleMode(this.sdlTexture, cast(SDL_ScaleMode) newMode) != 0) {
                throw new SDLException;
            }
        }
    }
}
