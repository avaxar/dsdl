/++
 + Authors: Avaxar <avaxar@nekkl.org>
 + Copyright: Copyright © 2023, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.ttf;
@safe:

// dfmt off
import bindbc.sdl;
static if (bindSDLTTF):
// dfmt on

import dsdl.sdl;
import dsdl.pixels : Color;
import dsdl.surface;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.string : toStringz;
import std.typecons : Tuple;

version (BindSDL_Static) {
}
else {
    /++
     + Loads the SDL2_ttf shared dynamic library, which wraps bindbc-sdl's `loadSDLTTF` function
     +
     + Unless if bindbc-sdl is on static mode (by adding a `BindSDL_Static` version), this function will exist and must
     + be called before any calls are made to the library. Otherwise, a segfault will happen upon any function calls.
     +
     + Params:
     +   libName = name or path to look the SDL2_ttf SO/DLL for, otherwise `null` for default searching path
     + Throws: `dsdl.SDLException` if failed to find the library
     +/
    void loadSO(string libName = null) @trusted {
        SDLTTFSupport current = libName is null ? loadSDLTTF() : loadSDLTTF(libName.toStringz());
        if (current == sdlTTFSupport) {
            return;
        }

        import loader = bindbc.loader.sharedlib;

        string errors;
        foreach (info; loader.errors) {
            errors ~= "\n- " ~ info.error.to!string ~ ": " ~ info.message.to!string;
        }

        Version wanted = Version(sdlTTFSupport);
        if (current == SDLTTFSupport.noLibrary) {
            throw new SDLException("No SDL2_ttf library found, especially of version " ~ wanted.format() ~ errors,
                    __FILE__, __LINE__);
        }
        else {
            throw new SDLException("dsdl expects SDL_ttf " ~ wanted.format() ~ ", but got " ~ getVersion()
                    .format() ~ errors, __FILE__, __LINE__);
        }
    }
}

/++
 + Wraps `TTF_Init` which initializes SDL2_ttf
 +
 + Throws: `dsdl.SDLException` if failed to initialize
 + Example:
 + ---
 + dsdl.ttf.init();
 + ---
 +/
void init() @trusted {
    if (TTF_Init() != 0) {
        throw new SDLException;
    }
}

version (unittest) {
    import std.stdio;

    static this() {
        version (BindSDL_Static) {
        }
        else {
            dsdl.ttf.loadSO();
        }
        writeln("Testing with SDL_ttf ", getVersion().format(), " for binding version ",
                Version(sdlTTFSupport).format(), "...");

        try {
            dsdl.ttf.init();
        }
        catch (SDLException exc) {
            writeln("Initializing SDL_ttf resulted an error: ", exc.msg);
        }
    }
}

/++
 + Wraps `TTF_Quit` which deinitializes SDL2_ttf
 +/
void quit() @trusted {
    TTF_Quit();
}

/++
 + Wraps `TTF_WasInit` which checks whether SDL2_ttf has been initialized
 +
 + Returns: `true` if the library has been initialized, otherwise `false`
 +/
bool wasInit() @trusted {
    return TTF_WasInit() > 0;
}

/++
 + Wraps `TTF_Linked_version` which gets the version of the linked SDL2_ttf library
 +
 + Returns: `dsdl.Version` of the linked SDL2_ttf library
 +/
Version getVersion() @trusted {
    return Version(*TTF_Linked_Version());
}

static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
    /++
     + Wraps `TTF_GetFreeTypeVersion` (from SDL_ttf 2.0.18) which gets the version of the FreeType library used by the
     + linked SDL2_ttf
     +
     + Returns: `dsdl.Version` of the used FreeType library
     +/
    Version getFreeTypeVersion() @trusted
    in {
        assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
    }
    do {
        int[3] ver = void;
        TTF_GetFreeTypeVersion(&ver[0], &ver[1], &ver[2]);
        return Version(ver[0].to!ubyte, ver[1].to!ubyte, ver[2].to!ubyte);
    }

    /++
     + Wraps `TTF_GetHarfBuzzVersion` (from SDL_ttf 2.0.18) which gets the version of the HarfBuzz library used by the
     + linked SDL2_ttf
     +
     + Returns: `dsdl.Version` of the used HarfBuzz library
     +/
    Version getHarfBuzzVersion() @trusted
    in {
        assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
    }
    do {
        int[3] ver = void;
        TTF_GetHarfBuzzVersion(&ver[0], &ver[1], &ver[2]);
        return Version(ver[0].to!ubyte, ver[1].to!ubyte, ver[2].to!ubyte);
    }
}

/++
 + D struct that wraps a glyph's metrics information
 +/
struct GlyphMetrics {
    int[2] min; /// Tuple of the `minX` and `minY` values
    int[2] max; /// Tuple of the `maxX` and `maxY` values
    int advance; /// Advancing step size of the glyph

    this() @disable;

    /++
     + Constructs a new `dsdl.ttf.GlyphMetrics` by feeding in its attributes
     +
     + Params:
     +   min = tuple of the `minX` and `minY` values
     +   max = tuple of the `maxX` and `maxY` values
     +   advance = advancing step size of the glyph
     +/
    this(int[2] min, int[2] max, int advance) {
        this.min = min;
        this.max = max;
        this.advance = advance;
    }

