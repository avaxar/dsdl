/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.window;
@safe:

import bindbc.sdl;
import dsdl.sdl;
import dsdl.display;
import dsdl.pixels;
import dsdl.rect;
import dsdl.renderer;
import dsdl.surface;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.string : toStringz;
import std.typecons : Nullable, nullable;

/++
 + D enum that wraps `SDL_WINDOWPOS_*` to specify certain state of position in `dsdl.Window` construction
 +/
enum WindowPos : uint {
    centered = SDL_WINDOWPOS_CENTERED, /// Wraps `SDL_WINDOWPOS_CENTERED` which sets the window to be in the center
    undefined = SDL_WINDOWPOS_UNDEFINED /// Wraps `SDL_WINDOWPOS_UNDEFINED` which leaves the window's position undefined
}

private uint toSDLWindowFlags(bool fullscreen, bool fullscreenDesktop, bool openGL, bool shown,
        bool hidden, bool borderless, bool resizable, bool minimized, bool maximized, bool inputGrabbed,
        bool inputFocus, bool mouseFocus, bool foreign, bool allowHighDPI, bool mouseCapture,
        bool alwaysOnTop, bool skipTaskbar, bool utility, bool tooltip, bool popupMenu, bool vulkan,
        bool metal, bool mouseGrabbed, bool keyboardGrabbed)
in {
    static if (sdlSupport < SDLSupport.v2_0_1) {
        assert(allowHighDPI == false);
    }
    else {
        if (allowHighDPI) {
            assert(getVersion() >= Version(2, 0, 1));
        }
    }

    static if (sdlSupport < SDLSupport.v2_0_4) {
        assert(mouseCapture == false);
    }
    else {
        if (mouseCapture) {
            assert(getVersion() >= Version(2, 0, 4));
        }
    }

    static if (sdlSupport < SDLSupport.v2_0_5) {
        assert(alwaysOnTop == false);
        assert(skipTaskbar == false);
        assert(utility == false);
        assert(tooltip == false);
        assert(popupMenu == false);
    }
    else {
        if (alwaysOnTop || skipTaskbar || utility || tooltip || popupMenu) {
            assert(getVersion() >= Version(2, 0, 5));
        }
    }

    static if (sdlSupport < SDLSupport.v2_0_6) {
        assert(vulkan == false);
        assert(metal == false);
    }
    else {
        if (vulkan || metal) {
            assert(getVersion() >= Version(2, 0, 6));
        }
    }

    static if (sdlSupport < SDLSupport.v2_0_16) {
        assert(mouseGrabbed == false);
        assert(keyboardGrabbed == false);
    }
    else {
        if (mouseGrabbed || keyboardGrabbed) {
            assert(getVersion() >= Version(2, 0, 16));
        }
    }
}
do {
    uint flags = 0;

    flags |= fullscreen ? SDL_WINDOW_FULLSCREEN : 0;
    flags |= fullscreenDesktop ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0;
    flags |= openGL ? SDL_WINDOW_OPENGL : 0;
    flags |= shown ? SDL_WINDOW_SHOWN : 0;
    flags |= hidden ? SDL_WINDOW_HIDDEN : 0;
    flags |= borderless ? SDL_WINDOW_BORDERLESS : 0;
    flags |= resizable ? SDL_WINDOW_RESIZABLE : 0;
    flags |= minimized ? SDL_WINDOW_MINIMIZED : 0;
    flags |= maximized ? SDL_WINDOW_MAXIMIZED : 0;
    flags |= inputGrabbed ? SDL_WINDOW_INPUT_GRABBED : 0;
    flags |= inputFocus ? SDL_WINDOW_INPUT_FOCUS : 0;
    flags |= mouseFocus ? SDL_WINDOW_MOUSE_FOCUS : 0;
    flags |= foreign ? SDL_WINDOW_FOREIGN : 0;

    static if (sdlSupport >= SDLSupport.v2_0_1) {
        flags |= allowHighDPI ? SDL_WINDOW_ALLOW_HIGHDPI : 0;
    }
    static if (sdlSupport >= SDLSupport.v2_0_4) {
        flags |= mouseCapture ? SDL_WINDOW_MOUSE_CAPTURE : 0;
    }
    static if (sdlSupport >= SDLSupport.v2_0_5) {
        flags |= alwaysOnTop ? SDL_WINDOW_ALWAYS_ON_TOP : 0;
        flags |= skipTaskbar ? SDL_WINDOW_SKIP_TASKBAR : 0;
        flags |= utility ? SDL_WINDOW_UTILITY : 0;
        flags |= tooltip ? SDL_WINDOW_TOOLTIP : 0;
        flags |= popupMenu ? SDL_WINDOW_POPUP_MENU : 0;
    }
    static if (sdlSupport >= SDLSupport.v2_0_6) {
        flags |= vulkan ? SDL_WINDOW_VULKAN : 0;
        flags |= metal ? SDL_WINDOW_METAL : 0;
    }
    static if (sdlSupport >= SDLSupport.v2_0_16) {
        flags |= mouseGrabbed ? SDL_WINDOW_MOUSE_GRABBED : 0;
        flags |= keyboardGrabbed ? SDL_WINDOW_KEYBOARD_GRABBED : 0;
    }

    return flags;
}

static if (sdlSupport >= SDLSupport.v2_0_16) {
    /++
     + D enum that wraps `SDL_FlashOperation` (from SDL 2.0.16) defining window flashing operations
     +/
    enum FlashOperation {
        /++
         + Wraps `SDL_FLASH_*` enumeration constants
         +/
        cancel = SDL_FLASH_CANCEL,
        briefly = SDL_FLASH_BRIEFLY, /// ditto
        untilFocused = SDL_FLASH_UNTIL_FOCUSED /// ditto
    }
}

