const std = @import("std");

pub fn createServer(
    alloc: std.mem.Allocator,
) !Server {
    const socketName = ".srcfindsocket";
    const dir = std.fs.cwd();
    const statInfo = dir.statFile(socketName) catch |err| switch (err) {};
}
