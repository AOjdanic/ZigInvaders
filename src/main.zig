// (setup terminal for raw mode (non-blocking input)
// initialize game state (player position, aliens, bullets, etc.)
//
// while game not over:
//     frame_start_time = now()
//
//     // 1. INPUT
//     try to read key (non-blocking)
//     if key exists:
//         update input_state (left, right, shoot, quit, etc.)
//
//     // 2. UPDATE
//     update player based on input_state
//     update bullets (move upward)
//     update aliens (move sideways/down every N frames)
//     check collisions (bullets vs aliens, aliens vs player)
//
//     // 3. RENDER
//     clear screen
//     draw player
//     draw aliens
//     draw bullets
//     draw score/status
//
//     // 4. TIMING
//     frame_end_time = now()
//     sleep until frame_start_time + (1/60) sec

const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("time.h");
    @cInclude("stdlib.h");
    @cInclude("poll.h");
});

fn getTerminalSettings(config_struct: *c.struct_termios) void {
    _ = c.tcgetattr(c.STDIN_FILENO, config_struct);
}

fn restoreOriginalTerminalSettings(config: *c.struct_termios) void {
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, config);
}

fn enableRawTerminalMode(config: *c.struct_termios) void {
    var raw_config = config.*;
    raw_config.c_lflag &= ~@as(c_ulong, c.ICANON);
    raw_config.c_lflag &= ~@as(c_ulong, c.ECHO);
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &raw_config);
}

fn setNonBlockingInputMode() void {
    const old_flags = c.fcntl(c.STDIN_FILENO, c.F_GETFL, @as(c_int, 0));
    _ = c.fcntl(c.STDIN_FILENO, c.F_SETFL, @as(c_int, old_flags | c.O_NONBLOCK));
}

const IOError = error{ NoInput, ReadFailed };

fn getInputKey(files_to_poll: *[1]std.posix.pollfd) !u8 {

    // poll for input, return number of fds which have some input in them
    const no_of_ready_fds = std.posix.poll(files_to_poll, 100) catch return IOError.ReadFailed;

    // check if there are any files that have some input and if this is from
    // input event
    if (no_of_ready_fds == 0 or (files_to_poll[0].revents & std.posix.POLL.IN) == 0) return IOError.NoInput;

    var buf: [1]u8 = undefined;

    // attempt reading the input char
    const read_bytes = std.posix.read(c.STDIN_FILENO, &buf) catch return IOError.ReadFailed;
    if (read_bytes == 0) return IOError.NoInput;

    return buf[0];
}

fn clearScreen() void {
    // clear terminal and move cursor to starting position
    // (needs to happen after the drawing of the frame)

    // https://en.wikipedia.org/wiki/ANSI_escape_code

    // the \x1b is an escape sequence
    // [ is a so-called CSI, or Control Sequence Introducer
    // H, if specified without numbers, like n;m, will default to 1;1,
    // meaning, the cursor moves to first row and first column
    // [2J by spec deletes the entire screen and even moves to top left
    // corner, but it doesn't seem to work on my os for moving the cursor,
    // works only on some operating systems
    print("\x1b[2J\x1b[H", .{});
}

// alien and player structs
const Player = struct { x: u16 = 40, y: u16 = 23, lives: u8 = 3, symbol: u8 = '^' };
const Alien = struct { x: u16, y: u16, alive: bool, symbol: u8 = 'A' };

// 5x11

const Actions = enum {
    MOVE_LEFT,
    MOVE_RIGHT,
    SHOOT,
};

fn updatePlayer() !void {}
fn updateAliens() !void {}
fn updateBullets() !void {}

const HEIGHT = 24;
const WIDTH = 81;

const POSITION_OFFSET = ((WIDTH - 1) / 2) - 5;

const Arena = [HEIGHT][WIDTH]u8;

var arena: Arena = undefined;

fn clearArena() void {
    arena = .{.{' '} ** WIDTH} ** HEIGHT;
}

fn drawArena(aliens: *[55]Alien, player: *Player) void {
    for (aliens.*) |alien| {
        arena[alien.y][alien.x] = alien.symbol;
    }

    arena[player.y][player.x] = player.symbol;

    for (arena) |row| {
        print("{s}", .{row});
        print("\n", .{});
    }
}

fn createAliens(aliens: *[55]Alien) void {
    const ROWS = 5;
    const COLUMNS = 11;

    for (0..ROWS) |i| {
        for (0..COLUMNS) |j| {
            aliens[i * COLUMNS + j] = Alien{
                .alive = true,
                .x = @intCast(j + POSITION_OFFSET),
                .y = @intCast(i),
            };
        }
    }
}

pub fn main() !void {
    // get original terminal config
    var terminal_config: c.struct_termios = undefined;
    getTerminalSettings(&terminal_config);

    // on program end, restore the original terminal config
    defer restoreOriginalTerminalSettings(&terminal_config);

    // change current terminal config to raw mode
    enableRawTerminalMode(&terminal_config);

    // set stdin to non-blocking
    setNonBlockingInputMode();

    // create an array of poll structs, which listen on input events
    var poll_fds = [_]std.posix.pollfd{.{ .fd = c.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 }};

    var aliens: [55]Alien = undefined;
    createAliens(&aliens);

    var player: Player = .{};

    // game loop

    print("\x1b[?25l", .{}); // hide cursor
    print("\x1b[?1049h", .{}); // enter alt buffer
    defer print("\x1b[?1049l", .{}); // leave alt buffer
    defer print("\x1b[?25h", .{}); //show the cursor
    while (true) {
        clearScreen();
        clearArena();
        drawArena(&aliens, &player);

        const char = getInputKey(&poll_fds) catch continue;
        if (char == 'q') {
            // end game loop
            break;
        }

        _ = c.usleep(16_000); // ~16 ms = ~60 fps
    }
}
