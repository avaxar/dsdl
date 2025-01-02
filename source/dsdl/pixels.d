/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.pixels;
@safe:

import bindbc.sdl;
import dsdl.sdl;

import core.memory : GC;
import std.conv : to;
import std.format : format;

/++
 + D struct that wraps `SDL_Color` containing 4 bytes for storing color values of 3 color channels and 1 alpha
 + channel.
 +
 + `dsdl.Color` stores unsigned `byte`-sized (0-255) `r`ed, `g`reen, `b`lue color, and `a`lpha channel values.
 + In total there are 16,777,216 possible color values. Combined with the `a`lpha (transparency) channel, there
 + are 4,294,967,296 combinations.
 +
 + Examples
 + ---
 + auto red = dsdl.Color(255, 0, 0);
 + auto translucentRed = dsdl.Color(255, 0, 0, 128);
 + ---
 +/
struct Color {
    SDL_Color sdlColor; /// Internal `SDL_Color` struct

    this() @disable;

    /++
     + Constructs a `dsdl.Color` from a vanilla `SDL_Color` from bindbc-sdl
     +
     + Params:
     +   sdlColor = the `SDL_Color` struct
     +/
    this(SDL_Color sdlColor) {
        this.sdlColor = sdlColor;
    }

    /++
     + Constructs a `dsdl.Color` by feeding in `r`ed, `g`reen, `b`lue, and optionally `a`lpha values
     +
     + Params:
     +   r = red color channel value (0-255)
     +   g = green color channel value (0-255)
     +   b = blue color channel value (0-255)
     +   a = alpha transparency channel value (0-255 / transparent-opaque)
     +/
    this(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
        this.sdlColor.r = r;
        this.sdlColor.g = g;
        this.sdlColor.b = b;
        this.sdlColor.a = a;
    }

    /++
     + Constructs a `dsdl.Color` by feeding in an array of `r`ed, `g`reen, and `b`lue, with `a`lpha being `255`
     +
     + Params:
     +   rgb = array of `r`ed, `g`reen, `b`lue values
     +/
    this(ubyte[3] rgb) {
        this.sdlColor.r = rgb[0];
        this.sdlColor.g = rgb[1];
        this.sdlColor.b = rgb[2];
        this.sdlColor.a = 255;
    }

    /++
     + Constructs a `dsdl.Color` by feeding in an array of `r`ed, `g`reen, `b`lue, and `a`lpha
     +
     + Params:
     +   rgba = array of `r`ed, `g`reen, `b`lue, `a`lpha values
     +/
    this(ubyte[4] rgba) {
        this.sdlColor.r = rgba[0];
        this.sdlColor.g = rgba[1];
        this.sdlColor.b = rgba[2];
        this.sdlColor.a = rgba[3];
    }

