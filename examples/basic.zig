const std = @import("std");
const fzwatch = @import("fzwatch");

fn callback(context: ?*anyopaque, event: fzwatch.Event) void {
    _ = context;
    switch (event) {
        .modified => std.debug.print("File was modified!\n", .{}),
    }
}

fn watcherThread(watcher: *fzwatch.Watcher, io: std.Io) !void {
    try watcher.start(io, .{});
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file-to-watch>\n", .{args[0]});
        return error.InvalidArgument;
    }
    const target_file = args[1];

    var watcher = try fzwatch.Watcher.init(allocator);
    defer watcher.deinit();

    try watcher.addFile(target_file);
    watcher.setCallback(callback, null);

    const thread = try std.Thread.spawn(.{}, watcherThread, .{ &watcher, io });

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        try std.Io.sleep(io, .fromSeconds(2), .awake);
    }

    thread.join();
}
