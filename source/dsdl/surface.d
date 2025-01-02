/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.surface;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.blend;
import dsdl.pixels;
import dsdl.rect;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.typecons : Nullable, nullable;

/++
 + D class that wraps `SDL_Surface` storing a 2D image in the RAM
 +
 + `dsdl.Surface` stores a 2D image out of pixels with a `width` and `height`, where each pixel stored in the
 + RAM according to its defined `dsdl.PixelFormat`.
 +/
final class Surface {
    private PixelFormat pixelFormatProxy = null;
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_Surface* sdlSurface = null; /// Internal `SDL_Surface` pointer

    /++
     + Constructs a `dsdl.Surface` from a vanilla `SDL_Surface*` from bindbc-sdl
     +
     + Params:
     +   sdlSurface = the `SDL_Surface` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_Surface*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_Surface* sdlSurface, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlSurface !is null);
    }
    do {
        this.sdlSurface = sdlSurface;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Constructs a blank RGB(A) `dsdl.Surface` with a set width, height, and `dsdl.PixelFormat` that wraps
     + `SDL_CreateRGBSurface`
     +
     + Params:
     +   size = size (width and height) of the `dsdl.Surface` in pixels
     +   rgbPixelFormat = an RGB(A) `dsdl.PixelFormat`
     + Throws: `dsdl.SDLException` if allocation failed
     +/
    this(uint[2] size, const PixelFormat rgbPixelFormat) @trusted
    in {
        assert(rgbPixelFormat !is null);
        assert(!rgbPixelFormat.indexed);
    }
    do {
        uint[4] masks = rgbPixelFormat.toMasks();

        this.sdlSurface = SDL_CreateRGBSurface(0, size[0].to!int, size[1].to!int,
                rgbPixelFormat.bitsPerPixel, masks[0], masks[1], masks[2], masks[3]);
        if (this.sdlSurface is null) {
            throw new SDLException;
        }
    }

    /++
     + Constructs an RGB(A) `dsdl.Surface` from an array of `pixels`
     +
     + Params:
     +   pixels = array of pixel data (copied internally)
     +   size = size (width and height) of the `dsdl.Surface` in pixels
     +   pitch = skips in bytes per line/row of the `dsdl.Surface`
     +   rgbPixelFormat = an RGB(A) `dsdl.PixelFormat`
     + Throws: `dsdl.SDLException` if allocation failed
     +/
    this(const void[] pixels, uint[2] size, size_t pitch, const PixelFormat rgbPixelFormat) @trusted
    in {
        assert(pixels !is null);
        assert(rgbPixelFormat !is null);
        assert(!rgbPixelFormat.indexed);
        assert(pitch * 8 >= size[0] * rgbPixelFormat.bitsPerPixel);
        assert(pixels.length == pitch * size[1]);
    }
    do {
        this(size, rgbPixelFormat);

        size_t lineBitSize = cast(size_t) size[0] * rgbPixelFormat.bitsPerPixel;
        size_t lineSize = lineBitSize / 8 + (lineBitSize % 8 != 0);

        foreach (line; 0 .. size[1]) {
            ubyte* srcLine = cast(ubyte*) pixels.ptr + line * pitch;
            ubyte* destLine = cast(ubyte*) this.sdlSurface.pixels + line * this.pitch;
            destLine[0 .. lineSize] = srcLine[0 .. lineSize];
        }
    }

    /++
     + Constructs a blank indexed palette-using `dsdl.Surface` with a set width, height, and index bit depth,
     + which wraps `SDL_CreateRGBSurface`
     +
     + Params:
     +   size = size (width and height) of the `dsdl.Surface` in pixels
     +   bitDepth = bit depth of the palette index (1, 4, or 8)
     +   palette = `dsdl.Palette` to use
     + Throws: `dsdl.SDLException` if allocation failed or palette-setting failed
     +/
    this(uint[2] size, ubyte bitDepth, Palette palette) @trusted
    in {
        assert(bitDepth == 1 || bitDepth == 4 || bitDepth == 8);
        assert(palette !is null);
    }
    do {
        this.sdlSurface = SDL_CreateRGBSurface(0, size[0], size[1], bitDepth, 0, 0, 0, 0);
        if (this.sdlSurface is null) {
            throw new SDLException;
        }

        this.palette = palette;
    }

    /++
     + Constructs a blank indexed palette-using `dsdl.Surface` from an array of `pixels`
     +
     + Params:
     +   pixels = array of pixel data (copied internally)
     +   size = size (width and height) of the `dsdl.Surface` in pixels
     +   pitch = skips in bytes per line/row of the `dsdl.Surface`
     +   bitDepth = bit depth of the palette index (1, 4, or 8)
     +   palette = `dsdl.Palette` to use
     + Throws: `dsdl.SDLException` if allocation failed or palette-setting failed
     +/
    this(const void[] pixels, uint[2] size, size_t pitch, ubyte bitDepth, Palette palette) @trusted
    in {
        assert(pixels !is null);
        assert(size[0] > 0 && size[1] > 0);
        assert(pitch * 8 >= size[0] * bitDepth);
        assert(pixels.length == pitch * size[1]);
        assert(palette !is null);
    }
    do {
        this(size, bitDepth, palette);

        size_t lineBitSize = size[0] * bitDepth;
        size_t lineSize = lineBitSize / 8 + (lineBitSize % 8 != 0);

        foreach (line; 0 .. size[1]) {
            ubyte* srcLine = cast(ubyte*) pixels.ptr + line * pitch;
            ubyte* destLine = cast(ubyte*) this.sdlSurface.pixels + line * this.pitch;
            destLine[0 .. lineSize] = srcLine[0 .. lineSize];
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_FreeSurface(this.sdlSurface);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlSurface !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Surface rhs) const @trusted {
        return this.sdlSurface is rhs.sdlSurface;
    }

    /++
     + Gets the hash of the `dsdl.Surface`
     +
     + Returns: unique hash for the instance being the pointer of the internal `SDL_Surface` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.sdlSurface;
    }

    /++
     + Formats the `dsdl.Surface` into its construction representation:
     + `"dsdl.PixelFormat([<bytes>], [<width>, <height>], <pitch>, <pixelFormat>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.Surface(%s, %s, %d, %s)".format(this.buffer, this.size, this.pitch, this.pixelFormat);
    }

    /++
     + Gets the `dsdl.PixelFormat` of the `dsdl.Surface`
     +
     + Returns: `const` proxy to the `dsdl.PixelFormat` of the `dsdl.Surface`
     +/
    const(PixelFormat) pixelFormat() const @property @trusted {
        if (this.pixelFormatProxy is null) {
            (cast(Surface) this).pixelFormatProxy = new PixelFormat(cast(SDL_PixelFormat*) this.sdlSurface.format,
                    false, cast(void*) this);
        }

        // If the internal pixel format pointer happens to change, rewire the proxy.
        if (this.pixelFormatProxy.sdlPixelFormat !is this.sdlSurface.format) {
            (cast(Surface) this).pixelFormatProxy.sdlPixelFormat = cast(SDL_PixelFormat*) this.sdlSurface.format;
        }

        return this.pixelFormatProxy;
    }

    /++
     + Gets the internal pixel buffer of the `dsdl.Surface`
     +
     + This function is marked as `@system` due to the potential of referencing invalid memory.
     +
     + Returns: slice of the buffer
     +/
    inout(void[]) buffer() inout @property @trusted {
        return (cast(inout(void*)) this.sdlSurface.pixels)[0 .. this.pitch * this.height];
    }

    /++
     + Gets the width of the `dsdl.Surface` in pixels
     +
     + Returns: width of the `dsdl.Surface` in pixels
     +/
    uint width() const @property @trusted {
        return this.sdlSurface.w;
    }

    /++
     + Gets the height of the `dsdl.Surface` in pixels
     +
     + Returns: height of the `dsdl.Surface` in pixels
     +/
    uint height() const @property @trusted {
        return this.sdlSurface.h;
    }

    /++
     + Gets the size of the `dsdl.Surface` in pixels
     +
     + Returns: array of width and height of the `dsdl.Surface` in pixels
     +/
    uint[2] size() const @property @trusted {
        return [this.sdlSurface.w, this.sdlSurface.h];
    }

    /++
     + Gets the pitch of the `dsdl.Surface` in bytes (multiple of bytes for each line/row)
     +
     + Returns: pitch of the `dsdl.Surface` in bytes
     +/
    size_t pitch() const @property @trusted {
        return this.sdlSurface.pitch;
    }

    /++
     + Gets the used color palette of the `dsdl.Surface`
     +
     + Returns: `dsdl.Palette` instance of the `dsdl.Surface`
     +/
    inout(Palette) palette() inout @property @trusted
    in {
        assert(this.pixelFormat.indexed);
    }
    do {
        return (cast(inout PixelFormat) this.pixelFormat).palette;
    }

    /++
     + Sets the color palette of the `dsdl.Surface`
     +
     + Params:
     +   newPalette = new `dsdl.Palette` instance to use for the `dsdl.Surface`
     +/
    void palette(Palette newPalette) @property @trusted
    in {
        assert(this.pixelFormat.indexed);
    }
    do {
        if (SDL_SetSurfacePalette(this.sdlSurface, newPalette.sdlPalette) != 0) {
            throw new SDLException;
        }

        (cast(PixelFormat) this.pixelFormat).palette = newPalette;
    }

    /++
     + Gets the pixel value in the `dsdl.Surface` at the given coordinate
     +
     + Params:
     +   xy = X and Y values of the coordinate
     + Returns: the pixel value
     +/
    uint getPixelAt(uint[2] xy) const @trusted
    in {
        assert(xy[0] < this.width);
        assert(xy[1] < this.height);
    }
    do {
        const ubyte* row = cast(ubyte*) this.sdlSurface.pixels + xy[1] * this.pitch;

        if (this.pixelFormat.bitsPerPixel >= 8) {
            const ubyte* pixelPtr = row + xy[0] * this.pixelFormat.bytesPerPixel;
            align(4) ubyte[4] pixel;
            pixel[0 .. this.pixelFormat.bytesPerPixel] = pixelPtr[0 .. this.pixelFormat.bytesPerPixel];

            return *cast(uint*) pixel.ptr;
        }
        else {
            ubyte pixelByte = *(row + (xy[0] * this.pixelFormat.bitsPerPixel) / 8);
            ubyte bitOffset = (xy[0] * this.pixelFormat.bitsPerPixel) % 8;

            switch (this.pixelFormat.sdlPixelFormatEnum) {
            case SDL_PIXELFORMAT_INDEX1LSB:
                return (pixelByte & (0b00000001 << bitOffset)) != 0;

            case SDL_PIXELFORMAT_INDEX1MSB:
                return (pixelByte & (0b10000000 >> bitOffset)) != 0;

            case SDL_PIXELFORMAT_INDEX4LSB:
                return pixelByte & (0b00001111 << (bitOffset * 4)) >> (bitOffset * 4);

            case SDL_PIXELFORMAT_INDEX4MSB:
                return pixelByte & (0b11110000 >> (bitOffset * 4)) >> (4 - bitOffset * 4);

            default:
                assert(false);
            }
        }
    }

    /++
     + Sets the pixel value in the `dsdl.Surface` at the given coordinate
     +
     + Params:
     +   xy = X and Y values of the coordinate
     +   value = pixel value to set at the given coordinate
     +/
    void setPixelAt(uint[2] xy, uint value) @trusted
    in {
        assert(xy[0] < this.width);
        assert(xy[1] < this.height);
        if (this.pixelFormat.bitsPerPixel != 32) { // Overflow protection
            assert(value < 1 << this.pixelFormat.bitsPerPixel);
        }
    }
    do {
        ubyte* row = cast(ubyte*) this.sdlSurface.pixels + xy[1] * this.pitch;

        if (this.pixelFormat.bitsPerPixel >= 8) {
            ubyte* pixelPtr = row + xy[0] * this.pixelFormat.bytesPerPixel;
            pixelPtr[0 .. this.pixelFormat.bytesPerPixel] = //
                (*cast(ubyte[4]*)&value)[0 .. this.pixelFormat.bytesPerPixel];
        }
        else {
            ubyte* pixelPtr = row + (xy[0] * this.pixelFormat.bitsPerPixel) / 8;
            ubyte bitOffset = (xy[0] * this.pixelFormat.bitsPerPixel) % 8;

            switch (this.pixelFormat.sdlPixelFormatEnum) {
            case SDL_PIXELFORMAT_INDEX1LSB:
                *pixelPtr &= !(0b00000001 << bitOffset);
                *pixelPtr |= value << bitOffset;
                break;

            case SDL_PIXELFORMAT_INDEX1MSB:
                *pixelPtr &= !(0b10000000 >> bitOffset);
                *pixelPtr |= value << (7 - bitOffset);
                break;

            case SDL_PIXELFORMAT_INDEX4LSB:
                *pixelPtr &= !(0b00001111 << (bitOffset * 4));
                *pixelPtr |= value << (bitOffset * 4);
                break;

            case SDL_PIXELFORMAT_INDEX4MSB:
                *pixelPtr &= !(0b11110000 >> (bitOffset * 4));
                *pixelPtr |= value << (4 - bitOffset * 4);
                break;

            default:
                assert(false);
            }
        }
    }

    /++
     + Gets the pixel color in the `dsdl.Surface` at the given coordinate
     +
     + Params:
     +   xy = X and Y values of the coordinate
     + Returns: the pixel color
     +/
    Color getAt(uint[2] xy) const
    in {
        assert(xy[0] < this.width);
        assert(xy[1] < this.height);
    }
    do {
        if (this.pixelFormat.hasAlpha) {
            return this.pixelFormat.getRGBA(this.getPixelAt(xy));
        }
        else {
            return this.pixelFormat.getRGB(this.getPixelAt(xy));
        }
    }

    /++
     + Sets the pixel color in the `dsdl.Surface` at the given coordinate
     +
     + Params:
     +   xy = X and Y values of the coordinate
     +   color = pixel color to set at the given coordinate
     +/
    void setAt(uint[2] xy, Color color)
    in {
        assert(xy[0] < this.width);
        assert(xy[1] < this.height);
    }
    do {
        if (this.pixelFormat.hasAlpha) {
            this.setPixelAt(xy, this.pixelFormat.mapRGBA(color));
        }
        else {
            this.setPixelAt(xy, this.pixelFormat.mapRGB(color));
        }
    }

    /++
     + Gets the color and alpha multipliers of the `dsdl.Surface` that wraps `SDL_GetSurfaceColorMod` and
     + `SDL_GetSurfaceAlphaMod`
     +
     + Returns: color and alpha multipliers of the `dsdl.Surface`
     +/
    Color mod() const @property @trusted {
        Color multipliers = void;
        SDL_GetSurfaceColorMod(cast(SDL_Surface*) this.sdlSurface, &multipliers.sdlColor.r,
                &multipliers.sdlColor.g, &multipliers.sdlColor.b);
        SDL_GetSurfaceAlphaMod(cast(SDL_Surface*) this.sdlSurface, &multipliers.sdlColor.a);
        return multipliers;
    }

    /++
     + Sets the color and alpha multipliers of the `dsdl.Surface` that wraps `SDL_SetSurfaceColorMod` and
     + `SDL_SetSurfaceAlphaMod`
     +
     + Params:
     +   newMod = `dsdl.Color` with `.r`, `.g`, `.b` as the color multipliers, and `.a` as the alpha multiplier
     +/
    void mod(Color newMod) @property @trusted {
        SDL_SetSurfaceColorMod(this.sdlSurface, newMod.r, newMod.g, newMod.b);
        SDL_SetSurfaceAlphaMod(this.sdlSurface, newMod.a);
    }

    /++
     + Wraps `SDL_GetSurfaceColorMod` which gets the color multipliers of the `dsdl.Surface`
     +
     + Returns: color multipliers of the `dsdl.Surface`
     +/
    ubyte[3] colorMod() const @property @trusted {
        ubyte[3] rgbMod = void;
        SDL_GetSurfaceColorMod(cast(SDL_Surface*) this.sdlSurface, &rgbMod[0], &rgbMod[1], &rgbMod[2]);
        return rgbMod;
    }

    /++
     + Wraps `SDL_SetSurfaceColorMod` which sets the color multipliers of the `dsdl.Surface`
     +
     + Params:
     +   newColorMod = an array of `ubyte`s representing red, green, and blue multipliers (each 0-255)
     +/
    void colorMod(ubyte[3] newColorMod) @property @trusted {
        SDL_SetSurfaceColorMod(this.sdlSurface, newColorMod[0], newColorMod[1], newColorMod[2]);
    }

    /++
     + Wraps `SDL_GetSurfaceAlphaMod` which gets the alpha multiplier of the `dsdl.Surface`
     +
     + Returns: alpha multiplier of the `dsdl.Surface`
     +/
    ubyte alphaMod() const @property @trusted {
        ubyte aMod = void;
        SDL_GetSurfaceAlphaMod(cast(SDL_Surface*) this.sdlSurface, &aMod);
        return aMod;
    }

    /++
     + Wraps `SDL_SetSurfaceAlphaMod` which sets the alpha multiplier of the `dsdl.Surface`
     +
     + Params:
     +   newAlphaMod = alpha multiplier (0-255)
     +/
    void alphaMod(ubyte newAlphaMod) @property @trusted {
        SDL_SetSurfaceAlphaMod(this.sdlSurface, newAlphaMod);
    }

    /++
     + Wraps `SDL_GetClipRect` which gets the clipping `dsdl.Rect` of the `dsdl.Surface`
     +
     + Returns: clipping `dsdl.Rect` of the `dsdl.Surface`
     +/
    Rect clipRect() const @property @trusted {
        Rect rect = void;
        SDL_GetClipRect(cast(SDL_Surface*) this.sdlSurface, &rect.sdlRect);
        return rect;
    }

    /++
     + Wraps `SDL_SetClipRect` which sets the clipping `dsdl.Rect` of the `dsdl.Surface`
     +
     + Params:
     +   newRect = `dsdl.Rect` to set as the clipping rectangle
     +/
    void clipRect(Rect newRect) @property @trusted {
        SDL_SetClipRect(this.sdlSurface, &newRect.sdlRect);
    }

    /++
     + Acts as `SDL_SetClipRect(surface, NULL)` which removes the clipping `dsdl.Rect` of the
     + `dsdl.Surface`
     +/
    void clipRect(typeof(null) _) @property @trusted {
        SDL_SetClipRect(this.sdlSurface, null);
    }

    /++
     + Wraps `SDL_SetClipRect` which sets or removes the clipping `dsdl.Rect` of the `dsdl.Surface`
     +
     + Params:
     +   newRect = `dsdl.Rect` to set as the clipping rectangle; `null` to remove the clipping rectangle
     +/
    void clipRect(Nullable!Rect newRect) @property @trusted {
        if (newRect.isNull) {
            this.clipRect = null;
        }
        else {
            this.clipRect = newRect.get;
        }
    }

    /++
     + Wraps `SDL_GetColorKey` which gets the color key used by the `dsdl.Surface` for transparency
     +
     + Returns: transparency color key in `dsdl.Color`
     + Throws: `dsdl.SDLException` if color key unable to be fetched
     +/
    Color colorKey() const @property @trusted {
        uint key = void;
        if (SDL_GetColorKey(cast(SDL_Surface*) this.sdlSurface, &key) != 0) {
            throw new SDLException;
        }

        if (this.pixelFormat.hasAlpha) {
            return this.pixelFormat.getRGBA(key);
        }
        else {
            return this.pixelFormat.getRGB(key);
        }
    }

    /++
     + Wraps `SDL_SetColorKey` which sets the color key used for the `dsdl.Surface` making pixels of the same
     + color transparent
     +
     + Params:
     +   newPixelKey = pixel value of the color key that get transparency
     + Throws: `dsdl.SDLException` if color key unable to set
     +/
    void colorKey(uint newPixelKey) @property @trusted {
        if (SDL_SetColorKey(this.sdlSurface, SDL_TRUE, newPixelKey) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_SetColorKey` which sets the color key used for the `dsdl.Surface` making pixels of the same
     + color transparent
     +
     + Params:
     +   newColorKey = `dsdl.Color` specifying pixels that get transparency
     + Throws: `dsdl.SDLException` if color key unable to set
     +/
    void colorKey(Color newColorKey) @property @trusted {
        if (this.pixelFormat.hasAlpha) {
            this.colorKey = this.pixelFormat.mapRGBA(newColorKey);
        }
        else {
            this.colorKey = this.pixelFormat.mapRGB(newColorKey);
        }
    }

    /++
     + Acts as `SDL_SetColorKey(surface, NULL)` which disables color-keying
     +/
    void colorKey(typeof(null) _) @property @trusted {
        if (SDL_SetColorKey(this.sdlSurface, SDL_FALSE, 0) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_SetColorKey` which sets or removes the color key used for the `dsdl.Surface` making pixels
     + of the same color transparent
     +
     + Params:
     +   newColorKey = `dsdl.Color` specifying pixels that get transparency; `null` to remove the color key
     + Throws: `dsdl.SDLException` if color key unable to set or removed
     +/
    void colorKey(Nullable!Color newColorKey) @property @trusted {
        if (newColorKey.isNull) {
            this.colorKey = null;
        }
        else {
            this.colorKey = newColorKey.get;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_9) {
        /++
         + Wraps `SDL_HasColorKey` (from SDL 2.0.9) which checks whether the `dsdl.Surface` has a color key
         + for transparency
         +
         + Returns: `true` if it does, otherwise `false`
         +/
        bool hasColorKey() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 9));
        }
        do {
            return SDL_HasColorKey(cast(SDL_Surface*) this.sdlSurface) == SDL_TRUE;
        }
    }

    /++
     + Wraps `SDL_GetSurfaceBlendMode` which gets the `dsdl.Surface`'s `dsdl.BlendMode` defining blitting
     +
     + Returns: `dsdl.BlendMode` of the `dsdl.Surface`
     + Throws: `dsdl.SDLException` if `dsdl.BlendMode` unable to get
     +/
    BlendMode blendMode() const @property @trusted {
        BlendMode mode = void;
        if (SDL_GetSurfaceBlendMode(cast(SDL_Surface*) this.sdlSurface, &mode.sdlBlendMode) != 0) {
            throw new SDLException;
        }

        return mode;
    }

    /++
     + Wraps `SDL_SetSurfaceBlendMode` which sets the `dsdl.Surface`'s `dsdl.BlendMode` defining blitting
     +
     + Params:
     +   newMode = `dsdl.BlendMode` to set
     + Throws: `dsdl.SDLException` if `dsdl.BlendMode` unable to set
     +/
    void blendMode(BlendMode newMode) @property @trusted {
        if (SDL_SetSurfaceBlendMode(this.sdlSurface, newMode.sdlBlendMode) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_ConvertPixels` which converts the `dsdl.Surface` from its RGB(A) `dsdl.PixelFormat` to another
     + `dsdl.Surface` with a different RGB(A) `dsdl.PixelFormat`
     +
     + Params:
     +   rgbPixelFormat = the RGB(A) `dsdl.PixelFormat` to target the conversion
     + Returns: result `dsdl.Surface` with the `targetPixelFormat`
     + Throws: `dsdl.SDLException` if pixels failed to convert
     +/
    Surface convert(const PixelFormat rgbPixelFormat) const @trusted
    in {
        assert(!this.pixelFormat.indexed);
        assert(rgbPixelFormat !is null);
    }
    do {
        auto target = new Surface([this.width, this.height], rgbPixelFormat);
        if (SDL_ConvertPixels(this.width, this.height, this.pixelFormat.sdlPixelFormatEnum,
                this.sdlSurface.pixels, this.pitch.to!int, target.pixelFormat.sdlPixelFormatEnum,
                target.sdlSurface.pixels, target.pitch.to!int) != 0) {
            throw new SDLException;
        }

        return target;
    }

    /++
     + Acts as `SDL_FillRect(surface, NULL)` which fills the entire `dsdl.Surface` with a pixel value
     +
     + Params:
     +   pixel = pixel value of the color to fill the entire `dsdl.Surface`
     +/
    void fill(uint pixel) @trusted {
        if (SDL_FillRect(this.sdlSurface, null, pixel) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Acts as `SDL_FillRect(surface, NULL)` which fills the entire `dsdl.Surface` with a `dsdl.Color` value
     +
     + Params:
     +   color = `dsdl.Color` of the color to fill the entire `dsdl.Surface`
     +/
    void fill(Color color) @trusted {
        if (this.pixelFormat.hasAlpha) {
            this.fill(this.pixelFormat.mapRGBA(color));
        }
        else {
            this.fill(this.pixelFormat.mapRGB(color));
        }
    }

    /++
     + Wraps `SDL_FillRect` which draws a filled rectangle in the `dsdl.Surface` with specifying a pixel color value
     +
     + Params:
     +   rect = `dsdl.Rect` specifying the position and size
     +   pixel = pixel value of the color to fill the rectangle
     + Throws: `dsdl.SDLException` if rectangle failed to draw
     +/
    void fillRect(Rect rect, uint pixel) @trusted {
        if (SDL_FillRect(this.sdlSurface, &rect.sdlRect, pixel) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_FillRect` which draws a filled rectangle in the `dsdl.Surface` with specifying a `dsdl.Color` value
     +
     + Params:
     +   rect = `dsdl.Rect` specifying the position and size
     +   color = `dsdl.Color` of the color to fill the rectangle
     + Throws: `dsdl.SDLException` if rectangle failed to draw
     +/
    void fillRect(Rect rect, Color color) @trusted {
        if (this.pixelFormat.hasAlpha) {
            this.fillRect(rect, this.pixelFormat.mapRGBA(color));
        }
        else {
            this.fillRect(rect, this.pixelFormat.mapRGB(color));
        }
    }

    /++
     + Wraps `SDL_FillRects` which draws multiple filled rectangles in the `dsdl.Surface` with specifying a pixel
     + color value
     +
     + Params:
     +   rects = an array of `dsdl.Rect`s specifying the drawn rectangles' positions and sizes
     +   pixel = pixel value of the color to fill the rectangles
     + Throws: `dsdl.SDLException` if the rectangles failed to draw
     +/
    void fillRects(const Rect[] rects, uint pixel) @trusted {
        if (SDL_FillRects(this.sdlSurface, cast(SDL_Rect*) rects.ptr, rects.length.to!int, pixel) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_FillRects` which draws multiple filled rectangles in the `dsdl.Surface` with specifying a
     + `dsdl.Color` value
     +
     + Params:
     +   rects = an array of `dsdl.Rect`s specifying the drawn rectangles' positions and sizes
     +   color = `dsdl.Color` of the color to fill the rectangles
     + Throws: `dsdl.SDLException` if the rectangles failed to draw
     +/
    void fillRects(const Rect[] rects, Color color) @trusted {
        if (this.pixelFormat.hasAlpha) {
            this.fillRects(rects, this.pixelFormat.mapRGBA(color));
        }
        else {
            this.fillRects(rects, this.pixelFormat.mapRGB(color));
        }
    }

    /++
     + Wraps `SDL_BlitSurface` which blits/draws a `dsdl.Surface` on top of the `dsdl.Surface` at a specific
     + point as the top-left point of the drawn `dsdl.Surface` without any scaling done
     +
     + Params:
     +   source = `dsdl.Surface` to blit/draw
     +   destPoint = top-left `dsdl.Point` of where `source` is drawn
     +/
    void blit(const Surface source, Point destPoint) @trusted {
        SDL_Rect dstrect = SDL_Rect(destPoint.x, destPoint.y, 0, 0);
        if (SDL_BlitSurface(cast(SDL_Surface*) source.sdlSurface, null, this.sdlSurface, &dstrect) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_BlitSurface` which blits/draws a `dsdl.Surface` on top of the `dsdl.Surface` at a specific
     + point as the top-left point of the drawn `dsdl.Surface` without any scaling done
     +
     + Params:
     +   source = `dsdl.Surface` to blit/draw
     +   destPoint = top-left `dsdl.Point` of where `source` is drawn
     +   srcRect = the clipping rect of `source` specifying which part is drawn
     +/
    void blit(const Surface source, Point destPoint, Rect srcRect) @trusted {
        SDL_Rect dstrect = SDL_Rect(destPoint.x, destPoint.y, 0, 0);
        if (SDL_BlitSurface(cast(SDL_Surface*) source.sdlSurface, &srcRect.sdlRect, this.sdlSurface, &dstrect) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_BlitScaled` which blits/draws a `dsdl.Surface` on top of the `dsdl.Surface` at a specific
     + point as the top-left point of the drawn `dsdl.Surface` with scaling
     +
     + Params:
     +   source = `dsdl.Surface` to blit/draw
     +   destRect = `dsdl.Rect` of where `source` should be drawn (squeezes/stretches to the dimensions as well)
     +/
    void blitScaled(const Surface source, Rect destRect) @trusted {
        if (SDL_BlitScaled(cast(SDL_Surface*) source.sdlSurface, null, this.sdlSurface, &destRect.sdlRect) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_BlitScaled` which blits/draws a `dsdl.Surface` on top of the `dsdl.Surface` at a specific
     + point as the top-left point of the drawn `dsdl.Surface` with scaling
     +
     + Params:
     +   source = `dsdl.Surface` to blit/draw
     +   destRect = `dsdl.Rect` of where `source` should be drawn (squeezes/stretches to the dimensions as well)
     +   srcRect = the clipping rect of `source` specifying which part is drawn
     +/
    void blitScaled(const Surface source, Rect destRect, Rect srcRect) @trusted {
        if (SDL_BlitScaled(cast(SDL_Surface*) source.sdlSurface, &srcRect.sdlRect,
                this.sdlSurface, &destRect.sdlRect) != 0) {
            throw new SDLException;
        }
    }
}
///
unittest {
    auto surface = new dsdl.Surface([100, 100], dsdl.PixelFormat.rgba8888);
    surface.fill(dsdl.Color(24, 24, 24));
    surface.fillRect(dsdl.Rect(25, 25, 50, 50), dsdl.Color(42, 42, 42));

    assert(surface.getAt([0, 0]) == dsdl.Color(24, 24, 24));
    assert(surface.getAt([50, 50]) == dsdl.Color(42, 42, 42));
}
