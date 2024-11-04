pub const FileEvent = enum { modified };
pub const FileCallback = fn (event: FileEvent) void;
