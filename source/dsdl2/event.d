/++
 + Authors: Avaxar <avaxar@nekkl.org>
 + Copyright: Copyright © 2023, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl2.event;
@safe:

import bindbc.sdl;
import dsdl2.sdl;
import dsdl2.display;
import dsdl2.keyboard;
import dsdl2.mouse;

import core.stdc.string : strlen;
import std.conv : to;
import std.format : format;

/++
 + Wraps `SDL_PumpEvents` which retrieves events from input devices
 +/
void pumpEvents() @trusted {
    SDL_PumpEvents();
}

/++
 + Wraps `SDL_PollEvent` which returns the latest event in queue
 +
 + Returns: `dsdl2.Event` if there's an event, otherwise `null`
 + Examples:
 + ---
 + // Polls every upcoming event in queue
 + dsdl2.pumpEvents();
 + while (auto event = dsdl2.pollEvent()){
 +     if (cast(dsdl2.QuitEvent)event) {
 +         dsdl2.quit();
 +     }
 + }
 + ---
 +/
Event pollEvent() @trusted {
    SDL_Event event = void;
    if (SDL_PollEvent(&event) == 1) {
        return Event.fromSDL(event);
    }
    else {
        return null;
    }
}

/++
 + D abstract class that wraps `SDL_Event` containing details of an event polled from `dsdl2.pollEvent()`
 +/
abstract class Event {
    SDL_Event sdlEvent; /// Internal `SDL_Event` struct

    override string toString() const;

    /++
     + Gets the `SDL_EventType` of the underlying `SDL_Event`
     +
     + Returns: `SDL_EventType` enumeration from bindbc-sdl
     +/
    SDL_EventType sdlEventType() const nothrow @property {
        return this.sdlEvent.type;
    }

    /++
     + Proxy to the timestamp of the `dsdl2.Event`
     +
     + Returns: timestamp of the `dsdl2.Event`
     +/
    ref inout(uint) timestamp() return inout @property {
        return this.sdlEvent.common.timestamp;
    }

    /++
     + Turns a vanilla `SDL_Event` from bindbc-sdl to `dsdl2.Event`
     +
     + Params:
     +   sdlEvent = vanilla `SDL_Event` from bindbc-sdl
     + Returns: `dsdl2.Event` of the same attributes
     +/
    static Event fromSDL(SDL_Event sdlEvent) @trusted {
        Event event;
        switch (sdlEvent.type) {
        default:
            event = new UnknownEvent(sdlEvent);
            break;

        case SDL_QUIT:
            event = new QuitEvent;
            break;

        case SDL_APP_TERMINATING:
            event = new AppTerminatingEvent;
            break;

        case SDL_APP_LOWMEMORY:
            event = new AppLowMemoryEvent;
            break;

        case SDL_APP_WILLENTERBACKGROUND:
            event = new AppWillEnterBackgroundEvent;
            break;

        case SDL_APP_DIDENTERBACKGROUND:
            event = new AppDidEnterBackgroundEvent;
            break;

        case SDL_APP_WILLENTERFOREGROUND:
            event = new AppWillEnterForegroundEvent;
            break;

        case SDL_APP_DIDENTERFOREGROUND:
            event = new AppDidEnterForegroundEvent;
            break;

            static if (sdlSupport >= SDLSupport.v2_0_14) {
        case SDL_LOCALECHANGED:
                event = new LocaleChangeEvent;
                break;
            }

            static if (sdlSupport >= SDLSupport.v2_0_9) {
        case SDL_DISPLAYEVENT:
                event = DisplayEvent.fromSDL(sdlEvent);
                break;
            }

        case SDL_WINDOWEVENT:
            event = WindowEvent.fromSDL(sdlEvent);
            break;

        case SDL_SYSWMEVENT:
            event = new SysWMEvent(sdlEvent.syswm.msg);
            break;

        case SDL_KEYDOWN:
        case SDL_KEYUP:
            event = KeyboardEvent.fromSDL(sdlEvent);
            break;

        case SDL_TEXTEDITING:
            event = new TextEditingEvent(sdlEvent.edit.windowID, sdlEvent.edit.text.ptr.to!string,
                sdlEvent.edit.start.to!uint, sdlEvent.edit.length.to!uint);
            break;

        case SDL_TEXTINPUT:
            event = new TextInputEvent(sdlEvent.text.windowID, sdlEvent.text.text.ptr.to!string);
            break;

            static if (sdlSupport >= SDLSupport.v2_0_4) {
        case SDL_KEYMAPCHANGED:
                event = new KeymapChangedEvent;
                break;
            }

        case SDL_MOUSEMOTION:
            event = new MouseMotionEvent(sdlEvent.motion.windowID, sdlEvent.motion.which,
                MouseState(sdlEvent.motion.state),
                [sdlEvent.motion.x, sdlEvent.motion.y],
                [sdlEvent.motion.xrel, sdlEvent.motion.yrel]);
            break;

        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:
            event = MouseButtonEvent.fromSDL(sdlEvent);
            break;

        case SDL_MOUSEWHEEL:
            static if (sdlSupport >= SDLSupport.v2_0_18) {
                event = new MouseWheelEvent(sdlEvent.wheel.windowID, sdlEvent.wheel.which,
                    [sdlEvent.wheel.x, sdlEvent.wheel.y], cast(MouseWheel) sdlEvent.wheel.direction,
                    [sdlEvent.wheel.preciseX, sdlEvent.wheel.preciseY]);
                break;
            }
            else static if (sdlSupport >= SDLSupport.v2_0_4) {
                event = new MouseWheelEvent(sdlEvent.wheel.windowID, sdlEvent.wheel.which,
                    [sdlEvent.wheel.x, sdlEvent.wheel.y], cast(MouseWheel) sdlEvent.wheel.direction);
                break;
            }
            else {
                event = new MouseWheelEvent(sdlEvent.wheel.windowID, sdlEvent.wheel.which,
                    [sdlEvent.wheel.x, sdlEvent.wheel.y]);
                break;
            }

        case SDL_DROPFILE:
            static if (sdlSupport >= SDLSupport.v2_0_5) {
        case SDL_DROPTEXT:
        case SDL_DROPBEGIN:
        case SDL_DROPCOMPLETE:
            }
            event = DropFileEvent.fromSDL(sdlEvent);
            break;
        }

        event.timestamp = sdlEvent.common.timestamp;
        return event;
    }
}

