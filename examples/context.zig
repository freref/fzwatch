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

    pub fn init(allocator: std.mem.Allocator, target_file: []const u8) !Object {
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

    fn watcherThread(watcher: *fzwatch.Watcher, io: std.Io) !void {
        try watcher.start(io, .{});
    }

    pub fn start(self: *Object, io: std.Io) !void {
        self.watcher.setCallback(callback, &self.to_increment);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{ &self.watcher, io });
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file-to-watch>\n", .{args[0]});
        return error.InvalidArgument;
    }
    const target_file = args[1];

    var obj = try Object.init(allocator, target_file);
    defer obj.deinit();
    try obj.start(io);

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        try std.Io.sleep(io, .fromSeconds(2), .awake);
    }

    obj.thread.join();
}
