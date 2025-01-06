/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.mixer;
@safe:

// dfmt off
import bindbc.sdl;
static if (bindSDLMixer):
// dfmt on

import dsdl.sdl;
import dsdl.audio;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.string : toStringz;
import std.typecons : Tuple;

version (BindSDL_Static) {
}
else {
    /++
     + Loads the SDL2_mixer shared dynamic library, which wraps bindbc-sdl's `loadSDLMixer` function
     +
     + Unless if bindbc-sdl is on static mode (by adding a `BindSDL_Static` version), this function will exist and must
     + be called before any calls are made to the library. Otherwise, a segfault will happen upon any function calls.
     +
     + Params:
     +   libName = name or path to look the SDL2_mixer SO/DLL for, otherwise `null` for default searching path
     + Throws: `dsdl.SDLException` if failed to find the library
     +/
    void loadSO(string libName = null) @trusted {
        SDLMixerSupport current = libName is null ? loadSDLMixer() : loadSDLMixer(libName.toStringz());
        if (current == sdlMixerSupport) {
            return;
        }

        import loader = bindbc.loader.sharedlib;

        string errors;
        foreach (info; loader.errors) {
            errors ~= "\n- " ~ info.error.to!string ~ ": " ~ info.message.to!string;
        }

        Version wanted = Version(sdlMixerSupport);
        if (current == SDLMixerSupport.noLibrary) {
            throw new SDLException("No SDL2_mixer library found, especially of version " ~ wanted.format() ~ errors,
                    __FILE__, __LINE__);
        }
        else {
            throw new SDLException("dsdl expects SDL_mixer " ~ wanted.format() ~ ", but got " ~ getVersion()
                    .format() ~ errors, __FILE__, __LINE__);
        }
    }
}

/++
 + Wraps `Mix_Init` which initializes selected SDL2_mixer audio format subsystems
 +
 + Params:
 +   flac = selects the `MIX_INIT_FLAC` subsystem
 +   mod = selects the `MIX_INIT_MOD` subsystem
 +   mp3 = selects the `MIX_INIT_MP3` subsystem
 +   ogg = selects the `MIX_INIT_OGG` subsystem
 +   mid = selects the `MIX_INIT_FLUIDSYNTH` (for SDL_mixer below 2.0.2) / `MIX_INIT_MID` subsystem
 +   opus = selects the `MIX_INIT_OPUS` subsystem (from SDL_mixer 2.0.4)
 +   everything = selects every available subsystem
 + Throws: `dsdl.SDLException` if any selected subsystem failed to initialize
 + Example:
 + ---
 + dsdl.mixer.init(everything : true);
 + ---
 +/
void init(bool flac = false, bool mod = false, bool mp3 = false, bool ogg = false, bool mid = false,
        bool opus = false, bool everything = false) @trusted
in {
    static if (sdlMixerSupport < SDLMixerSupport.v2_0_4) {
        assert(opus == false);
    }
    else {
        if (opus) {
            assert(dsdl.mixer.getVersion() >= Version(2, 0, 4));
        }
    }
}
do {
    int flags = 0;

    flags |= flac ? MIX_INIT_FLAC : 0;
    flags |= mod ? MIX_INIT_MOD : 0;
    flags |= mp3 ? MIX_INIT_MP3 : 0;
    flags |= ogg ? MIX_INIT_OGG : 0;
    flags |= everything ? MIX_INIT_FLAC | MIX_INIT_MOD | MIX_INIT_MP3 | MIX_INIT_OGG : 0;

    static if (sdlMixerSupport >= SDLMixerSupport.v2_0_2) {
        flags |= mid ? MIX_INIT_MID : 0;
        flags |= everything ? MIX_INIT_MID : 0;
    }
    else {
        flags |= mid ? MIX_INIT_FLUIDSYNTH : 0;
        flags |= everything ? MIX_INIT_FLUIDSYNTH : 0;
    }

    static if (sdlMixerSupport >= SDLMixerSupport.v2_0_4) {
        flags |= opus ? MIX_INIT_OPUS : 0;
        flags |= everything ? MIX_INIT_OPUS : 0;
    }

    if ((Mix_Init(flags) & flags) != flags) {
        throw new SDLException;
    }
}

version (unittest) {
    static this() {
        import std.stdio;

        version (BindSDL_Static) {
        }
        else {
            dsdl.mixer.loadSO();
        }
        writeln("Testing with SDL_mixer ", getVersion().format(), " for binding version ",
                Version(sdlMixerSupport).format(), "...");

        try {
            dsdl.mixer.init(everything: true);
        }
        catch (SDLException exc) {
            writeln("Initializing SDL_mixer resulted an error: ", exc.msg);
        }
    }
}

/++
 + Wraps `Mix_Quit` which entirely deinitializes SDL2_mixer
 +/
void quit() @trusted {
    Mix_Quit();
}

version (unittest) {
    static ~this() {
        dsdl.mixer.quit();
    }
}

/++
 + Wraps `Mix_Linked_Version` which gets the version of the linked SDL2_mixer library
 +
 + Returns: `dsdl.Version` of the linked SDL2_mixer library
 +/
Version getVersion() @trusted {
    return Version(*Mix_Linked_Version());
}

enum channels = cast(ubyte) MIX_CHANNELS; /// Alias to `MIX_CHANNELS`
enum defaultFrequency = cast(uint) MIX_DEFAULT_FREQUENCY; /// Alias to `MIX_DEFAULT_FREQUENCY`
enum defaultFormat = cast(AudioFormat) MIX_DEFAULT_FORMAT; /// Alias to `MIX_DEFAULT_FORMAT`
enum maxVolume = cast(ubyte) MIX_MAX_VOLUME; /// Alias to `MIX_MAX_VOLUME`

