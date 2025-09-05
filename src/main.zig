const std = @import("std");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
});

pub fn main() !void {
    var orig_termios: c.struct_termios = undefined;
    _ = c.tcgetattr(c.STDIN_FILENO, &orig_termios);
    defer _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &orig_termios);

    var raw = orig_termios;
    raw.c_lflag &= ~@as(c_ulong, c.ICANON);
    raw.c_lflag &= ~@as(c_ulong, c.ECHO);
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &raw);

    const old_flags = c.fcntl(c.STDIN_FILENO, c.F_GETFL, @as(c_int, 0));
    _ = c.fcntl(c.STDIN_FILENO, c.F_SETFL, @as(c_int, old_flags | c.O_NONBLOCK));

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var game_over = false;

    while (!game_over) {
        const key = stdin.takeByte() catch {
            continue;
        };

        if (key == 'q') {
            game_over = true;
        }

        std.debug.print("you typed: {c}\n", .{key});
    }
}
