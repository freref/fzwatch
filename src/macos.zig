const std = @import("std");
const darwin = std.os.darwin;
const c = @cImport({
    @cInclude("CoreServices/CoreServices.h");
});

pub const MacosWatcher = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !MacosWatcher {
        return MacosWatcher{
            .allocator = allocator,
            .files = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MacosWatcher) void {
        _ = self;
    }

    pub fn addFile(self: *MacosWatcher, path: []const u8) !void {
        const file = try self.allocator.dupe(u8, path);
        try self.files.append(file);
    }

    pub fn removeFile(self: *MacosWatcher, path: []const u8) !void {
        for (self.files.items, 0..) |file, index| {
            if (std.mem.eql(u8, file, path)) {
                self.allocator.free(file);
                _ = self.files.orderedRemove(index);
            }
        }
    }

    pub fn setCallback(self: *MacosWatcher, callback: c.FSEventStreamCallback) !void {
        _ = self;
        _ = callback;
    }

    pub fn start(self: *MacosWatcher) !void {
        _ = self;
    }

    pub fn stop(self: *MacosWatcher) !void {
        _ = self;
    }
};
