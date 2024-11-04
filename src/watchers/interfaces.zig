pub const Event = enum { modified };
pub const Callback = fn (event: Event) void;
