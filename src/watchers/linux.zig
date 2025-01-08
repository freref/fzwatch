const std = @import("std");
const interfaces = @import("interfaces.zig");

pub const LinuxWatcher = struct {
    allocator: std.mem.Allocator,
    paths: std.ArrayList([]const u8),
    inotify: struct {
        fd: i32,
        /// inotify wd offset from removing files
        offset: usize,
        /// the old watch descriptors that would have a lower wd than `offset`
        /// making them unsafe to normally check. by keeping them here we know that
        /// these specific low wd's are safe
        /// maps wd to offset at the time of population
        old: std.AutoHashMap(i32, i32)
    },
    callback: ?*const interfaces.Callback,
    running: bool,
    context: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) !LinuxWatcher {
        const fd = try std.posix.inotify_init1(std.os.linux.IN.NONBLOCK);
        errdefer std.posix.close(fd);

        return LinuxWatcher{
            .allocator = allocator,
            .paths = std.ArrayList([]const u8).init(allocator),
            .inotify = .{
                .fd = @intCast(fd),
                .offset     = 1,
                .old        = std.AutoHashMap(i32, i32).init(allocator)
            },
            .callback = null,
            .running = false,
            .context = null,
        };
    }

    pub fn deinit(self: *LinuxWatcher) void {
        self.stop();
        self.paths.deinit();
        self.inotify.old.deinit();
        std.posix.close(self.inotify.fd);
    }

    pub fn addFile(self: *LinuxWatcher, path: []const u8) !void {
        const wd = try std.posix.inotify_add_watch(
            self.inotify.fd,
            path,
            std.os.linux.IN.MODIFY,
        );

        try self.inotify.old.putNoClobber(wd, @intCast(self.inotify.offset));

        try self.paths.append(path);
    }

    pub fn removeFile(self: *LinuxWatcher, path: []const u8) !void {
        for (0.., self.paths.items) |idx, mem_path| {
            if (!std.mem.eql(u8, mem_path, path))
                continue;

            _ = std.posix.inotify_rm_watch(self.inotify.fd, @intCast(idx + self.inotify.offset));
            self.inotify.offset += 1;
            _ = self.paths.orderedRemove(idx);

            // self.inotify.old.clearRetainingCapacity();
            // for(0..idx) |i| try self.inotify.old.putNoClobber(@intCast(i), 0);

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
            const length = std.posix.read(self.inotify.fd, std.mem.sliceAsBytes(&buffer)) catch |err| switch (err) {
                error.WouldBlock => {
                    std.time.sleep(@as(u64, @intFromFloat(@as(f64, opts.latency) * @as(f64, @floatFromInt(std.time.ns_per_s)))));
                    continue;
                },
                else => {
                    return err;
                },
            };

            // in bytes
            var i: usize = 0;
            while (i < length) : (i += buffer[i].len + @sizeOf(std.os.linux.inotify_event)) {
                const ev = buffer[i];
                if(ev.wd < self.inotify.offset) {
                    try if(self.inotify.old.get(ev.wd)) |offset| {
                        std.log.info("{d}, {d}", .{offset, ev.wd});
                        try self.addFile(self.paths.items[@intCast(ev.wd - offset)]);
                    }
                    else if(ev.wd == 0) {continue;}
                    else error.InvalidWatchDescriptor;
                } else if (ev.wd > self.paths.items.len + self.inotify.offset)
                    return error.InvalidWatchDescriptor;

                const index = @as(usize, @intCast(@max(0, ev.wd))) - self.inotify.offset;
                // Editors like vim create temporary files when saving
                // So we have to re-add the file to the watcher
                if (ev.mask & std.os.linux.IN.IGNORED == 0 and ev.mask & std.os.linux.IN.MODIFY == 0)
                    continue;

                if(ev.mask & std.os.linux.IN.IGNORED != 0)
                    try self.addFile(self.paths.items[index]);
                if (self.callback) |callback| callback(self.context, .{
                    .kind = .modified,
                    .item = index
                });
            }
        }
    }

    pub fn stop(self: *LinuxWatcher) void {
        self.running = false;
    }
};
