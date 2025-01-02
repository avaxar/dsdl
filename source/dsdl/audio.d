/++
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.audio;
@safe:

import bindbc.sdl;
import dsdl.sdl;

import core.memory : GC;
import std.conv : to;
import std.format : format;
import std.string : toStringz;

/++
 + D enum that wraps `SDL_AudioFormat` defining scalar type per audio sample
 +/
enum AudioFormat {
    /++
     + Wraps `AUDIO_*` enumeration constants
     +/
    u8 = AUDIO_U8,
    s8 = AUDIO_S8, /// ditto
    u16LSB = AUDIO_U16LSB, /// ditto
    s16LSB = AUDIO_S16LSB, /// ditto
    u16MSB = AUDIO_U16MSB, /// ditto
    s16MSB = AUDIO_S16MSB, /// ditto
    u16 = AUDIO_U16, /// ditto
    s16 = AUDIO_S16, /// ditto
    s32LSB = AUDIO_S32LSB, /// ditto
    s32MSB = AUDIO_S32MSB, /// ditto
    s32 = AUDIO_S32, /// ditto
    f32LSB = AUDIO_F32LSB, /// ditto
    f32MSB = AUDIO_F32MSB, /// ditto
    f32 = AUDIO_F32, /// ditto

    u16Sys = AUDIO_U16SYS, /// ditto
    s16Sys = AUDIO_S16SYS, /// ditto
    s32Sys = AUDIO_S32SYS, /// ditto
    f32Sys = AUDIO_F32SYS /// ditto
}

/++
 + D enum that wraps `SDL_AUDIO_*` status enumerations
 +/
enum AudioStatus {
    /++
     + Wraps `SDL_AUDIO_*` enumeration constants
     +/
    stopped = SDL_AUDIO_STOPPED,
    playing = SDL_AUDIO_PLAYING, /// ditto
    paused = SDL_AUDIO_PAUSED /// ditto
}

enum maxVolume = cast(ubyte) SDL_MIX_MAXVOLUME; /// Alias to `SDL_MIX_MAXVOLUME`

/++
 + Wraps `SDL_AudioInit` which initializes the audio subsystem while specifying the audio driver used
 +
 + Params:
 +   driverName = the name of the audio driver
 + Throws: `dsdl.SDLException` if the audio driver could not be initialized
 +/
void initAudio(string driverName) @trusted {
    if (SDL_AudioInit(driverName.toStringz()) != 0) {
        throw new SDLException;
    }
}

/++
 + Wraps `SDL_AudioQuit` which quits the audio subsystem
 +/
void quitAudio() @trusted {
    SDL_AudioQuit();
}

/++
 + Wraps `SDL_GetNumAudioDrivers` and `SDL_GetAudioDriver` which return a list of available audio drivers
 +
 + Returns: names of the available audio drivers
 + Throws: `dsdl.SDLException` if failed to get the available audio drivers
 +/
const(string[]) getAudioDrivers() @trusted {
    int numDrivers = SDL_GetNumAudioDrivers();
    if (numDrivers <= 0) {
        throw new SDLException;
    }

    static string[] drivers;
    if (drivers !is null) {
        size_t originalLength = drivers.length;
        drivers.length = numDrivers;

        if (numDrivers > originalLength) {
            foreach (i; originalLength .. numDrivers) {
                drivers[i] = SDL_GetAudioDriver(i.to!int).to!string;
            }
        }
    }
    else {
        drivers = new string[](numDrivers);

        foreach (i; 0 .. numDrivers) {
            drivers[i] = SDL_GetAudioDriver(i).to!string;
        }
    }

    return drivers;
}

/++
 + Wraps `SDL_GetCurrentAudioDriver` which returns the current audio driver
 +
 + Returns: name of the current audio driver
 +/
string getCurrentAudioDriver() @trusted {
    return SDL_GetCurrentAudioDriver().to!string;
}

// TODO
struct AudioSpec {
    SDL_AudioSpec sdlAudioSpec; /// Internal `SDL_AudioSpec` struct
}

// TODO
final class AudioDevice {
    const SDL_AudioDeviceID sdlAudioDeviceID; /// Internal `SDL_AudioDeviceID`
}

private const(string[]) getAudioDeviceNamesRaw(int isCapture)() @trusted {
    int numDrivers = SDL_GetNumAudioDevices(isCapture);
    if (numDrivers <= 0) {
        throw new SDLException;
    }

    static string[] drivers;
    if (drivers !is null) {
        size_t originalLength = drivers.length;
        drivers.length = numDrivers;

        if (numDrivers > originalLength) {
            foreach (i; originalLength .. numDrivers) {
                drivers[i] = SDL_GetAudioDeviceName(i.to!int, isCapture).to!string;
            }
        }
    }
    else {
        drivers = new string[](numDrivers);

        foreach (i; 0 .. numDrivers) {
            drivers[i] = SDL_GetAudioDeviceName(i, isCapture).to!string;
        }
    }

    return drivers;
}

/++
 + Acts as `SDL_GetNumAudioDevices(0)` and `SDL_GetAudioDeviceName(..., 0)` which return a name list of available
 + non-capturing audio devices
 +
 + Returns: names of the available non-capturing audio devices
 + Throws: `dsdl.SDLException` if failed to get the available non-capturing audio devices
 +/
const(string[]) getAudioDeviceNames() @trusted {
    return getAudioDeviceNamesRaw!0;
}

/++
 + Acts as `SDL_GetNumAudioDevices(1)` and `SDL_GetAudioDeviceName(..., 1)` which return a name list of available
 + capturing audio devices
 +
 + Returns: names of the available capturing audio devices
 + Throws: `dsdl.SDLException` if failed to get the available capturing audio devices
 +/
const(string[]) getCapturingAudioDeviceNames() @trusted {
    return getAudioDeviceNamesRaw!1;
}

/++
 + Wraps `SDL_OpenAudio` which opens the default audio device
 +
 + Params:
 +   desired = desired `dsdl.AudioSpec`ifications
 + Returns: obtained `dsdl.AudioSpec`ifications
 +/
AudioSpec openAudio(AudioSpec desired) @trusted {
    // TODO: implement handling for `AudioSpec`
    assert(false, "Not implemented");
}

/++
 + Wraps `SDL_CloseAudio` which closes the default audio device
 +/
void closeAudio() @trusted {
    SDL_CloseAudio();
}

/++
 + Wraps `SDL_GetAudioStatus` which returns the current status of the default audio device
 +
 + Returns: `dsdl.AudioStatus` of the default audio device
 +/
AudioStatus getAudioStatus() @trusted {
    return cast(AudioStatus) SDL_GetAudioStatus();
}

/++
 + Wraps `SDL_PauseAudio` which pauses the default audio device
 +
 + Params:
 +   paused = `true` to pause by default; `false` to resume
 +/
void pauseAudio(bool paused = true) @trusted {
    SDL_PauseAudio(paused ? 1 : 0);
}

/++
 + Acts as `SDL_PauseAudio(0)` which resumes the default audio device
 +/
void resumeAudio() @trusted {
    SDL_PauseAudio(0);
}

/++
 + Wraps `SDL_LockAudio` which locks the default audio device
 +/
void lockAudio() @trusted {
    SDL_LockAudio();
}

/++
 + Wraps `SDL_UnlockAudio` which unlocks the default audio device
 +/
void unlockAudio() @trusted {
    SDL_UnlockAudio();
}
