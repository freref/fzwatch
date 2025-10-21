const std = @import("std");
const fzwatch = @import("fzwatch");

fn callback(context: ?*anyopaque, event: fzwatch.Event) void {
    _ = context;
    switch (event) {
        .modified => std.debug.print("File was modified!\n", .{}),
    }
}

fn watcherThread(watcher: *fzwatch.Watcher) !void {
    try watcher.start(.{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file-to-watch>\n", .{args[0]});
        return error.InvalidArgument;
    }
    const target_file = args[1];

    var watcher = try fzwatch.Watcher.init(allocator);
    defer watcher.deinit();

    try watcher.addFile(target_file);
    watcher.setCallback(callback, null);

    const thread = try std.Thread.spawn(.{}, watcherThread, .{&watcher});

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.Thread.sleep(std.time.ns_per_s * 2);
    }

    thread.join();
}
