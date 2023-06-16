/++
 + Authors: Avaxar <avaxar@nekkl.org>
 + Copyright: Copyright © 2023, Avaxar
 + License: $(LINK2 https://mit-license.org/, MIT License)
 +/

module dsdl2.pixels;
@safe:

import bindbc.sdl;
import dsdl2.sdl;

import std.format : format;

/++ 
 + A D struct that wraps `SDL_Color` containing 4 bytes for storing color values of 3 color channels and 1 alpha
 + channel.
 + 
 + `dsdl2.Color` stores unsigned `byte`-sized (0-255) `r`ed, `g`reen, `b`lue color, and `a`lpha channel values.
 + In total there are 16,777,216 possible color values. Combined with the `a`lpha (transparency) channel, there
 + are 4,294,967,296 combinations.
 +
 + Examples
 + ---
 + auto red = dsdl2.Color(255, 0, 0);
 + auto translucentRed = dsdl2.Color(255, 0, 0, 128);
 + ---
 +/
struct Color {
    SDL_Color _sdlColor;
    alias _sdlColor this;

    @disable this();

    /++ 
     + Constructs a `dsdl2.Color` from a vanilla `SDL_Color` from bindbc-sdl
     + 
     + Params:
     +   sdlColor = the `SDL_Color` struct
     +/
    this(SDL_Color sdlColor) {
        this._sdlColor = sdlColor;
    }

    /++ 
     + Constructs a `dsdl2.Color` by feeding in `r`ed, `g`reen, `b`lue, and optionally `a`lpha values
     + 
     + Params:
     +   r = red color channel value (0-255)
     +   g = green color channel value (0-255)
     +   b = blue color channel value (0-255)
     +   a = alpha transparency channel value (0-255 / transparent-opaque)
     +/
    this(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    /++
     + Formats the `dsdl2.Color` into its construction representation: `"dsdl2.Color(<r>, <g>, <b>, <a>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl2.Color(%d, %d, %d, %d)".format(this.r, this.g, this.b, this.a);
    }
}

/++ 
 + A D class that wraps `SDL_Palette` storing multiple `dsdl2.Color` as a palette to be used along with
 + indexed `dsdl2.PixelFormat` instances
 + 
 + Examples:
 + ---
 + auto myPalette = new dsdl2.Palette([dsdl2.Color(1, 2, 3), dsdl2.Color(3, 2, 1)]);
 + assert(myPalette.length == 2);
 + assert(myPalette[0] == dsdl2.Color(1, 2, 3));
 + ---
 +/
final class Palette {
    @system SDL_Palette* _sdlPalette = null;

    /++ 
     + Constructs a `dsdl2.Palette` from a vanilla `SDL_Palette*` from bindbc-sdl
     + 
     + Params:
     +   sdlPalette = the `SDL_Palette` pointer to manage
     +/
    this(SDL_Palette* sdlPalette) @system
    in {
        assert(sdlPalette !is null);
    }
    do {
        this._sdlPalette = sdlPalette;
    }

    /++ 
     + Constructs a `dsdl2.Palette` and allocate memory for a set amount of `dsdl2.Color`s 
     + 
     + Params:
     +   ncolors = amount of `dsdl2.Color`s to allocate in the `dsdl2.Palette`
     +/
    this(int ncolors) @trusted {
        this._sdlPalette = SDL_AllocPalette(ncolors);
        if (this._sdlPalette is null) {
            throw new SDLException;
        }
    }

    /++ 
     + Constructs a `dsdl2.Palette` from an array of `dsdl2.Color`s
     + 
     + Params:
     +   colors = an array/slice of `dsdl2.Color`s to be put in the `dsdl2.Palette`
     +/
    this(const Color[] colors) @trusted {
        this._sdlPalette = SDL_AllocPalette(cast(int) colors.length);
        if (this._sdlPalette is null) {
            throw new SDLException;
        }

        foreach (i, const ref Color color; colors) {
            this._sdlPalette.colors[i] = color._sdlColor;
        }
    }

    ~this() @trusted {
        SDL_FreePalette(this._sdlPalette);
    }

    @trusted invariant {
        assert(this._sdlPalette !is null);
    }

    /++ 
     + Indexing operation overload
     +/
    ref inout(Color) opIndex(size_t i) inout @trusted
    in {
        assert(0 <= i && i < this.length);
    }
    do {
        return *cast(inout(Color*))&this._sdlPalette.colors[i];
    }

    /++ 
     + Dollar sign overload
     +/
    size_t opDollar(size_t dim)() const if (dim == 0) {
        return this.length;
    }

    /++
     + Formats the `dsdl2.Palette` into its construction representation: `"dsdl2.Palette([<list of dsdl2.Color>])"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const {
        string str = "dsdl2.Palette([";

        foreach (size_t i; 0 .. this.length) {
            str ~= this[i].toString();

            if (i + 1 < this.length) {
                str ~= ", ";
            }
        }

        return str ~= "])";
    }

    /++ 
     + Gets the length of `dsdl2.Color`s allocated in the `dsdl2.Palette`
     + 
     + Returns: number of `dsdl2.Color`s
     +/
    size_t length() const @trusted {
        return this._sdlPalette.ncolors;
    }
}

/++ 
 + A D class that wraps `SDL_PixelFormat` defining the color and alpha channel bit layout in the internal
 + representation of a pixel
 + 
 + Examples:
 + ---
 + const auto rgba = dsdl2.PixelFormat.rgba8888
 + assert(rgba.map(dsdl2.Color(0x12, 0x34, 0x56, 0x78)) == 0x12345678);
 + assert(rgba.get(0x12345678) == dsdl2.Color(0x12, 0x34, 0x56, 0x78));
 + ---
 +/
final class PixelFormat {
    static PixelFormat _multiton(SDL_PixelFormatEnum sdlPixelFormatEnum, ubyte minMinorVer = 0,
        ubyte minPatchVer = 0)()
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

    static PixelFormat _instantiateIndexed(SDL_PixelFormatEnum sdlPixelFormatEnum)(Palette palette)
    in {
        assert(palette !is null);
    }
    do {
        return new PixelFormat(sdlPixelFormatEnum, palette);
    }

    /++ 
     + Instantiates indexed `dsdl2.PixelFormat` for use with `dsdl2.Palette`s
     +/
    static alias index1lsb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX1LSB;
    static alias index1msb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX1MSB; /// ditto
    static alias index4lsb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX4LSB; /// ditto
    static alias index4msb = _instantiateIndexed!SDL_PIXELFORMAT_INDEX4MSB; /// ditto

    /++ 
     + Retrieves one of the `dsdl2.PixelFormat` multiton presets
     +/
    static alias index8 = _multiton!SDL_PIXELFORMAT_INDEX8;
    static alias rgb332 = _multiton!SDL_PIXELFORMAT_RGB332; /// ditto
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
    static alias yv12 = _multiton!SDL_PIXELFORMAT_YV12; /// ditto
    static alias iyuv = _multiton!SDL_PIXELFORMAT_IYUV; /// ditto
    static alias yuy2 = _multiton!SDL_PIXELFORMAT_YUY2; /// ditto
    static alias uyvy = _multiton!SDL_PIXELFORMAT_UYVY; /// ditto
    static alias yvyu = _multiton!SDL_PIXELFORMAT_YVYU; /// ditto

    static if (sdlSupport >= SDLSupport.v2_0_4) {
        /++ 
         + Retrieves one of the `dsdl2.PixelFormat` multiton presets (from SDL 2.0.4)
         +/
        static alias nv12 = _multiton!(SDL_PIXELFORMAT_NV12, 0, 4);
        static alias nv21 = _multiton!(SDL_PIXELFORMAT_NV21, 0, 4); /// ditto
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        /++ 
         + Retrieves one of the `dsdl2.PixelFormat` multiton presets (from SDL 2.0.5)
         +/
        static alias rgba32 = _multiton!(SDL_PIXELFORMAT_RGBA32, 0, 5);
        static alias argb32 = _multiton!(SDL_PIXELFORMAT_ARGB32, 0, 5); /// ditto
        static alias bgra32 = _multiton!(SDL_PIXELFORMAT_BGRA32, 0, 5); /// ditto
        static alias abgr32 = _multiton!(SDL_PIXELFORMAT_ABGR32, 0, 5); /// ditto
    }

    private Palette paletteRef = null;
    @system SDL_PixelFormat* _sdlPixelFormat = null;

    /++ 
     + Constructs a `dsdl2.PixelFormat` from a vanilla `SDL_PixelFormat*` from bindbc-sdl
     + 
     + Params:
     +   sdlPixelFormat = the `SDL_PixelFormat` pointer to manage
     +/
    this(SDL_PixelFormat* sdlPixelFormat) @system
    in {
        assert(sdlPixelFormat !is null);
    }
    do {
        this._sdlPixelFormat = sdlPixelFormat;
    }

    /++ 
     + Constructs a `dsdl2.PixelFormat` using an `SDL_PixelFormatEnum` from bindbc-sdl
     + 
     + Params:
     +   sdlPixelFormatEnum = the `SDL_PixelFormatEnum` enumeration (non-indexed)
     +/
    this(SDL_PixelFormatEnum sdlPixelFormatEnum) @trusted
    in {
        assert(sdlPixelFormatEnum != SDL_PIXELFORMAT_UNKNOWN);
        assert(!SDL_ISPIXELFORMAT_INDEXED(sdlPixelFormatEnum));
    }
    do {
        this._sdlPixelFormat = SDL_AllocFormat(sdlPixelFormatEnum);
        if (this._sdlPixelFormat is null) {
            throw new SDLException;
        }
    }

    /++ 
     + Constructs a `dsdl2.PixelFormat` using an indexed `SDL_PixelFormatEnum` from bindbc-sdl, allowing use with
     + `dsdl2.Palette`s
     + 
     + Params:
     +   sdlPixelFormatEnum = the `SDL_PixelFormatEnum` enumeration (indexed)
     +   palette            = the `dsdl2.Palette` class instance to be bound of its color palette
     +/
    this(SDL_PixelFormatEnum sdlPixelFormatEnum, Palette palette) @trusted
    in {
        assert(SDL_ISPIXELFORMAT_INDEXED(sdlPixelFormatEnum));
        assert(palette !is null);
    }
    do {
        this._sdlPixelFormat = SDL_AllocFormat(sdlPixelFormatEnum);
        if (this._sdlPixelFormat is null) {
            throw new SDLException;
        }

        if (SDL_SetPixelFormatPalette(this._sdlPixelFormat, palette._sdlPalette) != 0) {
            throw new SDLException;
        }

        this.paletteRef = palette;
    }

    /++ 
     + Constructs a `dsdl2.PixelFormat` from user-provided bit masks for RGB color and alpha channels by internally
     + using `SDL_MasksToPixelFormatEnum` to retrieve the `SDL_PixelFormatEnum`
     + 
     + Params:
     +   bitDepth  = bit depth of a pixel (size of one pixel in bits) 
     +   redMask   = bit mask of the red color channel
     +   greenMask = bit mask of the green color channel
     +   blueMask  = bit mask of the blue color channel
     +   alphaMask = bit mask of the alpha channel
     +/
    this(int bitDepth, uint redMask, uint greenMask, uint blueMask, uint alphaMask) @trusted {
        uint sdlPixelFormatEnum = SDL_MasksToPixelFormatEnum(bitDepth, redMask, greenMask, blueMask, alphaMask);
        if (sdlPixelFormatEnum == SDL_PIXELFORMAT_UNKNOWN) {
            throw new SDLException("Pixel format conversion is not possible", __FILE__, __LINE__);
        }

        this(sdlPixelFormatEnum);
    }

    ~this() @trusted {
        SDL_FreeFormat(this._sdlPixelFormat);
    }

    @trusted invariant {
        assert(this._sdlPixelFormat !is null);
        assert(this._sdlPixelFormat.format != SDL_PIXELFORMAT_UNKNOWN);

        if (SDL_ISPIXELFORMAT_INDEXED(this._sdlPixelFormat.format)) {
            assert(this.paletteRef !is null);
            assert(this._sdlPixelFormat.palette !is null);
        }
    }

    /++
     + Formats the `dsdl2.PixelFormat` into its construction representation:
     + `"dsdl2.PixelFormat(<sdlPixelFormatEnum>)"` or `"dsdl2.PixelFormat(<sdlPixelFormatEnum>, <palette>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        if (SDL_ISPIXELFORMAT_INDEXED(this._sdlPixelFormat.format)) {
            return "dsdl2.PixelFormat(%s, %s)".format(
                SDL_GetPixelFormatName(
                    this._sdlPixelFormat.format), this.paletteRef);
        }
        else {
            return "dsdl2.PixelFormat(%s)".format(
                SDL_GetPixelFormatName(this._sdlPixelFormat.format));
        }
    }

    /++ 
     + Wraps `SDL_GetRGB` which converts a pixel `uint` value to a comprehensible `dsdl2.Color` struct without
     + accounting the alpha value (automatically set to opaque [255]), based on the pixel format defined by the
     + `dsdl2.PixelFormat`
     + 
     + Params:
     +   pixel = the pixel `uint` value to convert
     + 
     + Returns: the `dsdl2.Color` struct of the given `pixel` value
     +/
    Color getRGB(uint pixel) const @trusted {
        Color color = Color(0, 0, 0, 255);
        SDL_GetRGB(pixel, this._sdlPixelFormat, &color.r, &color.g, &color.b);
        return color;
    }

    /++ 
     + Wraps `SDL_GetRGBA` which converts a pixel `uint` value to a comprehensible `dsdl2.Color` struct, based on
     + the pixel format defined by the `dsdl2.PixelFormat`
     + 
     + Params:
     +   pixel = the pixel `uint` value to convert
     + 
     + Returns: the `dsdl2.Color` struct of the given `pixel` value
     +/
    Color getRGBA(uint pixel) const @trusted {
        Color color = void;
        SDL_GetRGBA(pixel, this._sdlPixelFormat, &color.r, &color.g, &color.b, &color.a);
        return color;
    }

    /++ 
     + Wraps `SDL_MapRGB` which converts a `dsdl2.Color` to its pixel `uint` value according to the pixel format
     + defined by the `dsdl2.PixelFormat` without accounting the alpha value, assuming that it's opaque
     + 
     + Params:
     +   color = the `dsdl2.Color` struct to convert
     + 
     + Returns: the converted pixel value
     +/
    uint mapRGB(Color color) const @trusted {
        return SDL_MapRGB(this._sdlPixelFormat, color.r, color.g, color.b);
    }

    /++ 
     + Wraps `SDL_MapRGBA` which converts a `dsdl2.Color` to its pixel `uint` value according to the pixel format
     + defined by the `dsdl2.PixelFormat`
     + 
     + Params:
     +   color = the `dsdl2.Color` struct to convert
     + 
     + Returns: the converted pixel value
     +/
    uint mapRGBA(Color color) const @trusted {
        return SDL_MapRGBA(this._sdlPixelFormat, color.r, color.g, color.b, color.a);
    }

    /++ 
     + Wraps `SDL_SetPixelFormatPalette` which sets the `dsdl2.Palette` for indexed `dsdl2.PixelFormat`s`
     + 
     + Params:
     +   palette = the `dsdl2.Palette` class instance to be bound of its color palette
     +/
    void setPalette(Palette palette) @trusted
    in {
        assert(this.isIndexed());
        assert(palette !is null);
    }
    do {
        if (SDL_SetPixelFormatPalette(this._sdlPixelFormat, palette._sdlPalette) != 0) {
            throw new SDLException;
        }

        this.paletteRef = palette;
    }

    /++ 
     + Gets the `dsdl2.Palette` bounds to the indexed `dsdl2.PixelFormat`
     + 
     + Returns: the bound `dsdl2.Palette`
     +/
    inout(Palette) getPalette() inout @trusted
    in {
        assert(this.isIndexed());
    }
    do {
        return this.paletteRef;
    }

    /++ 
     + Gets the bit depth (size of a pixel in bits) of the `dsdl2.PixelFormat`
     + 
     + Returns: the bit depth of the `dsdl2.PixelFormat`
     +/
    uint bitDepth() const @trusted {
        return this._sdlPixelFormat.BitsPerPixel;
    }

    /++ 
     + Wraps `SDL_PixelFormatEnumToMasks` which gets the bit mask for all four channels of the `dsdl2.PixelFormat`
     + 
     + Returns: an array of 4 bit masks for each channel (red, green, blue, and alpha)
     +/
    uint[4] toMasks() const @trusted {
        uint[4] rgbaMasks = void;
        int bitDepth = void;

        if (SDL_PixelFormatEnumToMasks(this._sdlPixelFormat.format, &bitDepth, &rgbaMasks[0], &rgbaMasks[1],
            &rgbaMasks[2], &rgbaMasks[3]) == SDL_FALSE) {
            throw new SDLException;
        }

        return rgbaMasks;
    }

    /++ 
     + Wraps `SDL_ISPIXELFORMAT_INDEXED` which checks whether the `dsdl2.PixelFormat` is indexed
     + 
     + Returns: `true` if it is indexed, otherwise `false`
     +/
    bool isIndexed() const @trusted {
        return SDL_ISPIXELFORMAT_INDEXED(this._sdlPixelFormat.format);
    }

    /++ 
     + Wraps `SDL_ISPIXELFORMAT_ALPHA` which checks whether the `dsdl2.PixelFormat` is capable of storing alpha value
     + 
     + Returns: `true` if it can have an alpha channel, otherwise `false`
     +/
    bool hasAlpha() const @trusted {
        return SDL_ISPIXELFORMAT_ALPHA(this._sdlPixelFormat.format);
    }

    /++ 
     + Wraps `SDL_ISPIXELFORMAT_FOURCC` which checks whether the `dsdl2.PixelFormat` represents a unique format
     + 
     + Returns: `true` if it is unique, otherwise `false`
     +/
    bool isFourCC() const @trusted {
        return SDL_ISPIXELFORMAT_FOURCC(this._sdlPixelFormat.format) != 0;
    }
}