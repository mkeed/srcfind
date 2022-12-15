const std = @import("std");

pub const FileSystem = struct {
    fd: std.os.fd_t,
    pub fn init() !FileSystem {
        const res = @intCast(std.os.fd_t, @bitCast(isize, std.os.linux.inotify_init1(0))); //std.os.linux.O.IN_NONBLOCK
        if (res < 0) {
            return error.InotifyFailed;
        }
        return FileSystem{
            .fd = res,
        };
    }
    pub fn addFile(self: FileSystem, file: []const u8) !i32 {
        std.log.info("added file:{s}", .{file});
        var buffer: [512]u8 = undefined;
        const fileZ = try std.fmt.bufPrintZ(buffer[0..], "{s}", .{file});
        //IN_MODIFY
        const res = @intCast(i32, @bitCast(isize, std.os.linux.inotify_add_watch(
            self.fd,
            fileZ,
            std.os.linux.IN.MODIFY,
        )));
        if (res < 0) {
            return error.AddWatchFailed;
        }
        return res;
    }

    pub fn addDir(self: FileSystem, dir: []const u8) !i32 {
        std.log.info("added dir:{s}", .{dir});
        var buffer: [512]u8 = undefined;
        const fileZ = try std.fmt.bufPrintZ(buffer[0..], "{s}", .{dir});
        //IN_MODIFY
        const res = @intCast(i32, @bitCast(isize, std.os.linux.inotify_add_watch(
            self.fd,
            fileZ,
            std.os.linux.IN.CREATE,
        )));
        if (res < 0) {
            return error.AddWatchFailed;
        }
        return res;
    }

    pub fn readEvents(self: FileSystem) !void {
        var readBuf: [4096]u8 = undefined;
        const len = try std.os.read(self.fd, readBuf[0..]);
        var subBuf = readBuf[0..len];
        while (subBuf.len > 0) {
            var event: std.os.linux.inotify_event = undefined;
            @memcpy(@ptrCast([*]u8, &event), subBuf.ptr, @sizeOf(@TypeOf(event)));
            subBuf = subBuf[@sizeOf(@TypeOf(event))..];
            const name = subBuf[0..event.len];
            subBuf = subBuf[name.len..];
            std.log.info("event:{} name:{s}", .{ event, name });
        }
    }
};
