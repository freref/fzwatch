const std = @import("std");
const fzwatch = @import("fzwatch");

const Object = struct {
    allocator: std.mem.Allocator,
    to_increment: usize,
    watcher: fzwatch.Watcher,
    thread: ?std.Thread,

    fn callback(context: ?*anyopaque, event: fzwatch.Event) void {
        switch (event) {
            .modified => {
                const to_increment: *usize = @as(*usize, @ptrCast(@alignCast(context.?)));
                to_increment.* += 1;
                std.debug.print("File was modified! (incremented to {d})\n", .{to_increment.*});
            },
        }
    }

    pub fn init(allocator: std.mem.Allocator, target_file: [:0]u8) !Object {
        var watcher = try fzwatch.Watcher.init(allocator);
        try watcher.addFile(target_file);

        return Object{
            .allocator = allocator,
            .to_increment = 0,
            .watcher = watcher,
            .thread = null,
        };
    }

    pub fn deinit(self: *Object) void {
        self.watcher.deinit();
    }

    fn watcherThread(watcher: *fzwatch.Watcher) !void {
        try watcher.start(.{});
    }

    pub fn start(self: *Object) !void {
        self.watcher.setCallback(callback, &self.to_increment);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{&self.watcher});
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file-to-watch>\n", .{args[0]});
        return error.InvalidArgument;
    }
    const target_file = args[1];

    var obj = try Object.init(allocator, target_file);
    defer obj.deinit();
    try obj.start();

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.Thread.sleep(std.time.ns_per_s * 2);
    }

    obj.thread.join();
}
