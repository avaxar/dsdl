/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.keyboard;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.rect;
import dsdl.window;

import std.bitmanip : bitfields;
import std.format : format;

/++
 + Wraps `SDL_GetKeyboardFocus` which gets the keyboard-focused window
 +
 + This function is marked as `@system` due to the potential of referencing invalid memory.
 +
 + Returns: `dsdl.Window` proxy of the window with the keyboard focus; `null` if no window is focused
 +/
Window getKeyboardFocusedWindow() @system {
    SDL_Window* sdlWindow = SDL_GetKeyboardFocus();
    if (sdlWindow is null) {
        return null;
    }

    return new Window(sdlWindow, false);
}

/++
 + Wraps `SDL_GetKeyboardState` which gets the current key states of the keyboard
 +
 + Returns: `bool` array of whether the keys are pressed or not as indexed by `dsdl.Scancode`
 +/
const(bool[]) getKeyboardState() @trusted {
    int numKeys = void;
    ubyte* ptr = SDL_GetKeyboardState(&numKeys);
    return (cast(bool*) ptr)[0 .. numKeys];
}

/++
 + Wraps `SDL_GetModState` which gets the current modifier key states
 +
 + Returns: `dsdl.Keymod` containing whether the modifier keys are pressed or not
 +/
Keymod getModState() @trusted {
    return Keymod(SDL_GetModState());
}

/++
 + Wraps `SDL_GetScancodeFromKey` which gets the `dsdl.Scancode` from a `dsdl.Keycode`
 +
 + Params:
 +   keycode = the `dsdl.Keycode` enumeration
 + Returns: `dsdl.Scancode` equivalent
 +/
Scancode keycodeToScancode(Keycode keycode) @trusted {
    return cast(Scancode) SDL_GetScancodeFromKey(keycode);
}

/++
 + Wraps `SDL_GetKeyFromScancode` which gets the `dsdl.Keycode` from a `dsdl.Scancode`
 +
 + Params:
 +   scancode = the `dsdl.Scancode` enumeration
 + Returns: `dsdl.Keycode` equivalent
 +/
Keycode scancodeToKeycode(Scancode scancode) @trusted {
    return cast(Keycode) SDL_GetKeyFromScancode(scancode);
}

/++
 + Wraps `SDL_StartTextInput` which starts text input, invoking the IME if available
 +/
void startTextInput() @trusted {
    SDL_StartTextInput();
}

/++
 + Wraps `SDL_IsTextInputActive` which checks whether text input is active
 +/
bool isTextInputActive() @trusted {
    return SDL_IsTextInputActive() == SDL_TRUE;
}

/++
 + Wraps `SDL_StopTextInput` which stops text input, closing the IME if invoked prior
 +/
void stopTextInput() @trusted {
    SDL_StopTextInput();
}

/++
 + Wraps `SDL_HasScreenKeyboardSupport` which checks whether screen keyboard is supported
 +/
bool hasScreenKeyboardSupport() @trusted {
    return SDL_HasScreenKeyboardSupport() == SDL_TRUE;
}

/++
 + Wraps `SDL_SetTextInputRect` which sets the text input rectangle
 +/
void setTextInputRect(Rect rect) @trusted {
    SDL_SetTextInputRect(&rect.sdlRect);
}

static if (sdlSupport >= SDLSupport.v2_0_22) {
    /++
     + Wraps `SDL_ClearComposition` (from SDL 2.0.22) which clears any composition in the text input
     +/
    void clearComposition() @trusted
    in {
        assert(getVersion() >= Version(2, 0, 22));
    }
    do {
        SDL_ClearComposition();
    }

    /++
     + Wraps `SDL_IsTextInputShown` (from SDL 2.0.22) which checks whether the text input IME is shown
     +
     + Returns: `true` if the IME is shown, otherwise `false`
     +/
    bool isTextInputShown() @trusted
    in {
        assert(getVersion() >= Version(2, 0, 22));
    }
    do {
        return SDL_IsTextInputShown() == SDL_TRUE;
    }
}

static if (sdlSupport >= SDLSupport.v2_24) {
    /++
     + Wraps `SDL_ResetKeyboard` (from SDL 2.24) which resets the entire keyboard state
     +/
    void resetKeyboard() @trusted
    in {
        assert(getVersion() >= Version(2, 24));
    }
    do {
        SDL_ResetKeyboard();
    }
}

/++
 + D struct that wraps `SDL_Keymod` containing modifier key states
 +/
struct Keymod {
    // dfmt off
    mixin(bitfields!(
            bool, "lShift", 1,
            bool, "rShift", 1,
            bool, "lCtrl", 1,
            bool, "rCtrl", 1,
            bool, "lAlt", 1,
            bool, "rAlt", 1,
            bool, "lGUI", 1,
            bool, "rGUI", 1,
            bool, "num", 1,
            bool, "caps", 1,
            bool, "mode", 1,
            bool, "scroll", 1,
            ubyte, "", 4));
    // dfmt on

    this() @disable;

