/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.sdl;
@safe:

import bindbc.sdl;

import std.conv : to;
import std.format : format;
import std.string : toStringz;

/++
 + SDL exception generated from `SDL_GetError()` or dsdl-specific exceptions
 +/
final class SDLException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }

    this(string file = __FILE__, size_t line = __LINE__) @trusted {
        super(SDL_GetError().to!string, file, line);
    }
}

version (BindSDL_Static) {
}
else {
    /++
     + Loads the SDL2 shared dynamic library, which wraps bindbc-sdl's `loadSDL` function
     +
     + Unless if bindbc-sdl is on static mode (by adding a `BindSDL_Static` version), this function will exist and must
     + be called before any calls are made to the library. Otherwise, a segfault will happen upon any function calls.
     +
     + Params:
     +   libName = name or path to look the SDL2 SO/DLL for, otherwise `null` for default searching path
     + Throws: `dsdl.SDLException` if failed to find the library
     +/
    void loadSO(string libName = null) @trusted {
        SDLSupport current = libName is null ? loadSDL() : loadSDL(libName.toStringz());
        if (current == sdlSupport) {
            return;
        }

        import loader = bindbc.loader.sharedlib;

        string errors;
        foreach (info; loader.errors) {
            errors ~= "\n- " ~ info.error.to!string ~ ": " ~ info.message.to!string;
        }

        Version wanted = Version(sdlSupport);
        if (current == SDLSupport.noLibrary) {
            throw new SDLException("No SDL2 library found, especially of version " ~ wanted.format() ~ errors,
                    __FILE__, __LINE__);
        }
        else {
            throw new SDLException("dsdl expects SDL " ~ wanted.format() ~ ", but got " ~ getVersion()
                    .format() ~ errors, __FILE__, __LINE__);
        }
    }
}

private uint toSDLInitFlags(bool timer, bool audio, bool video, bool joystick, bool haptic,
        bool gameController, bool events, bool everything, bool noParachute, bool sensor)
in {
    static if (sdlSupport < SDLSupport.v2_0_9) {
        assert(sensor == false);
    }
    else {
        if (sensor) {
            assert(getVersion() >= Version(2, 0, 9));
        }
    }
}
do {
    uint flags = 0;

    flags |= timer ? SDL_INIT_TIMER : 0;
    flags |= audio ? SDL_INIT_AUDIO : 0;
    flags |= video ? SDL_INIT_VIDEO : 0;
    flags |= joystick ? SDL_INIT_JOYSTICK : 0;
    flags |= haptic ? SDL_INIT_HAPTIC : 0;
    flags |= gameController ? SDL_INIT_GAMECONTROLLER : 0;
    flags |= events ? SDL_INIT_EVENTS : 0;
    flags |= everything ? SDL_INIT_EVERYTHING : 0;
    flags |= noParachute ? SDL_INIT_NOPARACHUTE : 0;

    static if (sdlSupport >= SDLSupport.v2_0_9) {
        flags |= sensor ? SDL_INIT_SENSOR : 0;
    }

    return flags;
}

/++
 + Wraps `SDL_Init` which initializes selected subsystems
 +
 + Params:
 +   timer = selects the `SDL_INIT_TIMER` subsystem
 +   audio = selects the `SDL_INIT_AUDIO` subsystem
 +   video = selects the `SDL_INIT_VIDEO` subsystem
 +   joystick = selects the `SDL_INIT_JOYSTICK` subsystem
 +   haptic = selects the `SDL_INIT_HAPTIC` subsystem
 +   gameController = selects the `SDL_INIT_GAMECONTROLLER` subsystem
 +   events = selects the `SDL_INIT_EVENTS` subsystem
 +   everything = selects the `SDL_INIT_EVERYTHING` subsystem
 +   noParachute = selects the `SDL_INIT_NOPARACHUTE` subsystem
 +   sensor = selects the `SDL_INIT_SENSOR` subsystem (from SDL 2.0.9)
 + Throws: `dsdl.SDLException` if any selected subsystem failed to initialize
 + Example:
 + ---
 + dsdl.init(everything : true);
 + ---
 +/
