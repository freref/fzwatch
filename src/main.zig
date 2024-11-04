const std = @import("std");
const builtin = @import("builtin");
pub const Event = @import("watchers/interfaces.zig").Event;

const watchers = struct {
    pub const macos = @import("watchers/macos.zig");
    // pub const linux = @import("watchers/linux.zig");
    // pub const windows = @import("watchers/windows.zig");
};

pub const watcher_os = switch (builtin.os.tag) {
    .macos => watchers.macos.MacosWatcher,
    .linux => @compileError("Linux not supported"),
    .windows => @compileError("Windows not supported"),
    else => @compileError("Unsupported operating system"),
};

comptime {
    _ = watcher_os;
}

pub const FileWatcher = watcher_os;
