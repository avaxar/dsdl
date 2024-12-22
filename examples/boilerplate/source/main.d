@safe:

import std.stdio;
static import dsdl;

void main() {
    // SDL initialization
    dsdl.loadSO();
    dsdl.init(everything: true);

    // Prints backend information
    writeln("Version of SDL used: ", dsdl.getVersion());
    writeln("List of drivers: ", dsdl.getVideoDrivers());
    writeln("Used driver: ", dsdl.getCurrentVideoDriver());

    // Creates a simple 800x600 window in the center of the screen, as well as its associated GPU renderer
    // dfmt off
    auto window = new dsdl.Window("My Window", [dsdl.WindowPos.centered, dsdl.WindowPos.centered], [800, 600]);
    auto renderer = new dsdl.Renderer(window, accelerated : true, presentVSync : true);
    // dfmt on

    // The application loop
    bool running = true;
    while (running) {
        // Gets incoming events
        dsdl.pumpEvents();
        while (auto event = dsdl.pollEvent()) {
            // On quit
            if (cast(dsdl.QuitEvent) event) {
                running = false;
            }
        }

        // Clears the screen with white
        renderer.drawColor = dsdl.Color(255, 255, 255);
        renderer.clear();

        // Draws a filled red box at the center of the screen
        renderer.drawColor = dsdl.Color(255, 0, 0);
        renderer.fillRect(dsdl.Rect(350, 250, 100, 100));

        renderer.present();
    }

    // Quits SDL
    dsdl.quit();
}
