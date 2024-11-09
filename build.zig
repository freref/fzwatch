const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "fzwatch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (target.result.os.tag == .macos) {
        lib.linkFramework("CoreServices");
    }

    lib.linkLibC();

    const module = b.addModule("fzwatch", .{
        .root_source_file = b.path("src/main.zig"),
    });

    module.linkLibrary(lib);

    // Basic example
    const basic = b.addExecutable(.{
        .name = "fzwatch-example",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    basic.root_module.addImport("fzwatch", module);

    const run_cmd = b.addRunArtifact(basic);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run-basic", "Run the example");
    run_step.dependOn(&run_cmd.step);

    // Context example
    const context = b.addExecutable(.{
        .name = "fzwatch-context",
        .root_source_file = b.path("examples/context.zig"),
        .target = target,
        .optimize = optimize,
    });
    context.root_module.addImport("fzwatch", module);

    const run_cmd_context = b.addRunArtifact(context);
    run_cmd_context.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd_context.addArgs(args);
    }
    const run_step_context = b.step("run-context", "Run the example");
    run_step_context.dependOn(&run_cmd_context.step);

    b.installArtifact(lib);
}