    /++
     + Constructs a `dsdl.Keymod` from a vanilla `SDL_Keymod` from bindbc-sdl
     +
     + Params:
     +   sdlKeymod = the `SDL_Keymod` flag
     +/
    this(SDL_Keymod sdlKeymod) {
        this.lShift = (sdlKeymod & KMOD_LSHIFT) != 0;
        this.rShift = (sdlKeymod & KMOD_RSHIFT) != 0;
        this.lCtrl = (sdlKeymod & KMOD_LCTRL) != 0;
        this.rCtrl = (sdlKeymod & KMOD_RCTRL) != 0;
        this.lAlt = (sdlKeymod & KMOD_LALT) != 0;
        this.rAlt = (sdlKeymod & KMOD_RALT) != 0;
        this.lGUI = (sdlKeymod & KMOD_LGUI) != 0;
        this.rGUI = (sdlKeymod & KMOD_RGUI) != 0;
        this.num = (sdlKeymod & KMOD_NUM) != 0;
        this.caps = (sdlKeymod & KMOD_CAPS) != 0;
        this.mode = (sdlKeymod & KMOD_MODE) != 0;
        this.scroll = (sdlKeymod & KMOD_SCROLL) != 0;
    }

    /++
     + Constructs a `dsdl.Keymod` by providing the flags
     +
     + Params:
     +   base = base `SDL_Keymod` to assign (Put `0` for none)
     +   lShift = whether the left shift key is pressed
     +   rShift = whether the right shift key is pressed
     +   lCtrl = whether the left ctrl key is pressed
     +   rCtrl = whether the right ctrl key is pressed
     +   lAlt = whether the left alt key is pressed
     +   rAlt = whether the right alt key is pressed
     +   lGUI = whether the left GUI/"Windows" key is pressed
     +   rGUI = whether the right GUI/"Windows" key is pressed
     +   num = whether num lock is toggled
     +   caps = whether caps lock is toggled
     +   mode = whether the AltGr keys are toggled
     +   scroll = whether scroll lock is toggled
     +/
    this(SDL_Keymod base, bool lShift = false, bool rShift = false, bool lCtrl = false, bool rCtrl = false,
            bool lAlt = false, bool rAlt = false, bool lGUI = false, bool rGUI = false, bool num = false,
            bool caps = false, bool mode = false, bool scroll = false) {
        this(base);
        this.lShift = lShift;
        this.rShift = rShift;
        this.lCtrl = lCtrl;
        this.rCtrl = rCtrl;
        this.lAlt = lAlt;
        this.rAlt = rAlt;
        this.lGUI = lGUI;
        this.rGUI = rGUI;
        this.num = num;
        this.caps = caps;
        this.mode = mode;
        this.scroll = scroll;
    }

