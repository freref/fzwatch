# fzwatch
A lightweight and cross-platform file watcher for your Zig projects.
> [!NOTE]  
> This project exists to support [fancy-cat](https://github.com/freref/fancy-cat) and has limited features.

## Usage
A basic example can be found under [examples](./examples/basic.zig). The API is defined as follows:
```zig
pub const Event = enum { modified };
pub const Callback = fn (event: Event, context: *anyopaque) void;

pub fn init(allocator: std.mem.Allocator) !MacosWatcher;
pub fn deinit(self: *MacosWatcher) void;
pub fn addFile(self: *MacosWatcher, path: []const u8) !void;
pub fn removeFile(self: *MacosWatcher, path: []const u8) !void;
pub fn setCallback(self: *MacosWatcher, callback: Callback) void;
pub fn start(self: *MacosWatcher) !void;
pub fn stop(self: *MacosWatcher) !void;
````
