const std = @import("std");
const fs = @import("FileSystem.zig");
const ta = @import("TracingAllocator.zig");

const String = std.ArrayList(u8);
const ScanItem = struct {
    name: String,
    id: i32,
    contents: String,
    pub fn deinit(self: ScanItem) void {
        self.name.deinit();
        self.contents.deinit();
    }
    pub fn init(alloc: std.mem.Allocator, id: i32, name: []const u8) !ScanItem {
        var nameString = String.init(alloc);
        errdefer nameString.deinit();
        try nameString.appendSlice(name);

        return ScanItem{
            .name = nameString,
            .id = id,
            .contents = String.init(alloc),
        };
    }
    pub fn updateFile(self: *ScanItem, dir: std.fs.Dir) !void {
        var file = try dir.openFile(self.name.items, .{});
        defer file.close();

        const stat = try file.stat();
        try self.contents.ensureTotalCapacity(stat.size);
        self.contents.expandToCapacity();
        _ = try file.readAll(self.contents.items);
    }
    pub fn initFile(alloc: std.mem.Allocator, id: i32, name: []const u8, dir: std.fs.Dir) !ScanItem {
        var self = try ScanItem.init(alloc, id, name);
        errdefer self.deinit();
        try self.updateFile(dir);
        return self;
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

pub fn scan(alloc: std.mem.Allocator, f: fs.FileSystem, startDir: []const u8) !Scan {
    var scanItems = Scan.init(alloc);
    errdefer scanItems.deinit();

    var lookDir = std.ArrayList([]const u8).init(alloc);
    defer lookDir.deinit();
    {
        try lookDir.append(startDir);
        try scanItems.dirs.append(try ScanItem.init(alloc, try f.addDir(startDir), startDir));
    }
    var name = std.ArrayList(u8).init(alloc);
    defer name.deinit();
    var dir = std.fs.cwd();
    while (lookDir.popOrNull()) |dirName| {
        var iterDir = try dir.openIterableDir(dirName, .{});
        defer iterDir.close();
        var iterator = iterDir.iterate();
        while (try iterator.next()) |item| {
            if (item.name[0] == '.') continue;
            name.clearRetainingCapacity();
            try std.fmt.format(name.writer(), "{s}/{s}", .{ dirName, item.name });
            switch (item.kind) {
                .Directory => {
                    var nitem = try ScanItem.init(alloc, try f.addDir(name.items), name.items);
                    errdefer nitem.deinit();
                    try lookDir.append(nitem.name.items);
                    try scanItems.dirs.append(nitem);
                },
                .File => {
                    var nitem = try ScanItem.initFile(alloc, try f.addDir(name.items), name.items, dir);
                    errdefer nitem.deinit();
                    try scanItems.files.append(nitem);
                },
                else => {},
            }
        }
    }
    return scanItems;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .enable_memory_limit = true }){};
    defer _ = gpa.deinit();
    const galloc = gpa.allocator();
    var trace = ta.TracingAllocator().init(galloc);
    //var trace = std.heap.LoggingAllocator(.debug, .err).init(galloc);
    const alloc = trace.allocator();

    var f = try fs.FileSystem.init();
    var s = try scan(alloc, f, ".");
    std.log.info("total bytes:{}", .{gpa.total_requested_bytes});
    defer s.deinit();
    try f.readEvents();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