/++
 + D class that wraps SDL events that aren't recognized by dsdl2
 +/
final class UnknownEvent : Event {
    this(SDL_Event sdlEvent) {
        this.sdlEvent = sdlEvent;
    }

    override string toString() const {
        return "dsdl2.UnknownEvent(%s)".format(this.sdlEvent);
    }
}

/++
 + D class that wraps `SDL_QUIT` `SDL_Event`s
 +/
final class QuitEvent : Event {
    this() {
        this.sdlEvent.type = SDL_QUIT;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_QUIT);
    }

    override string toString() const {
        return "dsdl2.QuitEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_TERMINATING` `SDL_Event`s
 +/
final class AppTerminatingEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_TERMINATING;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_TERMINATING);
    }

    override string toString() const {
        return "dsdl2.AppTerminatingEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_LOWMEMORY` `SDL_Event`s
 +/
final class AppLowMemoryEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_LOWMEMORY;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_LOWMEMORY);
    }

    override string toString() const {
        return "dsdl2.AppLowMemoryEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_WILLENTERBACKGROUND` `SDL_Event`s
 +/
final class AppWillEnterBackgroundEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_WILLENTERBACKGROUND;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_WILLENTERBACKGROUND);
    }

    override string toString() const {
        return "dsdl2.AppWillEnterBackgroundEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_DIDENTERBACKGROUND` `SDL_Event`s
 +/
final class AppDidEnterBackgroundEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_DIDENTERBACKGROUND;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_DIDENTERBACKGROUND);
    }

    override string toString() const {
        return "dsdl2.AppDidEnterBackgroundEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_WILLENTERFOREGROUND` `SDL_Event`s
 +/
final class AppWillEnterForegroundEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_WILLENTERFOREGROUND;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_WILLENTERFOREGROUND);
    }

    override string toString() const {
        return "dsdl2.AppWillEnterForegroundEvent()";
    }
}

/++
 + D class that wraps `SDL_APP_DIDENTERFOREGROUND` `SDL_Event`s
 +/
final class AppDidEnterForegroundEvent : Event {
    this() {
        this.sdlEvent.type = SDL_APP_DIDENTERFOREGROUND;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_APP_DIDENTERFOREGROUND);
    }

    override string toString() const {
        return "dsdl2.AppDidEnterForegroundEvent()";
    }
}

static if (sdlSupport >= SDLSupport.v2_0_14) {
    /++
     + D class that wraps `SDL_LOCALECHANGED` `SDL_Event`s (from SDL 2.0.14)
     +/
    class LocaleChangeEvent : Event {
        this() {
            this.sdlEvent.type = SDL_LOCALECHANGED;
        }

        invariant {
            assert(this.sdlEvent.type == SDL_LOCALECHANGED);
        }

        override string toString() const {
            return "dsdl2.LocaleChangeEvent()";
        }
    }
}

static if (sdlSupport >= SDLSupport.v2_0_9) {
    /++
     + D abstract class that wraps `SDL_DISPLAYEVENT` `SDL_Event`s (from SDL 2.0.9)
     +/
    abstract class DisplayEvent : Event {
        invariant {
            assert(this.sdlEvent.type == SDL_DISPLAYEVENT);
        }

        SDL_DisplayEventID sdlDisplayEventID() const nothrow @property {
            return this.sdlEvent.display.event;
        }

        ref inout(uint) display() return inout @property {
            return this.sdlEvent.display.display;
        }

        static Event fromSDL(SDL_Event sdlEvent)
        in {
            assert(sdlEvent.type == SDL_DISPLAYEVENT);
        }
        do {
            Event event;
            switch (sdlEvent.display.event) {
            default:
                event = new UnknownEvent(sdlEvent);
                break;

            case SDL_DISPLAYEVENT_ORIENTATION:
                event = new DisplayOrientationEvent(sdlEvent.display.display,
                    cast(DisplayOrientation) sdlEvent.display.data1);
                break;

            case SDL_DISPLAYEVENT_CONNECTED:
                event = new DisplayConnectedEvent(sdlEvent.display.display);
                break;

            case SDL_DISPLAYEVENT_DISCONNECTED:
                event = new DisplayDisconnectedEvent(sdlEvent.display.display);
                break;
            }

            event.timestamp = sdlEvent.display.timestamp;
            return event;
        }
    }

    /++
     + D class that wraps `SDL_DISPLAYEVENT_ORIENTATION` `SDL_DISPLAYEVENT` `SDL_Event`s (from SDL 2.0.9)
     +/
    class DisplayOrientationEvent : DisplayEvent {
        this(uint display, DisplayOrientation orientation) {
            this.sdlEvent.type = SDL_DISPLAYEVENT;
            this.sdlEvent.display.event = SDL_DISPLAYEVENT_ORIENTATION;
            this.sdlEvent.display.display = display;
            this.sdlEvent.display.data1 = orientation;
        }

        invariant {
            assert(this.sdlEvent.display.event == SDL_DISPLAYEVENT_ORIENTATION);
        }

        override string toString() const {
            return "dsdl2.DisplayOrientationEvent(%d, %d)".format(this.display, this.orientation);
        }

        ref inout(DisplayOrientation) orientation() return inout @property @trusted {
            return *cast(inout(DisplayOrientation*))&this.sdlEvent.display.data1;
        }
    }

    /++
     + D class that wraps `SDL_DISPLAYEVENT_CONNECTED` `SDL_DISPLAYEVENT` `SDL_Event`s (from SDL 2.0.9)
     +/
    class DisplayConnectedEvent : DisplayEvent {
        this(uint display) {
            this.sdlEvent.type = SDL_DISPLAYEVENT;
            this.sdlEvent.display.event = SDL_DISPLAYEVENT_CONNECTED;
            this.sdlEvent.display.display = display;
        }

        invariant {
            assert(this.sdlEvent.display.event == SDL_DISPLAYEVENT_CONNECTED);
        }

        override string toString() const {
            return "dsdl2.DisplayConnectedEvent(%d)".format(this.display);
        }
    }

    /++
     + D class that wraps `SDL_DISPLAYEVENT_DISCONNECTED` `SDL_DISPLAYEVENT` `SDL_Event`s (from SDL 2.0.9)
     +/
    class DisplayDisconnectedEvent : DisplayEvent {
        this(uint display) {
            this.sdlEvent.type = SDL_DISPLAYEVENT;
            this.sdlEvent.display.event = SDL_DISPLAYEVENT_DISCONNECTED;
            this.sdlEvent.display.display = display;
        }

        invariant {
            assert(this.sdlEvent.display.event == SDL_DISPLAYEVENT_DISCONNECTED);
        }

        override string toString() const {
            return "dsdl2.DisplayDisconnectedEvent(%d)".format(this.display);
        }
    }
}