    /++
     + Formats the `dsdl.Keymod` into its construction representation:
     + `"dsdl.Keymod(<sdlKeymod>, <lShift>, <rShift>, <lCtrl>, <rCtrl>, <lAlt>, <rAlt>, <lGUI>, <rGUI>, <num>, <caps>, <mode>, <scroll>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.Keymod(%d, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)".format(this.sdlKeymod,
                this.lShift, this.rShift, this.lCtrl, this.rCtrl, this.lAlt, this.rAlt,
                this.lGUI, this.rGUI, this.num, this.caps, this.mode, this.scroll);
    }

    /++
     + Gets the internal `SDL_Keymod` representation
     +
     + Returns: `SDL_Keymod` with the appropriate bitflags toggled
     +/
    SDL_Keymod sdlKeymod() const @property {
        // dfmt off
        return (this.lShift ? KMOD_LSHIFT : 0)
         | (this.rShift ? KMOD_RSHIFT : 0)
         | (this.lCtrl ? KMOD_LCTRL : 0)
         | (this.rCtrl ? KMOD_RCTRL : 0)
         | (this.lAlt ? KMOD_LALT : 0)
         | (this.rAlt ? KMOD_RALT : 0)
         | (this.lGUI ? KMOD_LGUI : 0)
         | (this.rGUI ? KMOD_RGUI : 0)
         | (this.num ? KMOD_NUM : 0)
         | (this.caps ? KMOD_CAPS : 0)
         | (this.mode ? KMOD_MODE : 0)
         | (this.scroll ? KMOD_SCROLL : 0);
        // dfmt on
    }

    /++
     + Checks whether either of the shift keys is pressed
     +
     + Returns: `lShift || rShift`
     +/
    bool shift() const @property {
        return this.lShift || this.rShift;
    }

    /++
     + Checks whether either of the ctrl keys is pressed
     +
     + Returns: `lCtrl || rCtrl`
     +/
    bool ctrl() const @property {
        return this.lCtrl || this.rCtrl;
    }

    /++
     + Checks whether either of the alt keys is pressed
     +
     + Returns: `lAlt || rAlt`
     +/
    bool alt() const @property {
        return this.lAlt || this.rAlt;
    }

    /++
     + Checks whether either of the GUI/"Windows" keys is pressed
     +
     + Returns: `lGUI || rGUI`
     +/
    bool gui() const @property {
        return this.lGUI || this.rGUI;
    }
}

/++
 + D enum that wraps `SDL_Scancode` defining keyboard scancodes
 +/
enum Scancode {
    /++
     + Wraps `SDL_SCANCODE_*` enumeration constants
     +/
    n0 = SDL_SCANCODE_0,
    n1 = SDL_SCANCODE_1, /// ditto
    n2 = SDL_SCANCODE_2, /// ditto
    n3 = SDL_SCANCODE_3, /// ditto
    n4 = SDL_SCANCODE_4, /// ditto
    n5 = SDL_SCANCODE_5, /// ditto
    n6 = SDL_SCANCODE_6, /// ditto
    n7 = SDL_SCANCODE_7, /// ditto
    n8 = SDL_SCANCODE_8, /// ditto
    n9 = SDL_SCANCODE_9, /// ditto
    a = SDL_SCANCODE_A, /// ditto
    acBack = SDL_SCANCODE_AC_BACK, /// ditto
    acBookmarks = SDL_SCANCODE_AC_BOOKMARKS, /// ditto
    acForward = SDL_SCANCODE_AC_FORWARD, /// ditto
    acHome = SDL_SCANCODE_AC_HOME, /// ditto
    acRefresh = SDL_SCANCODE_AC_REFRESH, /// ditto
    acSearch = SDL_SCANCODE_AC_SEARCH, /// ditto
    acStop = SDL_SCANCODE_AC_STOP, /// ditto
    again = SDL_SCANCODE_AGAIN, /// ditto
    altErase = SDL_SCANCODE_ALTERASE, /// ditto
    apostrophe = SDL_SCANCODE_APOSTROPHE, /// ditto
    application = SDL_SCANCODE_APPLICATION, /// ditto
    audioMute = SDL_SCANCODE_AUDIOMUTE, /// ditto
    audioNext = SDL_SCANCODE_AUDIONEXT, /// ditto
    audioPlay = SDL_SCANCODE_AUDIOPLAY, /// ditto
    audioPrev = SDL_SCANCODE_AUDIOPREV, /// ditto
    audioStop = SDL_SCANCODE_AUDIOSTOP, /// ditto
    b = SDL_SCANCODE_B, /// ditto
    backslash = SDL_SCANCODE_BACKSLASH, /// ditto
    backspace = SDL_SCANCODE_BACKSPACE, /// ditto
    brightnessDown = SDL_SCANCODE_BRIGHTNESSDOWN, /// ditto
    brightnessUp = SDL_SCANCODE_BRIGHTNESSUP, /// ditto
    c = SDL_SCANCODE_C, /// ditto
    calculator = SDL_SCANCODE_CALCULATOR, /// ditto
    cancel = SDL_SCANCODE_CANCEL, /// ditto
    capsLock = SDL_SCANCODE_CAPSLOCK, /// ditto
    clear = SDL_SCANCODE_CLEAR, /// ditto
    clearAgain = SDL_SCANCODE_CLEARAGAIN, /// ditto
    comma = SDL_SCANCODE_COMMA, /// ditto
    computer = SDL_SCANCODE_COMPUTER, /// ditto
    copy = SDL_SCANCODE_COPY, /// ditto
    crSel = SDL_SCANCODE_CRSEL, /// ditto
    currencySubUnit = SDL_SCANCODE_CURRENCYSUBUNIT, /// ditto
    currencyUnit = SDL_SCANCODE_CURRENCYUNIT, /// ditto
    cut = SDL_SCANCODE_CUT, /// ditto
    d = SDL_SCANCODE_D, /// ditto
    decimalSeparator = SDL_SCANCODE_DECIMALSEPARATOR, /// ditto
    delete_ = SDL_SCANCODE_DELETE, /// ditto
    displaySwitch = SDL_SCANCODE_DISPLAYSWITCH, /// ditto
    down = SDL_SCANCODE_DOWN, /// ditto
    e = SDL_SCANCODE_E, /// ditto
    eject = SDL_SCANCODE_EJECT, /// ditto
    end = SDL_SCANCODE_END, /// ditto
    equals = SDL_SCANCODE_EQUALS, /// ditto
    escape = SDL_SCANCODE_ESCAPE, /// ditto
    execute = SDL_SCANCODE_EXECUTE, /// ditto
    exSel = SDL_SCANCODE_EXSEL, /// ditto
    f = SDL_SCANCODE_F, /// ditto
    f1 = SDL_SCANCODE_F1, /// ditto
    f10 = SDL_SCANCODE_F10, /// ditto
    f11 = SDL_SCANCODE_F11, /// ditto
    f12 = SDL_SCANCODE_F12, /// ditto
    f13 = SDL_SCANCODE_F13, /// ditto
    f14 = SDL_SCANCODE_F14, /// ditto
    f15 = SDL_SCANCODE_F15, /// ditto
    f16 = SDL_SCANCODE_F16, /// ditto
    f17 = SDL_SCANCODE_F17, /// ditto
    f18 = SDL_SCANCODE_F18, /// ditto
    f19 = SDL_SCANCODE_F19, /// ditto
    f2 = SDL_SCANCODE_F2, /// ditto
    f20 = SDL_SCANCODE_F20, /// ditto
    f21 = SDL_SCANCODE_F21, /// ditto
    f22 = SDL_SCANCODE_F22, /// ditto
    f23 = SDL_SCANCODE_F23, /// ditto
    f24 = SDL_SCANCODE_F24, /// ditto
    f3 = SDL_SCANCODE_F3, /// ditto
    f4 = SDL_SCANCODE_F4, /// ditto
    f5 = SDL_SCANCODE_F5, /// ditto
    f6 = SDL_SCANCODE_F6, /// ditto
    f7 = SDL_SCANCODE_F7, /// ditto
    f8 = SDL_SCANCODE_F8, /// ditto
    f9 = SDL_SCANCODE_F9, /// ditto
    find = SDL_SCANCODE_FIND, /// ditto
    g = SDL_SCANCODE_G, /// ditto
    grave = SDL_SCANCODE_GRAVE, /// ditto
    h = SDL_SCANCODE_H, /// ditto
    help = SDL_SCANCODE_HELP, /// ditto
    home = SDL_SCANCODE_HOME, /// ditto
    i = SDL_SCANCODE_I, /// ditto
    insert = SDL_SCANCODE_INSERT, /// ditto
    j = SDL_SCANCODE_J, /// ditto
    k = SDL_SCANCODE_K, /// ditto
    kbdIllumDown = SDL_SCANCODE_KBDILLUMDOWN, /// ditto
    kbdIllumToggle = SDL_SCANCODE_KBDILLUMTOGGLE, /// ditto
    kbdIllumUp = SDL_SCANCODE_KBDILLUMUP, /// ditto
    kp0 = SDL_SCANCODE_KP_0, /// ditto
    kp00 = SDL_SCANCODE_KP_00, /// ditto
    kp000 = SDL_SCANCODE_KP_000, /// ditto
    kp1 = SDL_SCANCODE_KP_1, /// ditto
    kp2 = SDL_SCANCODE_KP_2, /// ditto
    kp3 = SDL_SCANCODE_KP_3, /// ditto
    kp4 = SDL_SCANCODE_KP_4, /// ditto
    kp5 = SDL_SCANCODE_KP_5, /// ditto
    kp6 = SDL_SCANCODE_KP_6, /// ditto
    kp7 = SDL_SCANCODE_KP_7, /// ditto
    kp8 = SDL_SCANCODE_KP_8, /// ditto
    kp9 = SDL_SCANCODE_KP_9, /// ditto
    kpA = SDL_SCANCODE_KP_A, /// ditto
    kpAmpersand = SDL_SCANCODE_KP_AMPERSAND, /// ditto
    kpAt = SDL_SCANCODE_KP_AT, /// ditto
    kpB = SDL_SCANCODE_KP_B, /// ditto
    kpBackspace = SDL_SCANCODE_KP_BACKSPACE, /// ditto
    kpBinary = SDL_SCANCODE_KP_BINARY, /// ditto
    kpC = SDL_SCANCODE_KP_C, /// ditto
    kpClear = SDL_SCANCODE_KP_CLEAR, /// ditto
    kpClearEntry = SDL_SCANCODE_KP_CLEARENTRY, /// ditto
    kpColon = SDL_SCANCODE_KP_COLON, /// ditto
    kpComma = SDL_SCANCODE_KP_COMMA, /// ditto
    kpD = SDL_SCANCODE_KP_D, /// ditto
    kpDblAmpersand = SDL_SCANCODE_KP_DBLAMPERSAND, /// ditto
    kpDblVerticalBar = SDL_SCANCODE_KP_DBLVERTICALBAR, /// ditto
    kpDecimal = SDL_SCANCODE_KP_DECIMAL, /// ditto
    kpDivide = SDL_SCANCODE_KP_DIVIDE, /// ditto
    kpE = SDL_SCANCODE_KP_E, /// ditto
    kpEnter = SDL_SCANCODE_KP_ENTER, /// ditto
    kpEquals = SDL_SCANCODE_KP_EQUALS, /// ditto
    kpEqualsAS400 = SDL_SCANCODE_KP_EQUALSAS400, /// ditto
    kpExclam = SDL_SCANCODE_KP_EXCLAM, /// ditto
    kpF = SDL_SCANCODE_KP_F, /// ditto
    kpGreater = SDL_SCANCODE_KP_GREATER, /// ditto
    kpHash = SDL_SCANCODE_KP_HASH, /// ditto
    kpHexadecimal = SDL_SCANCODE_KP_HEXADECIMAL, /// ditto
    kpLeftBrace = SDL_SCANCODE_KP_LEFTBRACE, /// ditto
    kpLeftParen = SDL_SCANCODE_KP_LEFTPAREN, /// ditto
    kpLess = SDL_SCANCODE_KP_LESS, /// ditto
    kpMemAdd = SDL_SCANCODE_KP_MEMADD, /// ditto
    kpMemClear = SDL_SCANCODE_KP_MEMCLEAR, /// ditto
    kpMemDivide = SDL_SCANCODE_KP_MEMDIVIDE, /// ditto
    kpMemMultiply = SDL_SCANCODE_KP_MEMMULTIPLY, /// ditto
    kpMemRecall = SDL_SCANCODE_KP_MEMRECALL, /// ditto
    kpMemStore = SDL_SCANCODE_KP_MEMSTORE, /// ditto
    kpMemSubtract = SDL_SCANCODE_KP_MEMSUBTRACT, /// ditto
    kpMinus = SDL_SCANCODE_KP_MINUS, /// ditto
    kpMultiply = SDL_SCANCODE_KP_MULTIPLY, /// ditto
    kpOctal = SDL_SCANCODE_KP_OCTAL, /// ditto
    kpPercent = SDL_SCANCODE_KP_PERCENT, /// ditto
    kpPeriod = SDL_SCANCODE_KP_PERIOD, /// ditto
    kpPlus = SDL_SCANCODE_KP_PLUS, /// ditto
    kpPlusMinus = SDL_SCANCODE_KP_PLUSMINUS, /// ditto
    kpPower = SDL_SCANCODE_KP_POWER, /// ditto
    kpRightBrace = SDL_SCANCODE_KP_RIGHTBRACE, /// ditto
    kpRightParen = SDL_SCANCODE_KP_RIGHTPAREN, /// ditto
    kpSpace = SDL_SCANCODE_KP_SPACE, /// ditto
    kpTab = SDL_SCANCODE_KP_TAB, /// ditto
    kpVerticalBar = SDL_SCANCODE_KP_VERTICALBAR, /// ditto
    kpXOR = SDL_SCANCODE_KP_XOR, /// ditto
    l = SDL_SCANCODE_L, /// ditto
    lAlt = SDL_SCANCODE_LALT, /// ditto
    lCtrl = SDL_SCANCODE_LCTRL, /// ditto
    left = SDL_SCANCODE_LEFT, /// ditto
    leftBracket = SDL_SCANCODE_LEFTBRACKET, /// ditto
    lGUI = SDL_SCANCODE_LGUI, /// ditto
    lShift = SDL_SCANCODE_LSHIFT, /// ditto
    m = SDL_SCANCODE_M, /// ditto
    mail = SDL_SCANCODE_MAIL, /// ditto
    mediaSelect = SDL_SCANCODE_MEDIASELECT, /// ditto
    menu = SDL_SCANCODE_MENU, /// ditto
    minus = SDL_SCANCODE_MINUS, /// ditto
    mode = SDL_SCANCODE_MODE, /// ditto
    mute = SDL_SCANCODE_MUTE, /// ditto
    n = SDL_SCANCODE_N, /// ditto
    numLockClear = SDL_SCANCODE_NUMLOCKCLEAR, /// ditto
    o = SDL_SCANCODE_O, /// ditto
    oper = SDL_SCANCODE_OPER, /// ditto
    out_ = SDL_SCANCODE_OUT, /// ditto
    p = SDL_SCANCODE_P, /// ditto
    pageDown = SDL_SCANCODE_PAGEDOWN, /// ditto
    pageUp = SDL_SCANCODE_PAGEUP, /// ditto
    paste = SDL_SCANCODE_PASTE, /// ditto
    pause = SDL_SCANCODE_PAUSE, /// ditto
    period = SDL_SCANCODE_PERIOD, /// ditto
    power = SDL_SCANCODE_POWER, /// ditto
    printScreen = SDL_SCANCODE_PRINTSCREEN, /// ditto
    prior = SDL_SCANCODE_PRIOR, /// ditto
    q = SDL_SCANCODE_Q, /// ditto
    r = SDL_SCANCODE_R, /// ditto
    rAlt = SDL_SCANCODE_RALT, /// ditto
    rCtrl = SDL_SCANCODE_RCTRL, /// ditto
    return1 = SDL_SCANCODE_RETURN, /// ditto
    return2 = SDL_SCANCODE_RETURN2, /// ditto
    rGUI = SDL_SCANCODE_RGUI, /// ditto
    right = SDL_SCANCODE_RIGHT, /// ditto
    rightBracket = SDL_SCANCODE_RIGHTBRACKET, /// ditto
    rShift = SDL_SCANCODE_RSHIFT, /// ditto
    s = SDL_SCANCODE_S, /// ditto
    scrollLock = SDL_SCANCODE_SCROLLLOCK, /// ditto
    select = SDL_SCANCODE_SELECT, /// ditto
    semicolon = SDL_SCANCODE_SEMICOLON, /// ditto
    separator = SDL_SCANCODE_SEPARATOR, /// ditto
    slash = SDL_SCANCODE_SLASH, /// ditto
    sleep = SDL_SCANCODE_SLEEP, /// ditto
    space = SDL_SCANCODE_SPACE, /// ditto
    stop = SDL_SCANCODE_STOP, /// ditto
    sysReq = SDL_SCANCODE_SYSREQ, /// ditto
    t = SDL_SCANCODE_T, /// ditto
    tab = SDL_SCANCODE_TAB, /// ditto
    thousandsSeparator = SDL_SCANCODE_THOUSANDSSEPARATOR, /// ditto
    u = SDL_SCANCODE_U, /// ditto
    undo = SDL_SCANCODE_UNDO, /// ditto
    unknown = SDL_SCANCODE_UNKNOWN, /// ditto
    up = SDL_SCANCODE_UP, /// ditto
    v = SDL_SCANCODE_V, /// ditto
    volumeDown = SDL_SCANCODE_VOLUMEDOWN, /// ditto
    volumeUp = SDL_SCANCODE_VOLUMEUP, /// ditto
    w = SDL_SCANCODE_W, /// ditto
    www = SDL_SCANCODE_WWW, /// ditto
    x = SDL_SCANCODE_X, /// ditto
    y = SDL_SCANCODE_Y, /// ditto
    z = SDL_SCANCODE_Z, /// ditto
    international1 = SDL_SCANCODE_INTERNATIONAL1, /// ditto
    international2 = SDL_SCANCODE_INTERNATIONAL2, /// ditto
    international3 = SDL_SCANCODE_INTERNATIONAL3, /// ditto
    international4 = SDL_SCANCODE_INTERNATIONAL4, /// ditto
    international5 = SDL_SCANCODE_INTERNATIONAL5, /// ditto
    international6 = SDL_SCANCODE_INTERNATIONAL6, /// ditto
    international7 = SDL_SCANCODE_INTERNATIONAL7, /// ditto
    international8 = SDL_SCANCODE_INTERNATIONAL8, /// ditto
    international9 = SDL_SCANCODE_INTERNATIONAL9, /// ditto
    lang1 = SDL_SCANCODE_LANG1, /// ditto
    lang2 = SDL_SCANCODE_LANG2, /// ditto
    lang3 = SDL_SCANCODE_LANG3, /// ditto
    lang4 = SDL_SCANCODE_LANG4, /// ditto
    lang5 = SDL_SCANCODE_LANG5, /// ditto
    lang6 = SDL_SCANCODE_LANG6, /// ditto
    lang7 = SDL_SCANCODE_LANG7, /// ditto
    lang8 = SDL_SCANCODE_LANG8, /// ditto
    lang9 = SDL_SCANCODE_LANG9, /// ditto
    nonUSBackslash = SDL_SCANCODE_NONUSBACKSLASH, /// ditto
    nonUSHash = SDL_SCANCODE_NONUSHASH /// ditto
}

/++
 + D enum that wraps `SDL_Keycode` defining virtual keys
 +/
enum Keycode {
    /++
     + Wraps `SDLK_*` enumeration constants
     +/
    n0 = SDLK_0,
    n1 = SDLK_1, /// ditto
    n2 = SDLK_2, /// ditto
    n3 = SDLK_3, /// ditto
    n4 = SDLK_4, /// ditto
    n5 = SDLK_5, /// ditto
    n6 = SDLK_6, /// ditto
    n7 = SDLK_7, /// ditto
    n8 = SDLK_8, /// ditto
    n9 = SDLK_9, /// ditto
    a = SDLK_a, /// ditto
    acBack = SDLK_AC_BACK, /// ditto
    acBookmarks = SDLK_AC_BOOKMARKS, /// ditto
    acForward = SDLK_AC_FORWARD, /// ditto
    acHome = SDLK_AC_HOME, /// ditto
    acRefresh = SDLK_AC_REFRESH, /// ditto
    acSearch = SDLK_AC_SEARCH, /// ditto
    acStop = SDLK_AC_STOP, /// ditto
    again = SDLK_AGAIN, /// ditto
    altErase = SDLK_ALTERASE, /// ditto
    quote = SDLK_QUOTE, /// ditto
    application = SDLK_APPLICATION, /// ditto
    audioMute = SDLK_AUDIOMUTE, /// ditto
    audioNext = SDLK_AUDIONEXT, /// ditto
    audioPlay = SDLK_AUDIOPLAY, /// ditto
    audioPrev = SDLK_AUDIOPREV, /// ditto
    audioStop = SDLK_AUDIOSTOP, /// ditto
    b = SDLK_b, /// ditto
    backslash = SDLK_BACKSLASH, /// ditto
    backspace = SDLK_BACKSPACE, /// ditto
    brightnessDown = SDLK_BRIGHTNESSDOWN, /// ditto
    brightnessUp = SDLK_BRIGHTNESSUP, /// ditto
    c = SDLK_c, /// ditto
    calculator = SDLK_CALCULATOR, /// ditto
    cancel = SDLK_CANCEL, /// ditto
    capsLock = SDLK_CAPSLOCK, /// ditto
    clear = SDLK_CLEAR, /// ditto
    clearAgain = SDLK_CLEARAGAIN, /// ditto
    comma = SDLK_COMMA, /// ditto
    computer = SDLK_COMPUTER, /// ditto
    copy = SDLK_COPY, /// ditto
    crSel = SDLK_CRSEL, /// ditto
    currencySubUnit = SDLK_CURRENCYSUBUNIT, /// ditto
    currencyUnit = SDLK_CURRENCYUNIT, /// ditto
    cut = SDLK_CUT, /// ditto
    d = SDLK_d, /// ditto
    decimalSeparator = SDLK_DECIMALSEPARATOR, /// ditto
    delete_ = SDLK_DELETE, /// ditto
    displaySwitch = SDLK_DISPLAYSWITCH, /// ditto
    down = SDLK_DOWN, /// ditto
    e = SDLK_e, /// ditto
    eject = SDLK_EJECT, /// ditto
    end = SDLK_END, /// ditto
    equals = SDLK_EQUALS, /// ditto
    escape = SDLK_ESCAPE, /// ditto
    execute = SDLK_EXECUTE, /// ditto
    exSel = SDLK_EXSEL, /// ditto
    f = SDLK_f, /// ditto
    f1 = SDLK_F1, /// ditto
    f10 = SDLK_F10, /// ditto
    f11 = SDLK_F11, /// ditto
    f12 = SDLK_F12, /// ditto
    f13 = SDLK_F13, /// ditto
    f14 = SDLK_F14, /// ditto
    f15 = SDLK_F15, /// ditto
    f16 = SDLK_F16, /// ditto
    f17 = SDLK_F17, /// ditto
    f18 = SDLK_F18, /// ditto
    f19 = SDLK_F19, /// ditto
    f2 = SDLK_F2, /// ditto
    f20 = SDLK_F20, /// ditto
    f21 = SDLK_F21, /// ditto
    f22 = SDLK_F22, /// ditto
    f23 = SDLK_F23, /// ditto
    f24 = SDLK_F24, /// ditto
    f3 = SDLK_F3, /// ditto
    f4 = SDLK_F4, /// ditto
    f5 = SDLK_F5, /// ditto
    f6 = SDLK_F6, /// ditto
    f7 = SDLK_F7, /// ditto
    f8 = SDLK_F8, /// ditto
    f9 = SDLK_F9, /// ditto
    find = SDLK_FIND, /// ditto
    g = SDLK_g, /// ditto
    backquote = SDLK_BACKQUOTE, /// ditto
    h = SDLK_h, /// ditto
    help = SDLK_HELP, /// ditto
    home = SDLK_HOME, /// ditto
    i = SDLK_i, /// ditto
    insert = SDLK_INSERT, /// ditto
    j = SDLK_j, /// ditto
    k = SDLK_k, /// ditto
    kbdIllumDown = SDLK_KBDILLUMDOWN, /// ditto
    kbdIllumToggle = SDLK_KBDILLUMTOGGLE, /// ditto
    kbdIllumUp = SDLK_KBDILLUMUP, /// ditto
    kp0 = SDLK_KP_0, /// ditto
    kp00 = SDLK_KP_00, /// ditto
    kp000 = SDLK_KP_000, /// ditto
    kp1 = SDLK_KP_1, /// ditto
    kp2 = SDLK_KP_2, /// ditto
    kp3 = SDLK_KP_3, /// ditto
    kp4 = SDLK_KP_4, /// ditto
    kp5 = SDLK_KP_5, /// ditto
    kp6 = SDLK_KP_6, /// ditto
    kp7 = SDLK_KP_7, /// ditto
    kp8 = SDLK_KP_8, /// ditto
    kp9 = SDLK_KP_9, /// ditto
    kpA = SDLK_KP_A, /// ditto
    kpAmpersand = SDLK_KP_AMPERSAND, /// ditto
    kpAt = SDLK_KP_AT, /// ditto
    kpB = SDLK_KP_B, /// ditto
    kpBackspace = SDLK_KP_BACKSPACE, /// ditto
    kpBinary = SDLK_KP_BINARY, /// ditto
    kpC = SDLK_KP_C, /// ditto
    kpClear = SDLK_KP_CLEAR, /// ditto
    kpClearEntry = SDLK_KP_CLEARENTRY, /// ditto
    kpColon = SDLK_KP_COLON, /// ditto
    kpComma = SDLK_KP_COMMA, /// ditto
    kpD = SDLK_KP_D, /// ditto
    kpDblAmpersand = SDLK_KP_DBLAMPERSAND, /// ditto
    kpDblVerticalBar = SDLK_KP_DBLVERTICALBAR, /// ditto
    kpDecimal = SDLK_KP_DECIMAL, /// ditto
    kpDivide = SDLK_KP_DIVIDE, /// ditto
    kpE = SDLK_KP_E, /// ditto
    kpEnter = SDLK_KP_ENTER, /// ditto
    kpEquals = SDLK_KP_EQUALS, /// ditto
    kpEqualsAS400 = SDLK_KP_EQUALSAS400, /// ditto
    kpExclam = SDLK_KP_EXCLAM, /// ditto
    kpF = SDLK_KP_F, /// ditto
    kpGreater = SDLK_KP_GREATER, /// ditto
    kpHash = SDLK_KP_HASH, /// ditto
    kpHexadecimal = SDLK_KP_HEXADECIMAL, /// ditto
    kpLeftBrace = SDLK_KP_LEFTBRACE, /// ditto
    kpLeftParen = SDLK_KP_LEFTPAREN, /// ditto
    kpLess = SDLK_KP_LESS, /// ditto
    kpMemAdd = SDLK_KP_MEMADD, /// ditto
    kpMemClear = SDLK_KP_MEMCLEAR, /// ditto
    kpMemDivide = SDLK_KP_MEMDIVIDE, /// ditto
    kpMemMultiply = SDLK_KP_MEMMULTIPLY, /// ditto
    kpMemRecall = SDLK_KP_MEMRECALL, /// ditto
    kpMemStore = SDLK_KP_MEMSTORE, /// ditto
    kpMemSubtract = SDLK_KP_MEMSUBTRACT, /// ditto
    kpMinus = SDLK_KP_MINUS, /// ditto
    kpMultiply = SDLK_KP_MULTIPLY, /// ditto
    kpOctal = SDLK_KP_OCTAL, /// ditto
    kpPercent = SDLK_KP_PERCENT, /// ditto
    kpPeriod = SDLK_KP_PERIOD, /// ditto
    kpPlus = SDLK_KP_PLUS, /// ditto
    kpPlusMinus = SDLK_KP_PLUSMINUS, /// ditto
    kpPower = SDLK_KP_POWER, /// ditto
    kpRightBrace = SDLK_KP_RIGHTBRACE, /// ditto
    kpRightParen = SDLK_KP_RIGHTPAREN, /// ditto
    kpSpace = SDLK_KP_SPACE, /// ditto
    kpTab = SDLK_KP_TAB, /// ditto
    kpVerticalBar = SDLK_KP_VERTICALBAR, /// ditto
    kpXOR = SDLK_KP_XOR, /// ditto
    l = SDLK_l, /// ditto
    lAlt = SDLK_LALT, /// ditto
    lCtrl = SDLK_LCTRL, /// ditto
    left = SDLK_LEFT, /// ditto
    leftBracket = SDLK_LEFTBRACKET, /// ditto
    lGUI = SDLK_LGUI, /// ditto
    lShift = SDLK_LSHIFT, /// ditto
    m = SDLK_m, /// ditto
    mail = SDLK_MAIL, /// ditto
    mediaSelect = SDLK_MEDIASELECT, /// ditto
    menu = SDLK_MENU, /// ditto
    minus = SDLK_MINUS, /// ditto
    mode = SDLK_MODE, /// ditto
    mute = SDLK_MUTE, /// ditto
    n = SDLK_n, /// ditto
    numLockClear = SDLK_NUMLOCKCLEAR, /// ditto
    o = SDLK_o, /// ditto
    oper = SDLK_OPER, /// ditto
    out_ = SDLK_OUT, /// ditto
    p = SDLK_p, /// ditto
    pageDown = SDLK_PAGEDOWN, /// ditto
    pageUp = SDLK_PAGEUP, /// ditto
    paste = SDLK_PASTE, /// ditto
    pause = SDLK_PAUSE, /// ditto
    period = SDLK_PERIOD, /// ditto
    power = SDLK_POWER, /// ditto
    printScreen = SDLK_PRINTSCREEN, /// ditto
    prior = SDLK_PRIOR, /// ditto
    q = SDLK_q, /// ditto
    r = SDLK_r, /// ditto
    rAlt = SDLK_RALT, /// ditto
    rCtrl = SDLK_RCTRL, /// ditto
    return1 = SDLK_RETURN, /// ditto
    return2 = SDLK_RETURN2, /// ditto
    rGUI = SDLK_RGUI, /// ditto
    right = SDLK_RIGHT, /// ditto
    rightBracket = SDLK_RIGHTBRACKET, /// ditto
    rShift = SDLK_RSHIFT, /// ditto
    s = SDLK_s, /// ditto
    scrollLock = SDLK_SCROLLLOCK, /// ditto
    select = SDLK_SELECT, /// ditto
    semicolon = SDLK_SEMICOLON, /// ditto
    separator = SDLK_SEPARATOR, /// ditto
    slash = SDLK_SLASH, /// ditto
    sleep = SDLK_SLEEP, /// ditto
    space = SDLK_SPACE, /// ditto
    stop = SDLK_STOP, /// ditto
    sysReq = SDLK_SYSREQ, /// ditto
    t = SDLK_t, /// ditto
    tab = SDLK_TAB, /// ditto
    thousandsSeparator = SDLK_THOUSANDSSEPARATOR, /// ditto
    u = SDLK_u, /// ditto
    undo = SDLK_UNDO, /// ditto
    unknown = SDLK_UNKNOWN, /// ditto
    up = SDLK_UP, /// ditto
    v = SDLK_v, /// ditto
    volumeDown = SDLK_VOLUMEDOWN, /// ditto
    volumeUp = SDLK_VOLUMEUP, /// ditto
    w = SDLK_w, /// ditto
    www = SDLK_WWW, /// ditto
    x = SDLK_x, /// ditto
    y = SDLK_y, /// ditto
    z = SDLK_z, /// ditto
    ampersand = SDLK_AMPERSAND, /// ditto
    asterisk = SDLK_ASTERISK, /// ditto
    at = SDLK_AT, /// ditto
    caret = SDLK_CARET, /// ditto
    colon = SDLK_COLON, /// ditto
    dollar = SDLK_DOLLAR, /// ditto
    exclaim = SDLK_EXCLAIM, /// ditto
    greater = SDLK_GREATER, /// ditto
    hash = SDLK_HASH, /// ditto
    leftParen = SDLK_LEFTPAREN, /// ditto
    less = SDLK_LESS, /// ditto
    percent = SDLK_PERCENT, /// ditto
    plus = SDLK_PLUS, /// ditto
    question = SDLK_QUESTION, /// ditto
    quoteDbl = SDLK_QUOTEDBL, /// ditto
    rightParen = SDLK_RIGHTPAREN, /// ditto
    underscore = SDLK_UNDERSCORE /// ditto
}
