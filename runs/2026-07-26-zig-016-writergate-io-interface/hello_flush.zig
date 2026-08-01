const std = @import("std");
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var buffer: [256]u8 = undefined;
    var fw = std.Io.File.stdout().writer(io, &buffer);
    try fw.interface.print("hello, writergate\n", .{});
    try fw.interface.flush();
}
