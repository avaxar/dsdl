import std.conv : to;
import std.stdio;

import bindbc.opengl;
static import dsdl;

int main() {
    // Initializes SDL2 and OpenGL 3.0
    dsdl.loadSO();
    dsdl.init(everything: true);
    dsdl.setGLAttribute(dsdl.GLAttribute.contextProfileMask, dsdl.GLProfile.core);
    dsdl.setGLAttribute(dsdl.GLAttribute.contextMajorVersion, 3);
    dsdl.setGLAttribute(dsdl.GLAttribute.contextMinorVersion, 0);

    // Prints backkend information
    writeln("Version of SDL used: ", dsdl.getVersion());
    writeln("List of drivers: ", dsdl.getVideoDrivers());
    writeln("Used driver: ", dsdl.getCurrentVideoDriver());

    // dfmt off
    auto window = new dsdl.Window("OpenGL Window", [
        dsdl.WindowPos.undefined, dsdl.WindowPos.undefined
    ], [800, 600], openGL : true, resizable : true);
    // dfmt on
    window.minimumSize = [400, 300];
    auto context = new dsdl.GLContext(window);

    // Loads OpenGL through bindbc-opengl
    auto glSupportReceived = loadOpenGL();
    if (glSupportReceived != glSupport) {
        import loader = bindbc.loader.sharedlib;

        foreach (info; loader.errors) {
            writeln(info.error, info.message);
        }

        switch (glSupportReceived) {
        case GLSupport.noLibrary:
            writeln("No OpenGL library detected!");
            return 1;

        case GLSupport.badLibrary:
            writeln("The OpenGL version provided is lower than 3.0!");
            return 1;

        case GLSupport.noContext:
            writeln("No OpenGL context is available!");
            return 1;

        default:
            break;
        }
    }

    // Dumps version information
    int glMajor, glMinor;
    glGetIntegerv(GL_MAJOR_VERSION, &glMajor);
    glGetIntegerv(GL_MINOR_VERSION, &glMinor);
    // dfmt off
    writeln("OpenGL version: ", glMajor, ".", glMinor, // Version of the OpenGL library
            " / ", (cast(const(char)*) glGetString(GL_VERSION)).to!string, // OpenGL-provided string of its version
            " / ", (cast(const(char)*) glGetString(GL_VENDOR)).to!string, // Vendor of the OpenGL library
            " / ", (cast(const(char)*) glGetString(GL_RENDERER)).to!string); // OpenGL renderer
    // dfmt on

    // Set OpenGL rendering rendering up
    glViewport(0, 0, 800, 600);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);

    // Compiling vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    auto vertexShaderStr = import("vertex.vert").ptr;
    glShaderSource(vertexShader, 1, &vertexShaderStr, null);
    glCompileShader(vertexShader);

    // Compiling fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    auto fragmentShaderStr = import("fragment.frag").ptr;
    glShaderSource(fragmentShader, 1, &fragmentShaderStr, null);
    glCompileShader(fragmentShader);

    // Linking shaders and removing no longer used shaders
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // Making VAO
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    // Making VBO
    GLuint vbo;
    // dfmt off
    float[] vertices = [
        0.0, 0.75, 0.0, // Vertex 1 position
        1.0, 0.0, 0.0, 1.0, // Vertex 1 color

        0.75, -0.75, 0.0, // Vertex 2 position
        0.0, 1.0, 0.0, 1.0, // Vertex 2 color

        -0.75, -0.75, 0.0, // Vertex 3 position
        0.0, 0.0, 1.0, 1.0 // Vertex 3 color
    ];
    // dfmt on
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof, vertices.ptr, GL_STATIC_DRAW);

    // Making EBO
    GLuint ebo;
    uint[] indices = [0, 1, 2];
    glGenBuffers(1, &ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof, indices.ptr, GL_STATIC_DRAW);

    // 0th vertex attribute: position
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 7 * float.sizeof, cast(void*) 0);
    glEnableVertexAttribArray(0);

    // 1st vertex attribute: color
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 7 * float.sizeof, cast(void*)(3 * float.sizeof));
    glEnableVertexAttribArray(1);

    // Setup before rendering loop
    bool running = true;
    context.makeCurrent(window);
    glUseProgram(shaderProgram);
    glBindVertexArray(vao);

    while (running) {
        // Handle events
        dsdl.pumpEvents();
        while (auto event = dsdl.pollEvent()) {
            if (cast(dsdl.QuitEvent) event) {
                running = false;
                break;
            }
            else if (auto resizeEvent = cast(dsdl.WindowResizedEvent) event) {
                glViewport(0, 0, resizeEvent.width, resizeEvent.height);
            }
        }

        // Clears the OpenGL window
        glClearColor(0.75, 0.75, 0.75, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // Draws the triangle
        glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_INT, cast(void*) 0);

        // Displays to the window
        window.swapGL();
    }

    // Quit SDL
    dsdl.quit();

    return 0;
}