/++
 + D abstract class that wraps `SDL_WINDOWEVENT` `SDL_Event`s
 +/
abstract class WindowEvent : Event {
    invariant {
        assert(this.sdlEvent.type == SDL_WINDOWEVENT);
    }

    SDL_WindowEventID sdlWindowEventID() const nothrow @property {
        return this.sdlEvent.window.event;
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.window.windowID;
    }

    static Event fromSDL(SDL_Event sdlEvent)
    in {
        assert(sdlEvent.type == SDL_WINDOWEVENT);
    }
    do {
        Event event;
        switch (sdlEvent.window.event) {
        default:
            event = new UnknownEvent(sdlEvent);
            break;

        case SDL_WINDOWEVENT_SHOWN:
            event = new WindowShownEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_HIDDEN:
            event = new WindowHiddenEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_EXPOSED:
            event = new WindowExposedEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_MOVED:
            event = new WindowMovedEvent(sdlEvent.window.windowID,
                [sdlEvent.window.data1, sdlEvent.window.data2]);
            break;

        case SDL_WINDOWEVENT_RESIZED:
            event = new WindowResizedEvent(sdlEvent.window.windowID,
                [sdlEvent.window.data1, sdlEvent.window.data2]);
            break;

        case SDL_WINDOWEVENT_SIZE_CHANGED:
            event = new WindowSizeChangedEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_MINIMIZED:
            event = new WindowMinimizedEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_MAXIMIZED:
            event = new WindowMaximizedEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_RESTORED:
            event = new WindowRestoredEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_ENTER:
            event = new WindowEnterEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_LEAVE:
            event = new WindowLeaveEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_FOCUS_GAINED:
            event = new WindowFocusGainedEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_FOCUS_LOST:
            event = new WindowFocusLostEvent(sdlEvent.window.windowID);
            break;

        case SDL_WINDOWEVENT_CLOSE:
            event = new WindowCloseEvent(sdlEvent.window.windowID);
            break;

            static if (sdlSupport >= SDLSupport.v2_0_5) {
        case SDL_WINDOWEVENT_TAKE_FOCUS:
                event = new WindowTakeFocusEvent(sdlEvent.window.windowID);
                break;

        case SDL_WINDOWEVENT_HIT_TEST:
                event = new WindowHitTestEvent(sdlEvent.window.windowID);
                break;
            }

            static if (sdlSupport >= SDLSupport.v2_0_18) {
        case SDL_WINDOWEVENT_ICCPROF_CHANGED:
                event = new WindowICCProfileChangedEvent(sdlEvent.window.windowID);
                break;

        case SDL_WINDOWEVENT_DISPLAY_CHANGED:
                event = new WindowDisplayChangedEvent(sdlEvent.window.windowID,
                    sdlEvent.window.data1);
                break;
            }
        }

        event.timestamp = sdlEvent.window.timestamp;
        return event;
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_SHOWN` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowShownEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_SHOWN;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_SHOWN);
    }

    override string toString() const {
        return "dsdl2.WindowShownEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_HIDDEN` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowHiddenEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_HIDDEN;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_HIDDEN);
    }

    override string toString() const {
        return "dsdl2.WindowHiddenEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_EXPOSED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowExposedEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_EXPOSED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_EXPOSED);
    }

    override string toString() const {
        return "dsdl2.WindowExposedEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_MOVED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowMovedEvent : WindowEvent {
    this(uint windowID, int[2] xy) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_MOVED;
        this.sdlEvent.window.windowID = windowID;
        this.sdlEvent.window.data1 = xy[0];
        this.sdlEvent.window.data2 = xy[1];
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_MOVED);
    }

    override string toString() const {
        return "dsdl2.WindowMovedEvent(%d, %s)".format(this.windowID, this.xy);
    }

    ref inout(int) x() return inout @property {
        return this.sdlEvent.window.data1;
    }

    ref inout(int) y() return inout @property {
        return this.sdlEvent.window.data2;
    }

    ref inout(int[2]) xy() return inout @property @trusted {
        return *cast(inout(int[2]*))&this.sdlEvent.window.data1;
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_RESIZED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowResizedEvent : WindowEvent {
    this(uint windowID, uint[2] size) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_RESIZED;
        this.sdlEvent.window.windowID = windowID;
        this.sdlEvent.window.data1 = size[0].to!int;
        this.sdlEvent.window.data2 = size[1].to!int;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_RESIZED);
    }

    override string toString() const {
        return "dsdl2.WindowResizedEvent(%d, %s)".format(this.windowID, this.size);
    }

    ref inout(uint) width() return inout @property @trusted {
        return *cast(inout(uint*))&this.sdlEvent.window.data1;
    }

    ref inout(uint) height() return inout @property @trusted {
        return *cast(inout(uint*))&this.sdlEvent.window.data2;
    }

    ref inout(uint[2]) size() return inout @property @trusted {
        return *cast(inout(uint[2]*))&this.sdlEvent.window.data1;
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_SIZE_CHANGED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowSizeChangedEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_SIZE_CHANGED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_SIZE_CHANGED);
    }

    override string toString() const {
        return "dsdl2.WindowSizeChangedEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_MINIMIZED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowMinimizedEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_MINIMIZED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_MINIMIZED);
    }

    override string toString() const {
        return "dsdl2.WindowMinimizedEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_MAXIMIZED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowMaximizedEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_MAXIMIZED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_MAXIMIZED);
    }

    override string toString() const {
        return "dsdl2.WindowMaximizedEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_RESTORED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowRestoredEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_RESTORED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_RESTORED);
    }

    override string toString() const {
        return "dsdl2.WindowRestoredEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_ENTER` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowEnterEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_ENTER;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_ENTER);
    }

    override string toString() const {
        return "dsdl2.WindowEnterEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_LEAVE` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowLeaveEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_LEAVE;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_LEAVE);
    }

    override string toString() const {
        return "dsdl2.WindowLeaveEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_FOCUS_GAINED` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowFocusGainedEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_FOCUS_GAINED;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_FOCUS_GAINED);
    }

    override string toString() const {
        return "dsdl2.WindowFocusGainedEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_FOCUS_LOST` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowFocusLostEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_FOCUS_LOST;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_FOCUS_LOST);
    }

    override string toString() const {
        return "dsdl2.WindowFocusLostEvent(%d)".format(this.windowID);
    }
}

