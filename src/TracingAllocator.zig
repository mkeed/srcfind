const std = @import("std");
const Allocator = std.mem.Allocator;
pub fn TracingAllocator() type {
    return struct {
        parent_allocator: Allocator,
        curAllocated: usize,
        totalAllocated: usize,
        const Self = @This();
        pub fn init(parent_allocator: Allocator) Self {
            return .{
                .parent_allocator = parent_allocator,
                .curAllocated = 0,
                .totalAllocated = 0,
            };
        }

        pub fn allocator(self: *Self) Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        fn alloc(
            ctx: *anyopaque,
            len: usize,
            log2_ptr_align: u8,
            ra: usize,
        ) ?[*]u8 {
            const self = @ptrCast(*Self, @alignCast(@alignOf(Self), ctx));
            const result = self.parent_allocator.rawAlloc(len, log2_ptr_align, ra);
            if (result != null) {
                self.curAllocated += len;
                self.totalAllocated += len;
            }
            return result;
        }
        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            new_len: usize,
            ra: usize,
        ) bool {
            const self = @ptrCast(*Self, @alignCast(@alignOf(Self), ctx));
            if (self.parent_allocator.rawResize(buf, log2_buf_align, new_len, ra)) {
                if (new_len <= buf.len) {
                    self.curAllocated -= (buf.len - new_len);
                } else {
                    self.curAllocated += (new_len - buf.len);
                    self.totalAllocated += (new_len - buf.len);
                }
            }
            return false;
        }
        fn free(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            ra: usize,
        ) void {
            const self = @ptrCast(*Self, @alignCast(@alignOf(Self), ctx));
            self.parent_allocator.rawFree(buf, log2_buf_align, ra);
            self.curAllocated -= buf.len;
        }
    };
}
