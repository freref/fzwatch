const std = @import("std");
const fzwatch = @import("fzwatch");

fn callback(context: ?*anyopaque, event: fzwatch.Event) void {
    _ = context;
    switch (event.kind) {
        .modified => std.debug.print("File {d} was modified!\n", .{event.item}),
    }
}

fn watcherThread(watcher: *fzwatch.Watcher) !void {
    try watcher.start(.{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var watcher = try fzwatch.Watcher.init(allocator);
    defer watcher.deinit();

    try watcher.addFile("README.md");
    // try watcher.removeFile("README.md");
    try watcher.addFile("build.zig");
    try watcher.removeFile("build.zig");
    try watcher.addFile("build.zig.zon");
    try watcher.removeFile("build.zig.zon");
    watcher.setCallback(callback, null);

    const thread = try std.Thread.spawn(.{}, watcherThread, .{&watcher});

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.time.sleep(std.time.ns_per_s * 2);
    }

    thread.join();
}