void init(bool timer = false, bool audio = false, bool video = false, bool joystick = false,
        bool haptic = false, bool gameController = false, bool events = false, bool everything = false,
        bool noParachute = false, bool sensor = false) @trusted {
    uint flags = toSDLInitFlags(timer, audio, video, joystick, haptic, gameController, events,
            everything, noParachute, sensor);

    if (SDL_Init(flags) != 0) {
        throw new SDLException;
    }
}

version (unittest) {
    static this() {
        import std.stdio;

        version (BindSDL_Static) {
        }
        else {
            loadSO();
        }
        writeln("Testing with SDL ", getVersion().format(), " for binding version ",
                Version(sdlSupport).format(), "...");

        try {
            dsdl.init(everything: true);
        }
        catch (SDLException exc) {
            writeln("Initializing SDL resulted an error: ", exc.msg);
        }
    }
}

/++
 + Wraps `SDL_Quit` which entirely deinitializes SDL2
 +/
void quit() @trusted {
    SDL_Quit();
}

version (unittest) {
    static ~this() {
        quit();
    }
}

/++
 + Wraps `SDL_QuitSubSystem` which deinitializes specified subsystems
 +
 + Params:
 +   timer = selects the `SDL_INIT_TIMER` subsystem
 +   audio = selects the `SDL_INIT_AUDIO` subsystem
 +   video = selects the `SDL_INIT_VIDEO` subsystem
 +   joystick = selects the `SDL_INIT_JOYSTICK` subsystem
 +   haptic = selects the `SDL_INIT_HAPTIC` subsystem
 +   gameController = selects the `SDL_INIT_GAMECONTROLLER` subsystem
 +   events = selects the `SDL_INIT_EVENTS` subsystem
 +   everything = selects the `SDL_INIT_EVERYTHING` subsystem
 +   noParachute = selects the `SDL_INIT_NOPARACHUTE` subsystem
 +   sensor = selects the `SDL_INIT_SENSOR` subsystem (from SDL 2.0.9)
 +/
void quit(bool timer = false, bool audio = false, bool video = false, bool joystick = false,
        bool haptic = false, bool gameController = false, bool events = false, bool everything = false,
        bool noParachute = false, bool sensor = false) @trusted {
    uint flags = toSDLInitFlags(timer, audio, video, joystick, haptic, gameController, events,
            everything, noParachute, sensor);

    SDL_QuitSubSystem(flags);
}

/++
 + Wraps `SDL_WasInit` which checks whether particular subsystem(s) is already initialized
 +
 + Params:
 +   timer = selects the `SDL_INIT_TIMER` subsystem
 +   audio = selects the `SDL_INIT_AUDIO` subsystem
 +   video = selects the `SDL_INIT_VIDEO` subsystem
 +   joystick = selects the `SDL_INIT_JOYSTICK` subsystem
 +   haptic = selects the `SDL_INIT_HAPTIC` subsystem
 +   gameController = selects the `SDL_INIT_GAMECONTROLLER` subsystem
 +   events = selects the `SDL_INIT_EVENTS` subsystem
 +   everything = selects the `SDL_INIT_EVERYTHING` subsystem
 +   noParachute = selects the `SDL_INIT_NOPARACHUTE` subsystem
 +   sensor = selects the `SDL_INIT_SENSOR` subsystem (from SDL 2.0.9)
 +
 + Returns: `true` if the selected subsystem(s) is initialized, otherwise `false`
 + Example:
 + ---
 + dsdl.init();
 + assert(dsdl.wasInit(video : true) == true);
 + ---
 +/
bool wasInit(bool timer = false, bool audio = false, bool video = false, bool joystick = false,
        bool haptic = false, bool gameController = false, bool events = false, bool everything = false,
        bool noParachute = false, bool sensor = false) @trusted {
    uint flags = toSDLInitFlags(timer, audio, video, joystick, haptic, gameController, events,
            everything, noParachute, sensor);

    return SDL_WasInit(flags) != 0;
}