    /++
     + Formats the `dsdl.ttf.GlyphMetrics` into its construction representation:
     + `"dsdl.ttf.GlyphMetrics(<min>, <max>, <advance>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.ttf.GlyphMetrics(%s, %s, %d)".format(this.min, this.max, this.advance);
    }

    /++
     + Proxy to the minimum X value of the `dsdl.ttf.GlyphMetrics`
     +
     + Returns: minimum X value of the `dsdl.ttf.GlyphMetrics`
     +/
    ref inout(int) minX() return inout @property {
        return this.min[0];
    }

    /++
     + Proxy to the minimum Y value of the `dsdl.ttf.GlyphMetrics`
     +
     + Returns: minimum Y value of the `dsdl.ttf.GlyphMetrics`
     +/
    ref inout(int) minY() return inout @property {
        return this.min[1];
    }

    /++
     + Proxy to the maximum X value of the `dsdl.ttf.GlyphMetrics`
     +
     + Returns: maximum X value of the `dsdl.ttf.GlyphMetrics`
     +/
    ref inout(int) maxX() return inout @property {
        return this.max[0];
    }

    /++
     + Proxy to the maximum Y value of the `dsdl.ttf.GlyphMetrics`
     +
     + Returns: maximum Y value of the `dsdl.ttf.GlyphMetrics`
     +/
    ref inout(int) maxY() return inout @property {
        return this.max[1];
    }
}

/++
 + D enum that wraps `TTF_HINTING_*` enumerations
 +/
enum Hinting {
    /++
     + Wraps `TTF_HINTING_*` enumeration constants
     +/
    normal = TTF_HINTING_NORMAL,
    light = TTF_HINTING_LIGHT, /// ditto
    mono = TTF_HINTING_MONO, /// ditto
    none = TTF_HINTING_NONE, /// ditto

    lightSubpixel = 4 /// Wraps `TTF_HINTING_LIGHT_SUBPIXEL` (from SDL_ttf 2.0.18)
}

/++
 + D enum that defines the render quality of font texts
 +/
enum RenderQuality {
    solid, /// Fast quality to 8-bit surface
    shaded, /// High quality to 8-bit surface with background color
    blended, /// High quality to ARGB surface
    lcd /// LCD subpixel quality to ARGB surface with background color (from SDL_ttf 2.20)
}

static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
    /++
     + D enum that wraps `TTF_WRAPPED_ALIGN_*` enumerations (from SDL_ttf 2.20)
     +/
    enum WrappedAlign {
        /++
         + Wraps `TTF_WRAPPED_ALIGN_*` enumeration constants
         +/
        left = TTF_WRAPPED_ALIGN_LEFT,
        center = TTF_WRAPPED_ALIGN_CENTER, /// ditto
        right = TTF_WRAPPED_ALIGN_RIGHT /// ditto
    }

    /++
     + D enum that wraps `TTF_Direction` (from SDL_ttf 2.20)
     +/
    enum Direction {
        /++
         + Wraps `TTF_DIRECTION_*` enumeration constants
         +/
        leftToRight = TTF_DIRECTION_LTR,
        rightToLeft = TTF_DIRECTION_RTL, /// ditto
        topToBottom = TTF_DIRECTION_TTB, /// ditto
        bottomToTop = TTF_DIRECTION_BTT /// ditto
    }
}

/++
 + D class that wraps `TTF_Font` enclosing a font object to render text from
 +/
final class Font {
    private bool isOwner = true;
    private void* userRef = null;

    @system TTF_Font* ttfFont = null; /// Internal `TTF_Font` pointer

    /++
     + Constructs a `dsdl.ttf.Font` from a vanilla `TTF_Font*` from bindbc-sdl
     +
     + Params:
     +   ttfFont = the `TTF_Font` pointer to manage
     +   isOwner = whether the instance owns the given `TTF_Font*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(TTF_Font* ttfFont, bool isOwner = true, void* userRef = null) @system
    in {
        assert(ttfFont !is null);
    }
    do {
        this.ttfFont = ttfFont;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Loads a `dsdl.ttf.Font` from a font file, which wraps `TTF_OpenFont`
     +
     + Params:
     +   file = path to the font file
     +   size = point size of the loaded font
     + Throws: `dsdl.SDLException` if unable to load the font
     +/
    this(string file, uint size) @trusted {
        this.ttfFont = TTF_OpenFont(file.toStringz(), size.to!int);
        if (this.ttfFont is null) {
            throw new SDLException;
        }
    }

    /++
     + Loads a `dsdl.ttf.Font` from a font file with a face index, which wraps `TTF_OpenFontIndex`
     +
     + Params:
     +   file = path to the font file
     +   size = point size of the loaded font
     +   index = face index of the loaded font
     + Throws: `dsdl.SDLException` if unable to load the font
     +/
    this(string file, uint size, size_t index) @trusted {
        this.ttfFont = TTF_OpenFontIndex(file.toStringz(), size.to!int, index.to!c_long);
        if (this.ttfFont is null) {
            throw new SDLException;
        }
    }

    /++
     + Loads a `dsdl.ttf.Font` from a buffer, which wraps `TTF_OpenFontRW`
     +
     + Params:
     +   data = buffer of the font file
     +   size = point size of the loaded font
     + Throws: `dsdl.SDLException` if unable to load the font
     +/
    this(const void[] data, uint size) @trusted {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }

        this.ttfFont = TTF_OpenFontRW(sdlRWops, 1, size.to!int);
        if (this.ttfFont is null) {
            throw new SDLException;
        }
    }

    /++
     + Loads a `dsdl.ttf.Font` from a buffer with a face index, which wraps `TTF_OpenFontIndexRW`
     +
     + Params:
     +   data = buffer of the font file
     +   size = point size of the loaded font
     +   index = face index of the loaded font
     + Throws: `dsdl.SDLException` if unable to load the font
     +/
    this(const void[] data, uint size, size_t index) @trusted {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }

