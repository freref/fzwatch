const std = @import("std");

const Event = @import("interfaces.zig").Event;
const Callback = @import("interfaces.zig").Callback;
const c = @cImport({
    @cInclude("sys/inotify.h");
});

pub const Opts = struct {
    latency: f16 = 1.0,
};

pub const LinuxWatcher = struct {
    allocator: std.mem.Allocator,
    // XXX hold the files as []u8 so we don't need to convert twice?
    files: std.ArrayList([]const u8),
    stream: i32,
    callback: ?*const Callback,
    running: bool,
    context: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) !LinuxWatcher {
        return LinuxWatcher{
            .allocator = allocator,
            .files = std.ArrayList([]const u8).init(allocator),
            .stream = -1,
            .callback = null,
            .running = false,
            .context = null,
        };
    }

    pub fn deinit(self: *LinuxWatcher) void {
        if (self.stream == -1) try self.stop();
        for (self.files.items) |file| {
            c.CFRelease(file);
        }
        self.files.deinit();
    }

    pub fn addFile(self: *LinuxWatcher, path: []const u8) !void {
        try self.files.append(path);
    }

    pub fn removeFile(self: *LinuxWatcher, path: []const u8) !void {
        defer c.CFRelease(path);

        for (self.files.items, 0..) |file, index| {
            if ((file == path)) {
                c.CFRelease(file);
                _ = self.files.orderedRemove(index);
                break;
            }
        }
    }

    pub fn setCallback(self: *LinuxWatcher, callback: Callback, context: ?*anyopaque) void {
        self.callback = callback;
        self.context = context;
    }

    fn fsEventsCallback(
        stream: c.ConstFSEventStreamRef,
        info: ?*anyopaque,
        numEvents: usize,
        eventPaths: ?*anyopaque,
        eventFlags: [*c]const c.FSEventStreamEventFlags,
        eventIds: [*c]const c.FSEventStreamEventId,
    ) callconv(.C) void {
        _ = stream;
        _ = eventPaths;
        _ = eventIds;

        const self = @as(*LinuxWatcher, @ptrCast(@alignCast(info.?)));

        var i: usize = 0;
        while (i < numEvents) : (i += 1) {
            const flags = eventFlags[i];
            if (flags & c.kFSEventStreamEventFlagItemModified != 0) {
                self.callback.?(self.context, Event.modified);
            }
        }
    }

    pub fn start(self: *LinuxWatcher, opts: Opts) !void {
        if (self.files.items.len == 0) return error.NoFilesToWatch;

        const files = std.ArrayList([]const u8).init(self.allocator);
        defer files.deinit();
        _ = opts;

        // var context = c.FSEventStreamContext{
        //     .version = 0,
        //     .info = self,
        //     .retain = null,
        //     .release = null,
        //     .copyDescription = null,
        // };

        // stream is now a queue of events.
        self.stream = c.inotify_init1(c.IN_NONBLOCK);
        if (self.stream == -1) return error.StreamCreateFailed;

        var watch_descriptors = try std.heap.page_allocator.alloc(i32, self.files.items.len);
        defer watch_descriptors.deinit();

        for (self.files.items, 0..) |file, index| {
            watch_descriptors[index] = c.inotify_add_watch(self.stream, file, c.IN_MODIFY);
            if (watch_descriptors[index] == -1) {
                return error.StreamStartFailed;
            }
        }

        c.FSEventStreamScheduleWithRunLoop(
            self.stream.?,
            c.CFRunLoopGetCurrent(),
            c.kCFRunLoopDefaultMode,
        );

        if (c.FSEventStreamStart(self.stream.?) == 0) {
            try self.stop();
            return error.StreamStartFailed;
        }

        self.running = true;

        while (self.running) {
            _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0, 1);
        }
    }

    pub fn stop(self: *LinuxWatcher) !void {
        self.running = false;
        if (self.stream) |stream| {
            c.FSEventStreamStop(stream);
            c.FSEventStreamInvalidate(stream);
            c.FSEventStreamRelease(stream);
            self.stream = null;
        }
    }
};
