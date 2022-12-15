const std = @import("std");
const fs = @import("FileSystem.zig");

const String = std.ArrayList(u8);
const ScanItem = struct {
    name: String,
    id: i32,
    pub fn deinit(self: ScanItem) void {
        self.name.deinit();
    }
};

pub const Scan = struct {
    alloc: std.mem.Allocator,
    dirs: std.ArrayList(ScanItem),
    files: std.ArrayList(ScanItem),
    pub fn init(alloc: std.mem.Allocator) Scan {
        return .{
            .alloc = alloc,
            .dirs = std.ArrayList(ScanItem).init(alloc),
            .files = std.ArrayList(ScanItem).init(alloc),
        };
    }
    pub fn deinit(self: Scan) void {
        for (self.dirs.items) |item| item.deinit();
        self.dirs.deinit();
        for (self.files.items) |item| item.deinit();
        self.files.deinit();
    }
    pub fn print(self: Scan) void {
        for (self.dirs.items) |dir| {
            std.log.info("dir=>{s}", .{dir.items});
        }
        for (self.files.items) |dir| {
            std.log.info("file=>{s}", .{dir.items});
        }
    }
};

pub fn scan(alloc: std.mem.Allocator, f: fs.FileSystem) !Scan {
    var scanItems = Scan.init(alloc);
    errdefer scanItems.deinit();

    var lookDir = std.ArrayList([]const u8).init(alloc);
    defer lookDir.deinit();
    {
        var startDir = String.init(alloc);
        errdefer startDir.deinit();
        try startDir.appendSlice(".");
        try lookDir.append(startDir.items);
        try scanItems.dirs.append(.{
            .name = startDir,
            .id = try f.addDir(startDir.items),
        });
    }
    var dir = std.fs.cwd();
    while (lookDir.popOrNull()) |dirName| {
        var iterDir = try dir.openIterableDir(dirName, .{});
        defer iterDir.close();
        var iterator = iterDir.iterate();
        while (try iterator.next()) |item| {
            if (item.name[0] == '.') continue;
            switch (item.kind) {
                .Directory => {
                    var name = String.init(alloc);
                    errdefer name.deinit();
                    try std.fmt.format(name.writer(), "{s}/{s}", .{ dirName, item.name });
                    try scanItems.dirs.append(.{
                        .name = name,
                        .id = try f.addDir(name.items),
                    });
                    try lookDir.append(name.items);
                },
                .File => {
                    var name = String.init(alloc);
                    errdefer name.deinit();
                    try std.fmt.format(name.writer(), "{s}/{s}", .{ dirName, item.name });
                    try scanItems.files.append(.{
                        .name = name,
                        .id = try f.addFile(name.items),
                    });
                },
                else => {},
            }
        }
    }
    return scanItems;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var f = try fs.FileSystem.init();
    var s = try scan(alloc, f);
    defer s.deinit();
    try f.readEvents();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