    /++
     + Formats the `dsdl.Color` into its construction representation: `"dsdl.Color(<r>, <g>, <b>, <a>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.Color(%d, %d, %d, %d)".format(this.r, this.g, this.b, this.a);
    }

    /++
     + Proxy to the red color value of the `dsdl.Color`
     +
     + Returns: red color value of the `dsdl.Color`
     +/
    ref inout(ubyte) r() return inout @property {
        return this.sdlColor.r;
    }

    /++
     + Proxy to the green color value of the `dsdl.Color`
     +
     + Returns: green color value of the `dsdl.Color`
     +/
    ref inout(ubyte) g() return inout @property {
        return this.sdlColor.g;
    }

    /++
     + Proxy to the blue color value of the `dsdl.Color`
     +
     + Returns: blue color value of the `dsdl.Color`
     +/
    ref inout(ubyte) b() return inout @property {
        return this.sdlColor.b;
    }

    /++
     + Proxy to the alpha transparency value of the `dsdl.Color`
     +
     + Returns: alpha transparency value of the `dsdl.Color`
     +/
    ref inout(ubyte) a() return inout @property {
        return this.sdlColor.a;
    }

    /++
     + Static array proxy of the `dsdl.Color`
     +
     + Returns: array of `r`, `g`, `b`, `a`
     +/
    ref inout(ubyte[4]) array() return inout @property @trusted {
        return *cast(inout(ubyte[4]*))&this.sdlColor;
    }
}

/++
 + D class that wraps `SDL_Palette` storing multiple `dsdl.Color` as a palette to use along with indexed
 + `dsdl.PixelFormat` instances
 +/
final class Palette {
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_Palette* sdlPalette = null; /// Internal `SDL_Palette` pointer

    /++
     + Constructs a `dsdl.Palette` from a vanilla `SDL_Palette*` from bindbc-sdl
     +
     + Params:
     +   sdlPalette = the `SDL_Palette` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_Palette*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_Palette* sdlPalette, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlPalette !is null);
    }
    do {
        this.sdlPalette = sdlPalette;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Constructs a `dsdl.Palette` and allocate memory for a set amount of `dsdl.Color`s
     +
     + Params:
     +   ncolors = amount of `dsdl.Color`s to allocate in the `dsdl.Palette`
     + Throws: `dsdl.SDLException` if allocation failed
     +/
    this(uint ncolors) @trusted {
        this.sdlPalette = SDL_AllocPalette(ncolors.to!int);
        if (this.sdlPalette is null) {
            throw new SDLException;
        }
    }

    /++
     + Constructs a `dsdl.Palette` from an array of `dsdl.Color`s
     +
     + Params:
     +   colors = an array/slice of `dsdl.Color`s to put in the `dsdl.Palette`
     + Throws: `dsdl.SDLException` if allocation failed
     +/
    this(const Color[] colors) @trusted {
        this.sdlPalette = SDL_AllocPalette(colors.length.to!int);
        if (this.sdlPalette is null) {
            throw new SDLException;
        }

        foreach (i, const ref color; colors) {
            this.sdlPalette.colors[i] = color.sdlColor;
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_FreePalette(this.sdlPalette);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlPalette !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Palette rhs) const @trusted {
        if (rhs is null) {
            return false;
        }

        if (this.sdlPalette is rhs.sdlPalette) {
            return true;
        }

        if (this.length != rhs.length) {
            return false;
        }

        foreach (i; 0 .. this.length) {
            if (this[i] != rhs[i]) {
                return false;
            }
        }

        return true;
    }

    /++
     + Gets the hash of the `dsdl.Palette`
     +
     + Returns: unique hash for the `dsdl.Palette`
     +/
    override hash_t toHash() const @trusted {
        try {
            return this.colors.hashOf;
        }
        catch (Exception) {
            assert(false);
        }
    }

    /++
     + Indexing operation overload
     +/
    ref inout(Color) opIndex(size_t i) return inout @trusted
    in {
        assert(0 <= i && i < this.length);
    }
    do {
        return *cast(inout(Color*))&this.sdlPalette.colors[i];
    }

    /++
     + Dollar sign overload
     +/
    size_t opDollar(size_t dim)() const if (dim == 0) {
        return this.length;
    }

    /++
     + Formats the `dsdl.Palette` into its construction representation: `"dsdl.Palette([<list of dsdl.Color>])"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const {
        string str = "dsdl.Palette([";

        foreach (i; 0 .. this.length) {
            str ~= this[i].toString();

            if (i + 1 < this.length) {
                str ~= ", ";
            }
        }

        return str ~= "])";
    }

    /++
     + Gets the length of `dsdl.Color`s allocated in the `dsdl.Palette`
     +
     + Returns: number of `dsdl.Color`s
     +/
    size_t length() const @property @trusted {
        return this.sdlPalette.ncolors;
    }