/++
 + D class that wraps `SDL_Window` managing a window instance specific to the OS
 +
 + `dsdl.Window` provides access to creating windows and managing them for rendering. Internally, SDL uses
 + OS functions to summon the window.
 +
 + Example:
 + ---
 + auto window = new dsdl.Window("My Window", [dsdl.WindowPos.centered, dsdl.WindowPos.centered], [800, 600]);
 + window.surface.fill(dsdl.Color(255, 0, 0));
 + window.update();
 + ---
 +/
final class Window {
    private PixelFormat pixelFormatProxy = null;
    private Surface surfaceProxy = null;
    private bool isOwner = true;
    private void* userRef = null;

    @system SDL_Window* sdlWindow = null; /// Internal `SDL_Window` pointer

    /++
     + Constructs a `dsdl.Window` from a vanilla `SDL_Window*` from bindbc-sdl
     +
     + Params:
     +   sdlWindow = the `SDL_Window` pointer to manage
     +   isOwner = whether the instance owns the given `SDL_Window*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(SDL_Window* sdlWindow, bool isOwner = true, void* userRef = null) @system
    in {
        assert(sdlWindow !is null);
    }
    do {
        this.sdlWindow = sdlWindow;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    /++
     + Creates an SDL-handled window from a native pointer handle of the OS, which wraps `SDL_CreateWindowFrom`
     +
     + Params:
     +   nativeHandle = pointer to the native OS window
     + Throws: `dsdl.SDLException` if window creation failed
     +/
    this(void* nativeHandle) @system
    in {
        assert(nativeHandle !is null);
    }
    do {
        this.sdlWindow = SDL_CreateWindowFrom(nativeHandle);
        if (this.sdlWindow is null) {
            throw new SDLException;
        }
    }

    /++
     + Creates a window on the desktop placed at a coordinate in the screen, which wraps `SDL_CreateWindow`
     +
     + Params:
     +   title = title given to the shown window
     +   position = top-left position of the window in the desktop environment (pair of two `uint`s or flags from
     +              `dsdl.WindowPos`)
     +   size = size of the window in pixels
     +   shaped = `true` to use `SDL_CreateShapedWindow`; `false` to use `SDL_CreateWindow` instead
     +   fullscreen = adds `SDL_WINDOW_FULLSCREEN` flag
     +   fullscreenDesktop = adds `SDL_WINDOW_FULLSCREEN_DESKTOP` flag
     +   openGL = adds `SDL_WINDOW_OPENGL` flag
     +   shown = adds `SDL_WINDOW_SHOWN` flag
     +   hidden = adds `SDL_WINDOW_HIDDEN` flag
     +   borderless = adds `SDL_WINDOW_BORDERLESS` flag
     +   resizable = adds `SDL_WINDOW_RESIZABLE` flag
     +   minimized = adds `SDL_WINDOW_MINIMIZED` flag
     +   maximized = adds `SDL_WINDOW_MAXIMIZED` flag
     +   inputGrabbed = adds `SDL_WINDOW_INPUT_GRABBED` flag
     +   inputFocus = adds `SDL_WINDOW_INPUT_FOCUS` flag
     +   mouseFocus = adds `SDL_WINDOW_MOUSE_FOCUS` flag
     +   foreign = adds `SDL_WINDOW_FOREIGN` flag
     +   allowHighDPI = adds `SDL_WINDOW_ALLOW_HIGHDPI` flag (from SDL 2.0.1)
     +   mouseCapture = adds `SDL_WINDOW_MOUSE_CAPTURE` flag (from SDL 2.0.2)
     +   alwaysOnTop = adds `SDL_WINDOW_ALWAYS_ON_TOP` flag (from SDL 2.0.5)
     +   skipTaskbar = adds `SDL_WINDOW_SKIP_TASKBAR` flag (from SDL 2.0.5)
     +   utility = adds `SDL_WINDOW_UTILITY` flag (from SDL 2.0.5)
     +   tooltip = adds `SDL_WINDOW_TOOLTIP` flag (from SDL 2.0.5)
     +   popupMenu = adds `SDL_WINDOW_POPUP_MENU` flag (from SDL 2.0.5)
     +   vulkan = adds `SDL_WINDOW_VULKAN` flag (from SDL 2.0.6)
     +   metal = adds `SDL_WINDOW_METAL` flag (from SDL 2.0.6)
     +   mouseGrabbed = adds `SDL_WINDOW_MOUSE_GRABBED` flag (from SDL 2.0.16)
     +   keyboardGrabbed = adds `SDL_WINDOW_KEYBOARD_GRABBED` flag (from SDL 2.0.16)
     + Throws: `dsdl.SDLException` if window creation failed
     +/
    this(string title, uint[2] position, uint[2] size, bool shaped = false, bool fullscreen = false,
            bool fullscreenDesktop = false, bool openGL = false, bool shown = false, bool hidden = false,
            bool borderless = false, bool resizable = false, bool minimized = false, bool maximized = false,
            bool inputGrabbed = false, bool inputFocus = false, bool mouseFocus = false, bool foreign = false,
            bool allowHighDPI = false, bool mouseCapture = false, bool alwaysOnTop = false,
            bool skipTaskbar = false, bool utility = false, bool tooltip = false, bool popupMenu = false,
            bool vulkan = false, bool metal = false, bool mouseGrabbed = false, bool keyboardGrabbed = false) @trusted
    in {
        assert(title !is null);
    }
    do {
        uint flags = toSDLWindowFlags(fullscreen, fullscreenDesktop, openGL, shown, hidden,
                borderless, resizable, minimized,
                maximized, inputGrabbed, inputFocus, mouseFocus, foreign, allowHighDPI, mouseCapture, alwaysOnTop,
                skipTaskbar, utility, tooltip, popupMenu, vulkan, metal, mouseGrabbed, keyboardGrabbed);

        if (shaped) {
            this.sdlWindow = SDL_CreateShapedWindow(title.toStringz(), position[0].to!int,
                    position[1].to!int, size[0].to!int, size[1].to!int, flags);
        }
        else {
            this.sdlWindow = SDL_CreateWindow(title.toStringz(), position[0].to!int,
                    position[1].to!int, size[0].to!int, size[1].to!int, flags);
        }

        if (this.sdlWindow is null) {
            throw new SDLException;
        }
    }

    ~this() @trusted {
        if (this.isOwner) {
            SDL_DestroyWindow(this.sdlWindow);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.sdlWindow !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Window rhs) const @trusted {
        return this.sdlWindow is rhs.sdlWindow;
    }

    /++
     + Gets the hash of the `dsdl.Window`
     +
     + Returns: unique hash for the instance being the pointer of the internal `SDL_Window` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.sdlWindow;
    }

    /++
     + Formats the `dsdl.Window` into its construction representation: `"dsdl.Window(<sdlWindow>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.Window(0x%x)".format(this.sdlWindow);
    }

    /++
     + Wraps `SDL_GetWindowID` which gets the internal window ID of the `dsdl.Window`
     +
     + Returns: `uint` of the internal window ID
     +/
    uint id() const @property @trusted {
        return SDL_GetWindowID(cast(SDL_Window*) this.sdlWindow);
    }

    /++
     + Wraps `SDL_GetWindowDisplayIndex` which gets the display where the center of the window is located
     +
     + Returns: `dsdl.Display` of the display the window is located
     + Throws: `dsdl.SDLException` if failed to get the display
     +/
    const(Display) display() const @property @trusted {
        int index = SDL_GetWindowDisplayIndex(cast(SDL_Window*) this.sdlWindow);
        if (index < 0) {
            throw new SDLException;
        }

        return getDisplays()[index];
    }

    /++
     + Wraps `SDL_GetWindowDisplayMode` which gets the window's display mode attributes
     +
     + Returns: `dsdl.DisplayMode` storing the attributes
     + Throws: `dsdl.SDLException` if failed to get the display mode
     +/
    DisplayMode displayMode() const @property @trusted {
        SDL_DisplayMode sdlMode = void;
        if (SDL_GetWindowDisplayMode(cast(SDL_Window*) this.sdlWindow, &sdlMode) != 0) {
            throw new SDLException;
        }

        return DisplayMode(sdlMode);
    }

    /++
     + Wraps `SDL_SetWindowDisplayMode` which sets new display mode attributes to the window
     +
     + Params:
     +   newDisplayMode = `dsdl.DisplayMode` containing the desired attributes
     + Throws: `dsdl.SDLException` if failed to set the display mode
     +/
    void displayMode(DisplayMode newDisplayMode) @property @trusted {
        SDL_DisplayMode sdlMode = newDisplayMode.sdlDisplayMode;
        if (SDL_SetWindowDisplayMode(this.sdlWindow, &sdlMode) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Gets the `dsdl.PixelFormat` used for pixel data of the window
     +
     + Returns: read-only `dsdl.PixelFormat` instance
     +/
    const(PixelFormat) pixelFormat() const @property @trusted {
        // If the internal pixel format pointer happens to change, rewire the proxy.
        if (this.pixelFormatProxy is null
                || this.pixelFormatProxy.sdlPixelFormatEnum !is SDL_GetWindowPixelFormat(
                    cast(SDL_Window*) this.sdlWindow)) {
            (cast(Window) this).pixelFormatProxy = new PixelFormat(
                    SDL_GetWindowPixelFormat(cast(SDL_Window*) this.sdlWindow));
        }

        return this.pixelFormatProxy;
    }

    /++
     + Wraps `SDL_GetRenderer` which gets the renderer of the window
     +
     + Returns: `dsdl.Renderer` proxy
     +/
    inout(Renderer) renderer() inout @property @trusted {
        if (SDL_Renderer* sdlRenderer = SDL_GetRenderer(cast(SDL_Window*) this.sdlWindow)) {
            return cast(inout(Renderer)) new Renderer(sdlRenderer, false, cast(void*) this);
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GetWindowTitle` which gets the shown title of the window
     +
     + Returns: title `string` of the window
     +/
    string title() const @property @trusted {
        return SDL_GetWindowTitle(cast(SDL_Window*) this.sdlWindow).to!string;
    }

    /++
     + Wraps `SDL_SetWindowTitle` which sets a new title to the window
     +
     + Params:
     +   newTitle = `string` of the new title
     +/
    void title(string newTitle) @property @trusted {
        SDL_SetWindowTitle(this.sdlWindow, newTitle.toStringz());
    }

    /++
     + Wraps `SDL_SetWindowIcon` which sets a new icon to the window
     +
     + Params:
     +   newIcon = `dsdl.Surface` of the new icon
     +/
    void icon(Surface newIcon) @property @trusted
    in {
        assert(newIcon !is null);
    }
    do {
        SDL_SetWindowIcon(this.sdlWindow, newIcon.sdlSurface);
    }

    /++
     + Wraps `SDL_GetWindowPosition` which gets the top-left X coordinate position of the window in
     + the desktop environment
     +
     + Returns: top-left X coordinate position of the window in the desktop environment
     +/
    int x() const @property @trusted {
        int x = void;
        SDL_GetWindowPosition(cast(SDL_Window*) this.sdlWindow, &x, null);
        return x;
    }

    /++
     + Wraps `SDL_SetWindowPosition` which sets the X position of the window in the desktop environment
     +
     + Params:
     +   newX = top-left X coordinate of the new window position in the desktop environment
     +/
    void x(int newX) @property @trusted {
        SDL_SetWindowPosition(this.sdlWindow, newX, this.y);
    }

    /++
     + Wraps `SDL_GetWindowPosition` which gets the top-left Y coordinate position of the window in
     + the desktop environment
     +
     + Returns: top-left Y coordinate position of the window in the desktop environment
     +/
    int y() const @property @trusted {
        int y = void;
        SDL_GetWindowPosition(cast(SDL_Window*) this.sdlWindow, null, &y);
        return y;
    }

    /++
     + Wraps `SDL_SetWindowPosition` which sets the Y position of the window in the desktop environment
     +
     + Params:
     +   newY = top-left Y coordinate of the new window position in the desktop environment
     +/
    void y(int newY) @property @trusted {
        SDL_SetWindowPosition(this.sdlWindow, this.x, newY);
    }

    /++
     + Wraps `SDL_GetWindowPosition` which gets the top-left coordinate position of the window in
     + the desktop environment
     +
     + Returns: top-left coordinate position of the window in the desktop environment
     +/
    int[2] position() const @property @trusted {
        int[2] xy = void;
        SDL_GetWindowPosition(cast(SDL_Window*) this.sdlWindow, &xy[0], &xy[1]);
        return xy;
    }

    /++
     + Wraps `SDL_SetWindowPosition` which sets the position of the window in the desktop environment
     +
     + Params:
     +   newPosition = top-left coordinate of the new window position in the desktop environment
     +/
    void position(int[2] newPosition) @property @trusted {
        SDL_SetWindowPosition(this.sdlWindow, newPosition[0], newPosition[1]);
    }

    /++
     + Wraps `SDL_GetWindowSize` which gets the width of the window in pixels
     +
     + Returns: width of the window in pixels
     +/
    uint width() const @property @trusted {
        uint w = void;
        SDL_GetWindowSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&w, null);
        return w;
    }

    /++
     + Wraps `SDL_SetWindowSize` which resizes the width of the window in pixels
     +
     + Params:
     +   newWidth = new resized width of the window in pixels
     +/
    void width(uint newWidth) @property @trusted {
        SDL_SetWindowSize(this.sdlWindow, newWidth.to!int, this.height);
    }

    /++
     + Wraps `SDL_GetWindowSize` which gets the height of the window in pixels
     +
     + Returns: height of the window in pixels
     +/
    uint height() const @property @trusted {
        uint h = void;
        SDL_GetWindowSize(cast(SDL_Window*) this.sdlWindow, null, cast(int*)&h);
        return h;
    }

    /++
     + Wraps `SDL_SetWindowSize` which resizes the height of the window in pixels
     +
     + Params:
     +   newHeight = new resized height of the window in pixels
     +/
    void height(uint newHeight) @property @trusted {
        SDL_SetWindowSize(this.sdlWindow, this.width, newHeight.to!int);
    }

    /++
     + Wraps `SDL_GetWindowSize` which gets the size of the window in pixels
     +
     + Returns: size of the window in pixels
     +/
    uint[2] size() const @property @trusted {
        uint[2] wh = void;
        SDL_GetWindowSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&wh[0], cast(int*)&wh[1]);
        return wh;
    }

    /++
     + Wraps `SDL_SetWindowSize` which resizes the size of the window in pixels
     +
     + Params:
     +   newSize = new resized size of the window in pixels (width and height)
     +/
    void size(uint[2] newSize) @property @trusted {
        SDL_SetWindowSize(this.sdlWindow, newSize[0].to!int, newSize[1].to!int);
    }

    /++
     + Wraps `SDL_GetWindowMinimumSize` which gets the minimum size in pixels that the window can be
     + resized to
     +
     + Returns: minimum set size of the window in pixels
     +/
    uint[2] minimumSize() const @property @trusted {
        uint[2] wh;
        SDL_GetWindowMinimumSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&wh[0], cast(int*)&wh[1]);
        return wh;
    }

    /++
     + Wraps `SDL_SetWindowMinimumSize` which sets the minimum size in pixels that the window can be
     + resized to
     +
     + Params:
     +   newMinimumSize = new minimum set size of the window in pixels (width and height)
     +/
    void minimumSize(uint[2] newMinimumSize) @property @trusted {
        SDL_SetWindowMinimumSize(this.sdlWindow, newMinimumSize[0].to!int, newMinimumSize[1].to!int);
    }

    /++
     + Wraps `SDL_GetWindowMaximumSize` which gets the maximum size in pixels that the window can be
     + resized to
     +
     + Returns: maximum set size of the window in pixels
     +/
    uint[2] maximumSize() const @property @trusted {
        uint[2] wh;
        SDL_GetWindowMaximumSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&wh[0], cast(int*)&wh[1]);
        return wh;
    }

    /++
     + Wraps `SDL_SetWindowMaximumSize` which sets the maximum size in pixels that the window can be
     + resized to
     +
     + Params:
     +   newMaximumSize = new maximum set size of the window in pixels (width and height)
     +/
    void maximumSize(uint[2] newMaximumSize) @property @trusted {
        SDL_SetWindowMaximumSize(this.sdlWindow, newMaximumSize[0].to!int, newMaximumSize[1].to!int);
    }

    /++
     + Wraps `SDL_ShowWindow` which sets the window to be visible in the desktop environment
     +/
    void show() @trusted {
        SDL_ShowWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_HideWindow` which sets the window to be invisible in the desktop environment
     +/
    void hide() @trusted {
        SDL_HideWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_RaiseWindow` which raises the window above other windows, and sets input focus to the window
     +/
    void raise() @trusted {
        SDL_RaiseWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_MaximizeWindow` which maximizes the window in the desktop environment
     +/
    void maximize() @trusted {
        SDL_MaximizeWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_MinimizeWindow` which minimizes the window in the desktop environment
     +/
    void minimize() @trusted {
        SDL_MinimizeWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_RestoreWindow` which restores the size and position of the window as it was originally
     +/
    void restore() @trusted {
        SDL_RestoreWindow(this.sdlWindow);
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is in real fullscreen
     +
     + Returns: `true` if the the window is in real fullscreen, otherwise `false`
     +/
    bool fullscreen() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_FULLSCREEN) == SDL_WINDOW_FULLSCREEN;
    }

    /++
     + Wraps `SDL_SetWindowFullscreen` which sets the fullscreen mode of the window
     +
     + Params:
     +   newFullscreen = `true` to make the window fullscreen, otherwise `false`
     + Throws: `dsdl.SDLException` if failed to set the window's fullscreen mode
     +/
    void fullscreen(bool newFullscreen) @property @trusted {
        if (SDL_SetWindowFullscreen(this.sdlWindow, newFullscreen ? SDL_WINDOW_FULLSCREEN : 0) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is in desktop fullscreen
     +
     + Returns: `true` if the the window is in desktop fullscreen, otherwise `false`
     +/
    bool fullscreenDesktop() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_FULLSCREEN_DESKTOP) == SDL_WINDOW_FULLSCREEN_DESKTOP;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window utilizes OpenGL
     +
     + Returns: `true` if the the window utilizes OpenGL, otherwise `false`
     +/
    bool openGL() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_OPENGL) == SDL_WINDOW_OPENGL;
    }

    static if (sdlSupport >= SDLSupport.v2_0_6) {
        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window utilizes Vulkan (from SDL 2.0.6)
         +
         + Returns: `true` if the the window utilizes Vulkan, otherwise `false`
         +/
        bool vulkan() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 6));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_VULKAN) == SDL_WINDOW_VULKAN;
        }

        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window utilizes Metal (from SDL 2.0.6)
         +
         + Returns: `true` if the the window utilizes Metal, otherwise `false`
         +/
        bool metal() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 6));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_METAL) == SDL_WINDOW_METAL;
        }
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is foreign
     +
     + Returns: `true` if the the window is foreign, otherwise `false`
     +/
    bool foreign() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_FOREIGN) == SDL_WINDOW_FOREIGN;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is shown
     +
     + Returns: `true` if the the window is shown, otherwise `false`
     +/
    bool shown() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_SHOWN) == SDL_WINDOW_SHOWN;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is hidden
     +
     + Returns: `true` if the the window is hidden, otherwise `false`
     +/
    bool hidden() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_HIDDEN) == SDL_WINDOW_HIDDEN;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the borders of the window are non-existent
     +
     + Returns: `true` if borders of the window are non-existent, otherwise `false`
     +/
    bool borderless() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_BORDERLESS) == SDL_WINDOW_BORDERLESS;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the borders of the window are visible
     +
     + Returns: `true` if borders are visible, otherwise `false`
     +/
    bool bordered() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_BORDERLESS) != SDL_WINDOW_BORDERLESS;
    }

    /++
     + Wraps `SDL_SetWindowBordered` which sets whether the borders' visibility
     +
     + Params:
     +   newBordered = `true` to make the borders visible, otherwise `false`
     +/
    void bordered(bool newBordered) @property @trusted {
        SDL_SetWindowBordered(this.sdlWindow, newBordered);
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window's size is resizable by the user
     +
     + Returns: `true` if the window is resizable, otherwise `false`
     +/
    bool resizable() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_RESIZABLE) == SDL_WINDOW_RESIZABLE;
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        /++
         + Wraps `SDL_SetWindowResizable` (from SDL 2.0.5) which sets the window's resizability
         +
         + Params:
         +   newResizable = `true` to make the window resizable, otherwise `false`
         +/
        void resizable(bool newResizable) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            SDL_SetWindowResizable(this.sdlWindow, newResizable);
        }
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is minimized
     +
     + Returns: `true` if window is minimized, otherwise `false`
     +/
    bool minimized() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_MINIMIZED) == SDL_WINDOW_MINIMIZED;
    }

    /++
     + Wraps `SDL_GetWindowFlags` to check whether the window is maximized
     +
     + Returns: `true` if window is maximized, otherwise `false`
     +/
    bool maximized() const @property @trusted {
        return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_MAXIMIZED) == SDL_WINDOW_MAXIMIZED;
    }

    static if (sdlSupport >= SDLSupport.v2_0_1) {
        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window allows high DPI (from SDL 2.0.1)
         +
         + Returns: `true` if window allows high DPI, otherwise `false`
         +/
        bool allowsHighDPI() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 1));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_ALLOW_HIGHDPI) == SDL_WINDOW_ALLOW_HIGHDPI;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window is always on top (from SDL 2.0.5)
         +
         + Returns: `true` if window is always on top, otherwise `false`
         +/
        bool alwaysOnTop() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_ALWAYS_ON_TOP) == SDL_WINDOW_ALWAYS_ON_TOP;
        }

        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window is not on the taskbar (from SDL 2.0.5)
         +
         + Returns: `true` if window is not on the taskbar, otherwise `false`
         +/
        bool skipsTaskbar() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_SKIP_TASKBAR) == SDL_WINDOW_SKIP_TASKBAR;
        }

        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window is treated as a utility window (from SDL 2.0.5)
         +
         + Returns: `true` if window is treated as a utility window, otherwise `false`
         +/
        bool utility() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_UTILITY) == SDL_WINDOW_UTILITY;
        }

        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window is treated as a tooltip window (from SDL 2.0.5)
         +
         + Returns: `true` if window is treated as a tooltip window, otherwise `false`
         +/
        bool tooltip() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_TOOLTIP) == SDL_WINDOW_TOOLTIP;
        }

        /++
         + Wraps `SDL_GetWindowFlags` to check whether the window is treated as a popup menu (from SDL 2.0.5)
         +
         + Returns: `true` if window is treated as a popup menu, otherwise `false`
         +/
        bool popupMenu() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            return (SDL_GetWindowFlags(cast(SDL_Window*) this.sdlWindow) & SDL_WINDOW_POPUP_MENU) == SDL_WINDOW_POPUP_MENU;
        }
    }

    /++
     + Wraps `SDL_GetWindowGrab` which gets the window's input grab mode
     +
     + Returns: `true` if the window is in input grab mode, otherwise `false`
     +/
    bool inputGrab() const @property @trusted {
        return SDL_GetWindowGrab(cast(SDL_Window*) this.sdlWindow) == SDL_TRUE;
    }

    /++
     + Wraps `SDL_SetWindowGrab` which sets the window's input grab mode
     +
     + Params:
     +   newGrab = `true` to set the window on input grab mode, otherwise `false`
     +/
    void inputGrab(bool newGrab) @property @trusted {
        SDL_SetWindowGrab(this.sdlWindow, newGrab);
    }

    /++
     + Wraps `SDL_GetWindowBrightness` which gets the window's brightness value
     +
     + Returns: `float` value from `0.0` to `1.0` indicating the window's brightness
     +/
    float brightness() const @property @trusted {
        return SDL_GetWindowBrightness(cast(SDL_Window*) this.sdlWindow);
    }

    /++
     + Wraps `SDL_SetWindowBrightness` which sets the window's brightness value
     +
     + Params:
     +   newBrightness = `float` value specifying the window's brightness from `0.0` (darkest) to `1.0` (brightest)
     + Throws: `dsdl.SDLException` if failed to set the window's brightness value
     +/
    void brightness(float newBrightness) @property @trusted {
        if (SDL_SetWindowBrightness(this.sdlWindow, newBrightness) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_IsScreenKeyboardShown` which checks whether the screen keyboard is shown on the window
     +
     + Returns: `true` if the screen keyboard is shown, otherwise `false`
     +/
    bool hasShownScreenKeyboard() const @property @trusted {
        return SDL_IsScreenKeyboardShown(cast(SDL_Window*) this.sdlWindow) == SDL_TRUE;
    }

    /++
     + Wraps `SDL_GetKeyboardFocus` which verifies whether keyboard input is focused to the window
     +
     + Returns: `true` if keyboard input is focused, otherwise `false`
     +/
    bool keyboardFocused() const @property @trusted {
        return SDL_GetKeyboardFocus() == this.sdlWindow;
    }

    /++
     + Wraps `SDL_GetMouseFocus` which verifies whether mouse input is focused to the window
     +
     + Returns: `true` if mouse input is focused, otherwise `false`
     +/
    bool mouseFocused() const @property @trusted {
        return SDL_GetMouseFocus() == this.sdlWindow;
    }

    /++
     + Wraps `SDL_GetMouseState` which gets the mouse position in the window
     +
     + Returns: `[x, y]` of the mouse position relative to the window, otherwise `[-1, -1]` if mouse input is not
     +          focused to the window
     +/
    int[2] mousePosition() const @property @trusted {
        if (SDL_GetMouseFocus() != this.sdlWindow) {
            return [-1, -1];
        }

        int[2] pos = void;
        SDL_GetMouseState(&pos[0], &pos[1]);
        return pos;
    }

    /++
     + Wraps `SDL_WarpMouseInWindow` which sets the mouse position in the window
     +
     + Params:
     +   newMousePosition = coordinate of the mouse position to set
     +/
    void mousePosition(int[2] newMousePosition) @property @trusted {
        SDL_WarpMouseInWindow(this.sdlWindow, newMousePosition[0], newMousePosition[1]);
    }

    /++
     + Wraps `SDL_GetWindowSurface` which gets the window's surface for software rendering
     +
     + Returns: `dsdl.Surface` proxy to the window's surface
     + Throws: `dsdl.SDLException` if failed to get the window's surface
     +/
    inout(Surface) surface() inout @property @trusted {
        SDL_Surface* surfacePtr = SDL_GetWindowSurface(cast(SDL_Window*) this.sdlWindow);
        if (surfacePtr is null) {
            throw new SDLException;
        }

        if (this.surfaceProxy is null) {
            (cast(Window) this).surfaceProxy = new Surface(surfacePtr, false, cast(void*) this);
        }

        // If the surface pointer happens to change, rewire the proxy.
        if (this.surfaceProxy.sdlSurface !is surfacePtr) {
            (cast(Window) this).surfaceProxy.sdlSurface = surfacePtr;
        }

        return this.surfaceProxy;
    }

    static if (sdlSupport >= SDLSupport.v2_28) {
        /++
         + Wraps `SDL_DestroyWindowSurface` (from SDL 2.28) which destructs the underlying associated surface
         + of the window
         +
         + Throws: `dsdl.SDLException` if failed to destruct the surface
         +/
        void surface(typeof(null) _) @property @trusted
        in {
            assert(getVersion() >= Version(2, 28));
        }
        do {
            if (SDL_DestroyWindowSurface(this.sdlWindow) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `SDL_HasWindowSurface` (from SDL 2.28) which checks whether there is a surface associated with
         + the window
         +
         + Returns: `true` if the window has an associated surface, otherwise `false`
         +/
        bool hasSurface() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 28));
        }
        do {
            return SDL_HasWindowSurface(cast(SDL_Window*) this.sdlWindow) == SDL_TRUE;
        }
    }

    /++
     + Wraps `SDL_UpdateWindowSurface` which makes the changes to the window's surface current
     +
     + Throws: `dsdl.SDLException` if failed to update the window's changes
     +/
    void update() @trusted {
        if (SDL_UpdateWindowSurface(this.sdlWindow) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_UpdateWindowSurfaceRects` which makes the changes of certain parts of the window surface
     + as defined by a list of `dsdl.Rect`s current
     +
     + Params:
     +   rects = array of `dsdl.Rect`s defining parts of the window surface to update
     + Throws: `dsdl.SDLException` if failed to update the window's changes
     +/
    void update(Rect[] rects) @trusted {
        if (SDL_UpdateWindowSurfaceRects(this.sdlWindow, cast(SDL_Rect*) rects.ptr, rects.length.to!int) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `SDL_GL_SwapWindow` which updates the window with any OpenGL changes
     +/
    void swapGL() @trusted {
        SDL_GL_SwapWindow(this.sdlWindow);
    }

    static if (sdlSupport >= SDLSupport.v2_0_1) {
        /++
         + Wraps `SDL_GL_GetDrawableSize` (from SDL 2.0.1) which gets the drawable height of the window in OpenGL
         + in pixels
         +
         + Returns: height of the window in OpenGL in pixels
         +/
        uint drawableGLWidth() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 1));
        }
        do {
            uint w = void;
            SDL_GL_GetDrawableSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&w, null);
            return w;
        }

        /++
         + Wraps `SDL_GL_GetDrawableSize` (from SDL 2.0.1) which gets the drawable width of the window in OpenGL
         + in pixels
         +
         + Returns: width of the window in OpenGL in pixels
         +/
        uint drawableGLHeight() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 1));
        }
        do {
            uint h = void;
            SDL_GL_GetDrawableSize(cast(SDL_Window*) this.sdlWindow, null, cast(int*)&h);
            return h;
        }

        /++
         + Wraps `SDL_GL_GetDrawableSize` (from SDL 2.0.1) which gets the drawable size of the window in OpenGL
         + in pixels
         +
         + Returns: size of the window in OpenGL in pixels
         +/
        uint[2] drawableGLSize() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 1));
        }
        do {
            uint[2] wh = void;
            SDL_GL_GetDrawableSize(cast(SDL_Window*) this.sdlWindow, cast(int*)&wh[0], cast(int*)&wh[1]);
            return wh;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        /++
         + Wraps `SDL_SetWindowInputFocus` (from SDL 2.0.5) which focuses the window to be in reach to the user
         +
         + Throws: `dsdl.SDLException` if failed to focus the window
         +/
        void focus() @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            if (SDL_SetWindowInputFocus(this.sdlWindow) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `SDL_SetWindowModalFor` (from SDL 2.0.5) which sets the window to be a modal of another parent
         + window, making the window always be above its parent window
         +
         + Params:
         +   parent = the parent window which owns the window as a modal
         + Throws: `dsdl.SDLException` if failed to set the window as modal
         +/
        void modalFor(Window parent) @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
            assert(parent !is null);
        }
        do {
            if (SDL_SetWindowModalFor(this.sdlWindow, parent.sdlWindow) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `SDL_GetWindowOpacity` (from SDL 2.0.5) which gets the opacity of the window
         +
         + Returns: `float` indicating the opacity of the window from `0.0` (transparent) to `1.0` (opaque)
         + Throws: `dsdl.SDLException` if failed to get the window's opacity
         +/
        float opacity() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            float alpha = void;
            if (SDL_GetWindowOpacity(cast(SDL_Window*) this.sdlWindow, &alpha) != 0) {
                throw new SDLException;
            }

            return alpha;
        }

        /++
         + Wraps `SDL_SetWindowOpacity` (from SDL 2.0.5) which sets the opacity of the window
         +
         + Params:
         +   newOpacity = `float` indicating the opacity of the window from `0.0` (transparent) to `1.0` (opaque)
         + Throws: `dsdl.SDLException` if failed to set the window's opacity
         +/
        void opacity(float newOpacity) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 5));
        }
        do {
            if (SDL_SetWindowOpacity(this.sdlWindow, newOpacity) != 0) {
                throw new SDLException;
            }
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_16) {
        /++
         + Wraps `SDL_FlashWindow` (from SDL 2.0.16) which flashes the window in the desktop environment
         +
         + Params:
         +   operation = flashing operation to do
         + Throws: `dsdl.SDLException` if failed to flash the window
         +/
        void flash(FlashOperation operation) @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            if (SDL_FlashWindow(this.sdlWindow, operation) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `SDL_SetWindowAlwaysOnTop` (from SDL 2.0.16) which sets the status of the window always
         + being on top above other windows
         +
         + Params:
         +   newOnTop = `true` to always make the window to be on top, otherwise `false`
         +/
        void onTop(bool newOnTop) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            SDL_SetWindowAlwaysOnTop(this.sdlWindow, newOnTop);
        }

        /++
         + Wraps `SDL_GetWindowKeyboardGrab` (from SDL 2.0.16) which gets the status of the window grabbing
         + onto keyboard input
         +
         + Returns: `true` if the window is grabbing onto keyboard input, otherwise `false`
         +/
        bool keyboardGrab() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            return SDL_GetWindowKeyboardGrab(cast(SDL_Window*) this.sdlWindow) == SDL_TRUE;
        }

        /++
         + Wraps `SDL_SetWindowKeyboardGrab` (from SDL 2.0.16) which sets the status of the window grabbing
         + onto keyboard input
         +
         + Params:
         +   newKeyboardGrab = `true` to enable keyboard grab, otherwise `false`
         +/
        void keyboardGrab(bool newKeyboardGrab) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            SDL_SetWindowKeyboardGrab(this.sdlWindow, newKeyboardGrab);
        }

        /++
         + Wraps `SDL_GetWindowMouseGrab` (from SDL 2.0.16) which gets the status of the window grabbing
         + onto mouse input
         +
         + Returns: `true` if the window is grabbing onto mouse input, otherwise `false`
         +/
        bool mouseGrab() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            return SDL_GetWindowMouseGrab(cast(SDL_Window*) this.sdlWindow) == SDL_TRUE;
        }

        /++
         + Wraps `SDL_SetWindowMouseGrab` (from SDL 2.0.16) which sets the status of the window grabbing
         + onto mouse input
         +
         + Params:
         +   newMouseGrab = `true` to enable mouse grab, otherwise `false`
         +/
        void mouseGrab(bool newMouseGrab) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 16));
        }
        do {
            SDL_SetWindowMouseGrab(this.sdlWindow, newMouseGrab);
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_18) {
        /++
         + Wraps `SDL_GetWindowICCProfile` (from SDL 2.0.18) which gets the raw ICC profile data for the
         + screen the window is currently on
         +
         + Returns: untyped array buffer of the raw ICC profile data
         + Throws `dsdl.SDLException` if failed to obtain the ICC profile data
         +/
        void[] iccProfile() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 18));
        }
        do {
            size_t size = void;
            void* data = SDL_GetWindowICCProfile(cast(SDL_Window*) this.sdlWindow, &size);
            scope (exit)
                SDL_free(data);

            if (data is null) {
                throw new SDLException;
            }

            // Copies the data under allocation with the GC, as `data` is a manually-handled resource
            // allocated by SDL
            return data[0 .. size].dup;
        }

        /++
         + Wraps `SDL_GetWindowMouseRect` (from SDL 2.0.18) which gets the window's mouse confinement rectangle
         +
         + Returns: `dsdl.Rect` of the mouse's confinement rectangle in the window
         +/
        Nullable!Rect mouseRect() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 18));
        }
        do {
            const(SDL_Rect)* rect = SDL_GetWindowMouseRect(cast(SDL_Window*) this.sdlWindow);
            if (rect is null) {
                return Nullable!Rect.init;
            }
            else {
                return Rect(*rect).nullable;
            }
        }

        /++
         + Wraps `SDL_SetWindowMouseRect` (from SDL 2.0.18) which sets the window's mouse confinement rectangle
         +
         + Params:
         +   newMouseRect = `dsdl.Rect` specifying the rectangle in window coordinate space to confine the mouse
         +                  pointer in
         + Throws: `dsdl.SDLException` if failed to set the confinement
         +/
        void mouseRect(Rect newMouseRect) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 18));
        }
        do {
            if (SDL_SetWindowMouseRect(this.sdlWindow, &newMouseRect.sdlRect) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Acts as `SDL_SetWindowMouseRect(window, NULL)` (from SDL 2.0.18) which resets the window's mouse
         + confinement rectangle
         +
         + Throws: `dsdl.SDLException` if failed to reset the confinement
         +/
        void mouseRect(typeof(null) _) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 18));
        }
        do {
            if (SDL_SetWindowMouseRect(this.sdlWindow, null) != 0) {
                throw new SDLException;
            }
        }

        /++
         + Wraps `SDL_SetWindowMouseRect` (from SDL 2.0.18) which sets or resets the window's mouse
         + confinement rectangle
         +
         + Params:
         +   newMouseRect = `dsdl.Rect` specifying the rectangle in window coordinate space to confine the mouse
         +                  pointer in; `null` to reset the confinement
         + Throws: `dsdl.SDLException` if failed to set or reset the confinement
         +/
        void mouseRect(Nullable!Rect newMouseRect) @property @trusted
        in {
            assert(getVersion() >= Version(2, 0, 18));
        }
        do {
            if (newMouseRect.isNull) {
                this.mouseRect = null;
            }
            else {
                this.mouseRect = newMouseRect.get;
            }
        }
    }

    static if (sdlSupport >= SDLSupport.v2_26) {
        /++
         + Wraps `SDL_GetWindowSizeInPixels` (from SDL 2.26) which gets the actual size of the window in the
         + screen in pixels
         +
         + Returns: actual size of the window in the screen in pixels
         +/
        uint[2] sizeInPixels() const @property @trusted
        in {
            assert(getVersion() >= Version(2, 26));
        }
        do {
            uint[2] size = void;
            SDL_GetWindowSizeInPixels(cast(SDL_Window*) this.sdlWindow, cast(int*)&size[0], cast(int*)&size[1]);
            return size;
        }
    }
}