/++
 + D enum that wraps `Mix_Fading`
 +/
enum Fading {
    /++
     + Wraps `MIX_*` enumeration constants
     +/
    noFading = MIX_NO_FADING,
    fadingIn = MIX_FADING_IN, /// ditto
    fadingOut = MIX_FADING_OUT /// ditto
}

/++
 + D enum that wraps `Mix_MusicType`
 +/
enum MusicType {
    /++
     + Wraps `MUS_*` enumeration constants
     +/
    none = MUS_NONE,
    cmd = MUS_CMD, /// ditto
    wav = MUS_WAV, /// ditto
    mod = MUS_MOD, /// ditto
    mid = MUS_MID, /// ditto
    ogg = MUS_OGG, /// ditto
    mp3 = MUS_MP3, /// ditto
    flac = MUS_FLAC, /// ditto

    opus = 10 /// Wraps `MUS_OPUS` (from SDL_mixer 2.0.4)
}

/++
 + Wraps `Mix_OpenAudio` which opens the default audio device for playback by SDL_mixer
 +
 + Params:
 +   frequency = audio playback frequency in Hz
 +   format = `dsdl.AudioFormat` enumeration indicating the scalar type of each audio sample
 +   channels = channels for `dsdl.mixer.Chunk` playback (1 for mono; 2 for stereo)
 +   chunkSize = audio buffer size
 + Throws: `dsdl.SDLException` if failed to open default audio device
 +/
void openAudio(uint frequency, AudioFormat format, uint channels, uint chunkSize) @trusted {
    if (Mix_OpenAudio(frequency.to!int, cast(ushort) format, channels.to!int, chunkSize.to!int) != 0) {
        throw new SDLException;
    }
}

static if (sdlMixerSupport >= SDLMixerSupport.v2_0_2) {
    /++
     + Wraps `Mix_OpenAudioDevice` (from SDL_mixer 2.0.2) which opens a selected audio device for playback by SDL_mixer
     +
     + Params:
     +   frequency = audio playback frequency in Hz
     +   format = `dsdl.AudioFormat` enumeration indicating the scalar type of each audio sample
     +   channels = channels for `dsdl.mixer.Chunk` playback (1 for mono; 2 for stereo)
     +   chunkSize = audio buffer size
     +   deviceName = name of the selected device
     +   allowFrequencyChange = adds `SDL_AUDIO_ALLOW_FREQUENCY_CHANGE` flag
     +   allowFormatChange = adds `SDL_AUDIO_ALLOW_FORMAT_CHANGE` flag
     +   allowChannelsChange = adds `SDL_AUDIO_ALLOW_CHANNELS_CHANGE` flag
     +   allowSamplesChange = adds `SDL_AUDIO_ALLOW_SAMPLES_CHANGE` flag (from SDL_mixer 2.0.9)
     +   allowAnyChange = adds `SDL_AUDIO_ALLOW_ANY_CHANGE` flag
     + Throws: `dsdl.SDLException` if failed to open the selected audio device
     +/
    void openAudioDevice(uint frequency, AudioFormat format, uint channels, uint chunkSize, string deviceName,
            bool allowFrequencyChange = false, bool allowFormatChange = false,
            bool allowChannelsChange = false, bool allowSamplesChange = false, bool allowAnyChange = false) @trusted
    in {
        assert(dsdl.mixer.getVersion() >= Version(2, 0, 2));

        static if (sdlSupport < SDLSupport.v2_0_9) {
            assert(allowSamplesChange == false);
        }
        else {
            if (allowSamplesChange) {
                assert(dsdl.mixer.getVersion() >= Version(2, 0, 9));
            }
        }
    }
    do {
        int changeFlags = 0;
        changeFlags |= allowFrequencyChange ? SDL_AUDIO_ALLOW_FREQUENCY_CHANGE : 0;
        changeFlags |= allowFormatChange ? SDL_AUDIO_ALLOW_FORMAT_CHANGE : 0;
        changeFlags |= allowChannelsChange ? SDL_AUDIO_ALLOW_CHANNELS_CHANGE : 0;
        changeFlags |= allowAnyChange ? SDL_AUDIO_ALLOW_ANY_CHANGE : 0;

        static if (sdlSupport >= SDLSupport.v2_0_9) {
            changeFlags |= allowSamplesChange ? SDL_AUDIO_ALLOW_SAMPLES_CHANGE : 0;
        }

        if (Mix_OpenAudioDevice(frequency.to!int, cast(ushort) format, channels.to!int,
                chunkSize.to!int, deviceName.toStringz(), changeFlags) != 0) {
            throw new SDLException;
        }
    }
}

/++
 + Wraps `Mix_AllocateChannels` which changes the amount of track channels managed by SDL_mixer
 +
 + Params:
 +   channels = new amount of track channels (not the same as device channels)
 +/
void allocateChannels(uint channels) @trusted {
    Mix_AllocateChannels(channels.to!int);
}

/++
 + Wraps `Mix_ReserveChannels` which reserves the first track channels managed by SDL_mixer for the application
 +
 + Params:
 +   channels = amount of the first track channels to reserve (not the same as device channels)
 +/
void reserveChannels(uint channels) @trusted {
    Mix_ReserveChannels(channels.to!int);
}

private alias MixerSpec = Tuple!(uint, "frequency", AudioFormat, "format", uint, "channels");

