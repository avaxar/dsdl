/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.clipboard;
@safe:

import bindbc.sdl;
import dsdl.sdl;

import std.conv : to;
import std.string : toStringz;

/++
 + Wraps `SDL_GetClipboardText` which gets the text stored in the clipboard
 +
 + Returns: clipboard text content
 + Throws: `dsdl.SDLException` if the clipboard text failed to allocate on SDL's side
 +/
string getClipboard() @trusted {
    char* clipboard = SDL_GetClipboardText();
    scope (exit)
        SDL_free(clipboard);

    if (clipboard !is null) {
        return clipboard.to!string;
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_HasClipboardText` which checks whether the clipboard exists and contains a non-empty text string
 +
 + Returns: `true` if it exists and contains a non-empty string, otherwise `false`
 +/
bool hasClipboard() @trusted {
    return SDL_HasClipboardText() == SDL_TRUE;
}

/++
 + Wraps `SDL_SetClipboardText` which puts a string of text into the clipboard
 +
 + Params:
 +   text = `string` to put into the clipboard
 + Throws: `dsdl.SDLException` on fail when putting the string into the clipboard
 +/
void setClipboard(string text) @trusted {
    if (SDL_SetClipboardText(text.toStringz()) != 0) {
        throw new SDLException;
    }
}

static if (sdlSupport >= SDLSupport.v2_26) {
    /++
     + Wraps `SDL_GetPrimarySelectionText` (from SDL 2.26) which gets the text stored in the primary selection
     +
     + Returns: primary selection text content
     + Throws: `dsdl.SDLException` if the primary selection text failed to allocate on SDL's side
     +/
    string getPrimarySelection() @trusted
    in {
        assert(getVersion() >= Version(2, 26));
    }
    do {
        char* primarySelection = SDL_GetPrimarySelectionText();
        scope (exit)
            SDL_free(primarySelection);

        if (primarySelection !is null) {
            return primarySelection.to!string;
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_HasPrimarySelectionText` (from SDL 2.26) which checks whether the primary selection exists
     + and contains a non-empty text string
     +
     + Returns: `true` if it exists and contains a non-empty string, otherwise `false`
     +/
    bool hasPrimarySelection() @trusted
    in {
        assert(getVersion() >= Version(2, 26));
    }
    do {
        return SDL_HasPrimarySelectionText() == SDL_TRUE;
    }

    /++
     + Wraps `SDL_SetPrimarySelectionText` (from SDL 2.26) which puts a string of text into the primary
     + selection
     +
     + Params:
     +   text = `string` to put into the primary selection
     + Throws: `dsdl.SDLException` on fail when putting the string into the primary selection
     +/
    void setPrimarySelection(string text) @trusted
    in {
        assert(getVersion() >= Version(2, 26));
    }
    do {
        if (SDL_SetPrimarySelectionText(text.toStringz()) != 0) {
            throw new SDLException;
        }
    }
}
