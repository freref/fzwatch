pub const Event = struct {
    kind: enum { modified },
    /// the index into `Watcher.paths.items` which this event came from
    item: usize
};
pub const Callback = fn (context: ?*anyopaque, event: Event) void;
pub const Opts = struct { latency: f16 = 1.0 };
