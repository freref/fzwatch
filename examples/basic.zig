const std = @import("std");
const fzwatch = @import("fzwatch");

// TODO check callback interface
fn callback(event: fzwatch.Event) void {
    switch (event) {
        .modified => std.debug.print("File was modified!\n", .{}),
    }
}

fn watcherThread(watcher: *fzwatch.FileWatcher) !void {
    try watcher.start();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var watcher = try fzwatch.FileWatcher.init(allocator);
    defer watcher.deinit();

    try watcher.addFile("README.md");
    watcher.setCallback(callback);

    const thread = try std.Thread.spawn(.{}, watcherThread, .{&watcher});

    std.debug.print("Started watching test.txt...\n", .{});
    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.time.sleep(std.time.ns_per_s * 2);
    }

    thread.join();
}