    /++
     + Proxy to the `dsdl.Color` array of the `dsdl.Palette`
     +
     + This function is marked as `@system` due to the potential of referencing invalid memory.
     +
     + Returns: `dsdl.Color` array of the `dsdl.Palette`
     +/
    inout(Color[]) colors() inout @property @system {
        return (cast(inout(Color*))&this.sdlPalette.colors)[0 .. this.length];
    }
}
///
unittest {
    auto myPalette = new dsdl.Palette([dsdl.Color(1, 2, 3), dsdl.Color(3, 2, 1)]);
    assert(myPalette.length == 2);
    assert(myPalette[0] == dsdl.Color(1, 2, 3));
}

/++
 + D class that wraps `SDL_PixelFormat` defining the color and alpha channel bit layout in the internal
 + representation of a pixel
 +/
final class PixelFormat {
    static PixelFormat _multiton(SDL_PixelFormatEnum sdlPixelFormatEnum, ubyte minMinorVer = 0, ubyte minPatchVer = 0)()
    in {
        assert(getVersion() >= Version(2, minMinorVer, minPatchVer));
    }
    do {
        static PixelFormat pixelFormat = null;
        if (pixelFormat is null) {
            pixelFormat = new PixelFormat(sdlPixelFormatEnum);
        }

        return pixelFormat;
    }

    static PixelFormat _instantiateIndexed(SDL_PixelFormatEnum sdlPixelFormatEnum,
            ubyte minMinorVer = 0, ubyte minPatchVer = 0)(Palette palette)
    in {
        assert(getVersion() >= Version(2, minMinorVer, minPatchVer));
        assert(palette !is null);
    }
    do {
        return new PixelFormat(sdlPixelFormatEnum, palette);
    }

    /++
     + Instantiates indexed `dsdl.PixelFormat` for use with `dsdl.Palette`s from `SDL_PIXELFORMAT_*` enumeration
     + constants
     +/
    static alias index1lsb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX1LSB;
    static alias index1msb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX1MSB; /// ditto
    static alias index4lsb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX4LSB; /// ditto
    static alias index4msb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX4MSB; /// ditto
    static alias index8 = _instantiateIndexed!SDL_PIXELFORMAT_INDEX8; /// ditto
    static alias yv12 = _instantiateIndexed!SDL_PIXELFORMAT_YV12; /// ditto
    static alias yuy2 = _instantiateIndexed!SDL_PIXELFORMAT_YUY2; /// ditto

    /++
     + Retrieves one of the `dsdl.PixelFormat` multiton presets from `SDL_PIXELFORMAT_*` enumeration constants
     +/
    static alias rgb332 = _multiton!SDL_PIXELFORMAT_RGB332;
    static alias rgb444 = _multiton!SDL_PIXELFORMAT_RGB444; /// ditto
    static alias rgb555 = _multiton!SDL_PIXELFORMAT_RGB555; /// ditto
    static alias bgr555 = _multiton!SDL_PIXELFORMAT_BGR555; /// ditto
    static alias argb4444 = _multiton!SDL_PIXELFORMAT_ARGB4444; /// ditto
    static alias rgba444 = _multiton!SDL_PIXELFORMAT_RGBA4444; /// ditto
    static alias abgr4444 = _multiton!SDL_PIXELFORMAT_ABGR4444; /// ditto
    static alias bgra4444 = _multiton!SDL_PIXELFORMAT_BGRA4444; /// ditto
    static alias argb1555 = _multiton!SDL_PIXELFORMAT_ARGB1555; /// ditto
    static alias rgba5551 = _multiton!SDL_PIXELFORMAT_RGBA5551; /// ditto
    static alias abgr1555 = _multiton!SDL_PIXELFORMAT_ABGR1555; /// ditto
    static alias bgra5551 = _multiton!SDL_PIXELFORMAT_BGRA5551; /// ditto
    static alias rgb565 = _multiton!SDL_PIXELFORMAT_RGB565; /// ditto
    static alias bgr565 = _multiton!SDL_PIXELFORMAT_BGR565; /// ditto
    static alias rgb24 = _multiton!SDL_PIXELFORMAT_RGB24; /// ditto
    static alias bgr24 = _multiton!SDL_PIXELFORMAT_BGR24; /// ditto
    static alias rgb888 = _multiton!SDL_PIXELFORMAT_RGB888; /// ditto
    static alias rgbx8888 = _multiton!SDL_PIXELFORMAT_RGBX8888; /// ditto
    static alias bgr888 = _multiton!SDL_PIXELFORMAT_BGR888; /// ditto
    static alias bgrx8888 = _multiton!SDL_PIXELFORMAT_BGRX8888; /// ditto
    static alias argb8888 = _multiton!SDL_PIXELFORMAT_ARGB8888; /// ditto
    static alias rgba8888 = _multiton!SDL_PIXELFORMAT_RGBA8888; /// ditto
    static alias abgr8888 = _multiton!SDL_PIXELFORMAT_ABGR8888; /// ditto
    static alias bgra8888 = _multiton!SDL_PIXELFORMAT_BGRA8888; /// ditto
    static alias argb2101010 = _multiton!SDL_PIXELFORMAT_ARGB2101010; /// ditto