        this.ttfFont = TTF_OpenFontIndexRW(sdlRWops, 1, size.to!int, index.to!c_long);
        if (this.ttfFont is null) {
            throw new SDLException;
        }
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Loads a `dsdl.ttf.Font` from a font file with DPI, which wraps `TTF_OpenFontDPI` (from SDL_ttf 2.0.18)
         +
         + Params:
         +   file = path to the font file
         +   size = point size of the loaded font
         +   hdpi = target horizontal DPI
         +   vdpi = target vertical DPI
         + Throws: `dsdl.SDLException` if unable to load the font
         +/
        this(string file, uint size, uint hdpi, uint vdpi) @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            this.ttfFont = TTF_OpenFontDPI(file.toStringz(), size.to!int, hdpi, vdpi);
            if (this.ttfFont is null) {
                throw new SDLException;
            }
        }

        /++
         + Loads a `dsdl.ttf.Font` from a font file with DPI and face index, which wraps `TTF_OpenFontIndexDPI` (from
         + SDL_ttf 2.0.18)
         +
         + Params:
         +   file = path to the font file
         +   size = point size of the loaded font
         +   index = face index of the loaded font
         +   hdpi = target horizontal DPI
         +   vdpi = target vertical DPI
         + Throws: `dsdl.SDLException` if unable to load the font
         +/
        this(string file, uint size, size_t index, uint hdpi, uint vdpi) @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            this.ttfFont = TTF_OpenFontIndexDPI(file.toStringz(), size.to!int, index.to!c_long, hdpi, vdpi);
            if (this.ttfFont is null) {
                throw new SDLException;
            }
        }

        /++
         + Loads a `dsdl.ttf.Font` from a buffer with DPI, which wraps `TTF_OpenFontDPIRW` (from SDL_ttf 2.0.18)
         +
         + Params:
         +   data = buffer of the font file
         +   size = point size of the loaded font
         +   hdpi = target horizontal DPI
         +   vdpi = target vertical DPI
         + Throws: `dsdl.SDLException` if unable to load the font
         +/
        this(const void[] data, uint size, uint hdpi, uint vdpi) @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
            if (sdlRWops is null) {
                throw new SDLException;
            }

            this.ttfFont = TTF_OpenFontDPIRW(sdlRWops, 1, size.to!int, hdpi, vdpi);
            if (this.ttfFont is null) {
                throw new SDLException;
            }
        }

        /++
         + Loads a `dsdl.ttf.Font` from a buffer with DPI and face index, which wraps `TTF_OpenFontIndexDPIRW` (from
         + SDL_ttf 2.0.18)
         +
         + Params:
         +   data = buffer of the font file
         +   size = point size of the loaded font
         +   index = face index of the loaded font
         +   hdpi = target horizontal DPI
         +   vdpi = target vertical DPI
         + Throws: `dsdl.SDLException` if unable to load the font
         +/
        this(const void[] data, uint size, size_t index, uint hdpi, uint vdpi) @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
            if (sdlRWops is null) {
                throw new SDLException;
            }

            this.ttfFont = TTF_OpenFontIndexDPIRW(sdlRWops, 1, size.to!int, index.to!c_long, hdpi, vdpi);
            if (this.ttfFont is null) {
                throw new SDLException;
            }
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            TTF_CloseFont(this.ttfFont);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.ttfFont !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Font rhs) const @trusted {
        return this.ttfFont is rhs.ttfFont;
    }

    /++
     + Gets the hash of the `dsdl.ttf.Font`
     +
     + Returns: unique hash for the instance being the pointer of the internal `TTF_Font` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.ttfFont;
    }

    /++
     + Formats the `dsdl.ttf.Font` into its construction representation: `"dsdl.ttf.Font(<ttfFont>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.ttf.Font(0x%x)".format(this.ttfFont);
    }

    /++
     + Wraps `TTF_GetFontStyle` to get whether the `dsdl.ttf.Font` style is bold
     +
     + Returns: `true` if the `dsdl.ttf.Font` is bold, otherwise `false`
     +/
    bool bold() const @property @trusted {
        return (TTF_GetFontStyle(this.ttfFont) & TTF_STYLE_BOLD) == TTF_STYLE_BOLD;
    }

    /++
     + Wraps `TTF_SetFontStyle` to set the `dsdl.ttf.Font` style to be bold
     +
     + Params:
     +   newBold = `true` to make the `dsdl.ttf.Font` bold, otherwise `false`
     +/
    void bold(bool newBold) @property @trusted {
        if (newBold) {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) | TTF_STYLE_BOLD);
        }
        else {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) & ~TTF_STYLE_BOLD);
        }
    }

    /++
     + Wraps `TTF_GetFontStyle` to get whether the `dsdl.ttf.Font` style is italic
     +
     + Returns: `true` if the `dsdl.ttf.Font` is italic, otherwise `false`
     +/
    bool italic() const @property @trusted {
        return (TTF_GetFontStyle(this.ttfFont) & TTF_STYLE_ITALIC) == TTF_STYLE_ITALIC;
    }

    /++
     + Wraps `TTF_SetFontStyle` to set the `dsdl.ttf.Font` style to be italic
     +
     + Params:
     +   newItalic = `true` to make the `dsdl.ttf.Font` italic, otherwise `false`
     +/
    void italic(bool newItalic) @property @trusted {
        if (newItalic) {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) | TTF_STYLE_ITALIC);
        }
        else {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) & ~TTF_STYLE_ITALIC);
        }
    }

    /++
     + Wraps `TTF_GetFontStyle` to get whether the `dsdl.ttf.Font` style is underlined
     +
     + Returns: `true` if the `dsdl.ttf.Font` is underlined, otherwise `false`
     +/
    bool underline() const @property @trusted {
        return (TTF_GetFontStyle(this.ttfFont) & TTF_STYLE_UNDERLINE) == TTF_STYLE_UNDERLINE;
    }

    /++
     + Wraps `TTF_SetFontStyle` to set the `dsdl.ttf.Font` style to be underlined
     +
     + Params:
     +   newUnderline = `true` to make the `dsdl.ttf.Font` underlined, otherwise `false`
     +/
    void underline(bool newUnderline) @property @trusted {
        if (newUnderline) {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) | TTF_STYLE_UNDERLINE);
        }
        else {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) & ~TTF_STYLE_UNDERLINE);
        }
    }

    /++
     + Wraps `TTF_GetFontStyle` to get whether the `dsdl.ttf.Font` style is strikethrough
     +
     + Returns: `true` if the `dsdl.ttf.Font` is strikethrough, otherwise `false`
     +/
    bool strikethrough() const @property @trusted {
        return (TTF_GetFontStyle(this.ttfFont) & TTF_STYLE_STRIKETHROUGH) == TTF_STYLE_STRIKETHROUGH;
    }

    /++
     + Wraps `TTF_SetFontStyle` to set the `dsdl.ttf.Font` style to be strikethrough
     +
     + Params:
     +   newStrikethrough = `true` to make the `dsdl.ttf.Font` strikethrough, otherwise `false`
     +/
    void strikethrough(bool newStrikethrough) @property @trusted {
        if (newStrikethrough) {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) | TTF_STYLE_STRIKETHROUGH);
        }
        else {
            TTF_SetFontStyle(this.ttfFont, TTF_GetFontStyle(this.ttfFont) & ~TTF_STYLE_STRIKETHROUGH);
        }
    }

    /++
     + Wraps `TTF_GetFontOutline` to get the `dsdl.ttf.Font` outline value
     +
     + Returns: `uint` outline value of the `dsdl.ttf.Font`
     +/
    uint outline() const @property @trusted {
        return TTF_GetFontOutline(this.ttfFont).to!uint;
    }

    /++
     + Wraps `TTF_SetFontOutline` to set the `dsdl.ttf.Font` outline value
     +
     + Params:
     +   newOutline = new outline value for the `dsdl.ttf.Font`; `0` to set as default
     +/
    void outline(uint newOutline) @property @trusted {
        TTF_SetFontOutline(this.ttfFont, newOutline.to!int);
    }

    /++
     + Wraps `TTF_GetFontHinting` to get the `dsdl.ttf.Font` hinting
     +
     + Returns: `dsdl.ttf.Hinting` enumeration for the `dsdl.ttf.Font` hinting
     +/
    Hinting hinting() const @property @trusted {
        return cast(Hinting) TTF_GetFontHinting(this.ttfFont);
    }

    /++
     + Wraps `TTF_SetFontHinting` to set the `dsdl.ttf.Font` hinting
     +
     + Params:
     +   newHinting = new `dsdl.ttf.Hinting` for the `dsdl.ttf.Font`
     +/
    void hinting(Hinting newHinting) @property @trusted {
        TTF_SetFontHinting(this.ttfFont, newHinting);
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Wraps `TTF_GetFontSDF` (from SDL_ttf 2.0.18) to get whether the `dsdl.ttf.Font` has signed distance field
         +
         + Returns: `true` if the `dsdl.ttf.Font` has SDF, otherwise `false`
         +/
        bool sdf() const @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            return TTF_GetFontSDF(this.ttfFont) == SDL_TRUE;
        }

        /++
         + Wraps `TTF_SetFontSDF` (from SDL_ttf 2.0.18) to set signed distance field
         +
         + Params:
         +   newSDF = `true` to set SDF, otherwise `false`
         + Throws: `dsdl.SDLException` if unable to set SDF
         +/
        void sdf(bool newSDF) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            if (TTF_SetFontSDF(this.ttfFont, newSDF ? SDL_TRUE : SDL_FALSE) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `TTF_SetFontSize` (from SDL_ttf 2.0.18) to set the `dsdl.ttf.Font`'s size
         +
         + Params:
         +   newSize = new size for the `dsdl.ttf.Font`
         +/
        void size(uint newSize) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            if (TTF_SetFontSize(this.ttfFont, newSize.to!int) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `TTF_SetFontSizeDPI` (from SDL_ttf 2.0.18) to set the `dsdl.ttf.Font`'s size in DPI
         +
         + Params:
         +   newSizeDPI = new DPI size tuple of the font size, `hdpi`, and `vdpi`
         + Throws: `dsdl.SDLException` if unable to set size
         +/
        void sizeDPI(Tuple!(uint, uint, uint) newSizeDPI) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            if (TTF_SetFontSizeDPI(this.ttfFont, newSizeDPI[0].to!int, newSizeDPI[1], newSizeDPI[2]) != 0) {
                throw new SDLException;
            }
        }
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
        /++
         + Wraps `TTF_GetFontWrappedAlign` (from SDL_ttf 2.20) to get the `dsdl.ttf.Font`'s wrap alignment mode
         +
         + Returns: `dsdl.ttf.WrappedAlign` enumeration of the `dsdl.ttf.Font`
         +/
        WrappedAlign wrappedAlign() const @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }
        do {
            return cast(WrappedAlign) TTF_GetFontWrappedAlign(this.ttfFont);
        }

        /++
         + Wraps `TTF_SetFontWrappedAlign` (from SDL_ttf 2.20) to set the `dsdl.ttf.Font`'s wrap alignment mode
         +
         + Params:
         +   newWrappedAlign = new `dsdl.ttf.WrappedAlign` of the `dsdl.ttf.Font`
         +/
        void wrappedAlign(WrappedAlign newWrappedAlign) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }
        do {
            TTF_SetFontWrappedAlign(this.ttfFont, newWrappedAlign);
        }

        /++
         + Wraps `TTF_SetFontDirection` (from SDL_ttf 2.20) to set the `dsdl.ttf.Font`'s script direction
         +
         + Params:
         +   newDirection = new script `dsdl.ttf.Direction` for the `dsdl.ttf.Font`
         + Throws: `dsdl.SDLException` if unable to set script direction
         +/
        void direction(Direction newDirection) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }
        do {
            if (TTF_SetFontDirection(this.ttfFont, newDirection) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `TTF_SetFontScriptName` (from SDL_ttf 2.20) to set the `dsdl.ttf.Font`'s script name
         +
         + Params:
         +   newScriptName = new script name for the `dsdl.ttf.Font`
         + Throws: `dsdl.SDLException` if unable to set script name
         +/
        void scriptName(string newScriptName) @property @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }
        do {
            if (TTF_SetFontScriptName(this.ttfFont, newScriptName.toStringz()) != 0) {
                throw new SDLException;
            }
        }
    }

    /++
     + Wraps `TTF_FontHeight` to get the `dsdl.ttf.Font`'s height
     +
     + Returns: `int` height of the `dsdl.ttf.Font`
     +/
    int height() const @property @trusted {
        return TTF_FontHeight(this.ttfFont);
    }

    /++
     + Wraps `TTF_FontAscent` to get the `dsdl.ttf.Font`'s ascent
     +
     + Returns: `int` ascent of the `dsdl.ttf.Font`
     +/
    int ascent() const @property @trusted {
        return TTF_FontAscent(this.ttfFont);
    }

    /++
     + Wraps `TTF_FontDescent` to get the `dsdl.ttf.Font`'s descent
     +
     + Returns: `int` descent of the `dsdl.ttf.Font`
     +/
    int descent() const @property @trusted {
        return TTF_FontDescent(this.ttfFont);
    }

    /++
     + Wraps `TTF_FontLineSkip` to get the `dsdl.ttf.Font`'s line skip
     +
     + Returns: `int` line skip of the `dsdl.ttf.Font`
     +/
    int lineSkip() const @property @trusted {
        return TTF_FontLineSkip(this.ttfFont);
    }

    /++
     + Wraps `TTF_GetFontKerning` to get the `dsdl.ttf.Font`'s kerning
     +
     + Returns: `bool` whether the `dsdl.ttf.Font` has kerning
     +/
    bool kerning() const @property @trusted {
        return TTF_GetFontKerning(this.ttfFont) != 0;
    }

    /++
     + Wraps `TTF_SetFontKerning` to set the `dsdl.ttf.Font`'s kerning
     +
     + Params:
     +   newKerning = new `bool` value for the `dsdl.ttf.Font`'s kerning
     +/
    void kerning(bool newKerning) @property @trusted {
        TTF_SetFontKerning(this.ttfFont, newKerning ? 1 : 0);
    }

    /++
     + Wraps `TTF_FontFaces` to get the `dsdl.ttf.Font`'s number of font faces
     +
     + Returns: number of font faces of the `dsdl.ttf.Font`
     +/
    size_t faces() const @property @trusted {
        return TTF_FontFaces(this.ttfFont);
    }

    /++
     + Wraps `TTF_FontFaceIsFixedWidth` to check whether the `dsdl.ttf.Font`'s font face is fixed width
     +
     + Returns: `true` if the `dsdl.ttf.Font`'s font face is fixed width, otherwise `false`
     +/
    bool fixedWidth() const @property @trusted {
        return TTF_FontFaceIsFixedWidth(this.ttfFont) != 0;
    }

    /++
     + Wraps `TTF_FontFaceFamilyName` to get the `dsdl.ttf.Font` family name
     +
     + Returns: font family name of the `dsdl.ttf.Font`
     +/
    string familyName() const @property @trusted {
        return TTF_FontFaceFamilyName(this.ttfFont).to!string;
    }

    /++
     + Wraps `TTF_FontFaceStyleName` to get the `dsdl.ttf.Font` style name
     +
     + Returns: font style name of the `dsdl.ttf.Font`
     +/
    string styleName() const @property @trusted {
        return TTF_FontFaceStyleName(this.ttfFont).to!string;
    }

    /++
     + Wraps `TTF_GlyphIsProvided` to check whether the `dsdl.ttf.Font` provides a glyph
     +
     + Params:
     +   glyph = `wchar` glyph to check
     + Returns: `true` if the `dsdl.ttf.Font` provides the glyph, otherwise `false`
     +/
    bool providesGlyph(wchar glyph) const @trusted {
        return TTF_GlyphIsProvided(this.ttfFont, cast(ushort) glyph) != 0;
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Wraps `TTF_GlyphIsProvided32` (from SDL_ttf 2.0.18) to check whether the `dsdl.ttf.Font` provides a glyph
         +
         + Params:
         +   glyph = `dchar` glyph to check
         + Returns: `true` if the `dsdl.ttf.Font` provides the glyph, otherwise `false`
         +/
        bool providesGlyph(dchar glyph) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            return TTF_GlyphIsProvided32(cast(TTF_Font*) this.ttfFont, cast(uint) glyph) != 0;
        }
    }

    /++
     + Wraps `TTF_GlyphMetrics` to the metrics of a glyph in the `dsdl.ttf.Font`
     +
     + Params:
     +   glyph = `wchar` glyph to get the metrics of
     + Returns: `dsdl.ttf.GlyphMetrics` of the glyph
     + Throws: `dsdl.SDLException` if unable to get glyph metrics
     +/
    GlyphMetrics glyphMetrics(wchar glyph) const @trusted {
        GlyphMetrics metrics = void;
        if (TTF_GlyphMetrics(cast(TTF_Font*) this.ttfFont, cast(ushort) glyph, &metrics.min[0],
                &metrics.max[0], &metrics.min[1], &metrics.max[1], &metrics.advance) != 0) {
            throw new SDLException;
        }

        return metrics;
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Wraps `TTF_GlyphMetrics32` (from SDL_ttf 2.0.18) to the metrics of a glyph in the `dsdl.ttf.Font`
         +
         + Params:
         +   glyph = `dchar` glyph to get the metrics of
         + Returns: `dsdl.ttf.GlyphMetrics` of the glyph
         + Throws: `dsdl.SDLException` if unable to get glyph metrics
         +/
        GlyphMetrics glyphMetrics(dchar glyph) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            GlyphMetrics metrics = void;
            if (TTF_GlyphMetrics32(cast(TTF_Font*) this.ttfFont, cast(uint) glyph, &metrics.min[0],
                    &metrics.max[0], &metrics.min[1], &metrics.max[1], &metrics.advance) != 0) {
                throw new SDLException;
            }

            return metrics;
        }
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_14) {
        /++
         + Wraps `TTF_GetFontKerningSize` (from SDL_ttf 2.0.14) to get the kerning between two glyphs in the
         + `dsdl.ttf.Font`
         +
         + Params:
         +   prevGlyph = preceeding `wchar` glyph
         +   glyph = `wchar` glyph
         + Returns: kerning between `prevGlyph` and `glyph`
         +/
        int glyphKerning(wchar prevGlyph, wchar glyph) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 14));
        }
        do {
            return TTF_GetFontKerningSizeGlyphs(cast(TTF_Font*) this.ttfFont, //
                    cast(ushort) prevGlyph, cast(ushort) glyph);
        }
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Wraps `TTF_GetFontKerningSize` (from SDL_ttf 2.0.18) to get the kerning between two glyphs in the
         + `dsdl.ttf.Font`
         +
         + Params:
         +   prevGlyph = preceeding `dchar` glyph
         +   glyph = `dchar` glyph
         + Returns: kerning between `prevGlyph` and `glyph`
         +/
        int glyphKerning(dchar prevGlyph, dchar glyph) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            return TTF_GetFontKerningSizeGlyphs32(cast(TTF_Font*) this.ttfFont, cast(uint) prevGlyph, cast(uint) glyph);
        }
    }

    /++
     + Wraps `TTF_SizeUTF8` to get the size of a rendered text in the `dsdl.ttf.Font`
     +
     + Params:
     +   text = rendered `string` text to get the size of
     + Returns: the size of the rendered text (width and height)
     + Throws: `dsdl.SDLException` if unable to get text size
     +/
    uint[2] textSize(string text) const @trusted {
        uint[2] wh = void;
        if (TTF_SizeUTF8(cast(TTF_Font*) this.ttfFont, text.toStringz(), cast(int*)&wh[0], cast(int*)&wh[1]) != 0) {
            throw new SDLException;
        }

        return wh;
    }

    /++
     + Wraps `TTF_SizeUNICODE` to get the size of a rendered text in the `dsdl.ttf.Font`
     +
     + Params:
     +   text = rendered `wstring` text to get the size of
     + Returns: the size of the rendered text (width and height)
     + Throws: `dsdl.SDLException` if unable to get text size
     +/
    uint[2] textSize(wstring text) const @trusted {
        // `std.string.toStringz` doesn't have any `wstring` overloads.
        wchar[] ctext;
        ctext.length = text.length + 1;
        ctext[0 .. text.length] = text;
        ctext[text.length] = '\0';

        uint[2] wh = void;
        if (TTF_SizeUNICODE(cast(TTF_Font*) this.ttfFont, cast(ushort*) ctext.ptr,
                cast(int*)&wh[0], cast(int*)&wh[1]) != 0) {
            throw new SDLException;
        }

        return wh;
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        private alias TextMeasurement = Tuple!(uint, "extent", uint, "count");

        /++
         + Wraps `TTF_MeasureUTF8` (from SDL_ttf 2.0.18) to calculate the maximum number of characters from a text that
         + can be rendered given a maximum fitting width
         +
         + Params:
         +   text = `string` of characters to measure
         +   measureWidth = maximum fitting width
         + Returns: named tuple of `extent` (calculated width) and `count` (number of characters)
         + Throws: `dsdl.SDLException` if unable to measure text
         +/
        TextMeasurement measureText(string text, uint measureWidth) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            TextMeasurement measurement = void;
            if (TTF_MeasureUTF8(cast(TTF_Font*) this.ttfFont, text.toStringz(),
                    measureWidth.to!int, cast(int*)&measurement.extent, cast(int*)&measurement.count) != 0) {
                throw new SDLException;
            }

            return measurement;
        }

        /++
         + Wraps `TTF_MeasureUNICODE` (from SDL_ttf 2.0.18) to calculate the maximum number of characters from a text
         + that can be rendered given a maximum fitting width
         +
         + Params:
         +   text = `wstring` of characters to measure
         +   measureWidth = maximum fitting width
         + Returns: named tuple of `extent` (calculated width) and `count` (number of characters)
         + Throws: `dsdl.SDLException` if unable to measure text
         +/
        TextMeasurement measureText(wstring text, uint measureWidth) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }
        do {
            // `std.string.toStringz` doesn't have any `wstring` overloads.
            wchar[] ctext;
            ctext.length = text.length + 1;
            ctext[0 .. text.length] = text;
            ctext[text.length] = '\0';

            TextMeasurement measurement = void;
            if (TTF_MeasureUNICODE(cast(TTF_Font*) this.ttfFont, cast(ushort*) ctext.ptr,
                    measureWidth.to!int, cast(int*)&measurement[0], cast(int*)&measurement[1]) != 0) {
                throw new SDLException;
            }

            return measurement;
        }
    }

    /++
     + Wraps `TTF_RenderGlyph_Solid`, `TTF_RenderGlyph_Shaded`, `TTF_RenderGlyph_Blended`, and additionally
     + `TTF_RenderGlyph_LCD` (from SDL_ttf 2.20) to render a glyph in the `dsdl.ttf.Font`
     +
     + Params:
     +   glyph = `wchar` glyph to render
     +   foreground = foreground `dsdl.Color` of the glyph
     +   background = background `dsdl.Color` of the resulted surface (only for `RenderQuality.shaded` and
     +                `RenderQuality.lcd`)
     +   quality = `dsdl.ttf.RenderQuality` of the resulted render
     + Returns: `dsdl.Surface` containing the rendered glyph
     + Throws: `dsdl.SDLException` if failed to render glyph
     +/
    Surface render(wchar glyph, Color foreground, Color background = Color(0, 0, 0, 0),
            RenderQuality quality = RenderQuality.shaded) const @trusted
    in {
        if (quality == RenderQuality.lcd) {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }

        if (background != Color(0, 0, 0, 0)) {
            assert(quality == RenderQuality.shaded || quality == RenderQuality.lcd,
                    "Only shaded and LCD render quality" ~ " can have a background color.");
        }
    }
    do {
        SDL_Surface* sdlSurface;
        switch (quality) {
        case RenderQuality.solid:
            sdlSurface = TTF_RenderGlyph_Solid(cast(TTF_Font*) this.ttfFont,
                    cast(ushort) glyph, foreground.sdlColor);
            break;

        case RenderQuality.shaded:
            sdlSurface = TTF_RenderGlyph_Shaded(cast(TTF_Font*) this.ttfFont,
                    cast(ushort) glyph, foreground.sdlColor, background.sdlColor);
            break;

        case RenderQuality.blended:
            sdlSurface = TTF_RenderGlyph_Blended(cast(TTF_Font*) this.ttfFont,
                    cast(ushort) glyph, foreground.sdlColor);
            break;

        case RenderQuality.lcd:
            static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
                sdlSurface = TTF_RenderGlyph_LCD(cast(TTF_Font*) this.ttfFont, cast(ushort) glyph,
                        foreground.sdlColor, background.sdlColor);
                break;
            }
            assert(0);

        default:
            assert(0);
        }

        if (sdlSurface is null) {
            throw new SDLException;
        }

        return new Surface(sdlSurface);
    }

    static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
        /++
         + Wraps `TTF_RenderGlyph32_Solid`, `TTF_RenderGlyph32_Shaded`, `TTF_RenderGlyph32_Blended` (from SDL_ttf
         + 2.0.18), and additionally `TTF_RenderGlyph32_LCD` (from SDL_ttf 2.20) to render a glyph in the
         + `dsdl.ttf.Font`
         +
         + Params:
         +   glyph = `dchar` glyph to render
         +   foreground = foreground `dsdl.Color` of the glyph
         +   background = background `dsdl.Color` of the resulted surface (only for `RenderQuality.shaded` and
         +                `RenderQuality.lcd`)
         +   quality = `dsdl.ttf.RenderQuality` of the resulted render
         + Returns: `dsdl.Surface` containing the rendered glyph
         + Throws: `dsdl.SDLException` if failed to render glyph
         +/
        Surface render(dchar glyph, Color foreground, Color background = Color(0, 0, 0, 0),
                RenderQuality quality = RenderQuality.shaded) const @trusted
        in {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));

            if (quality == RenderQuality.lcd) {
                assert(dsdl.ttf.getVersion() >= Version(2, 20));
            }

            if (background != Color(0, 0, 0, 0)) {
                assert(quality == RenderQuality.shaded || quality == RenderQuality.lcd,
                        "Only shaded and LCD render " ~ "quality can have a background color.");
            }
        }
        do {
            SDL_Surface* sdlSurface;
            switch (quality) {
            case RenderQuality.solid:
                sdlSurface = TTF_RenderGlyph32_Solid(cast(TTF_Font*) this.ttfFont,
                        cast(uint) glyph, foreground.sdlColor);
                break;

            case RenderQuality.shaded:
                sdlSurface = TTF_RenderGlyph32_Shaded(cast(TTF_Font*) this.ttfFont,
                        cast(uint) glyph, foreground.sdlColor, background.sdlColor);
                break;

            case RenderQuality.blended:
                sdlSurface = TTF_RenderGlyph32_Blended(cast(TTF_Font*) this.ttfFont,
                        cast(uint) glyph, foreground.sdlColor);
                break;

            case RenderQuality.lcd:
                static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
                    sdlSurface = TTF_RenderGlyph32_LCD(cast(TTF_Font*) this.ttfFont,
                            cast(uint) glyph, foreground.sdlColor, background.sdlColor);
                    break;
                }
                assert(0);

            default:
                assert(0);
            }

            if (sdlSurface is null) {
                throw new SDLException;
            }

            return new Surface(sdlSurface);
        }
    }

    /++
     + Wraps `TTF_RenderUTF8_Solid`, `TTF_RenderUTF8_Shaded`, `TTF_RenderUTF8_Blended`, and additionally
     + `TTF_RenderUTF8_LCD` (from SDL_ttf 2.20), as well as `TTF_RenderUTF8_Solid_Wrapped`,
     + `TTF_RenderUTF8_Shaded_Wrapped`, `TTF_RenderUTF8_Blended_Wrapped` (from SDL_ttf 2.0.18),
     + and `TTF_RenderUTF8_LCD_Wrapped` (from SDL_ttf 2.20) to render a text string in the `dsdl.ttf.Font`
     +
     + Params:
     +   text = `string` text to render
     +   foreground = foreground `dsdl.Color` of the text
     +   background = background `dsdl.Color` of the resulted surface (only for `RenderQuality.shaded` and
     +                `RenderQuality.lcd`)
     +   quality = `dsdl.ttf.RenderQuality` of the resulted render
     +   wrapLength = maximum width in pixels for wrapping text to the new line; `0` to only wrap on line breaks
     +                (wrapping only available from SDL_ttf 2.0.18)
     + Returns: `dsdl.Surface` containing the rendered text
     + Throws: `dsdl.SDLException` if failed to render text
     +/
    Surface render(string text, Color foreground, Color background = Color(0, 0, 0, 0),
            RenderQuality quality = RenderQuality.shaded, uint wrapLength = cast(uint)-1) const @trusted
    in {
        if (quality == RenderQuality.lcd) {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }

        if (wrapLength != cast(uint)-1) {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }

        if (background != Color(0, 0, 0, 0)) {
            assert(quality == RenderQuality.shaded || quality == RenderQuality.lcd,
                    "Only shaded and LCD render quality" ~ " can have a background color.");
        }
    }
    do {
        immutable char* ctext = text.toStringz();

        SDL_Surface* sdlSurface;
        switch (quality) {
        case RenderQuality.solid:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUTF8_Solid_Wrapped(cast(TTF_Font*) this.ttfFont, ctext,
                            foreground.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUTF8_Solid(cast(TTF_Font*) this.ttfFont, ctext, foreground.sdlColor);
            }
            break;

        case RenderQuality.shaded:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUTF8_Shaded_Wrapped(cast(TTF_Font*) this.ttfFont, ctext,
                            foreground.sdlColor, background.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUTF8_Shaded(cast(TTF_Font*) this.ttfFont, ctext,
                        foreground.sdlColor, background.sdlColor);
            }
            break;

        case RenderQuality.blended:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUTF8_Blended_Wrapped(cast(TTF_Font*) this.ttfFont,
                            ctext, foreground.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUTF8_Blended(cast(TTF_Font*) this.ttfFont, ctext, foreground.sdlColor);
            }
            break;

        case RenderQuality.lcd:
            static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
                if (wrapLength != cast(uint)-1) {
                    sdlSurface = TTF_RenderUTF8_LCD_Wrapped(cast(TTF_Font*) this.ttfFont, ctext,
                            foreground.sdlColor, background.sdlColor, wrapLength);
                }
                else {
                    sdlSurface = TTF_RenderUTF8_LCD(cast(TTF_Font*) this.ttfFont, ctext,
                            foreground.sdlColor, background.sdlColor);
                }
                break;
            }
            assert(0);

        default:
            assert(0);
        }

        if (sdlSurface is null) {
            throw new SDLException;
        }

        return new Surface(sdlSurface);
    }

    /++
     + Wraps `TTF_RenderUNICODE_Solid`, `TTF_RenderUNICODE_Shaded`, `TTF_RenderUNICODE_Blended`, and additionally
     + `TTF_RenderUNICODE_LCD` (from SDL_ttf 2.20), as well as `TTF_RenderUNICODE_Solid_Wrapped`,
     + `TTF_RenderUNICODE_Shaded_Wrapped`, `TTF_RenderUNICODE_Blended_Wrapped` (from SDL_ttf 2.0.18),
     + and `TTF_RenderUNICODE_LCD_Wrapped` (from SDL_ttf 2.20) to render a text string in the `dsdl.ttf.Font`
     +
     + Params:
     +   text = `wstring` text to render
     +   foreground = foreground `dsdl.Color` of the text
     +   background = background `dsdl.Color` of the resulted surface (only for `RenderQuality.shaded` and
     +                `RenderQuality.lcd`)
     +   quality = `dsdl.ttf.RenderQuality` of the resulted render
     +   wrapLength = maximum width in pixels for wrapping text to the new line; `0` to only wrap on line breaks
     +                (wrapping only available from SDL_ttf 2.0.18)
     + Returns: `dsdl.Surface` containing the rendered text
     + Throws: `dsdl.SDLException` if failed to render text
     +/
    Surface render(wstring text, Color foreground, Color background = Color(0, 0, 0, 0),
            RenderQuality quality = RenderQuality.shaded, uint wrapLength = cast(uint)-1) const @trusted
    in {
        if (quality == RenderQuality.lcd) {
            assert(dsdl.ttf.getVersion() >= Version(2, 20));
        }

        if (wrapLength != cast(uint)-1) {
            assert(dsdl.ttf.getVersion() >= Version(2, 0, 18));
        }

        if (background != Color(0, 0, 0, 0)) {
            assert(quality == RenderQuality.shaded || quality == RenderQuality.lcd,
                    "Only shaded and LCD render quality" ~ " can have a background color.");
        }
    }
    do {
        // `std.string.toStringz` doesn't have any `wstring` overloads.
        wchar[] ctext;
        ctext.length = text.length + 1;
        ctext[0 .. text.length] = text;
        ctext[text.length] = '\0';

        SDL_Surface* sdlSurface;
        switch (quality) {
        case RenderQuality.solid:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUNICODE_Solid_Wrapped(cast(TTF_Font*) this.ttfFont,
                            cast(ushort*) ctext.ptr, foreground.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUNICODE_Solid(cast(TTF_Font*) this.ttfFont,
                        cast(ushort*) ctext.ptr, foreground.sdlColor);
            }
            break;

        case RenderQuality.shaded:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUNICODE_Shaded_Wrapped(cast(TTF_Font*) this.ttfFont,
                            cast(ushort*) ctext.ptr, foreground.sdlColor, background.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUNICODE_Shaded(cast(TTF_Font*) this.ttfFont,
                        cast(ushort*) ctext.ptr, foreground.sdlColor, background.sdlColor);
            }
            break;

        case RenderQuality.blended:
            if (wrapLength != cast(uint)-1) {
                static if (sdlTTFSupport >= SDLTTFSupport.v2_0_18) {
                    sdlSurface = TTF_RenderUNICODE_Blended_Wrapped(cast(TTF_Font*) this.ttfFont,
                            cast(ushort*) ctext.ptr, foreground.sdlColor, wrapLength);
                }
            }
            else {
                sdlSurface = TTF_RenderUNICODE_Blended(cast(TTF_Font*) this.ttfFont,
                        cast(ushort*) ctext.ptr, foreground.sdlColor);
            }
            break;

        case RenderQuality.lcd:
            static if (sdlTTFSupport >= SDLTTFSupport.v2_20) {
                if (wrapLength != cast(uint)-1) {
                    sdlSurface = TTF_RenderUNICODE_LCD_Wrapped(cast(TTF_Font*) this.ttfFont,
                            cast(ushort*) ctext.ptr, foreground.sdlColor, background.sdlColor, wrapLength);
                }
                else {
                    sdlSurface = TTF_RenderUNICODE_LCD(cast(TTF_Font*) this.ttfFont,
                            cast(ushort*) ctext.ptr, foreground.sdlColor, background.sdlColor);
                }
                break;
            }
            assert(0);

        default:
            assert(0);
        }

        if (sdlSurface is null) {
            throw new SDLException;
        }

        return new Surface(sdlSurface);
    }
}
