pub const Event = enum { modified };
pub const Callback = fn (event: Event, context: *anyopaque) void;
