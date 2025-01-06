/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.image;
@safe:

// dfmt off
import bindbc.sdl;
static if (bindSDLImage):
// dfmt on

import dsdl.sdl;
import dsdl.renderer;
import dsdl.surface;
import dsdl.texture;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.string : toStringz;

version (BindSDL_Static) {
}
else {
    /++
     + Loads the SDL2_image shared dynamic library, which wraps bindbc-sdl's `loadSDLImage` function
     +
     + Unless if bindbc-sdl is on static mode (by adding a `BindSDL_Static` version), this function will exist and must
     + be called before any calls are made to the library. Otherwise, a segfault will happen upon any function calls.
     +
     + Params:
     +   libName = name or path to look the SDL2_image SO/DLL for, otherwise `null` for default searching path
     + Throws: `dsdl.SDLException` if failed to find the library
     +/
    void loadSO(string libName = null) @trusted {
        SDLImageSupport current = libName is null ? loadSDLImage() : loadSDLImage(libName.toStringz());
        if (current == sdlImageSupport) {
            return;
        }

        import loader = bindbc.loader.sharedlib;

        string errors;
        foreach (info; loader.errors) {
            errors ~= "\n- " ~ info.error.to!string ~ ": " ~ info.message.to!string;
        }

        Version wanted = Version(sdlImageSupport);
        if (current == SDLImageSupport.noLibrary) {
            throw new SDLException("No SDL2_image library found, especially of version " ~ wanted.format() ~ errors,
                    __FILE__, __LINE__);
        }
        else {
            throw new SDLException("dsdl expects SDL_image " ~ wanted.format() ~ ", but got " ~ getVersion()
                    .format() ~ errors, __FILE__, __LINE__);
        }
    }
}

/++
 + Wraps `IMG_Init` which initializes selected SDL2_image image format subsystems
 +
 + Params:
 +   jpg = selects the `IMG_INIT_JPG` subsystem
 +   png = selects the `IMG_INIT_PNG` subsystem
 +   tif = selects the `IMG_INIT_TIF` subsystem
 +   webp = selects the `IMG_INIT_WEBP` subsystem
 +   jxl = selects the `IMG_INIT_JXL` subsystem (from SDL_image 2.6)
 +   avif = selects the `IMG_INIT_AVIF` subsystem (from SDL_image 2.6)
 +   everything = selects every available subsystem
 + Throws: `dsdl.SDLException` if any selected subsystem failed to initialize
 + Example:
 + ---
 + dsdl.image.init(everything : true);
 + ---
 +/
void init(bool jpg = false, bool png = false, bool tif = false, bool webp = false, bool jxl = false,
        bool avif = false, bool everything = false) @trusted
in {
    static if (sdlImageSupport < SDLImageSupport.v2_6) {
        assert(jxl == false);
        assert(avif == false);
    }
    else {
        if (jxl || avif) {
            assert(dsdl.image.getVersion() >= Version(2, 6));
        }
    }
}
do {
    int flags = 0;

    flags |= jpg ? IMG_INIT_JPG : 0;
    flags |= png ? IMG_INIT_PNG : 0;
    flags |= tif ? IMG_INIT_TIF : 0;
    flags |= webp ? IMG_INIT_WEBP : 0;
    flags |= everything ? IMG_INIT_JPG | IMG_INIT_PNG | IMG_INIT_TIF | IMG_INIT_WEBP : 0;

    static if (sdlImageSupport >= SDLImageSupport.v2_6) {
        flags |= jxl ? IMG_INIT_JXL : 0;
        flags |= avif ? IMG_INIT_AVIF : 0;
        flags |= everything ? IMG_INIT_JXL | IMG_INIT_AVIF : 0;
    }

    if ((IMG_Init(flags) & flags) != flags) {
        throw new SDLException;
    }
}

version (unittest) {
    static this() {
        import std.stdio;

        version (BindSDL_Static) {
        }
        else {
            dsdl.image.loadSO();
        }
        writeln("Testing with SDL_image ", getVersion().format(), " for binding version ",
                Version(sdlImageSupport).format(), "...");

        try {
            dsdl.image.init(everything: true);
        }
        catch (SDLException exc) {
            writeln("Initializing SDL_image resulted an error: ", exc.msg);
        }
    }
}

/++
 + Wraps `IMG_Quit` which entirely deinitializes SDL2_image
 +/
void quit() @trusted {
    IMG_Quit();
}

version (unittest) {
    static ~this() {
        dsdl.image.quit();
    }
}