/++
 + Wraps `Mix_QuerySpec` which queries the default audio device information
 +
 + Returns: a named tuple detailing the default audio device's `frequency`, audio `format`, and `channels`
 + Throws: `dsdl.SDLException` if failed to query the information
 +/
MixerSpec querySpec() @trusted {
    MixerSpec spec = void;
    if (Mix_QuerySpec(cast(int*)&spec.frequency, cast(ushort*)&spec.format, cast(int*)&spec.channels) != 0) {
        throw new SDLException;
    }

    return spec;
}

static if (sdlMixerSupport >= SDLMixerSupport.v2_6) {
    /++
     + Wraps `Mix_MasterVolume` (from SDL_mixer 2.6) which gets the master volume
     +
     + Returns: master volume ranging from `0` to `128`
     +/
    ubyte getMasterVolume() @trusted {
        return cast(ubyte) Mix_MasterVolume(-1);
    }

    /++
     + Wraps `Mix_MasterVolume` (from SDL_mixer 2.6) which sets the master volume
     +
     + Params:
     +   newVolume = new master volume ranging from `0` to `128`
     +/
    void setMasterVolume(ubyte newVolume) @trusted {
        Mix_MasterVolume(newVolume);
    }
}

/++
 + D class that acts as a proxy for a mixer audio channel from a channel ID
 +/
final class Channel {
    const uint mixChannel; /// Channel ID from SDL_mixer

    this() @disable;

    private this(uint mixChannel) {
        this.mixChannel = mixChannel;
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Channel rhs) const {
        return this.mixChannel == rhs.mixChannel;
    }

    /++
     + Gets the hash of the `dsdl.mixer.Channel`
     +
     + Returns: unique hash for the instance being the channel ID
     +/
    override hash_t toHash() const {
        return cast(hash_t) this.mixChannel;
    }

