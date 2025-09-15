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

// alien and player structs
const Player = struct { x: u16, lives: u8 = 3 };
const Aliens = []struct { x: u16, y: u16, alive: bool };

pub fn main() !void {
    // get original terminal config
    var orig_termios: c.struct_termios = undefined;
    _ = c.tcgetattr(c.STDIN_FILENO, &orig_termios);

    // on program end, restore the original terminal config
    defer _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &orig_termios);

    // change current terminal config to raw mode
    var raw = orig_termios;
    raw.c_lflag &= ~@as(c_ulong, c.ICANON);
    raw.c_lflag &= ~@as(c_ulong, c.ECHO);
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &raw);

    const old_flags = c.fcntl(c.STDIN_FILENO, c.F_GETFL, @as(c_int, 0));
    _ = c.fcntl(c.STDIN_FILENO, c.F_SETFL, @as(c_int, old_flags | c.O_NONBLOCK));

    // create an array of poll structs, which listen on input events
    var poll_fds = [_]std.posix.pollfd{.{ .fd = c.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 }};

    // game loop
    while (true) {
        // clear terminal and move cursor to starting position
        // (needs to happen after the drawing of the frame)

        // https://en.wikipedia.org/wiki/ANSI_escape_code

        // the \x1b is an escape sequence
        // [ is a so-called CSI, or Control Sequence Introducer
        // H, if specified without numbers, like n;m, will default to 1;1,
        // meaning, the cursor moves to first row and first column
        // [2J by spec deletes the entire screen and even moves to top left
        // corner, but it doesn't seem to work on my os, works only on some
        defer print("\x1b[2J\x1b[H", .{});

        defer _ = c.usleep(16_000); // ~16 ms = ~60 fps

        // poll for input, return number of fds which have some input in them
        const no_of_ready_fds = try std.posix.poll(&poll_fds, 100);

        // check if there are any files that have some input and if this is from
        // input event
        if (no_of_ready_fds == 0 or (poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        var buf: [1]u8 = undefined;

        // attempt reading the input char
        const read_bytes = try std.posix.read(c.STDIN_FILENO, &buf);
        if (read_bytes == 0) continue;

        const char = buf[0];

        print("you typed: {c}", .{char});

        if (char == 'q') {
            // end game loop
            break;
        }
    }
}
