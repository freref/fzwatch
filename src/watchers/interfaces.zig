pub const Event = enum { modified };
pub const Callback = fn (context: ?*anyopaque, event: Event) void;