/++
 + D class that wraps `SDL_WINDOWEVENT_CLOSE` `SDL_WINDOWEVENT` `SDL_Event`s
 +/
final class WindowCloseEvent : WindowEvent {
    this(uint windowID) {
        this.sdlEvent.type = SDL_WINDOWEVENT;
        this.sdlEvent.window.event = SDL_WINDOWEVENT_CLOSE;
        this.sdlEvent.window.windowID = windowID;
    }

    invariant {
        assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_CLOSE);
    }

    override string toString() const {
        return "dsdl2.WindowCloseEvent(%d)".format(this.windowID);
    }
}

static if (sdlSupport >= SDLSupport.v2_0_5) {
    /++
     + D class that wraps `SDL_WINDOWEVENT_TAKE_FOCUS` `SDL_WINDOWEVENT` `SDL_Event`s (from SDL 2.0.5)
     +/
    class WindowTakeFocusEvent : WindowEvent {
        this(uint windowID) {
            this.sdlEvent.type = SDL_WINDOWEVENT;
            this.sdlEvent.window.event = SDL_WINDOWEVENT_TAKE_FOCUS;
            this.sdlEvent.window.windowID = windowID;
        }

        invariant {
            assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_TAKE_FOCUS);
        }

        override string toString() const {
            return "dsdl2.WindowTakeFocusEvent(%d)".format(this.windowID);
        }
    }

    /++
     + D class that wraps `SDL_WINDOWEVENT_HIT_TEST` `SDL_WINDOWEVENT` `SDL_Event`s (from SDL 2.0.5)
     +/
    class WindowHitTestEvent : WindowEvent {
        this(uint windowID) {
            this.sdlEvent.type = SDL_WINDOWEVENT;
            this.sdlEvent.window.event = SDL_WINDOWEVENT_HIT_TEST;
            this.sdlEvent.window.windowID = windowID;
        }

        invariant {
            assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_HIT_TEST);
        }

        override string toString() const {
            return "dsdl2.WindowHitTestEvent(%d)".format(this.windowID);
        }
    }
}

static if (sdlSupport >= SDLSupport.v2_0_18) {
    /++
     + D class that wraps `SDL_WINDOWEVENT_ICCPROF_CHANGED` `SDL_WINDOWEVENT` `SDL_Event`s (from SDL 2.0.18)
     +/
    class WindowICCProfileChangedEvent : WindowEvent {
        this(uint windowID) {
            this.sdlEvent.type = SDL_WINDOWEVENT;
            this.sdlEvent.window.event = SDL_WINDOWEVENT_ICCPROF_CHANGED;
            this.sdlEvent.window.windowID = windowID;
        }

        invariant {
            assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_ICCPROF_CHANGED);
        }

        override string toString() const {
            return "dsdl2.WindowICCProfileChangedEvent(%d)".format(this.windowID);
        }
    }

    /++
     + D class that wraps `SDL_WINDOWEVENT_DISPLAY_CHANGED` `SDL_WINDOWEVENT` `SDL_Event`s (from SDL 2.0.18)
     +/
    class WindowDisplayChangedEvent : WindowEvent {
        this(uint windowID, uint display) {
            this.sdlEvent.type = SDL_WINDOWEVENT;
            this.sdlEvent.window.event = SDL_WINDOWEVENT_DISPLAY_CHANGED;
            this.sdlEvent.window.windowID = windowID;
            this.sdlEvent.window.data1 = display.to!int;
        }

        invariant {
            assert(this.sdlEvent.window.event == SDL_WINDOWEVENT_DISPLAY_CHANGED);
        }

        override string toString() const {
            return "dsdl2.WindowDisplayChangedEvent(%d)".format(this.windowID, this.display);
        }

        ref inout(int) display() return inout @property {
            return this.sdlEvent.window.data1;
        }
    }
}

/++
 + D class that wraps `SDL_SYSWMEVENT` `SDL_Event`s
 +/
final class SysWMEvent : Event {
    this(SDL_SysWMmsg* msg) @system {
        this.sdlEvent.type = SDL_SYSWMEVENT;
        this.sdlEvent.syswm.msg = msg;
    }

    @trusted invariant {
        assert(this.sdlEvent.syswm.msg !is null);
    }

    override string toString() const @trusted {
        return "dsdl2.SysWMEvent(0x%x)".format(this.msg);
    }

    ref inout(SDL_SysWMmsg*) msg() return inout @property @system {
        return this.sdlEvent.syswm.msg;
    }
}

/++
 + D abstract class that wraps keyboard `SDL_Event`s
 +/
abstract class KeyboardEvent : Event {
    invariant {
        assert(this.sdlEvent.type == SDL_KEYDOWN || this.sdlEvent.type == SDL_KEYUP);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.key.windowID;
    }

