/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.mouse;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.surface;
import dsdl.window;

import core.memory : GC;
import std.bitmanip : bitfields;
import std.format : format;

/++
 + Wraps `SDL_GetMouseFocus` which gets the mouse-focused window
 +
 + This function is marked as `@system` due to the potential of referencing invalid memory.
 +
 + Returns: `dsdl.Window` proxy of the window with the mouse focus; `null` if no window is focused
 +/
Window getMouseFocusedWindow() @system {
    SDL_Window* sdlWindow = SDL_GetMouseFocus();
    if (sdlWindow is null) {
        return null;
    }

    return new Window(sdlWindow, false);
}

/++
 + Wraps `SDL_GetMouseState` which gets the states of the mouse buttons
 +
 + Returns: `dsdl.MouseState` specifying the pressed-states of the mouse buttons
 +/
MouseState getMouseState() @trusted {
    return MouseState(SDL_GetMouseState(null, null));
}

/++
 + Wraps `SDL_GetMouseState` which gets the mouse position relative to a focused window
 +
 + Returns: coordinate of the mouse in the focused window
 +/
int[2] getMousePosition() @trusted {
    int[2] pos = void;
    SDL_GetMouseState(&pos[0], &pos[1]);
    return pos;
}

/++
 + Wraps `SDL_WarpMouseInWindow` which sets the mouse position relative to a focused window
 +
 + Params:
 +   newPosition = new coordinate of the mouse in the focused window
 +/
void setMousePosition(int[2] newPosition) @trusted {
    SDL_Window* window = SDL_GetMouseFocus();
    if (window !is null) {
        SDL_WarpMouseInWindow(window, newPosition[0], newPosition[1]);
    }
}

/++
 + Wraps `SDL_GetRelativeMouseMode` which checks whether relative mouse mode is enabled or not
 +
 + Returns: `true` if relative mouse mode is enabled, otherwise `false`
 +/
bool getRelativeMouseMode() @trusted {
    return SDL_GetRelativeMouseMode() == SDL_TRUE;
}

/++
 + Wraps `SDL_SetRelativeMouseMode` which sets relative mouse mode
 +
 + Params:
 +   newRelativeMouseMode = `true` to enable relative mouse mode, otherwise `false`
 + Throws: `dsdl.SDLException` if failed to toggle relative mouse mode
 +/