    static alias iyuv = _multiton!SDL_PIXELFORMAT_IYUV; /// ditto
    static alias uyvy = _multiton!SDL_PIXELFORMAT_UYVY; /// ditto
    static alias yvyu = _multiton!SDL_PIXELFORMAT_YVYU; /// ditto

    static if (sdlSupport >= SDLSupport.v2_0_4) {
        /++
         + Instantiates indexed `dsdl.PixelFormat` for use with `dsdl.Palette`s from `SDL_PIXELFORMAT_*`
         + enumeration constants (from SDL 2.0.4)
         +/
        static alias nv12 = _instantiateIndexed!(SDL_PIXELFORMAT_NV12, 0, 4);
        static alias nv21 = _instantiateIndexed!(SDL_PIXELFORMAT_NV21, 0, 4); /// ditto
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        /++
         + Retrieves one of the `dsdl.PixelFormat` multiton presets from `SDL_PIXELFORMAT_*` enumeration constants
         + (from SDL 2.0.5)
         +/
        static alias rgba32 = _multiton!(SDL_PIXELFORMAT_RGBA32, 0, 5);
        static alias argb32 = _multiton!(SDL_PIXELFORMAT_ARGB32, 0, 5); /// ditto
        static alias bgra32 = _multiton!(SDL_PIXELFORMAT_BGRA32, 0, 5); /// ditto
        static alias abgr32 = _multiton!(SDL_PIXELFORMAT_ABGR32, 0, 5); /// ditto
    }

    private Palette paletteRef = null;
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_PixelFormat* sdlPixelFormat = null; /// Internal `SDL_PixelFormat` pointer