    ref inout(ubyte) repeat() return inout @property {
        return this.sdlEvent.key.repeat;
    }

    ref inout(Scancode) scancode() return inout @property @trusted {
        return *cast(inout(Scancode*))&this.sdlEvent.key.keysym.scancode;
    }

    ref inout(Keycode) sym() return inout @property @trusted {
        return *cast(inout(Keycode*))&this.sdlEvent.key.keysym.sym;
    }

    Keymod mod() const @property {
        return Keymod(this.sdlEvent.key.keysym.mod);
    }

    void mod(Keymod newMod) @property {
        this.sdlEvent.key.keysym.mod = newMod.sdlKeymod;
    }

    static Event fromSDL(SDL_Event sdlEvent)
    in {
        assert(sdlEvent.type == SDL_KEYDOWN || sdlEvent.type == SDL_KEYUP);
    }
    do {
        Event event;
        switch (sdlEvent.type) {
        default:
            assert(false);

        case SDL_KEYDOWN:
            event = new KeyDownKeyboardEvent(sdlEvent.key.windowID, sdlEvent.key.repeat,
                cast(Scancode) sdlEvent.key.keysym.scancode, cast(Keycode) sdlEvent.key.keysym.sym,
                Keymod(sdlEvent.key.keysym.mod));
            break;

        case SDL_KEYUP:
            event = new KeyUpKeyboardEvent(sdlEvent.key.windowID, sdlEvent.key.repeat,
                cast(Scancode) sdlEvent.key.keysym.scancode, cast(Keycode) sdlEvent.key.keysym.sym,
                Keymod(sdlEvent.key.keysym.mod));
            break;
        }

        event.timestamp = sdlEvent.key.timestamp;
        return event;
    }
}

/++
 + D class that wraps `SDL_KEYDOWN` `SDL_Event`s
 +/
final class KeyDownKeyboardEvent : KeyboardEvent {
    this(uint windowID, ubyte repeat, Scancode scancode, Keycode sym, Keymod mod) {
        this.sdlEvent.type = SDL_KEYDOWN;
        this.sdlEvent.key.windowID = windowID;
        this.sdlEvent.key.repeat = repeat;
        this.sdlEvent.key.keysym.scancode = cast(SDL_Scancode) scancode;
        this.sdlEvent.key.keysym.sym = cast(SDL_Keycode) sym;
        this.sdlEvent.key.keysym.mod = mod.sdlKeymod;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_KEYDOWN);
    }

    override string toString() const {
        return "dsdl2.KeyDownKeyboardEvent(%d, %d, %s, %s, %s)".format(this.windowID, this.repeat, this.scancode,
            this.sym, this.mod);
    }
}

/++
 + D class that wraps `SDL_KEYUP` `SDL_Event`s
 +/
final class KeyUpKeyboardEvent : KeyboardEvent {
    this(uint windowID, ubyte repeat, Scancode scancode, Keycode sym, Keymod mod) {
        this.sdlEvent.type = SDL_KEYUP;
        this.sdlEvent.key.windowID = windowID;
        this.sdlEvent.key.repeat = repeat;
        this.sdlEvent.key.keysym.scancode = cast(SDL_Scancode) scancode;
        this.sdlEvent.key.keysym.sym = cast(SDL_Keycode) sym;
        this.sdlEvent.key.keysym.mod = mod.sdlKeymod;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_KEYUP);
    }

    override string toString() const {
        return "dsdl2.KeyUpKeyboardEvent(%d, %d, %s, %s, %s)".format(this.windowID, this.repeat, this.scancode,
            this.sym, this.mod);
    }
}

/++
 + D class that wraps `SDL_TEXTEDITING` `SDL_Event`s
 +/
final class TextEditingEvent : Event {
    this(uint windowID, string text, uint start, uint length)
    in {
        assert(text.length < 32);
    }
    do {
        this.sdlEvent.type = SDL_TEXTEDITING;
        this.sdlEvent.edit.windowID = windowID;
        this.sdlEvent.edit.text[0 .. text.length] = text[];
        this.sdlEvent.edit.start = start.to!int;
        this.sdlEvent.edit.length = length.to!int;
    }

    invariant {
        assert(this.sdlEvent.type == SDL_TEXTEDITING);
    }

    override string toString() const @trusted {
        return "dsdl2.TextEditingEvent(%d, %s, %d, %d)".format(this.windowID,
            [this.text].to!string[1 .. $ - 1], this.start, this.length);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.edit.windowID;
    }

    string text() const @property @trusted {
        return this.sdlEvent.edit.text.ptr.to!string;
    }

    void text(string newText) @property
    in {
        assert(newText.length < 32);
    }
    do {
        this.sdlEvent.edit.text[0 .. newText.length] = newText[];
    }

    ref inout(uint) start() return inout @property {
        return *cast(inout(uint*))&this.sdlEvent.edit.start;
    }

    ref inout(uint) length() return inout @property {
        return *cast(inout(uint*))&this.sdlEvent.edit.length;
    }
}

/++
 + D class that wraps `SDL_TEXTINPUT` `SDL_Event`s
 +/
final class TextInputEvent : Event {
    this(uint windowID, string text)
    in {
        assert(text.length < 32);
    }
    do {
        this.sdlEvent.type = SDL_TEXTINPUT;
        this.sdlEvent.edit.windowID = windowID;
        this.sdlEvent.edit.text[0 .. text.length] = text[];
    }

    invariant {
        assert(this.sdlEvent.type == SDL_TEXTINPUT);
    }

    override string toString() const @trusted {
        return "dsdl2.TextInputEvent(%d, %s)".format(this.windowID,
            [this.text].to!string[1 .. $ - 1]);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.edit.windowID;
    }

    string text() const @property @trusted {
        return this.sdlEvent.edit.text.ptr.to!string;
    }

    void text(string newText) @property
    in {
        assert(newText.length < 32);
    }
    do {
        this.sdlEvent.edit.text[0 .. newText.length] = newText[];
    }
}

