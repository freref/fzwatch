const std = @import("std");
const darwin = std.os.darwin;
const interfaces = @import("interfaces.zig");
const c = @cImport({
    @cInclude("CoreServices/CoreServices.h");
});

pub const MacosWatcher = struct {
    allocator: std.mem.Allocator,
    // XXX hold the files as []u8 so we don't need to convert twice?
    files: std.ArrayList(c.CFStringRef),
    stream: c.FSEventStreamRef,
    callback: ?*const interfaces.Callback,
    running: bool,
    context: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) !MacosWatcher {
        return MacosWatcher{
            .allocator = allocator,
            .files = std.ArrayList(c.CFStringRef).empty,
            .stream = null,
            .callback = null,
            .running = false,
            .context = null,
        };
    }

    pub fn deinit(self: *MacosWatcher) void {
        if (self.stream != null) self.stop();
        for (self.files.items) |file| {
            c.CFRelease(file);
        }
        self.files.deinit(self.allocator);
    }

    pub fn addFile(self: *MacosWatcher, path: []const u8) !void {
        const file = c.CFStringCreateWithBytes(
            null,
            path.ptr,
            @as(c_long, @intCast(path.len)),
            c.kCFStringEncodingUTF8,
            0,
        );

        try self.files.append(self.allocator, file);
    }

    pub fn removeFile(self: *MacosWatcher, path: []const u8) !void {
        const target = c.CFStringCreateWithBytes(
            null,
            path.ptr,
            @as(c_long, @intCast(path.len)),
            c.kCFStringEncodingUTF8,
            0,
        );
        defer c.CFRelease(target);

        for (self.files.items, 0..) |file, index| {
            if (c.CFStringCompare(file, target, 0) == 0) {
                c.CFRelease(file);
                _ = self.files.orderedRemove(self.allocator, index);
                break;
            }
        }
    }

    pub fn setCallback(self: *MacosWatcher, callback: interfaces.Callback, context: ?*anyopaque) void {
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
    ) callconv(.c) void {
        _ = stream;
        _ = eventPaths;
        _ = eventIds;

        const self = @as(*MacosWatcher, @ptrCast(@alignCast(info.?)));

        var i: usize = 0;
        while (i < numEvents) : (i += 1) {
            const flags = eventFlags[i];
            if (flags & c.kFSEventStreamEventFlagItemModified != 0) {
                self.callback.?(self.context, .modified);
            }
        }
    }

    pub fn start(self: *MacosWatcher, opts: interfaces.Opts) !void {
        if (self.files.items.len == 0) return error.NoFilesToWatch;

        const files = c.CFArrayCreate(
            null,
            @as([*c]?*const anyopaque, @ptrCast(self.files.items.ptr)),
            @as(c_long, @intCast(self.files.items.len)),
            &c.kCFTypeArrayCallBacks,
        );
        defer c.CFRelease(files);

        var context = c.FSEventStreamContext{
            .version = 0,
            .info = self,
            .retain = null,
            .release = null,
            .copyDescription = null,
        };

        self.stream = c.FSEventStreamCreate(
            null,
            fsEventsCallback,
            &context,
            files,
            c.kFSEventStreamEventIdSinceNow,
            opts.latency,
            c.kFSEventStreamCreateFlagFileEvents,
        );

        if (self.stream == null) return error.StreamCreateFailed;

        c.FSEventStreamScheduleWithRunLoop(
            self.stream.?,
            c.CFRunLoopGetCurrent(),
            c.kCFRunLoopDefaultMode,
        );

        if (c.FSEventStreamStart(self.stream.?) == 0) {
            self.stop();
            return error.StreamStartFailed;
        }

        self.running = true;

        while (self.running) {
            _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, opts.latency, 0);
        }
    }

    pub fn stop(self: *MacosWatcher) void {
        self.running = false;
        if (self.stream) |stream| {
            c.FSEventStreamStop(stream);
            c.FSEventStreamInvalidate(stream);
            c.FSEventStreamRelease(stream);
            self.stream = null;
        }
    }
};
