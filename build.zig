const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("fzwatch", .{
        .root_source_file = b.path("src/main.zig"),
    });

    const example = b.addExecutable(.{
        .name = "fzwatch-example",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });

    example.root_module.addImport("fzwatch", module);
    if (target.result.os.tag == .macos) example.linkFramework("CoreServices");

    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