static if (sdlSupport >= SDLSupport.v2_0_4) {
    /++
     + D class that wraps `SDL_KEYMAPCHANGED` `SDL_Event`s (from SDL 2.0.4)
     +/
    final class KeymapChangedEvent : Event {
        this() {
            this.sdlEvent.type = SDL_KEYMAPCHANGED;
        }

        invariant {
            assert(this.sdlEvent.type == SDL_KEYMAPCHANGED);
        }

        override string toString() const {
            return "dsdl2.KeymapChangedEvent()";
        }
    }
}

/++
 + D class that wraps `SDL_MOUSEMOTION` `SDL_Event`s
 +/
final class MouseMotionEvent : Event {
    this(uint windowID, uint which, MouseState state, int[2] xy, int[2] xyRel) {
        this.sdlEvent.type = SDL_MOUSEMOTION;
        this.sdlEvent.motion.windowID = windowID;
        this.sdlEvent.motion.which = which;
        this.sdlEvent.motion.state = state.sdlMouseState;
        this.sdlEvent.motion.x = xy[0];
        this.sdlEvent.motion.y = xy[1];
        this.sdlEvent.motion.xrel = xyRel[0];
        this.sdlEvent.motion.yrel = xyRel[1];
    }

    invariant {
        assert(this.sdlEvent.type == SDL_MOUSEMOTION);
    }

    override string toString() const {
        return "dsdl2.MouseMotionEvent(%d, %d, %s, %s, %s)".format(this.windowID, this.which,
            this.state, this.xy, this.xyRel);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.motion.windowID;
    }

    ref inout(uint) which() return inout @property {
        return this.sdlEvent.motion.which;
    }

    MouseState state() const @property {
        return MouseState(this.sdlEvent.motion.state);
    }

    void state(MouseState newState) @property {
        this.sdlEvent.motion.state = newState.sdlMouseState;
    }

    ref inout(int) x() return inout @property {
        return this.sdlEvent.motion.x;
    }

    ref inout(int) y() return inout @property {
        return this.sdlEvent.motion.y;
    }

    ref inout(int[2]) xy() return inout @property @trusted {
        return *cast(inout(int[2]*))&this.sdlEvent.motion.x;
    }

    ref inout(int) xRel() return inout @property {
        return this.sdlEvent.motion.xrel;
    }

    ref inout(int) yRel() return inout @property {
        return this.sdlEvent.motion.yrel;
    }

    ref inout(int[2]) xyRel() return inout @property @trusted {
        return *cast(inout(int[2]*))&this.sdlEvent.motion.xrel;
    }
}

/++
 + D abstract class that wraps mouse button `SDL_Event`s
 +/
abstract class MouseButtonEvent : Event {
    invariant {
        assert(this.sdlEvent.type == SDL_MOUSEBUTTONDOWN || this.sdlEvent.type == SDL_MOUSEBUTTONUP);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.button.windowID;
    }

    ref inout(uint) which() return inout @property {
        return this.sdlEvent.button.which;
    }

    ref inout(MouseButton) button() inout @property @trusted {
        return *cast(inout(MouseButton*))&this.sdlEvent.button.button;
    }

    ref inout(ubyte) clicks() return inout @property {
        static if (sdlSupport >= SDLSupport.v2_0_2) {
            return this.sdlEvent.button.clicks;
        }
        else {
            return this.sdlEvent.button.padding1;
        }
    }

    ref inout(int) x() return inout @property {
        return this.sdlEvent.button.x;
    }

    ref inout(int) y() return inout @property {
        return this.sdlEvent.button.y;
    }

    ref inout(int[2]) xy() return inout @property @trusted {
        return *cast(inout(int[2]*))&this.sdlEvent.button.x;
    }

    static Event fromSDL(SDL_Event sdlEvent)
    in {
        assert(sdlEvent.type == SDL_MOUSEBUTTONDOWN || sdlEvent.type == SDL_MOUSEBUTTONUP);
    }
    do {
        Event event;
        switch (sdlEvent.type) {
        default:
            assert(false);

        case SDL_MOUSEBUTTONDOWN:
            static if (sdlSupport >= SDLSupport.v2_0_2) {
                event = new MouseButtonDownEvent(sdlEvent.button.windowID, sdlEvent.button.which,
                    cast(MouseButton) sdlEvent.button.button, sdlEvent.button.clicks,
                    [sdlEvent.button.x, sdlEvent.button.y]);
            }
            else {
                event = new MouseButtonDownEvent(sdlEvent.button.windowID, sdlEvent.button.which,
                    cast(MouseButton) sdlEvent.button.button, 1,
                    [sdlEvent.button.x, sdlEvent.button.y]);
            }
            break;

        case SDL_MOUSEBUTTONUP:
            static if (sdlSupport >= SDLSupport.v2_0_2) {
                event = new MouseButtonUpEvent(sdlEvent.button.windowID, sdlEvent.button.which,
                    cast(MouseButton) sdlEvent.button.button, sdlEvent.button.clicks,
                    [sdlEvent.button.x, sdlEvent.button.y]);
            }
            else {
                event = new MouseButtonUpEvent(sdlEvent.button.windowID, sdlEvent.button.which,
                    cast(MouseButton) sdlEvent.button.button, 1,
                    [sdlEvent.button.x, sdlEvent.button.y]);
            }
            break;
        }

        event.timestamp = sdlEvent.button.timestamp;
        return event;
    }
}

/++
 + D class that wraps `SDL_MOUSEBUTTONDOWN` `SDL_Event`s
 +/
final class MouseButtonDownEvent : MouseButtonEvent {
    this(uint windowID, uint which, MouseButton button, ubyte clicks, int[2] xy) {
        this.sdlEvent.type = SDL_MOUSEBUTTONDOWN;
        this.sdlEvent.button.windowID = windowID;
        this.sdlEvent.button.which = which;
        this.sdlEvent.button.button = button;
        this.sdlEvent.button.state = SDL_PRESSED;
        static if (sdlSupport >= SDLSupport.v2_0_2) {
            this.sdlEvent.button.clicks = clicks;
        }
        else {
            this.sdlEvent.button.padding1 = clicks;
        }
        this.sdlEvent.button.x = xy[0];
        this.sdlEvent.button.y = xy[1];
    }

