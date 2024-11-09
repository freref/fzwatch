pub const Event = enum { modified };
pub const Callback = fn (context: ?*anyopaque, event: Event) void;
pub const Opts = struct { latency: f16 = 1.0 };
