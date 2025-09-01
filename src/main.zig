const std = @import("std");
const ZigInvaders = @import("ZigInvaders");

pub fn main() !void {
    var game_over = false;
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;
    var input_char: u8 = undefined;

    while (!game_over) {
        input_char = try stdin.takeByte();
        if (input_char == 'q') {
            game_over = true;
        }

        std.debug.print("you typed: {c}\n", .{input_char});
    }
}