    invariant {
        assert(this.sdlEvent.type == SDL_MOUSEBUTTONDOWN);
        assert(this.sdlEvent.button.state == SDL_PRESSED);
    }

    override string toString() const {
        return "dsdl2.MouseButtonDownEvent(%d, %d, %s, %d, %s)".format(this.windowID,
            this.which, this.button, this.clicks, this.xy);
    }
}

/++
 + D class that wraps `SDL_MOUSEBUTTONUP` `SDL_Event`s
 +/
final class MouseButtonUpEvent : MouseButtonEvent {
    this(uint windowID, uint which, MouseButton button, ubyte clicks, int[2] xy) {
        this.sdlEvent.type = SDL_MOUSEBUTTONDOWN;
        this.sdlEvent.button.windowID = windowID;
        this.sdlEvent.button.which = which;
        this.sdlEvent.button.button = button;
        this.sdlEvent.button.state = SDL_RELEASED;
        static if (sdlSupport >= SDLSupport.v2_0_2) {
            this.sdlEvent.button.clicks = clicks;
        }
        else {
            this.sdlEvent.button.padding1 = clicks;
        }
        this.sdlEvent.button.x = xy[0];
        this.sdlEvent.button.y = xy[1];
    }

    invariant {
        assert(this.sdlEvent.type == SDL_MOUSEBUTTONDOWN);
        assert(this.sdlEvent.button.state == SDL_RELEASED);
    }

    override string toString() const {
        return "dsdl2.MouseButtonUpEvent(%d, %d, %s, %d, %s)".format(this.windowID,
            this.which, this.button, this.clicks, this.xy);
    }
}

/++
 + D class that wraps `SDL_MOUSEWHEEL` `SDL_Event`s
 +/
final class MouseWheelEvent : Event {
    static if (sdlSupport >= SDLSupport.v2_0_18) {
        this(uint windowID, uint which, int[2] xy, MouseWheel direction = MouseWheel.normal,
            float[2] preciseXY = [0.0, 0.0]) {
            this.sdlEvent.type = SDL_MOUSEWHEEL;
            this.sdlEvent.wheel.windowID = windowID;
            this.sdlEvent.wheel.which = which;
            this.sdlEvent.wheel.x = xy[0];
            this.sdlEvent.wheel.y = xy[1];
            this.sdlEvent.wheel.direction = cast(uint) direction;
            this.sdlEvent.wheel.preciseX = preciseXY[0];
            this.sdlEvent.wheel.preciseY = preciseXY[1];
        }
    }
    else static if (sdlSupport >= SDLSupport.v2_0_4) {
        this(uint windowID, uint which, int[2] xy, MouseWheel direction = MouseWheel.normal) {
            this.sdlEvent.type = SDL_MOUSEWHEEL;
            this.sdlEvent.wheel.windowID = windowID;
            this.sdlEvent.wheel.which = which;
            this.sdlEvent.wheel.x = xy[0];
            this.sdlEvent.wheel.y = xy[1];
            this.sdlEvent.wheel.direction = cast(uint) direction;
        }
    }
    else {
        this(uint windowID, uint which, int[2] xy) {
            this.sdlEvent.type = SDL_MOUSEWHEEL;
            this.sdlEvent.wheel.windowID = windowID;
            this.sdlEvent.wheel.which = which;
            this.sdlEvent.wheel.x = xy[0];
            this.sdlEvent.wheel.y = xy[1];
        }
    }

    invariant {
        assert(this.sdlEvent.type == SDL_MOUSEWHEEL);
    }

    ref inout(uint) windowID() return inout @property {
        return this.sdlEvent.wheel.windowID;
    }

    override string toString() const {
        static if (sdlSupport >= SDLSupport.v2_0_18) {
            return "dsdl2.MouseWheelEvent(%d, %d, %s, %s, %s)".format(this.windowID, this.which,
                this.xy, this.direction, this.preciseXY);
        }
        else static if (sdlSupport >= SDLSupport.v2_0_4) {
            return "dsdl2.MouseWheelEvent(%d, %d, %s, %s)".format(this.windowID, this.which, this.xy,
                this.direction);
        }
        else {
            return "dsdl2.MouseWheelEvent(%d, %d, %s)".format(this.windowID, this.which, this.xy);
        }
    }

    ref inout(uint) which() return inout @property {
        return this.sdlEvent.wheel.which;
    }

    ref inout(int) x() return inout @property {
        return this.sdlEvent.wheel.x;
    }

    ref inout(int) y() return inout @property {
        return this.sdlEvent.wheel.y;
    }

    ref inout(int[2]) xy() return inout @property @trusted {
        return *cast(inout(int[2]*))&this.sdlEvent.wheel.x;
    }

    static if (sdlSupport >= SDLSupport.v2_0_4) {
        ref inout(MouseWheel) direction() return inout @property @trusted {
            return *cast(inout(MouseWheel*))&this.sdlEvent.wheel.direction;
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_18) {
        ref inout(float) preciseX() return inout @property {
            return this.sdlEvent.wheel.preciseX;
        }

        ref inout(float) preciseY() return inout @property {
            return this.sdlEvent.wheel.preciseY;
        }

        ref inout(float[2]) preciseXY() return inout @property @trusted {
            return *cast(inout(float[2]*))&this.sdlEvent.wheel.preciseX;
        }
    }
}

/++
 + D abstract class that wraps drop `SDL_Event`s
 +/
abstract class DropEvent : Event {
    ~this() @trusted {
        if (this.sdlEvent.drop.file !is null) {
            SDL_free(this.sdlEvent.drop.file);
        }
    }

    invariant {
        static if (sdlSupport >= SDLSupport.v2_0_5) {
            assert(this.sdlEvent.type == SDL_DROPFILE || this.sdlEvent.type == SDL_DROPTEXT
                    || this.sdlEvent.type == SDL_DROPBEGIN || this.sdlEvent.type == SDL_DROPCOMPLETE);
        }
        else {
            assert(this.sdlEvent.type == SDL_DROPFILE);
        }
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        ref inout(uint) windowID() return inout @property @trusted {
            return this.sdlEvent.drop.windowID;
        }
    }