    /++
     + Formats the `dsdl.mixer.Channel` showing its internal information: `"dsdl.mixer.Channel(<mixChannel>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const {
        return "dsdl.mixer.Channel(%d)".format(this.mixChannel);
    }

    /++
     + Wraps `Mix_SetPanning` which sets the panning volume of the left and right channels for the track channel
     +
     + Params:
     +   newLR = tuple of the volumes from `0` to `255` of the left and right channels in order
     + Throws: `dsdl.SDLException` if failed to set the panning
     +/
    void panning(ubyte[2] newLR) const @property @trusted {
        if (Mix_SetPanning(this.mixChannel, newLR[0], newLR[1]) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_SetPanning` which sets the panning volume of the left and right channels as posteffect for all
     + channels
     +
     + Params:
     +   newLR = tuple of the volumes from `0` to `255` of the left and right channels in order
     + Throws: `dsdl.SDLException` if failed to set the panning
     +/
    static void allPanning(ubyte[2] newLR) @property @trusted {
        if (Mix_SetPanning(MIX_CHANNEL_POST, newLR[0], newLR[1]) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_SetPosition` which sets the simulated angle and distance of the channel playing from the listener
     +
     + Params:
     +   newAngleDistance = tuple of the simulated angle (in degrees clockwise, with `0` being the front) and distance
     + Throws: `dsdl.SDLException` if failed to set the position
     +/
    void position(Tuple!(short, ubyte) newAngleDistance) const @property @trusted {
        if (Mix_SetPosition(this.mixChannel, newAngleDistance[0], newAngleDistance[1]) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Acts as `Mix_SetPosition(MIX_CHANNEL_POST, newAngleDistance[0], newAngleDistance[1])` which sets the simulated
     + angle and distance for all channels as posteffect
     +
     + Params:
     +   newAngleDistance = tuple of the simulated angle (in degrees clockwise, with `0` being the front) and distance
     + Throws: `dsdl.SDLException` if failed to set the position
     +/
    static void allPosition(Tuple!(short, ubyte) newAngleDistance) @property @trusted {
        if (Mix_SetPosition(MIX_CHANNEL_POST, newAngleDistance[0], newAngleDistance[1]) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_SetDistance` which sets the simulated distance for the channel playing from the listener
     +
     + Params:
     +   newDistance = simulated distance from `0` to `255`
     + Throws: `dsdl.SDLException` if failed to set the distance
     +/
    void distance(ubyte newDistance) const @property @trusted {
        if (Mix_SetDistance(this.mixChannel, newDistance) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Acts as `Mix_SetDistance(MIX_CHANNEL_POST, newDistance)` which sets the simulated distance for all channels as
     + posteffect
     +
     + Params:
     +   newDistance = simulated distance from `0` to `255`
     + Throws: `dsdl.SDLException` if failed to set the distance
     +/
    static void allDistance(ubyte newDistance) @property @trusted {
        if (Mix_SetDistance(MIX_CHANNEL_POST, newDistance) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_Volume` which gets the volume of the channel
     +
     + Returns: volume ranging from `0` to `128`
     +/
    ubyte volume() const @property @trusted {
        return cast(ubyte) Mix_Volume(this.mixChannel, -1);
    }

    /++
     + Acts as `Mix_Volume(-1, -1)` which gets the volume of all channels
     +
     + Returns: volume ranging from `0` to `128`
     +/
    static ubyte allVolume() @property @trusted {
        return cast(ubyte) Mix_Volume(-1, -1);
    }

    /++
     + Wraps `Mix_Volume` which sets the volume of the channel
     +
     + Params:
     +   newVolume = new volume ranging from `0` to `128`
     +/
    void volume(ubyte newVolume) const @property @trusted {
        Mix_Volume(this.mixChannel, newVolume);
    }

    /++
     + Acts as `Mix_Volume(-1, newVolume)` which sets the volume of all channels
     +
     + Params:
     +   newVolume = new volume ranging from `0` to `128`
     +/
    static void allVolume(ubyte newVolume) @property @trusted {
        Mix_Volume(-1, newVolume);
    }

    /++
     + Wraps `Mix_SetReverseStereo` which sets whether the left and right channels are flipped in the channel
     +
     + Params:
     +   newReverse = `true` to enable reverse stereo; `false` to disable
     + Throws: `dsdl.SDLException` if failed to set the reverse stereo mode
     +/
    void reverseStereo(bool newReverse) const @property @trusted {
        if (Mix_SetReverseStereo(this.mixChannel, newReverse ? 1 : 0) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Acts as `Mix_SetReverseStereo(MIX_CHANNEL_POST, newReverse)` which sets whether the left and right channels are
     + flipped for all channels as posteffect
     +
     + Params:
     +   newReverse = `true` to enable reverse stereo; `false` to disable
     + Throws: `dsdl.SDLException` if failed to set the reverse stereo mode
     +/
    static void allReverseStereo(bool newReverse) @property @trusted {
        if (Mix_SetReverseStereo(MIX_CHANNEL_POST, newReverse ? 1 : 0) == 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_Paused` which checks whether the channel is paused
     +
     + Returns: `true` if channel is paused, otherwise `false`
     +/
    bool paused() const @property @trusted {
        return Mix_Paused(this.mixChannel) == 1;
    }

    /++
     + Wraps `Mix_Playing` which checks whether the channel is playing
     +
     + Returns: `true` if channel is playing, otherwise `false`
     +/
    bool playing() const @property @trusted {
        return Mix_Playing(this.mixChannel) == 1;
    }

    /++
     + Wraps `Mix_FadingChannel` which gets the fading stage of the channel
     +
     + Returns: `dsdl.mixer.Fading` enumeration indicating the channel's fading stage
     +/
    Fading fading() const @property @trusted {
        return cast(Fading) Mix_FadingChannel(this.mixChannel);
    }

    /++
     + Wraps `Mix_GetChunk` which gets the currently-playing `dsdl.mixer.Chunk` in the channel
     +
     + This function is marked as `@system` due to the potential of referencing invalid memory.
     +
     + Returns: `dsdl.mixer.Chunk` proxy to the playing chunk
     + Throws: `dsdl.SDLException` if failed to get the playing chunk
     +/
    Chunk chunk() const @property @system {
        if (Mix_Chunk* mixChunk = Mix_GetChunk(this.mixChannel)) {
            return new Chunk(mixChunk, false);
        }
        else {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_PlayChannelTimed` which plays a `dsdl.mixer.Chunk` in the channel
     +
     + Params:
     +   chunk = `dsdl.mixer.Chunk` to be played
     +   loops = how many times the chunk should be played (`cast(uint) -1` for infinity)
     +   ms = number of milliseconds the chunk should be played for
     + Throws: `dsdl.SDLException` if failed to play the chunk
     +/
    void play(const Chunk chunk, uint loops = 1, uint ms = cast(uint)-1) const @trusted {
        if (Mix_PlayChannelTimed(this.mixChannel, cast(Mix_Chunk*) chunk.mixChunk, loops, ms) == -1) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_FadeInChannelTimed` which plays a `dsdl.mixer.Chunk` in the channel with a fade-in effect
     +
     + Params:
     +   chunk = `dsdl.mixer.Chunk` to be played
     +   loops = how many times the chunk should be played (`cast(uint) -1` for infinity)
     +   fadeMs = number of milliseconds the chunk fades in before fully playing at full volume
     +   ms = number of milliseconds the chunk should be played for
     + Throws: `dsdl.SDLException` if failed to play the chunk
     +/
    void fadeIn(const Chunk chunk, uint loops = 1, uint fadeMs = 0, uint ms = cast(uint)-1) const @trusted {
        if (Mix_FadeInChannelTimed(this.mixChannel, cast(Mix_Chunk*) chunk.mixChunk, loops, fadeMs, ms) == -1) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_HaltChannel` which halts the channel
     +
     + Throws: `dsdl.SDLException` if failed to halt the channel
     +/
    void halt() const @trusted {
        if (Mix_HaltChannel(this.mixChannel) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Acts as `Mix_HaltChannel(-1)` which halts all channels
     +
     + Throws: `dsdl.SDLException` if failed to halt the channels
     +/
    static void haltAll() @trusted {
        if (Mix_HaltChannel(-1) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_ExpireChannel` which halts the channel after a specified delay
     +
     + Params:
     +   ms = number of milliseconds before the channel halts
     +/
    void expire(uint ms) const @trusted {
        Mix_ExpireChannel(this.mixChannel, ms);
    }

    /++
     + Acts as `Mix_ExpireChannel(-1, ms)` which halts all channels after a specified delay
     +
     + Params:
     +   ms = number of milliseconds before the channels halt
     +/
    static void expireAll(uint ms) @trusted {
        Mix_ExpireChannel(-1, ms);
    }

    /++
     + Wraps `Mix_FadeOutChannel` which performs fade-out for whatever chunk is playing in the channel
     +
     + Params:
     +   fadeMs = number of milliseconds to fade-out before fully halting
     +/
    void fadeOut(uint fadeMs) const @trusted {
        Mix_FadeOutChannel(this.mixChannel, fadeMs);
    }

    /++
     + Acts as `Mix_FadeOutChannel(-1, fadeMs)` which performs fade-out for whatever chunks are playing in all channels
     +
     + Params:
     +   fadeMs = number of milliseconds to fade-out before fully halting
     +/
    static void fadeOutAll(uint fadeMs) @trusted {
        Mix_FadeOutChannel(-1, fadeMs);
    }

    /++
     + Wraps `Mix_Pause` which pauses the channel
     +/
    void pause() const @trusted {
        Mix_Pause(this.mixChannel);
    }

    /++
     + Acts as `Mix_Pause(-1)` which pauses all channels
     +/
    static void pauseAll() @trusted {
        Mix_Pause(-1);
    }

    /++
     + Wraps `Mix_Resume` which resumes the channel
     +/
    void resume() const @trusted {
        Mix_Resume(this.mixChannel);
    }

    /++
     + Acts as `Mix_Resume(-1)` which resumes all channels
     +/
    static void resumeAll() @trusted {
        Mix_Resume(-1);
    }
}

/++
 + Gets `dsdl.mixer.Channel` proxy instances of the available audio channels provided by SDL_mixer
 +
 + Returns: array of proxies to the available `dsdl.mixer.Channel`s
 + Throws: `dsdl.SDLException` if failed to get the available audio channels
 +/
const(Channel[]) getChannels() @trusted {
    int numChannels = Mix_AllocateChannels(-1);

    static Channel[] channels;
    if (channels !is null) {
        size_t originalLength = channels.length;
        channels.length = numChannels;

        if (numChannels > originalLength) {
            foreach (i; originalLength .. numChannels) {
                channels[i] = new Channel(i.to!uint);
            }
        }
    }
    else {
        channels = new Channel[](numChannels);
        foreach (i; 0 .. numChannels) {
            channels[i] = new Channel(i);
        }
    }

    return channels;
}

/++
 + D class that wraps `Mix_Chunk` storing an audio chunk for playback
 +/
final class Chunk {
    private bool isOwner = true;
    private void* userRef = null;

    @system Mix_Chunk* mixChunk = null; /// Internal `Mix_Chunk` pointer

    /++
     + Constructs a `dsdl.mixer.Chunk` from a vanilla `Mix_Chunk*` from bindbc-sdl
     +
     + Params:
     +   mixChunk = the `Mix_Chunk` pointer to manage
     +   isOwner = whether the instance owns the given `Mix_Chunk*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(Mix_Chunk* mixChunk, bool isOwner = true, void* userRef = null) @system
    in {
        assert(mixChunk !is null);
    }
    do {
        this.mixChunk = mixChunk;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    ~this() @trusted {
        if (this.isOwner) {
            Mix_FreeChunk(this.mixChunk);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.mixChunk !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Chunk rhs) const @trusted {
        return this.mixChunk is rhs.mixChunk;
    }

    /++
     + Gets the hash of the `dsdl.mixer.Chunk`
     +
     + Returns: unique hash for the instance being the pointer of the internal `Mix_Chunk` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.mixChunk;
    }

    /++
     + Formats the `dsdl.mixer.Chunk` into its construction representation:
     + `"dsdl.mixer.Chunk(<mixChunk>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.mixer.Chunk(0x%x)".format(this.mixChunk);
    }

    /++
     + Wraps `Mix_GetNumChunkDecoders` and `Mix_GetChunkDecoder` which return a list of chunk decoders
     +
     + Returns: names of the available chunk decoders
     +/
    static string[] decoders() @property @trusted {
        int numDecoders = Mix_GetNumChunkDecoders();
        if (numDecoders <= 0) {
            throw new SDLException;
        }

        static string[] decoders;
        if (decoders !is null) {
            size_t originalLength = decoders.length;
            decoders.length = numDecoders;

            if (numDecoders > originalLength) {
                foreach (i; originalLength .. numDecoders) {
                    decoders[i] = Mix_GetChunkDecoder(i.to!int).to!string;
                }
            }
        }
        else {
            decoders = new string[](numDecoders);
            foreach (i; 0 .. numDecoders) {
                decoders[i] = Mix_GetChunkDecoder(i).to!string;
            }
        }

        return decoders;
    }

    static if (sdlMixerSupport >= SDLMixerSupport.v2_0_2) {
        /++
         + Wraps `Mix_HasChunkDecoder` (from SDL_mixer 2.0.2) which checks whether a chunk decoder is available
         +
         + Params:
         +   decoder = name of the chunk decoder
         + Returns: `true` if available, otherwise `false`
         +/
        static bool hasDecoder(string decoder) @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 0, 2));
        }
        do {
            return Mix_HasChunkDecoder(decoder.toStringz()) == SDL_TRUE;
        }
    }

    /++
     + Gets the raw PCM audio data buffer for the `dsdl.mixer.Chunk`
     +
     + This function is marked as `@system` due to the potential of referencing invalid memory.
     +
     + Returns: slice of the buffer
     +/
    inout(void[]) buffer() inout @property @trusted {
        return (cast(inout(void*)) this.mixChunk.abuf)[0 .. this.mixChunk.alen];
    }

    /++
     + Wraps `Mix_VolumeChunk` which gets the volume of the chunk
     +
     + Returns: volume ranging from `0` to `128`
     +/
    ubyte volume() const @property @trusted {
        return cast(ubyte) Mix_VolumeChunk(cast(Mix_Chunk*) this.mixChunk, -1);
    }

    /++
     + Wraps `Mix_VolumeChunk` which sets the volume of the chunk
     +
     + Params:
     +   newVolume = new volume ranging from `0` to `128`
     +/
    void volume(ubyte newVolume) @property @trusted {
        Mix_VolumeChunk(this.mixChunk, newVolume);
    }

    /++
     + Wraps `Mix_PlayChannelTimed` which plays the chunk on the first available free channel
     +
     + Params:
     +   loops = how many times the chunk should be played (`cast(uint) -1` for infinite)
     +   ms = number of milliseconds the chunk should be played for
     + Returns: `dsdl.mixer.Channel` the chunk is played on; `null` if no free channel
     +/
    const(Channel) play(uint loops = 1, uint ms = cast(uint)-1) const @trusted {
        int channel = Mix_PlayChannelTimed(-1, cast(Mix_Chunk*) this.mixChunk, loops, ms);
        if (channel == -1) {
            return null;
        }

        return getChannels()[channel];
    }

    /++
     + Wraps `Mix_FadeInChannelTimed` which plays the chunk on the first available free channel with a fade-in effect
     +
     + Params:
     +   loops = how many times the chunk should be played (`cast(uint) -1` for infinite)
     +   fadeMs = number of milliseconds the chunk fades in before fully playing at full volume
     +   ms = number of milliseconds the chunk should be played for
     + Returns: `dsdl.mixer.Channel` the chunk is played on; `null` if no free channel
     +/
    const(Channel) fadeIn(uint loops = 1, uint fadeMs = 0, uint ms = cast(uint)-1) const @trusted {
        int channel = Mix_FadeInChannelTimed(-1, cast(Mix_Chunk*) this.mixChunk, loops, fadeMs, ms);
        if (channel == -1) {
            return null;
        }

        return getChannels()[channel];
    }
}

/++
 + Wraps `Mix_LoadWAV` which loads an audio file from the filesystem to a `dsdl.mixer.Chunk`
 +
 + Params:
 +   file = path to the audio file
 + Returns: loaded `dsdl.mixer.Chunk`
 + Throws: `dsdl.SDLException` if unable to load
 +/
Chunk load(string file) @trusted {
    Mix_Chunk* mixChunk = Mix_LoadWAV(file.toStringz());
    if (mixChunk !is null) {
        return new Chunk(mixChunk);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `Mix_LoadWAV_RW` which loads an audio file from a buffer to a `dsdl.mixer.Chunk`
 +
 + Params:
 +   data = buffer of the audio file
 + Returns: loaded `dsdl.mixer.Chunk`
 + Throws: `dsdl.SDLException` if unable to load
 +/
Chunk loadRaw(const void[] data) @trusted {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    Mix_Chunk* mixChunk = Mix_LoadWAV_RW(sdlRWops, 1);
    if (mixChunk !is null) {
        return new Chunk(mixChunk);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `Mix_QuickLoad_RAW` which loads raw PCM audio data to a `dsdl.mixer.Chunk`
 +
 + Params:
 +   pcm = buffer of the raw PCM audio data
 + Returns: loaded `dsdl.mixer.Chunk`
 +/
Chunk loadPCM(const void[] pcm) @trusted {
    Mix_Chunk* mixChunk = Mix_QuickLoad_RAW(cast(ubyte*) pcm.ptr, pcm.length.to!int);
    if (mixChunk !is null) {
        return new Chunk(mixChunk);
    }
    else {
        throw new SDLException;
    }
}

/++
 + D class that wraps `Mix_Music` storing music for playback
 +/
final class Music {
    private bool isOwner = true;
    private void* userRef = null;

    @system Mix_Music* mixMusic = null; /// Internal `Mix_Music` pointer

    /++
     + Constructs a `dsdl.mixer.Music` from a vanilla `Mix_Music*` from bindbc-sdl
     +
     + Params:
     +   mixMusic = the `Mix_Music` pointer to manage
     +   isOwner = whether the instance owns the given `Mix_Music*` and should destroy it on its own
     +   userRef = optional pointer to maintain reference link, avoiding GC cleanup
     +/
    this(Mix_Music* mixMusic, bool isOwner = true, void* userRef = null) @system
    in {
        assert(mixMusic !is null);
    }
    do {
        this.mixMusic = mixMusic;
        this.isOwner = isOwner;
        this.userRef = userRef;
    }

    ~this() @trusted {
        if (this.isOwner) {
            Mix_FreeMusic(this.mixMusic);
        }
    }

    @trusted invariant { // @suppress(dscanner.trust_too_much)
        // Instance might be in an invalid state due to holding a non-owned externally-freed object when
        // destructed in an unpredictable order.
        if (!this.isOwner && GC.inFinalizer) {
            return;
        }

        assert(this.mixMusic !is null);
    }

    /++
     + Equality operator overload
     +/
    bool opEquals(const Music rhs) const @trusted {
        return this.mixMusic is rhs.mixMusic;
    }

    /++
     + Gets the hash of the `dsdl.mixer.Music`
     +
     + Returns: unique hash for the instance being the pointer of the internal `Mix_Music` pointer
     +/
    override hash_t toHash() const @trusted {
        return cast(hash_t) this.mixMusic;
    }

    /++
     + Formats the `dsdl.mixer.Music` into its construction representation:
     + `"dsdl.mixer.Music(<mixMusic>)"`
     +
     + Returns: the formatted `string`
     +/
    override string toString() const @trusted {
        return "dsdl.mixer.Music(0x%x)".format(this.mixMusic);
    }

    /++
     + Wraps `Mix_GetNumMusicDecoders` and `Mix_GetMusicDecoder` which return a list of music decoders
     +
     + Returns: names of the available music decoders
     +/
    static string[] decoders() @property @trusted {
        int numDecoders = Mix_GetNumMusicDecoders();
        if (numDecoders <= 0) {
            throw new SDLException;
        }

        static string[] decoders;
        if (decoders !is null) {
            size_t originalLength = decoders.length;
            decoders.length = numDecoders;

            if (numDecoders > originalLength) {
                foreach (i; originalLength .. numDecoders) {
                    decoders[i] = Mix_GetMusicDecoder(i.to!int).to!string;
                }
            }
        }
        else {
            decoders = new string[](numDecoders);
            foreach (i; 0 .. numDecoders) {
                decoders[i] = Mix_GetMusicDecoder(i).to!string;
            }
        }

        return decoders;
    }

    static if (sdlMixerSupport >= SDLMixerSupport.v2_6) {
        /++
         + Wraps `Mix_HasMusicDecoder` (from SDL_mixer 2.6) which checks whether a music decoder is available
         +
         + Params:
         +   decoder = name of the music decoder
         + Returns: `true` if available, otherwise `false`
         +/
        static bool hasDecoder(string decoder) @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_HasMusicDecoder(decoder.toStringz()) == SDL_TRUE;
        }
    }

    /++
     + Wraps `Mix_GetMusicType` which gets the format type of the `dsdl.mixer.Music`
     +
     + Returns: `dsdl.mixer.MusicType` enumeration indicating the format type
     +/
    MusicType type() const @property @trusted {
        return cast(MusicType) Mix_GetMusicType(this.mixMusic);
    }

    static if (sdlMixerSupport >= SDLMixerSupport.v2_6) {
        /++
         + Wraps `Mix_GetMusicTitle` (from SDL_mixer 2.6) which gets the title of the music
         +
         + Returns: title of the music
         +/
        string title() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicTitle(this.mixMusic).to!string;
        }

        /++
         + Wraps `Mix_GetMusicTitleTag` (from SDL_mixer 2.6) which gets the title tag of the music
         +
         + Returns: title tag of the music
         +/
        string titleTag() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicTitleTag(this.mixMusic).to!string;
        }

        /++
         + Wraps `Mix_GetMusicArtist` (from SDL_mixer 2.6) which gets the artist of the music
         +
         + Returns: artist of the music
         +/
        string artistTag() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicArtistTag(this.mixMusic).to!string;
        }

        /++
         + Wraps `Mix_GetMusicAlbum` (from SDL_mixer 2.6) which gets the album of the music
         +
         + Returns: album of the music
         +/
        string albumTag() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicAlbumTag(this.mixMusic).to!string;
        }

        /++
         + Wraps `Mix_GetMusicCopyright` (from SDL_mixer 2.6) which gets the copyright of the music
         +
         + Returns: copyright of the music
         +/
        string copyrightTag() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicCopyrightTag(this.mixMusic).to!string;
        }

        /++
         + Wraps `Mix_GetMusicVolume` (from SDL_mixer 2.6) which gets the volume of the music
         +
         + Returns: volume ranging from `0` to `128`
         +/
        ubyte volume() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return cast(ubyte) Mix_GetMusicVolume(cast(Mix_Music*) this.mixMusic);
        }

        /++
         + Wraps `Mix_GetMusicPosition` (from SDL_mixer 2.6) which gets the timestamp of the music in seconds
         +
         + Returns: position timestamp of the music in seconds; `-1.0` if codec doesn't support
         +/
        double position() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicPosition(cast(Mix_Music*) this.mixMusic);
        }

        /++
         + Wraps `Mix_MusicDuration` (from SDL_mixer 2.6) which gets the duration of the music in seconds
         +
         + Returns: duration of the music in seconds
         + Throws: `dsdl.SDLException` if failed to get duration
         +/
        double duration() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            double duration = Mix_MusicDuration(cast(Mix_Music*) this.mixMusic);
            if (duration == -1.0) {
                throw new SDLException;
            }

            return duration;
        }

        /++
         + Wraps `Mix_GetMusicLoopStartTime` (from SDL_mixer 2.6) which gets the loop start time of the music
         +
         + Returns: loop start time of the music; `-1.0` if not used or codec doesn't support
         +/
        double loopStartTime() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicLoopStartTime(cast(Mix_Music*) this.mixMusic);
        }