/++
 + D struct that wraps `SDL_version` containing version information
 +
 + Example:
 + ---
 + import std.stdio;
 + writeln("We're currently using SDL version ", dsdl.getVersion().format());
 + ---
 +/
struct Version {
    SDL_version sdlVersion; /// Internal `SDL_version` struct

    this() @disable;

    /++
     + Constructs a `dsdl.Version` from a vanilla `SDL_version` from bindbc-sdl
     +
     + Params:
     +   sdlVersion = the `SDL_version` struct
     +/
    this(SDL_version sdlVersion) {
        this.sdlVersion = sdlVersion;
    }

    /++
     + Constructs a `dsdl.Version` by feeding in `major`, `minor`, and `patch` version numbers
     +
     + Params:
     +   major = major version number
     +   minor = minor version number
     +   patch = patch verion number
     +/
    this(ubyte major, ubyte minor, ubyte patch = 0) {
        this.sdlVersion.major = major;
        this.sdlVersion.minor = minor;
        this.sdlVersion.patch = patch;
    }

    /++
     + Compares two `dsdl.Version`s from chronology
     +/
    int opCmp(Version other) const {
        if (this.major != other.major) {
            return this.major - other.major;
        }
        else if (this.minor != other.minor) {
            return this.minor - other.minor;
        }
        else {
            return this.patch - other.patch;
        }
    }
    ///
    unittest {
        assert(dsdl.Version(2, 0, 0) == dsdl.Version(2, 0, 0));
        assert(dsdl.Version(2, 0, 1) > dsdl.Version(2, 0, 0));
        assert(dsdl.Version(2, 0, 1) < dsdl.Version(2, 0, 2));
        assert(dsdl.Version(2, 0, 2) >= dsdl.Version(2, 0, 1));
        assert(dsdl.Version(2, 0, 2) <= dsdl.Version(2, 0, 2));
    }