    static Event fromSDL(SDL_Event sdlEvent) @trusted
    in {
        static if (sdlSupport >= SDLSupport.v2_0_5) {
            assert(sdlEvent.type == SDL_DROPFILE || sdlEvent.type == SDL_DROPTEXT
                    || sdlEvent.type == SDL_DROPBEGIN || sdlEvent.type == SDL_DROPCOMPLETE);
        }
        else {
            assert(sdlEvent.type == SDL_DROPFILE);
        }
    }
    do {
        Event event;
        switch (sdlEvent.type) {
        default:
            assert(false);

        case SDL_DROPFILE:
            static if (sdlSupport >= SDLSupport.v2_0_5) {
                event = new DropFileEvent(sdlEvent.drop.file[0 .. strlen(sdlEvent.drop.file)].idup,
                    sdlEvent.drop.windowID);
            }
            else {
                event = new DropFileEvent(sdlEvent.drop.file[0 .. strlen(sdlEvent.drop.file)].idup);
            }
            break;

            static if (sdlSupport >= SDLSupport.v2_0_5) {
        case SDL_DROPTEXT:
                event = new DropTextEvent(sdlEvent.drop.file[0 .. strlen(sdlEvent.drop.file)].idup,
                    sdlEvent.drop.windowID);
                break;

        case SDL_DROPBEGIN:
                event = new DropBeginEvent(sdlEvent.drop.windowID);
                break;

        case SDL_DROPCOMPLETE:
                event = new DropCompleteEvent(sdlEvent.drop.windowID);
                break;
            }
        }

        event.timestamp = sdlEvent.drop.timestamp;
        return event;
    }
}

/++
 + D class that wraps `SDL_DROPFILE` `SDL_Event`s
 +/
class DropFileEvent : DropEvent {
    this(string file) @trusted {
        this.sdlEvent.type = SDL_DROPFILE;
        this.sdlEvent.drop.file = cast(char*) SDL_malloc(file.length + 1);
        this.sdlEvent.drop.file[0 .. file.length] = file[0 .. file.length];
        this.sdlEvent.drop.file[file.length] = '\0';
    }

    static if (sdlSupport >= SDLSupport.v2_0_5) {
        this(string file, uint windowID) @trusted {
            this.sdlEvent.type = SDL_DROPFILE;
            this.sdlEvent.drop.file = cast(char*) SDL_malloc(file.length + 1);
            this.sdlEvent.drop.file[0 .. file.length] = file[0 .. file.length];
            this.sdlEvent.drop.file[file.length] = '\0';
            this.sdlEvent.drop.windowID = windowID;
        }
    }

    @trusted invariant {
        assert(this.sdlEvent.type == SDL_DROPFILE);
        assert(this.sdlEvent.drop.file !is null);
    }

    override string toString() const {
        static if (sdlSupport >= SDLSupport.v2_0_5) {
            return "dsdl2.DropFileEvent(%s, %d)".format(this.file, this.windowID);
        }
        else {
            return "dsdl2.DropFileEvent(%s)".format(this.file);
        }
    }

    string file() const @property @trusted {
        return this.sdlEvent.drop.file[0 .. strlen(this.sdlEvent.drop.file)].idup;
    }

    void file(string newFile) @property @trusted {
        SDL_realloc(this.sdlEvent.drop.file, newFile.length + 1);
        this.sdlEvent.drop.file[0 .. newFile.length] = newFile[0 .. newFile.length];
        this.sdlEvent.drop.file[newFile.length] = '\0';
    }
}

static if (sdlSupport >= SDLSupport.v2_0_5) {
    /++
     + D class that wraps `SDL_DROPTEXT` `SDL_Event`s (from SDL 2.0.5)
     +/
    class DropTextEvent : DropEvent {
        this(string file, uint windowID) @trusted {
            this.sdlEvent.type = SDL_DROPTEXT;
            this.sdlEvent.drop.file = cast(char*) SDL_malloc(file.length + 1);
            this.sdlEvent.drop.file[0 .. file.length] = file[0 .. file.length];
            this.sdlEvent.drop.file[file.length] = '\0';
            this.sdlEvent.drop.windowID = windowID;
        }

        @trusted invariant {
            assert(this.sdlEvent.type == SDL_DROPTEXT);
            assert(this.sdlEvent.drop.file !is null);
        }

        override string toString() const {
            return "dsdl2.DropTextEvent(%s, %d)".format(this.file, this.windowID);
        }

        string file() const @property @trusted {
            return this.sdlEvent.drop.file[0 .. strlen(this.sdlEvent.drop.file)].idup;
        }

        void file(string newFile) @property @trusted {
            SDL_realloc(this.sdlEvent.drop.file, newFile.length + 1);
            this.sdlEvent.drop.file[0 .. newFile.length] = newFile[0 .. newFile.length];
            this.sdlEvent.drop.file[newFile.length] = '\0';
        }
    }

    /++
     + D class that wraps `SDL_DROPBEGIN` `SDL_Event`s (from SDL 2.0.5)
     +/
    class DropBeginEvent : DropEvent {
        this(uint windowID) @trusted {
            this.sdlEvent.type = SDL_DROPBEGIN;
            this.sdlEvent.drop.windowID = windowID;
        }

        invariant {
            assert(this.sdlEvent.type == SDL_DROPBEGIN);
        }

        override string toString() const {
            return "dsdl2.DropBeginEvent(%d)".format(this.windowID);
        }
    }

    /++
     + D class that wraps `SDL_DROPCOMPLETE` `SDL_Event`s (from SDL 2.0.5)
     +/
    class DropCompleteEvent : DropEvent {
        this(uint windowID) @trusted {
            this.sdlEvent.type = SDL_DROPCOMPLETE;
            this.sdlEvent.drop.windowID = windowID;
        }

        invariant {
            assert(this.sdlEvent.type == SDL_DROPCOMPLETE);
        }

        override string toString() const {
            return "dsdl2.DropCompleteEvent(%d)".format(this.windowID);
        }
    }
}