        /++
         + Wraps `Mix_GetMusicLoopEndTime` (from SDL_mixer 2.6) which gets the loop end time of the music
         +
         + Returns: loop end time of the music; `-1.0` if not used or codec doesn't support
         +/
        double loopEndTime() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicLoopEndTime(cast(Mix_Music*) this.mixMusic);
        }

        /++
         + Wraps `Mix_GetMusicLoopLengthTime` (from SDL_mixer 2.6) which gets the loop length time of the music
         +
         + Returns: loop length time of the music; `-1.0` if not used or codec doesn't support
         +/
        double loopLengthTime() const @property @trusted
        in {
            assert(dsdl.mixer.getVersion() >= Version(2, 6));
        }
        do {
            return Mix_GetMusicLoopLengthTime(cast(Mix_Music*) this.mixMusic);
        }
    }

    /++
     + Wraps `Mix_SetMusicPosition` which sets the timestamp position of the currently playing music
     +
     + Params:
     +   newPosition = new timestamp position in seconds
     + Throws: `dsdl.SDLException` if failed to set position
     +/
    static void position(double newPosition) @property @trusted {
        if (Mix_SetMusicPosition(newPosition) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_VolumeMusic` which gets the volume for music
     +
     + Returns: volume ranging from `0` to `128`
     +/
    static ubyte volume() @property @trusted {
        return cast(ubyte) Mix_VolumeMusic(-1);
    }

    /++
     + Wraps `Mix_VolumeMusic` which sets the volume for music
     +
     + Params:
     +   newVolume = new volume ranging from `0` to `128`
     +/
    static void volume(ubyte newVolume) @property @trusted {
        Mix_VolumeMusic(newVolume);
    }

    /++
     + Wraps `Mix_PausedMusic` which checks whether music is paused
     +
     + Returns: `true` if music is paused, otherwise `false`
     +/
    static bool paused() @trusted {
        return Mix_PausedMusic() == 1;
    }

    /++
     + Wraps `Mix_PlayingMusic` which checks whether music is playing
     +
     + Returns: `true` if music is playing, otherwise `false`
     +/
    static bool playing() @trusted {
        return Mix_PlayingMusic() == 1;
    }

    /++
     + Wraps `Mix_FadingMusic` which gets the fading stage of the music
     +
     + Returns: `dsdl.mixer.Fading` enumeration indicating the music's fading stage
     +/
    static Fading fading() @property @trusted {
        return cast(Fading) Mix_FadingMusic();
    }

    /++
     + Wraps `Mix_SetMusicCMD` which sets a command to be called when a new music is played
     +
     + Params:
     +   newCommand = trigger command
     + Throws: `dsdl.SDLException` if failed to set command
     +/
    static void command(string newCommand) @property @trusted {
        if (Mix_SetMusicCMD(newCommand.toStringz()) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_PlayMusic` which plays the `dsdl.mixer.Music`
     +
     + Params:
     +   loops = how many times the music should be played (`cast(uint) -1` for infinity)
     + Throws: `dsdl.SDLException` if failed to play the music
     +/
    void play(uint loops = 1) const @trusted {
        if (Mix_PlayMusic(cast(Mix_Music*) this.mixMusic, loops.to!int) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_FadeInMusicPos` which plays the `dsdl.mixer.Music` with a fade-in effect
     +
     + Params:
     +   loops = how many times the chunk should be played (`cast(uint) -1` for infinity)
     +   fadeMs = number of milliseconds the chunk fades in before fully playing at full volume
     +   position = start timestamp of the music in seconds
     + Throws: `dsdl.SDLException` if failed to play the music
     +/
    void fadeIn(uint loops = 1, uint fadeMs = 0, double position = 0) const @trusted {
        if (Mix_FadeInMusicPos(cast(Mix_Music*) this.mixMusic, loops, fadeMs, position) != 0) {
            throw new SDLException;
        }
    }

    /++
     + Wraps `Mix_FadeOutMusic` which performs fade-out for the current music playing
     +
     + Params:
     +   fadeMs = number of milliseconds to fade-out before fully halting
     +/
    static void fadeOut(uint fadeMs) @trusted {
        Mix_FadeOutMusic(fadeMs.to!int);
    }

    /++
     + Wraps `Mix_HaltMusic` which halts the playing music
     +/
    static void halt() @trusted {
        Mix_HaltMusic();
    }

    /++
     + Wraps `Mix_PauseMusic` which pauses music playback
     +/
    static void pause() @trusted {
        Mix_PauseMusic();
    }

    /++
     + Wraps `Mix_ResumeMusic` which resumes music playback
     +/
    static void resume() @trusted {
        Mix_ResumeMusic();
    }

    /++
     + Wraps `Mix_RewindMusic` which rewinds music playback
     +/
    static void rewind() @trusted {
        Mix_RewindMusic();
    }
}

/++
 + Wraps `Mix_LoadMUS` which loads an audio file from the filesystem to a `dsdl.mixer.Music`
 +
 + Params:
 +   file = path to the audio file
 + Returns: loaded `dsdl.mixer.Music`
 + Throws: `dsdl.SDLException` if unable to load
 +/
Music loadMusic(string file) @trusted {
    Mix_Music* mixMusic = Mix_LoadMUS(file.toStringz());
    if (mixMusic !is null) {
        return new Music(mixMusic);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `Mix_LoadMUS_RW` which loads an audio file from a buffer to a `dsdl.mixer.Music`
 +
 + Params:
 +   data = buffer of the audio file
 + Returns: loaded `dsdl.mixer.Music`
 + Throws: `dsdl.SDLException` if unable to load
 +/
Music loadMusicRaw(const void[] data) @trusted {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    Mix_Music* mixMusic = Mix_LoadMUS_RW(sdlRWops, 1);
    if (mixMusic !is null) {
        return new Music(mixMusic);
    }
    else {
        throw new SDLException;
    }
}

/++
 + Wraps `Mix_LoadMUSType_RW` which loads a typed audio file from a buffer to a `dsdl.mixer.Music`
 +
 + Params:
 +   data = buffer of the audio file
 +   type = specified `dsdl.mixer.MusicType` enumeration of the music
 + Returns: loaded `dsdl.mixer.Music`
 + Throws: `dsdl.SDLException` if unable to load
 +/
Music loadMusicRaw(const void[] data, MusicType type) @trusted {
    SDL_RWops* sdlRWops = SDL_RWFromConstMem(data.ptr, data.length.to!int);
    if (sdlRWops is null) {
        throw new SDLException;
    }

    Mix_Music* mixMusic = Mix_LoadMUSType_RW(sdlRWops, type, 1);
    if (mixMusic !is null) {
        return new Music(mixMusic);
    }
    else {
        throw new SDLException;
    }
}