void setRelativeMouseMode(bool newRelativeMouseMode) @trusted {
    if (SDL_SetRelativeMouseMode(newRelativeMouseMode) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_GetRelativeMouseState` which gets the relative states of the mouse buttons
 +
 + Returns: `dsdl.MouseState` specifying the relative pressed-states of the mouse buttons
 +/
MouseState getRelativeMouseState() @trusted {
    return MouseState(SDL_GetRelativeMouseState(null, null));
}

/++
 + Wraps `SDL_GetRelativeMouseState` which gets the relative mouse position
 +
 + Returns: relative coordinate of the mouse
 +/
int[2] getRelativeMousePosition() @trusted {
    int[2] pos = void;
    SDL_GetRelativeMouseState(&pos[0], &pos[1]);
    return pos;
}

static if (sdlSupport >= SDLSupport.v2_0_4) {
    /++
     + Wraps `SDL_CaptureMouse` (from SDL 2.0.4) which sets mouse capture
     +
     + Params:
     +   newMouseCapture = `true` to enable mouse capture, otherwise `false`
     + Throws: `dsdl.SDLException` if failed to toggle mouse capture
     +/
    void setMouseCapture(bool newMouseCapture) @trusted
    in {
        assert(getVersion() >= Version(2, 0, 4));
    }
    do {
        if (SDL_CaptureMouse(newMouseCapture) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GetGlobalMouseState` (from SDL 2.0.4) which gets the global states of the mouse buttons
     +
     + Returns: `dsdl.MouseState` specifying the global pressed-states of the mouse buttons
     +/
    MouseState getGlobalMouseState() @trusted
    in {
        assert(getVersion() >= Version(2, 0, 4));
    }
    do {
        return MouseState(SDL_GetGlobalMouseState(null, null));
    }

    /++
     + Wraps `SDL_GetGlobalMouseState` (from SDL 2.0.4) which gets the mouse position globally
     +
     + Returns: coordinate of the mouse in the display
     +/
    int[2] getGlobalMousePosition() @trusted
    in {
        assert(getVersion() >= Version(2, 0, 4));
    }
    do {
        int[2] pos = void;
        SDL_GetGlobalMouseState(&pos[0], &pos[1]);
        return pos;
    }

    /++
     + Wraps `SDL_WarpMouseGlobal` (from SDL 2.0.4) which sets the mouse position globally in the display
     +
     + Params:
     +   newPosition = new coordinate of the mouse in the display
     +/
    void setGlobalMousePosition(int[2] newPosition) @trusted
    in {
        assert(getVersion() >= Version(2, 0, 4));
    }
    do {
        SDL_WarpMouseGlobal(newPosition[0], newPosition[1]);
    }
}

/++
 + D enum that wraps `SDL_BUTTON_*` enumerations
 +/
enum MouseButton {
    /++
     + Wraps `SDL_BUTTON_*` enumeration constants
     +/
    left = SDL_BUTTON_LEFT,
    middle = SDL_BUTTON_MIDDLE, /// ditto
    right = SDL_BUTTON_RIGHT, /// ditto
    x1 = SDL_BUTTON_X1, /// ditto
    x2 = SDL_BUTTON_X2
}

static if (sdlSupport >= SDLSupport.v2_0_4) {
    /++
     + D enum that wraps `SDL_MOUSEWHEEL_*` enumerations (from SDL 2.0.4)
     +/
    enum MouseWheel {
        /++
         + Wraps `SDL_MOUSEWHEEL_*` enumeration constants
         +/
        normal = SDL_MOUSEWHEEL_NORMAL,
        flipped = SDL_MOUSEWHEEL_FLIPPED /// ditto
    }
}

/++
 + D struct that encapsulates mouse button state flags
 +/
struct MouseState {
    // dfmt off
    mixin(bitfields!(
            bool, "left", 1,
            bool, "middle", 1,
            bool, "right", 1,
            bool, "x1", 1,
            bool, "x2", 1,
            bool, "", 3));
    // dfmt on

    this() @disable;

    /++
     + Constructs a `dsdl.MouseState` from a vanilla SDL mouse state flag
     +
     + Params:
     +   sdlMouseState = the `uint` flag
     +/
    this(uint sdlMouseState) {
        this.left = (sdlMouseState & SDL_BUTTON_LMASK) != 0;
        this.middle = (sdlMouseState & SDL_BUTTON_MMASK) != 0;
        this.right = (sdlMouseState & SDL_BUTTON_RMASK) != 0;
        this.x1 = (sdlMouseState & SDL_BUTTON_X1MASK) != 0;
        this.x2 = (sdlMouseState & SDL_BUTTON_X2MASK) != 0;
    }

    /++
     + Constructs a `dsdl.MouseState` by providing the flags
     +
     + Params:
     +   base = base flag to assign (`0` for none)
     +   left = whether the left mouse button is pressed
     +   middle = whether the middle mouse button is pressed
     +   right = whether the right mouse button is pressed
     +   x1 = whether the X1 mouse button is pressed
     +   x2 = whether the X2 mouse button is pressed
     +/
    this(uint base, bool left = false, bool middle = false, bool right = false, bool x1 = false, bool x2 = false) {
        this(base);
        this.left = left;
        this.middle = middle;
        this.right = right;
        this.x1 = x1;
        this.x2 = x2;
    }

    /++
     + Formats the `dsdl.MouseState` into its construction representation:
     + `"dsdl.MouseState(<sdlMouseState>, <left>, <middle>, <right>, <x1>, <x2>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.MouseState(%d, %s, %s, %s, %s, %s)".format(this.sdlMouseState, this.left,
                this.middle, this.right, this.x1, this.x2);
    }

    /++
     + Gets the internal flag representation
     +
     + Returns: `uint` with the appropriate bitflags toggled
     +/
    uint sdlMouseState() const @property {
        // dfmt off
        return (this.left ? SDL_BUTTON_LMASK : 0)
         | (this.middle ? SDL_BUTTON_MMASK : 0)
         | (this.right ? SDL_BUTTON_RMASK : 0)
         | (this.x1 ? SDL_BUTTON_X1MASK : 0)
         | (this.x2 ? SDL_BUTTON_X2MASK : 0);
        // dfmt on
    }
}

/++
 + Wraps `SDL_GetCursor` which gets the current set cursor
 +
 + Returns: `dsdl.Cursor` proxy of the set cursor
 +/
Cursor getCursor() @trusted {
    return new Cursor(SDL_GetCursor(), false);
}

/++
 + Wraps `SDL_GetDefaultCursor` which gets the default cursor
 +
 + Returns: `dsdl.Cursor` proxy of the default cursor
 +/
Cursor getDefaultCursor() @trusted {
    return new Cursor(SDL_GetDefaultCursor(), false);
}

/++
 + Wraps `SDL_ShowCursor` which sets the visibility of the cursor
 +
 + Returns: `true` if cursor is visible, otherwise `false`
 +/
bool getCursorVisibility() @trusted {
    return SDL_ShowCursor(SDL_QUERY) == SDL_ENABLE;
}

/++
 + Wraps `SDL_ShowCursor` which sets the visibility of the cursor
 +
 + Params:
 +   visible = `true` to make cursor visible, otherwise `false`
 + Throws: `dsdl.SDLException` if failed to set cursor visibility
 +/
void setCursorVisibility(bool visible) @trusted {
    if (SDL_ShowCursor(visible ? SDL_ENABLE : SDL_DISABLE) < 0) {
        throw new SDLException;
    }
}

/++
 + D class that wraps `SDL_Cursor` which sets cursor appearance
 +/
final class Cursor {
    static Cursor _multiton(SDL_SystemCursor sdlSystemCursor)() @trusted {
        static Cursor cursor = null;
        if (cursor is null) {
            SDL_Cursor* sdlCursor = SDL_CreateSystemCursor(sdlSystemCursor);
            if (sdlCursor is null) {
                throw new SDLException;
            }

            cursor = new Cursor(sdlCursor);
        }

        return cursor;
    }

    /++
     + Retrieves one of the `dsdl.Cursor` system cursor presets from `SDL_SYSTEM_CURSOR_*` enumeration constants
     +/
    static alias systemArrow = _multiton!SDL_SYSTEM_CURSOR_ARROW; /// dutto
    static alias systemIBeam = _multiton!SDL_SYSTEM_CURSOR_IBEAM; /// ditto
    static alias systemWait = _multiton!SDL_SYSTEM_CURSOR_WAIT; /// ditto
    static alias systemCrosshair = _multiton!SDL_SYSTEM_CURSOR_CROSSHAIR; /// ditto
    static alias systemWaitArrow = _multiton!SDL_SYSTEM_CURSOR_WAITARROW; /// ditto
    static alias systemSizeNWSE = _multiton!SDL_SYSTEM_CURSOR_SIZENWSE; /// ditto
    static alias systemSizeNESW = _multiton!SDL_SYSTEM_CURSOR_SIZENESW; /// ditto
    static alias systemSizeWE = _multiton!SDL_SYSTEM_CURSOR_SIZEWE; /// ditto
    static alias systemSizeNS = _multiton!SDL_SYSTEM_CURSOR_SIZENS; /// ditto
    static alias systemSizeAll = _multiton!SDL_SYSTEM_CURSOR_SIZEALL; /// ditto
    static alias systemNo = _multiton!SDL_SYSTEM_CURSOR_NO; /// ditto
    static alias systemHand = _multiton!SDL_SYSTEM_CURSOR_HAND; /// ditto

    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_Cursor* sdlCursor = null; /// Internal `SDL_Cursor` pointer

    /++
     + Constructs a `dsdl.Cursor` from a vanilla `SDL_Cursor*` from bindbc-sdl
     +
     + Params:
     +   sdlCursor = the `SDL_Cursor` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_Cursor*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_Cursor* sdlCursor, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlCursor !is null);
    }
    do {
        this.sdlCursor = sdlCursor;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Constructs a `dsdl.Cursor` from a `dsdl.Surface`, which wraps `SDL_CreateColorCursor`
     +
     + Params:
     +   surface = surface image of the cursor
     +   hotPosition = pixel position of the cursor hotspot
     + Throws: `dsdl.Exception` if cursor creation failed
     +/
    this(Surface surface, uint[2] hotPosition) @trusted {
        this.sdlCursor = SDL_CreateColorCursor(surface.sdlSurface, hotPosition[0], hotPosition[1]);
        if (this.sdlCursor is null) {
            throw new SDLException;
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_FreeCursor(this.sdlCursor);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlCursor !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Cursor rhs) const @trusted {
        return this.sdlCursor is rhs.sdlCursor;
    }

    /++
     + Gets the hash of the `dsdl.Cursor`
     +
     + Returns: unique hash for the instance being the pointer of the internal `SDL_Cursor` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.sdlCursor;
    }

    /++
     + Formats the `dsdl.Cursor` into its construction representation: `"dsdl.Cursor(<sdlCursor>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.Cursor(0x%x)".format(this.sdlCursor);
    }

    /++
     + Wraps `SDL_SetCursor` which sets the `dsdl.Cursor` to be the cursor
     +/
    void set() const @trusted {
        SDL_SetCursor(cast(SDL_Cursor*) this.sdlCursor);
    }
}