    /++
     + Formats the `dsdl.Version` into its construction representation: `"dsdl.Version(<major>, <minor>, <patch>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.Version(%d, %d, %d)".format(this.major, this.minor, this.patch);
    }

    /++
     + Proxy to the major version value of the `dsdl.Version`
     +
     + Returns: major version value value of the `dsdl.Version`
     +/
    ref inout(ubyte) major() return inout @property {
        return this.sdlVersion.major;
    }

    /++
     + Proxy to the minor version value of the `dsdl.Version`
     +
     + Returns: minor version value value of the `dsdl.Version`
     +/
    ref inout(ubyte) minor() return inout @property {
        return this.sdlVersion.minor;
    }

    /++
     + Proxy to the patch version value of the `dsdl.Version`
     +
     + Returns: patch version value value of the `dsdl.Version`
     +/
    ref inout(ubyte) patch() return inout @property {
        return this.sdlVersion.patch;
    }

    /++
     + Gets the static array representation of the `dsdl.Version`
     +
     + Returns: `major`, `minor`, `patch` as an array
     +/
    ubyte[3] array() const @property {
        return [this.sdlVersion.major, this.sdlVersion.minor, this.sdlVersion.patch];
    }

    /++
     + Formats the `dsdl.Version` into `string`: `"<major>.<minor>.<patch>"`
     +
     + Returns: the formatted `string`
     +/
    string format() const {
        return "%d.%d.%d".format(this.major, this.minor, this.patch);
    }
}
///
unittest {
    auto minimumVersion = dsdl.Version(2, 0, 0);
    auto ourVersion = dsdl.getVersion();
    assert(ourVersion >= minimumVersion);
}
///
unittest {
    assert(dsdl.Version(2, 0, 2) > dsdl.Version(2, 0, 0));
    assert(dsdl.Version(2, 2, 0) >= dsdl.Version(2, 0, 2));
    assert(dsdl.Version(3, 0, 0) >= dsdl.Version(2, 2, 0));
}

/++
 + Wraps `SDL_GetVersion` which gets the version of the linked SDL2 library
 +
 + Returns: `dsdl.Version` of the linked SDL2 library
 +/
Version getVersion() @trusted {
    Version ver = void;
    SDL_GetVersion(&ver.sdlVersion);
    return ver;
}

/++
 + Wraps `SDL_GetRevision` which returns the revision string of the linked SDL2 library
 +
 + Returns: `string` of the revision code
 +/
string getRevision() @trusted {
    return SDL_GetRevision().to!string;
}

/++
 + D enum that wraps `SDL_HintPriority`
 +/
enum HintPriority : SDL_HintPriority {
    /++
     + Wraps `SDL_HINT_*` enumeration constants
     +/
    default_ = SDL_HINT_DEFAULT,
    normal = SDL_HINT_NORMAL, /// ditto
    override_ = SDL_HINT_OVERRIDE /// ditto
}

/++
 + Wraps `SDL_SetHintWithPriority` which provides giving a hint to SDL2 in runtime
 +
 + Params:
 +   name = name of the hint
 +   value = value to set the hint as
 +   priority = priority of the hint configuration (by default, `dsdl.HintPriority.normal`)
 +
 + Returns: `true` if the hint was set, `false` otherwise
 +/
bool setHint(string name, string value, HintPriority priority = HintPriority.normal) @trusted {
    return SDL_SetHintWithPriority(name.toStringz(), value.toStringz(), priority) == SDL_TRUE;
}

static if (sdlSupport >= SDLSupport.v2_26) {
    /++
     + Wraps `SDL_ResetHints` (from SDL 2.26) which resets any user-set hints given to SDL2 to default
     +/
    void resetHints() @trusted
    in {
        assert(getVersion() >= Version(2, 26));
    }
    do {
        SDL_ResetHints();
    }
}

/++
 + Wraps `SDL_GetHint` which gets the value of a specified user-set hint
 +
 + Params:
 +   name = name of the hint
 + Returns: value of the given `name` of the hint
 +/
string getHint(string name) @trusted {
    if (const(char)* hint = SDL_GetHint(name.toStringz())) {
        return hint.to!string;
    }
    else {
        return "";
    }
}

static if (sdlSupport >= SDLSupport.v2_0_5) {
    /++
     + Wraps `SDL_GetHintBoolean` (from SDL 2.0.5) which gets the value of a specified user-set hint as a `bool`
     +
     + Params:
     +   name = name of the hint
     +   defaultValue = default returned value if the hint wasn't set
     + Returns: `bool` value of the given `name` of the hint or `defaultValue` if the hint wasn't set
     +/
    bool getHintBool(string name, bool defaultValue = false) @trusted
    in {
        assert(getVersion() >= Version(2, 0, 5));
    }
    do {
        return SDL_GetHintBoolean(name.toStringz(), defaultValue) == SDL_TRUE;
    }
}

/++
 + Wraps `SDL_GetTicks` or `SDL_GetTicks64` on SDL 2.0.18 which gets the time since the SDL library was initialized
 + in milliseconds
 +
 + Returns: milliseconds since the initialization of the SDL library
 +/
ulong getTicks() @trusted
in {
    static if (sdlSupport >= SDLSupport.v2_0_18) {
        assert(getVersion() >= Version(2, 0, 18));
    }
}
do {
    static if (sdlSupport >= SDLSupport.v2_0_18) {
        return SDL_GetTicks64();
    }
    else {
        return SDL_GetTicks();
    }
}

/++
 + Wraps `SDL_GetPerformanceCounter` which gets the current value of the platform-specific high resolution counter
 +
 + Returns: counter value in the scale of the counter frequency
 +/
ulong getPerformanceCounter() @trusted {
    return SDL_GetPerformanceCounter();
}

/++
 + Wraps `SDL_GetPerformanceFrequency` which gets the frequency of the platform-specific high resolution counter
 +
 + Returns: counts per second of the counter
 +/
ulong getPerformanceFrequency() @trusted {
    return SDL_GetPerformanceFrequency();
}
