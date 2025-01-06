/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.blend;
@safe:

import bindbc.sdl;
import dsdl.sdl;

import std.format : format;

static if (sdlSupport >= SDLSupport.v2_0_6) {
    /++
     + D enum that wraps `SDL_BlendOperation` (from SDL 2.0.6) defining blending operations
     +/
    enum BlendOperation {
        /++
         + Wraps `SDL_BLENDOPERATION_*` enumeration constants
         +/
        add = SDL_BLENDOPERATION_ADD,
        subtract = SDL_BLENDOPERATION_SUBTRACT, /// ditto
        revSubtract = SDL_BLENDOPERATION_REV_SUBTRACT, /// ditto
        minimum = SDL_BLENDOPERATION_MINIMUM, /// ditto
        maximum = SDL_BLENDOPERATION_MAXIMUM /// ditto
    }

    /++
     + D enum that wraps `SDL_BlendFactor` (from SDL 2.0.6) defining blending multipliers
     +/
    enum BlendFactor {
        /++
         + Wraps `SDL_BLENDFACTOR_*` enumeration constants
         +/
        zero = SDL_BLENDFACTOR_ZERO,
        one = SDL_BLENDFACTOR_ONE, /// ditto
        srcColor = SDL_BLENDFACTOR_SRC_COLOR, /// ditto
        oneMinusSrcColor = SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR, /// ditto
        srcAlpha = SDL_BLENDFACTOR_SRC_ALPHA, /// ditto
        oneMinusSrcAlpha = SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA, /// ditto
        dstColor = SDL_BLENDFACTOR_DST_COLOR, /// ditto
        oneMinusDstColor = SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR, /// ditto
        dstAlpha = SDL_BLENDFACTOR_DST_ALPHA, /// ditto
        oneMinusDstAlpha = SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA /// ditto
    }
}

/++
 + D struct that wraps `SDL_BlendMode` defining how blending should be done when an image is drawn on top of
 + another
 +/
struct BlendMode {
    /++
     + Preexisting built-in `dsdl.BlendMode`s from `SDL_BLENDMODE_*` enumeration constants
     +/
    static immutable none = BlendMode(SDL_BLENDMODE_NONE);
    static immutable blend = BlendMode(SDL_BLENDMODE_BLEND); /// ditto
    static immutable add = BlendMode(SDL_BLENDMODE_ADD); /// ditto
    static immutable mod = BlendMode(SDL_BLENDMODE_MOD); /// ditto
    static if (sdlSupport >= SDLSupport.v2_0_12) {
        static immutable mul = BlendMode(SDL_BLENDMODE_MUL); /// ditto
    }

    SDL_BlendMode sdlBlendMode; /// Internal `SDL_BlendMode` enumeration

    this() @disable;

    /++
     + Constructs a `dsdl.BlendMode` from a vanilla `SDL_BlendMode` from bindbc-sdl
     +
     + Params:
     +   sdlBlendMode = the `SDL_BlendMode` enumeration
     +/
    this(SDL_BlendMode sdlBlendMode) {
        this.sdlBlendMode = sdlBlendMode;
    }

    static if (sdlSupport >= SDLSupport.v2_0_6) {
        /++
         + Composes a custom `dsdl.BlendMode` based on certain attributes for blending which wraps
         + `SDL_ComposeCustomBlendMode` (from SDL 2.0.6)
         +
         + Params:
         +   srcColorFactor = multipliers to the color components of the source
         +   dstColorFactor = multipliers to the color components of the destination
         +   colorOperation = operation to perform on the multiplied color components of the source and destination
         +   srcAlphaFactor = multiplier to the alpha component of the source
         +   dstAlphaFactor = multiplier to the color component of the destination
         +   alphaOperation = operation to perform on the multiplied alpha components of the source and destination
         + Throws: `dsdl.SDLException` if impossible to compose the `dsdl.BlendMode`
         +/
        this(BlendFactor srcColorFactor, BlendFactor dstColorFactor, BlendOperation colorOperation,
                BlendFactor srcAlphaFactor, BlendFactor dstAlphaFactor, BlendOperation alphaOperation) @trusted
        in {
            assert(getVersion() >= Version(2, 0, 6));
        }
        do {

            this.sdlBlendMode = SDL_ComposeCustomBlendMode(srcColorFactor, dstColorFactor,
                    colorOperation, srcAlphaFactor, dstAlphaFactor, alphaOperation);
            if (this.sdlBlendMode != SDL_BLENDMODE_INVALID) {
                throw new SDLException("Invalid BlendMode composition", __FILE__, __LINE__);
            }
        }
    }

    invariant {
        static if (sdlSupport >= SDLSupport.v2_0_6) {
            assert(this.sdlBlendMode != SDL_BLENDMODE_INVALID);
        }
    }

    /++
     + Formats the `dsdl.BlendMode` into its construction representation: `"dsdl.Color(<sdlBlendMode>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.BlendMode(%d)".format(this.sdlBlendMode);
    }
}