    /++
     + Constructs a `dsdl.PixelFormat` from a vanilla `SDL_PixelFormat*` from bindbc-sdl
     +
     + Params:
     +   sdlPixelFormat = the `SDL_PixelFormat` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_PixelFormat*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_PixelFormat* sdlPixelFormat, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlPixelFormat !is null);
    }
    do {
        this.sdlPixelFormat = sdlPixelFormat;
        this.isOwner = isOwner;
        this.userRef = userRef;

        if (this.sdlPixelFormat.palette !is null) {
            this.paletteRef = new Palette(this.sdlPixelFormat.palette, false, cast(void*) this);
        }
    }

    /++
     + Constructs a `dsdl.PixelFormat` using an `SDL_PixelFormatEnum` from bindbc-sdl
     +
     + Params:
     +   sdlPixelFormatEnum = the `SDL_PixelFormatEnum` enumeration (non-indexed)
     + Throws: `dsdl.SDLException` if allocation failed
     +/
    this(SDL_PixelFormatEnum sdlPixelFormatEnum) @trusted
    in {
        assert(sdlPixelFormatEnum != SDL_PIXELFORMAT_UNKNOWN);
        assert(!SDL_ISPIXELFORMAT_INDEXED(sdlPixelFormatEnum));
    }
    do {
        this.sdlPixelFormat = SDL_AllocFormat(sdlPixelFormatEnum);
        if (this.sdlPixelFormat is null) {
            throw new SDLException;
        }
    }

    /++
     + Constructs a `dsdl.PixelFormat` using an indexed `SDL_PixelFormatEnum` from bindbc-sdl, allowing use with
     + `dsdl.Palette`s
     +
     + Params:
     +   sdlPixelFormatEnum = the `SDL_PixelFormatEnum` enumeration (indexed)
     +   palette = the `dsdl.Palette` class instance to bind as the color palette
     + Throws: `dsdl.SDLException` if allocation or palette-setting failed
     +/
    this(SDL_PixelFormatEnum sdlPixelFormatEnum, Palette palette) @trusted
    in {
        assert(SDL_ISPIXELFORMAT_INDEXED(sdlPixelFormatEnum));
        assert(palette !is null);
    }
    do {
        this.sdlPixelFormat = SDL_AllocFormat(sdlPixelFormatEnum);
        if (this.sdlPixelFormat is null) {
            throw new SDLException;
        }

        if (SDL_SetPixelFormatPalette(this.sdlPixelFormat, palette.sdlPalette) != 0) {
            throw new SDLException;
        }

        this.paletteRef = palette;
    }

    /++
     + Constructs a `dsdl.PixelFormat` from user-provided bit masks for RGB color and alpha channels by internally
     + using `SDL_MasksToPixelFormatEnum` to retrieve the `SDL_PixelFormatEnum`
     +
     + Params:
     +   bitsPerPixel = size of one pixel in bits
     +   rgbaMasks = bit masks for the red, green, blue, and alpha channels
     + Throws: `dsdl.SDLException` if pixel format conversion not possible
     +/
    this(ubyte bitsPerPixel, uint[4] rgbaMasks) @trusted
    in {
        assert(bitsPerPixel > 0);
    }
    do {
        uint sdlPixelFormatEnum = SDL_MasksToPixelFormatEnum(bitsPerPixel, rgbaMasks[0],
                rgbaMasks[1], rgbaMasks[2], rgbaMasks[3]);
        if (sdlPixelFormatEnum == SDL_PIXELFORMAT_UNKNOWN) {
            throw new SDLException("Pixel format conversion is not possible", __FILE__, __LINE__);
        }

        this(sdlPixelFormatEnum);
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_FreeFormat(this.sdlPixelFormat);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlPixelFormat !is null);
        if (this.isOwner) {
            assert(this.sdlPixelFormat.format != SDL_PIXELFORMAT_UNKNOWN);
        }

        if (SDL_ISPIXELFORMAT_INDEXED(this.sdlPixelFormat.format)) {
            assert(this.paletteRef !is null);
            if (this.isOwner) {
                assert(this.sdlPixelFormat.palette !is null);
            }
        }
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const PixelFormat rhs) const @trusted {
        if (rhs is null) {
            return false;
        }

        if (this.sdlPixelFormat.format == rhs.sdlPixelFormat.format) {
            return true;
        }

        if (this.sdlPixelFormatEnum != rhs.sdlPixelFormatEnum) {
            return false;
        }

        if (SDL_ISPIXELFORMAT_INDEXED(this.sdlPixelFormatEnum)) {
            return this.paletteRef == rhs.paletteRef;
        }
        else {
            return true;
        }
    }

    /++
     + Gets the hash of the `dsdl.PixelFormat`
     +
     + Returns: unique hash for the `dsdl.PixelFormat`
     +/
    override hash_t toHash() const @trusted {
        try {
            return this.sdlPixelFormatEnum.hashOf(this.paletteRef.hashOf);
        }
        catch (Exception) {
            assert(false);
        }
    }

    /++
     + Formats the `dsdl.PixelFormat` into its construction representation:
     + `"dsdl.PixelFormat(<sdlPixelFormatEnum>)"` or `"dsdl.PixelFormat(<sdlPixelFormatEnum>, <palette>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        if (SDL_ISPIXELFORMAT_INDEXED(this.sdlPixelFormatEnum)) {
            return "dsdl.PixelFormat(0x%x, %s)".format(this.sdlPixelFormatEnum, this.paletteRef);
        }
        else {
            return "dsdl.PixelFormat(0x%s)".format(this.sdlPixelFormatEnum);
        }
    }

    /++
     + Gets the `SDL_PixelFormatEnum` of the underlying `SDL_PixelFormat`
     +
     + Returns: `SDL_PixelFormatEnum` enumeration from bindbc-sdl
     +/
    SDL_PixelFormatEnum sdlPixelFormatEnum() const @property @trusted {
        return this.sdlPixelFormat.format;
    }

    /++
     + Wraps `SDL_GetRGB` which converts a pixel `uint` value to a comprehensible `dsdl.Color` struct without
     + accounting the alpha value (automatically set to opaque [255]), based on the pixel format defined by the
     + `dsdl.PixelFormat`
     +
     + Params:
     +   pixel = the pixel `uint` value to convert
     + Returns: the `dsdl.Color` struct of the given `pixel` value
     +/
    Color getRGB(uint pixel) const @trusted {
        Color color = Color(0, 0, 0, 255);
        SDL_GetRGB(pixel, this.sdlPixelFormat, &color.sdlColor.r, &color.sdlColor.g, &color.sdlColor.b);
        return color;
    }

    /++
     + Wraps `SDL_GetRGBA` which converts a pixel `uint` value to a comprehensible `dsdl.Color` struct, based on
     + the pixel format defined by the `dsdl.PixelFormat`
     +
     + Params:
     +   pixel = the pixel `uint` value to convert
     + Returns: the `dsdl.Color` struct of the given `pixel` value
     +/
    Color getRGBA(uint pixel) const @trusted {
        Color color = void;
        SDL_GetRGBA(pixel, this.sdlPixelFormat, &color.sdlColor.r, &color.sdlColor.g,
                &color.sdlColor.b, &color.sdlColor.a);
        return color;
    }

    /++
     + Wraps `SDL_MapRGB` which converts a `dsdl.Color` to its pixel `uint` value according to the pixel format
     + defined by the `dsdl.PixelFormat` without accounting the alpha value, assuming that it's opaque
     +
     + Params:
     +   color = the `dsdl.Color` struct to convert
     + Returns: the converted pixel value
     +/
    uint mapRGB(Color color) const @trusted {
        return SDL_MapRGB(this.sdlPixelFormat, color.sdlColor.r, color.sdlColor.g, color.sdlColor.b);
    }

    /++
     + Wraps `SDL_MapRGBA` which converts a `dsdl.Color` to its pixel `uint` value according to the pixel format
     + defined by the `dsdl.PixelFormat`
     +
     + Params:
     +   color = the `dsdl.Color` struct to convert
     + Returns: the converted pixel value
     +/
    uint mapRGBA(Color color) const @trusted {
        return SDL_MapRGBA(this.sdlPixelFormat, color.sdlColor.r, color.sdlColor.g,
                color.sdlColor.b, color.sdlColor.a);
    }

    /++
     + Gets the `dsdl.Palette` bounds to the indexed `dsdl.PixelFormat`
     +
     + Returns: the bound `dsdl.Palette`
     +/
    inout(Palette) palette() return inout @property @trusted
    in {
        assert(this.indexed);
    }
    do {
        return this.paletteRef;
    }

    /++
     + Wraps `SDL_SetPixelFormatPalette` which sets the `dsdl.Palette` for indexed `dsdl.PixelFormat`s`
     +
     + Params:
     +   newPalette = the `dsdl.Palette` class instance to bind as the color palette
     +/
    void palette(Palette newPalette) @property @trusted
    in {
        assert(this.indexed);
        assert(newPalette !is null);
    }
    do {
        if (SDL_SetPixelFormatPalette(this.sdlPixelFormat, newPalette.sdlPalette) != 0) {
            throw new SDLException;
        }

        this.paletteRef = newPalette;
    }

    /++
     + Gets the bit depth (size of a pixel in bits) of the `dsdl.PixelFormat`
     +
     + Returns: the bit depth of the `dsdl.PixelFormat`
     +/
    ubyte bitsPerPixel() const @property @trusted {
        return this.sdlPixelFormat.BitsPerPixel;
    }

    /++
     + Gets the how many bytes needed to represent a pixel in the `dsdl.PixelFormat`
     +
     + Returns: the bytes per pixel value of the `dsdl.PixelFormat`
     +/
    size_t bytesPerPixel() const @property @trusted {
        return this.sdlPixelFormat.BytesPerPixel;
    }

    /++
     + Wraps `SDL_PixelFormatEnumToMasks` which gets the bit mask for all four channels of the `dsdl.PixelFormat`
     +
     + Returns: an array of 4 bit masks for each channel (red, green, blue, and alpha)
     +/
    uint[4] toMasks() const @trusted {
        uint[4] rgbaMasks = void;
        int bitsPerPixel = void;

        if (SDL_PixelFormatEnumToMasks(this.sdlPixelFormatEnum, &bitsPerPixel, &rgbaMasks[0],
                &rgbaMasks[1], &rgbaMasks[2], &rgbaMasks[3]) == SDL_FALSE) {
            throw new SDLException;
        }

        return rgbaMasks;
    }

    /++
     + Wraps `SDL_ISPIXELFORMAT_INDEXED` which checks whether the `dsdl.PixelFormat` is indexed
     +
     + Returns: `true` if it is indexed, otherwise `false`
     +/
    bool indexed() const @property @trusted {
        return SDL_ISPIXELFORMAT_INDEXED(this.sdlPixelFormatEnum);
    }

    /++
     + Wraps `SDL_ISPIXELFORMAT_ALPHA` which checks whether the `dsdl.PixelFormat` is capable of storing alpha value
     +
     + Returns: `true` if it can have an alpha channel, otherwise `false`
     +/
    bool hasAlpha() const @property @trusted {
        return SDL_ISPIXELFORMAT_ALPHA(this.sdlPixelFormatEnum);
    }

    /++
     + Wraps `SDL_ISPIXELFORMAT_FOURCC` which checks whether the `dsdl.PixelFormat` represents a unique format
     +
     + Returns: `true` if it is unique, otherwise `false`
     +/
    bool fourCC() const @property @trusted {
        return SDL_ISPIXELFORMAT_FOURCC(this.sdlPixelFormatEnum) != 0;
    }
}
///
unittest {
    static if (sdlSupport >= SDLSupport.v2_0_5) {
        const auto rgba32 = dsdl.PixelFormat.rgba32;
        assert(rgba32.mapRGBA(dsdl.Color(0x12, 0x34, 0x56, 0x78)) == 0x78563412);
        assert(rgba32.getRGBA(0x78563412) == dsdl.Color(0x12, 0x34, 0x56, 0x78));
    }

    const auto rgba8888 = dsdl.PixelFormat.rgba8888;
    version (LittleEndian) {
        assert(rgba8888.mapRGBA(dsdl.Color(0x12, 0x34, 0x56, 0x78)) == 0x12345678);
        assert(rgba8888.getRGBA(0x12345678) == dsdl.Color(0x12, 0x34, 0x56, 0x78));
    }
    version (BigEndian) {
        assert(rgba8888.mapRGBA(dsdl.Color(0x12, 0x34, 0x56, 0x78)) == 0x78563412);
        assert(rgba8888.get(0x78563412) == dsdl.Color(0x12, 0x34, 0x56, 0x78));
    }
}
