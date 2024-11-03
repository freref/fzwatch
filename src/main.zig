const std = @import("std");
const builtin = @import("builtin");
const MacosWatcher = @import("macos.zig").MacosWatcher;

const watcher_os = switch (builtin.os.tag) {
    .macos => MacosWatcher,
    else => @compileError("Unsupported operating system"),
};

comptime {
    _ = watcher_os;
}

pub const FileWatcher = watcher_os;

pub fn main() !void {}
