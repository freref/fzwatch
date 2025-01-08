const std = @import("std");
const interfaces = @import("interfaces.zig");

pub const LinuxWatcher = struct {
    allocator: std.mem.Allocator,
    inotify_fd: i32,
    paths: std.ArrayList([]const u8),
    callback: ?*const interfaces.Callback,
    running: bool,
    context: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) !LinuxWatcher {
        const fd = try std.posix.inotify_init1(std.os.linux.IN.NONBLOCK);
        errdefer std.posix.close(fd);

        return LinuxWatcher{
            .allocator = allocator,
            .inotify_fd = @intCast(fd),
            .paths = std.ArrayList([]const u8).init(allocator),
            .callback = null,
            .running = false,
            .context = null,
        };
    }

    pub fn deinit(self: *LinuxWatcher) void {
        self.stop();
        self.paths.deinit();
        std.posix.close(self.inotify_fd);
    }

    pub fn addFile(self: *LinuxWatcher, path: []const u8) !void {
        _ = try std.posix.inotify_add_watch(
            self.inotify_fd,
            path,
            std.os.linux.IN.MODIFY,
        );

        try self.paths.append(path);
    }

    pub fn removeFile(self: *LinuxWatcher, path: []const u8) !void {
        for (0.., self.paths.items) |idx, mem_path| {
            if (std.mem.eql(u8, mem_path, path)) {
                std.posix.inotify_rm_watch(self.inotify_fd, @intCast(idx + @intFromBool(idx == self.paths.items.len)));
                _ = self.paths.swapRemove(idx);
                return;
            }
        }
    }

    pub fn setCallback(self: *LinuxWatcher, callback: interfaces.Callback, context: ?*anyopaque) void {
        self.callback = callback;
        self.context = context;
    }

    pub fn start(self: *LinuxWatcher, opts: interfaces.Opts) !void {
        // TODO add polling instead of busy waiting
        if (self.paths.items.len == 0) return error.NoFilesToWatch;

        self.running = true;
        var buffer: [4096]u8 align(@alignOf(std.os.linux.inotify_event)) = undefined;

        while (self.running) {
            const length = std.posix.read(self.inotify_fd, &buffer) catch |err| switch (err) {
                error.WouldBlock => {
                    std.time.sleep(@as(u64, @intFromFloat(@as(f64, opts.latency) * @as(f64, @floatFromInt(std.time.ns_per_s)))));
                    continue;
                },
                else => {
                    return err;
                },
            };

            var ptr: [*]u8 = &buffer;
            const end_ptr = ptr + @as(usize, @intCast(length));

            while (@intFromPtr(ptr) < @intFromPtr(end_ptr)) {
                const ev = @as(*const std.os.linux.inotify_event, @ptrCast(@alignCast(ptr)));
                // Editors like vim create temporary files when saving
                // So we have to re-add the file to the watcher
                if (ev.mask & std.os.linux.IN.IGNORED != 0) {
                    const wd_usize = @as(usize, @intCast(@max(0, ev.wd)));
                    if (wd_usize > self.paths.items.len) {
                        return error.InvalidWatchDescriptor;
                    }
                    // TODO: remove previous buffer
                    try self.addFile(self.paths.items[wd_usize - 1]);
                    if (self.callback) |callback| {
                        callback(self.context, interfaces.Event.modified);
                    }
                } else if (ev.mask & std.os.linux.IN.MODIFY != 0) {
                    if (self.callback) |callback| {
                        callback(self.context, interfaces.Event.modified);
                    }
                }

                ptr = @alignCast(ptr + @sizeOf(std.os.linux.inotify_event) + ev.len);
            }
        }
    }

    pub fn stop(self: *LinuxWatcher) void {
        self.running = false;
    }
};