/++
 + Wraps `IMG_Linked_version` which gets the version of the linked SDL2_image library
 +
 + Returns: `dsdl.Version` of the linked SDL2_image library
 +/
Version getVersion() @trusted {
    return Version(*IMG_Linked_Version());
}

/++
 + Wraps `IMG_Load` which loads an image from a filesystem path into a software `dsdl.Surface`
 +
 + Params:
 +   file = path to the image file
 + Returns: `dsdl.Surface` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Surface load(string file) @trusted {
    if (SDL_Surface* sdlSurface = IMG_Load(file.toStringz())) {
        return new Surface(sdlSurface);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_Load_RW` which loads an image from a data buffer into a software `dsdl.Surface`
 +
 + Params:
 +   data = data buffer of the image
 + Returns: `dsdl.Surface` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Surface loadRaw(const void[] data) @trusted {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    if (SDL_Surface* sdlSurface = IMG_Load_RW(sdlRWops, 1)) {
        return new Surface(sdlSurface);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_LoadTyped_RW` which loads a typed image from a data buffer into a software `dsdl.Surface`
 +
 + Params:
 +   data = data buffer of the image
 +   type = specified type of the image
 + Returns: `dsdl.Surface` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Surface loadRaw(const void[] data, string type) @trusted {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    if (SDL_Surface* sdlSurface = IMG_LoadTyped_RW(sdlRWops, 1, type.toStringz())) {
        return new Surface(sdlSurface);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_LoadTexture` which loads an image from a filesystem path into a hardware `dsdl.Texture`
 +
 + Params:
 +   renderer = given `dsdl.Renderer` to initialize the texture
 +   file = path to the image file
 + Returns: `dsdl.Texture` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Texture loadTexture(Renderer renderer, string file) @trusted
in {
    assert(renderer !is null);
}
do {
    if (SDL_Texture* sdlTexture = IMG_LoadTexture(renderer.sdlRenderer, file.toStringz())) {
        return new Texture(sdlTexture);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_LoadTexture_RW` which loads an image from a data buffer into a hardware `dsdl.Texture`
 +
 + Params:
 +   renderer = given `dsdl.Renderer` to initialize the texture
 +   data = data buffer of the image
 + Returns: `dsdl.Texture` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Texture loadTextureRaw(Renderer renderer, const void[] data) @trusted
in {
    assert(renderer !is null);
}
do {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    if (SDL_Texture* sdlTexture = IMG_LoadTexture_RW(renderer.sdlRenderer, sdlRWops, 1)) {
        return new Texture(sdlTexture);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_LoadTextureTyped_RW` which loads a typed image from a data buffer into a hardware `dsdl.Texture`
 +
 + Params:
 +   renderer = given `dsdl.Renderer` to initialize the texture
 +   data = data buffer of the image
 +   type = specified type of the image
 + Returns: `dsdl.Texture` of the loaded image
 + Throws: `dsdl.SDLException` if failed to load the image
 +/
Texture loadTextureRaw(Renderer renderer, const void[] data, string type) @trusted
in {
    assert(renderer !is null);
}
do {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    if (SDL_Texture* sdlTexture = IMG_LoadTextureTyped_RW(renderer.sdlRenderer, sdlRWops, 1, type.toStringz())) {
        return new Texture(sdlTexture);
    }
    else {
        throw new SDLException;
    }
}

bool _isType(alias func, ubyte minMinorVer = 0, ubyte minPatchVer = 0)(const void[] data) @trusted
in {
    assert(dsdl.image.getVersion() >= Version(2, minMinorVer, minPatchVer));
}
do {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }
    scope (exit)
        if (SDL_RWclose(sdlRWops) != 0) {
            throw new SDLException;
        }

    return func(sdlRWops) != 0;
}

alias isICO = _isType!IMG_isICO; /// Wraps `IMG_isICO` which checks whether `data` is an ICO file
alias isCUR = _isType!IMG_isCUR; /// Wraps `IMG_isCUR` which checks whether `data` is a CUR file
alias isBMP = _isType!IMG_isBMP; /// Wraps `IMG_isBMP` which checks whether `data` is a BMP file
alias isGIF = _isType!IMG_isGIF; /// Wraps `IMG_isGIF` which checks whether `data` is a GIF file
alias isJPG = _isType!IMG_isJPG; /// Wraps `IMG_isJPG` which checks whether `data` is a JPG file
alias isLBM = _isType!IMG_isLBM; /// Wraps `IMG_isLBM` which checks whether `data` is a LBM file
alias isPCX = _isType!IMG_isPCX; /// Wraps `IMG_isPCX` which checks whether `data` is a PCX file
alias isPNG = _isType!IMG_isPNG; /// Wraps `IMG_isPNG` which checks whether `data` is a PNG file
alias isPNM = _isType!IMG_isPNM; /// Wraps `IMG_isPNM` which checks whether `data` is a PNM file
alias isTIF = _isType!IMG_isTIF; /// Wraps `IMG_isTIF` which checks whether `data` is a TIF file
alias isXCF = _isType!IMG_isXCF; /// Wraps `IMG_isXCF` which checks whether `data` is an XCF file
alias isXPM = _isType!IMG_isXPM; /// Wraps `IMG_isXPM` which checks whether `data` is an XPM file
alias isXV = _isType!IMG_isXV; /// Wraps `IMG_isXV` which checks whether `data` is an XV file
alias isWEBP = _isType!IMG_isWEBP; /// Wraps `IMG_isWEBP` which checks whether `data` is a WEBP file

static if (sdlImageSupport >= SDLImageSupport.v2_0_2) {
    alias isSVG = _isType!(IMG_isSVG, 0, 2); /// Wraps `IMG_isSVG` which checks whether `data` is a SVG file (from SDL_image 2.0.2)
}

static if (sdlImageSupport >= SDLImageSupport.v2_6) {
    alias isAVIF = _isType!(IMG_isAVIF, 6); /// Wraps `IMG_isAVIF` which checks whether `data` is an AVIF file (from SDL_image 2.6)
    alias isJXL = _isType!(IMG_isJXL, 6); /// Wraps `IMG_isJXL` which checks whether `data` is a JXL file (from SDL_image 2.6)
    alias isQOI = _isType!(IMG_isQOI, 6); /// Wraps `IMG_isQOI` which checks whether `data` is a QOI file (from SDL_image 2.6)
}

Surface _loadTypeRaw(alias func, ubyte minMinorVer = 0, ubyte minPatchVer = 0)(const void[] data) @trusted
in {
    assert(dsdl.image.getVersion() >= Version(2, minMinorVer, minPatchVer));
}
do {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }
    scope (exit)
        if (SDL_RWclose(sdlRWops) != 0) {
            throw new SDLException;
        }

    if (SDL_Surface* sdlSurface = func(sdlRWops)) {
        return new Surface(sdlSurface);
    }
    else {
        throw new SDLException;
    }
}

alias loadICORaw = _loadTypeRaw!IMG_LoadICO_RW; /// Wraps `IMG_LoadICO_RW` which loads `data` as an ICO image to surface
alias loadCURRaw = _loadTypeRaw!IMG_LoadCUR_RW; /// Wraps `IMG_LoadCUR_RW` which loads `data` as a CUR image to surface
alias loadBMPRaw = _loadTypeRaw!IMG_LoadBMP_RW; /// Wraps `IMG_LoadBMP_RW` which loads `data` as a BMP image to surface
alias loadGIFRaw = _loadTypeRaw!IMG_LoadGIF_RW; /// Wraps `IMG_LoadGIF_RW` which loads `data` as a GIF image to surface
alias loadJPGRaw = _loadTypeRaw!IMG_LoadJPG_RW; /// Wraps `IMG_LoadJPG_RW` which loads `data` as a JPG image to surface
alias loadLBRaw = _loadTypeRaw!IMG_LoadLBM_RW; /// Wraps `IMG_LoadLBM_RW` which loads `data` as a LBM image to surface
alias loadPCXRaw = _loadTypeRaw!IMG_LoadPCX_RW; /// Wraps `IMG_LoadPCX_RW` which loads `data` as a PCX image to surface
alias loadPNGRaw = _loadTypeRaw!IMG_LoadPNG_RW; /// Wraps `IMG_LoadPNG_RW` which loads `data` as a PNG image to surface
alias loadPNMRaw = _loadTypeRaw!IMG_LoadPNM_RW; /// Wraps `IMG_LoadPNM_RW` which loads `data` as a PNM image to surface
alias loadTIFRaw = _loadTypeRaw!IMG_LoadTIF_RW; /// Wraps `IMG_LoadTIF_RW` which loads `data` as a TIF image to surface
alias loadXCFRaw = _loadTypeRaw!IMG_LoadXCF_RW; /// Wraps `IMG_LoadXCF_RW` which loads `data` as an XCF image to surface
alias loadXPMRaw = _loadTypeRaw!IMG_LoadXPM_RW; /// Wraps `IMG_LoadXPM_RW` which loads `data` as an XPM image to surface
alias loadXVRaw = _loadTypeRaw!IMG_LoadXV_RW; /// Wraps `IMG_LoadXV_RW` which loads `data` as an XV image as surface
alias loadWEBPRaw = _loadTypeRaw!IMG_LoadWEBP_RW; /// Wraps `IMG_LoadWEBP_RW` which loads `data` as a WEBP image to surface

static if (sdlImageSupport >= SDLImageSupport.v2_0_2) {
    alias loadSVGRaw = _loadTypeRaw!(IMG_LoadSVG_RW, 0, 2); /// Wraps `IMG_LoadSVG_RW` which loads `data` as a SVG image (from SDL_image 2.0.2)
}

static if (sdlImageSupport >= SDLImageSupport.v2_6) {
    alias loadAVIFRaw = _loadTypeRaw!(IMG_LoadAVIF_RW, 6); /// Wraps `IMG_LoadAVIF_RW` which loads `data` as an AVIF image (from SDL_image 2.6)
    alias loadJXLRaw = _loadTypeRaw!(IMG_LoadJXL_RW, 6); /// Wraps `IMG_LoadJXL_RW` which loads `data` as a JXL image (from SDL_image 2.6)
    alias loadQOIRaw = _loadTypeRaw!(IMG_LoadQOI_RW, 6); /// Wraps `IMG_LoadQOI_RW` which loads `data` as a QOI image (from SDL_image 2.6)

    /++
     + Wraps `IMG_LoadSizedSVG_RW` (from SDL_image 2.6) which loads a `dsdl.Surface` image from a buffer of SVG file
     + format, while providing the desired flattened size of the vector image
     +
     + Params:
     +   data = data buffer of the image
     +   size = desized size in pixels (width and height) of the flattened SVG image; `0` to either one of the
     +          dimensions to be adjusted for aspect ratio
     + Returns: `dsdl.Surface` of the loaded image
     + Throws: `dsdl.SDLException` if failed to load
     +/
    Surface loadSizedSVGRaw(const void[] data, uint[2] size) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 6));
    }
    do {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }
        scope (exit)
            if (SDL_RWclose(sdlRWops) != 0) {
                throw new SDLException;
            }

        if (SDL_Surface* sdlSurface = IMG_LoadSizedSVG_RW(sdlRWops, size[0].to!int, size[1].to!int)) {
            return new Surface(sdlSurface);
        }
        else {
            throw new SDLException;
        }
    }
}

/++
 + Wraps `IMG_SavePNG` which saves a `dsdl.Surface` image into a PNG file in the filesystem
 +
 + Params:
 +   surface = given `dsdl.Surface` of the image to save
 +   file = target file path to save
 + Throws: `dsdl.SDLException` if failed to save
 +/
void savePNG(Surface surface, string file) @trusted
in {
    assert(surface !is null);
}
do {
    if (IMG_SavePNG(surface.sdlSurface, file.toStringz()) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `IMG_SavePNG_RW` which saves a `dsdl.Surface` image into a buffer of PNG file format
 +
 + Params:
 +   surface = given `dsdl.Surface` of the image to save
 + Returns: `dsdl.SDLException` if failed to save
 +/
void[] savePNGRaw(Surface surface) @trusted
in {
    assert(surface !is null);
}
do {
    // TODO: Too much trouble than it's worth

    // SDL_RWops* rw = SDL_RWFromMem(null, 0);
    // if (rw is null) {
    //     throw new SDLException;
    // }
    // scope (exit)
    //     SDL_FreeRW(rw);

    // if (IMG_SavePNG_RW(surface.sdlSurface, rw, 1) != 0) {
    //     throw new SDLException;
    // }

    // SDL_RWseek(rw, 0, RW_SEEK_END);
    // void[] buffer = new void[cast(size_t) SDL_RWtell(rw)];
    // SDL_RWseek(rw, 0, RW_SEEK_SET);

    // SDL_RWread(rw, buffer.ptr, buffer.length, 1);
    // return buffer;

    import std.stdio;

    File tmpfile = File.tmpfile();
    scope (exit)
        tmpfile.close();

    if (IMG_SavePNG_RW(surface.sdlSurface, SDL_RWFromFP(tmpfile.getFP(), false), 1) != 0) {
        throw new SDLException;
    }

    tmpfile.seek(0, SEEK_END);
    void[] buffer = new void[cast(size_t) tmpfile.tell()];

    tmpfile.seek(0);
    buffer = tmpfile.rawRead(buffer);

    return buffer;
}

static if (sdlImageSupport >= SDLImageSupport.v2_0_2) {
    /++
     + Wraps `IMG_SaveJPG` (from SDL_image 2.0.2) which saves a `dsdl.Surface` image into a JPG file in the filesystem
     +
     + Params:
     +   surface = given `dsdl.Surface` of the image to save
     +   file = target file path to save
     +   quality = value ranging from `0` to `100` specifying the image quality compensating for compression
     + Throws: `dsdl.SDLException` if failed to save
     +/
    void saveJPG(Surface surface, string file, ubyte quality) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 0, 2));
        assert(surface !is null);
    }
    do {
        if (IMG_SaveJPG(surface.sdlSurface, file.toStringz(), quality) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `IMG_SaveJPG_RW` (from SDL_image 2.0.2) which saves a `dsdl.Surface` image into a buffer of JPG file format
     +
     + Params:
     +   surface = given `dsdl.Surface` of the image to save
     +   quality = value ranging from `0` to `100` specifying the image quality compensating for compression
     + Returns: `dsdl.SDLException` if failed to save
     +/
    void[] saveJPGRaw(Surface surface, ubyte quality) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 0, 2));
        assert(surface !is null);
    }
    do {
        // TODO: make a writable `SDL_RWops` to dynamic memory

        import std.stdio;

        File tmpfile = File.tmpfile();
        scope (exit)
            tmpfile.close();

        if (IMG_SaveJPG_RW(surface.sdlSurface, SDL_RWFromFP(tmpfile.getFP(), false), 1, quality) != 0) {
            throw new SDLException;
        }

        tmpfile.seek(0, SEEK_END);
        void[] buffer = new void[cast(size_t) tmpfile.tell()];

        tmpfile.seek(0);
        buffer = tmpfile.rawRead(buffer);

        return buffer;
    }
}

static if (sdlImageSupport >= SDLImageSupport.v2_6) {
    /++
     + D class that wraps `IMG_Animation` (from SDL_image 2.6) storing multiple `dsdl.Surface`s of an animation
     +/
    class Animation {
        private Surface[] framesProxy = null;
        private bool isOwner = true;
        private void* userRef = null;

        @system IMG_Animation* imgAnimation = null; /// Internal `IMG_Animation` pointer

        /++
         + Constructs a `dsdl.image.Animation` from a vanilla `IMG_Animation*` from bindbc-sdl
         +
         + Params:
         +   imgAnimation = the `IMG_Animation` pointer to manage
         +   isOwner = whether the instance owns the given `IMG_Animation*` and should destroy it on its own
         +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
         +/
        this(IMG_Animation* imgAnimation, bool isOwner = true, void* userRef = null) @system
        in {
            assert(imgAnimation !is null);
        }
        do {
            this.imgAnimation = imgAnimation;
            this.isOwner = isOwner;
            this.userRef = userRef;
        }

        ~this() @trusted {
            if (this.isOwner) {
                IMG_FreeAnimation(this.imgAnimation);
            }
        }

        @trusted invariant { // @suppress(dscanner.trust_too_much)
            // Instance might be in an invalid state due to holding a non-owned externally-freed object when
            // destructed in an unpredictable order.
            if (!this.isOwner && GC.inFinalizer) {
                return;
            }

            assert(this.imgAnimation !is null);
        }

        /++
         + Equality operator overload
         +/
        bool opEquals(const Animation rhs) const @trusted {
            return this.imgAnimation is rhs.imgAnimation;
        }

        /++
         + Gets the hash of the `dsdl.image.Animation`
         +
         + Returns: unique hash for the instance being the pointer of the internal `IMG_Animation` pointer
         +/
        override hash_t toHash() const @trusted {
            return cast(hash_t) this.imgAnimation;
        }

        /++
         + Formats the `dsdl.image.Animation` into its construction representation:
         + `"dsdl.image.Animation(<imgAnimation>)"`
         +
         + Returns: the formatted `string`
         +/
        override string toString() const @trusted {
            return "dsdl.image.Animation(0x%x)".format(this.imgAnimation);
        }

        /++
         + Gets the width of the `dsdl.image.Animation` in pixels
         +
         + Returns: width of the `dsdl.image.Animation` in pixels
         +/
        uint width() const @property @trusted {
            return this.imgAnimation.w.to!uint;
        }

        /++
         + Gets the height of the `dsdl.image.Animation` in pixels
         +
         + Returns: height of the `dsdl.image.Animation` in pixels
         +/
        uint height() const @property @trusted {
            return this.imgAnimation.h.to!uint;
        }

        /++
         + Gets the size of the `dsdl.image.Animation` in pixels
         +
         + Returns: size of the `dsdl.image.Animation` in pixels
         +/
        uint[2] size() const @property @trusted {
            return [this.imgAnimation.w.to!uint, this.imgAnimation.h.to!uint];
        }

        /++
         + Gets the frame count of the `dsdl.image.Animation`
         +
         + Returns: frame count of the `dsdl.image.Animation`
         +/
        size_t count() const @property @trusted {
            return cast(size_t) this.imgAnimation.count;
        }

        /++
         + Gets an array of `dsdl.Surface` frames of the `dsdl.image.Animation`
         +
         + Returns: array of `dsdl.Surface` frames of the `dsdl.image.Animation`
         +/
        const(Surface[]) frames() const @property @trusted {
            if (this.framesProxy is null) {
                (cast(Animation) this).framesProxy = new Surface[this.count];
                foreach (i; 0 .. this.count) {
                    (cast(Animation) this).framesProxy[i] = new Surface(cast(SDL_Surface*) this.imgAnimation.frames[i],
                            false, cast(void*) this);
                }
            }

            return this.framesProxy;
        }

        /++
         + Gets an array of delay per frame of the `dsdl.image.Animation`
         +
         + Returns: array of delay per frame of the `dsdl.image.Animation`
         +/
        const(uint[]) delays() const @property @trusted {
            return (cast(uint*)&this.imgAnimation.delays)[0 .. this.count];
        }
    }

    /++
     + Wraps `IMG_LoadAnimation` (from SDL_image 2.6) which loads an animation from a filesystem path into an
     + `dsdl.image.Animation`
     +
     + Params:
     +   file = path to the animation file
     + Returns: `dsdl.image.Animation` of the loaded animated image
     + Throws: `dsdl.SDLException` if failed to load the animation
     +/
    Animation loadAnimation(string file) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 6));
    }
    do {
        if (IMG_Animation* imgAnimation = IMG_LoadAnimation(file.toStringz())) {
            return new Animation(imgAnimation);
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `IMG_LoadAnimation_RW` (from SDL_image 2.6) which loads an animation from a data buffer into a
     + `dsdl.image.Animation`
     +
     + Params:
     +   data = data buffer of the animation
     + Returns: `dsdl.image.Animation` of the loaded animated image
     + Throws: `dsdl.SDLException` if failed to load the animation
     +/
    Animation loadAnimationRaw(const void[] data) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 6));
    }
    do {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }

        if (IMG_Animation* imgAnimation = IMG_LoadAnimation_RW(sdlRWops, 1)) {
            return new Animation(imgAnimation);
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `IMG_LoadAnimationTyped_RW` (from SDL_image 2.6) which loads a typed image from a data buffer into a
     + `dsdl.image.Animation`
     +
     + Params:
     +   data = data buffer of the animation
     +   type = specified type of the animation
     + Returns: `dsdl.image.Animation` of the loaded animated image
     + Throws: `dsdl.SDLException` if failed to load the animation
     +/
    Animation loadAnimationTypedRaw(const void[] data, string type) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 6));
    }
    do {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }

        if (IMG_Animation* imgAnimation = IMG_LoadAnimationTyped_RW(sdlRWops, 1, type.toStringz())) {
            return new Animation(imgAnimation);
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `IMG_LoadGIFAnimation_RW` (from SDL_image 2.6) which loads a `dsdl.image.Animation` from a buffer of
     + animated GIF file format
     +
     + Params:
     +   data = data buffer of the animation
     + Returns: `dsdl.image.Animation` of the animated GIF
     + Throws: `dsdl.SDLException` if failed to load
     +/
    Animation loadGIFAnimationRaw(const void[] data) @trusted
    in {
        assert(dsdl.image.getVersion() >= Version(2, 6));
    }
    do {
        SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
        if (sdlRWops is null) {
            throw new SDLException;
        }
        scope (exit)
            if (SDL_RWclose(sdlRWops) != 0) {
                throw new SDLException;
            }

        if (IMG_Animation* imgAnimation = IMG_LoadGIFAnimation_RW(sdlRWops)) {
            return new Animation(imgAnimation);
        }
        else {
            throw new SDLException;
        }
    }
}
