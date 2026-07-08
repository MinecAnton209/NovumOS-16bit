const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Codegen tool: comptime firmware -> build/firmware.bin
    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codegen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(codegen_exe);

    // zig build firmware
    const run_codegen = b.addRunArtifact(codegen_exe);

    const firmware_step = b.step("firmware", "Generate build/firmware.bin");
    firmware_step.dependOn(&run_codegen.step);
    run_codegen.step.dependOn(b.getInstallStep());

    // zig build test
    const codegen_tests = b.addTest(.{
        .root_module = codegen_exe.root_module,
    });
    const run_codegen_tests = b.addRunArtifact(codegen_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_codegen_tests.step);
}
