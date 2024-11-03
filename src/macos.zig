const std = @import("std");
const darwin = std.os.darwin;
const c = @cImport({
    @cInclude("CoreServices/CoreServices.h");
});

pub const MacosWatcher = struct {
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) MacosWatcher {
        return MacosWatcher{ .allocator = allocator };
    }

    pub fn deinit(self: *MacosWatcher) void {
        _ = self;
    }

    pub fn addFile(self: *MacosWatcher, path: []const u8) !void {
        _ = self;
        _ = path;
    }

    pub fn removeFile(self: *MacosWatcher, path: []const u8) !void {
        _ = self;
        _ = path;
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
