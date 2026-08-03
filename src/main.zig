const std = @import("std");
const builtin = @import("builtin");
pub const Event = @import("watchers/interfaces.zig").Event;

const watchers = struct {
    pub const macos = @import("watchers/macos.zig");
    pub const linux = @import("watchers/linux.zig");
};

pub const Watcher = switch (builtin.os.tag) {
    .macos => watchers.macos.MacosWatcher,
    .linux => watchers.linux.LinuxWatcher,
    else => @compileError("Unsupported OS"),
};

comptime {
    _ = Watcher;
}

test "detects file modification" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file_path = "testfile.txt";
    try tmp.dir.writeFile(io, .{
        .sub_path = file_path,
        .data = "initial content",
    });
    const abs_path = try tmp.dir.realPathFileAlloc(io, file_path, std.testing.allocator);
    defer std.testing.allocator.free(abs_path);

    var watcher = try Watcher.init(std.testing.allocator);
    defer watcher.deinit();
    try watcher.addFile(abs_path);

    var event_received = std.atomic.Value(bool).init(false);
    const callback = struct {
        fn handle(ctx: ?*anyopaque, ev: Event) void {
            std.debug.assert(ev == .modified);

            const flag = @as(*std.atomic.Value(bool), @ptrCast(ctx.?));
            flag.store(true, .release);
        }
    }.handle;
    watcher.setCallback(callback, &event_received);

    const watcher_thread = try std.Thread.spawn(.{}, struct {
        fn run(w: *Watcher) !void {
            try w.start(std.testing.io, .{ .latency = 0.1 });
        }
    }.run, .{&watcher});

    try std.Io.sleep(io, .fromMilliseconds(100), .awake);

    try tmp.dir.writeFile(io, .{
        .sub_path = file_path,
        .data = "modified content",
    });

    const start = std.Io.Timestamp.now(io, .awake).toMilliseconds();
    while (!event_received.load(.acquire)) {
        if (std.Io.Timestamp.now(io, .awake).toMilliseconds() - start > 2000) {
            std.debug.print("Timeout waiting for event\n", .{});
            return error.TestFailed;
        }
        try std.Io.sleep(io, .fromMilliseconds(10), .awake);
    }

    watcher.stop();
    watcher_thread.join();
}
