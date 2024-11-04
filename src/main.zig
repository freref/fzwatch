const std = @import("std");
const builtin = @import("builtin");
const MacosWatcher = @import("macos.zig").MacosWatcher;
const FileEvent = @import("common.zig").FileEvent;
const FileCallback = @import("common.zig").FileCallback;

pub const watcher_os = switch (builtin.os.tag) {
    .macos => MacosWatcher,
    .linux => @compileError("Linux not supported"),
    .windows => @compileError("Windows not supported"),
    else => @compileError("Unsupported operating system"),
};

comptime {
    _ = watcher_os;
}

pub const FileWatcher = watcher_os;

fn fileChanged(event: FileEvent) void {
    switch (event) {
        .modified => std.debug.print("File was modified!\n", .{}),
    }
}

fn watcherThread(watcher: *FileWatcher) !void {
    try watcher.start();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var watcher = try FileWatcher.init(allocator);
    defer watcher.deinit();

    // Watch test.txt for changes
    try watcher.addFile("README.md");
    watcher.setCallback(fileChanged);

    // Start watcher in separate thread
    const thread = try std.Thread.spawn(.{}, watcherThread, .{&watcher});

    // Main thread does "work"
    std.debug.print("Started watching test.txt...\n", .{});
    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.time.sleep(std.time.ns_per_s * 2); // Sleep for 2 seconds
    }

    thread.join();
}
