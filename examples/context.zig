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

    pub fn init(allocator: std.mem.Allocator) !Object {
        var watcher = try fzwatch.Watcher.init(allocator);
        try watcher.addFile("README.md");

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
        try watcher.start();
    }

    pub fn start(self: *Object) !void {
        self.watcher.setCallback(callback, &self.to_increment);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{&self.watcher});
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var obj = try Object.init(allocator);
    defer obj.deinit();
    try obj.start();

    var i: usize = 0;
    while (true) : (i += 1) {
        std.debug.print("Working... (iteration {d})\n", .{i});
        std.time.sleep(std.time.ns_per_s * 2);
    }

    obj.thread.join();
}
