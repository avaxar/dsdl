@safe:

import std.stdio;
import std.math;
import std.random;

static import dsdl;

void main() {
    dsdl.loadSO();
    dsdl.init(everything: true);

    // dfmt off
    auto window = new dsdl.Window("Pong",
        [dsdl.WindowPos.undefined, dsdl.WindowPos.undefined], [800, 600]);
    // dfmt on

    auto rand = Random(unpredictableSeed());

    float playerSpeed = 300.0;
    auto playerA = dsdl.FRect(10, 250, 10, 100);
    auto playerB = dsdl.FRect(780, 250, 10, 100);

    float ballSpeed = 300.0;
    float ballDirection = uniform(-PI, PI, rand);
    auto ball = dsdl.FRect(390, 290, 20, 20);

    bool running = true;
    float lastTick = dsdl.getTicks() / 1000.0;
    float deltaTime = 0.0;

    // Game loop
    while (running) {
        dsdl.pumpEvents();
        while (auto event = dsdl.pollEvent()) {
            if (cast(dsdl.QuitEvent) event) {
                running = false;
                break;
            }
        }

        // Updates movement from the keyboard
        auto keys = dsdl.getKeyboardState();
        // W and S for player A
        if (keys[dsdl.Scancode.w]) {
            playerA.y -= playerSpeed * deltaTime;
        }
        if (keys[dsdl.Scancode.s]) {
            playerA.y += playerSpeed * deltaTime;
        }
        // Up and down arrows for player B
        if (keys[dsdl.Scancode.up]) {
            playerB.y -= playerSpeed * deltaTime;
        }
        if (keys[dsdl.Scancode.down]) {
            playerB.y += playerSpeed * deltaTime;
        }

        // Updates the ball's movement from its direction
        ball.x += sin(ballDirection) * ballSpeed * deltaTime;
        ball.y -= cos(ballDirection) * ballSpeed * deltaTime;

        // Clamps both players' positions to not be out of the screen
        if (playerA.y < 10) {
            playerA.y = 10;
        }
        if (playerA.y > window.height - playerA.height - 10) {
            playerA.y = window.height - playerA.height - 10;
        }
        if (playerB.y < 10) {
            playerB.y = 10;
        }
        if (playerB.y > window.height - playerB.height - 10) {
            playerB.y = window.height - playerB.height - 10;
        }

        // Bounces the ball from the walls
        if (ball.y < 0) {
            ball.y = 0;
            ballDirection = PI - ballDirection;
        }
        if (ball.y > window.height - ball.height) {
            ball.y = window.height - ball.height;
            ballDirection = PI - ballDirection;
        }

        // Bounds the ball from the paddles
        if (ball.hasIntersection(playerA)) {
            ballDirection = -ballDirection + uniform(-1.0, 1.0, rand); // Adds minor direction shift
            ball.x = playerA.x + playerA.width;
        }
        if (ball.hasIntersection(playerB)) {
            ballDirection = -ballDirection + uniform(-1.0, 1.0, rand);
            ball.x = playerB.x - ball.width;
        }

        // If the ball hits the left or right side of the screen, reset the game
        if (ball.x < 0 || ball.x + ball.width > window.width) {
            ball.point = dsdl.FPoint((window.width - ball.width) / 2, (window.size[1] - ball.height) / 2);
            ballDirection = uniform(0.0, 2.0 * PI, rand);
        }

        // Clears the screen
        window.surface.fill(dsdl.Color(0, 0, 0));

        // Draws both of the players' paddles and the ball
        window.surface.fillRect(dsdl.Rect(playerA), dsdl.Color(255, 0, 0)); // Player A -> Red
        window.surface.fillRect(dsdl.Rect(playerB), dsdl.Color(0, 0, 255)); // Player B -> Blue
        window.surface.fillRect(dsdl.Rect(ball), dsdl.Color(255, 255, 255)); // Ball -> White

        window.update();
        deltaTime = dsdl.getTicks() / 1000.0 - lastTick;
        lastTick += deltaTime;
    }

    dsdl.quit();
}
