/// Event provides the type of file change and which file was affected via its index
/// in the watcher's file list
pub const Event = struct { kind: enum { modified }, index: usize };
pub const Callback = fn (context: ?*anyopaque, event: Event) void;
pub const Opts = struct { latency: f16 = 1.0 };
