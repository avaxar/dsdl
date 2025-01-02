/++
 + An object-oriented wrapper for SDL2 in the D programming language utilizing high level programming constructs,
 + accompanied with the $(LINK2 https://code.dlang.org/packages/bindbc-sdl, bindbc-sdl) binding.
 +
 + Use:
 + The recommended way of using this library in your project is to add it to your dub project. dsdl has been
 + published in the $(LINK2 https://code.dlang.org/packages/dsdl, dub package registry). A simple `dub add dsdl`
 + would do.
 +
 + Development:
 + This library is actively maintained over on its $(LINK2 https://github.com/avaxar/dsdl, GitHub repository).
 + Voluntary contributions in improving and fixing the library are welcome.
 +
 + Authors: Avaxar <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, Avaxar
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl;
public:

import dsdl.audio;
import dsdl.blend;
import dsdl.clipboard;
import dsdl.display;
import dsdl.event;
import dsdl.frect;
import dsdl.gl;
import dsdl.keyboard;
import dsdl.mouse;
import dsdl.pixels;
import dsdl.rect;
import dsdl.renderer;
import dsdl.sdl;
import dsdl.surface;
import dsdl.texture;
import dsdl.video;
import dsdl.window;
