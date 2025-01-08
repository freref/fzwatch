const std = @import("std");
const interfaces = @import("interfaces.zig");

pub const LinuxWatcher = struct {
    allocator: std.mem.Allocator,
    inotify_fd: i32,
    paths: std.ArrayList([]const u8),
    /// inotify wd offset from removing files
    offset: usize,
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
            .offset = 1,
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
            if (!std.mem.eql(u8, mem_path, path))
                continue;

            // need to update wd of all previous files so they are above the offset
            // so we just remove and add them back from inotify watch
            // TODO: 100% better way to do this
            for(0..idx) |i| {
                std.posix.inotify_rm_watch(self.inotify_fd, @intCast(idx + self.offset - i));

                const t = try std.posix.inotify_add_watch(
                    self.inotify_fd,
                    self.paths.items[i],
                    std.os.linux.IN.MODIFY,
                );

                std.log.debug("removed: {d} added {d}", .{idx + self.offset - i, t});
            }

            self.offset += idx;
            std.posix.inotify_rm_watch(self.inotify_fd, @intCast(idx + self.offset));
            self.offset += 1;
            _ = self.paths.orderedRemove(idx);

            return;
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
        var buffer: [4096]std.os.linux.inotify_event = undefined;

        while (self.running) {
            const length = std.posix.read(self.inotify_fd, std.mem.sliceAsBytes(&buffer)) catch |err| switch (err) {
                error.WouldBlock => {
                    std.time.sleep(@as(u64, @intFromFloat(@as(f64, opts.latency) * @as(f64, @floatFromInt(std.time.ns_per_s)))));
                    continue;
                },
                else => {
                    return err;
                },
            };

            var i: usize = 0;
            while (i < length) : (i += buffer[i].len + @sizeOf(std.os.linux.inotify_event)) {
                const ev = buffer[i];
                // Editors like vim create temporary files when saving
                // So we have to re-add the file to the watcher
                if (ev.mask & std.os.linux.IN.IGNORED != 0) {
                    const wd_usize = @as(usize, @intCast(@max(0, ev.wd)));
                    std.log.info("w {d}, l {d}, o {d}", .{wd_usize, self.paths.items.len, self.offset});
                    std.log.info("{d}", .{self.paths.items.len});
                    if(wd_usize == 0) continue;
                    if (wd_usize > self.paths.items.len + self.offset or wd_usize < self.offset)
                        return error.InvalidWatchDescriptor;

                    try self.addFile(self.paths.items[wd_usize - self.offset]);
                    if (self.callback) |callback| {
                        callback(self.context, .{
                            .kind = .modified,
                            .item = wd_usize - self.offset
                        });
                    }
                } else if (ev.mask & std.os.linux.IN.MODIFY != 0) {
                    if (self.callback) |callback| {
                        callback(self.context, .{
                            .kind = .modified,
                            .item = @as(usize, @intCast(ev.wd)) - self.offset
                        });
                    }
                }
            }
        }
    }

    pub fn stop(self: *LinuxWatcher) void {
        self.running = false;
    }
};
