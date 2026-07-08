const std = @import("std");

/// Build configuration for NovumOS-16bit.
///
/// Provides 3 build steps:
///   zig build firmware  — compile comptime firmware → build/firmware.bin
///   zig build emulate   — run CPU emulator (loads firmware.bin from disk)
///   zig build test      — run all unit tests (codegen + emulator)
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // =========================================================================
    // Codegen tool — generates firmware binary from comptime ISA.encode functions
    // =========================================================================
    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codegen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(codegen_exe);

    // `zig build firmware` — run codegen tool to produce build/firmware.bin
    const run_codegen = b.addRunArtifact(codegen_exe);

    const firmware_step = b.step("firmware", "Generate build/firmware.bin");
    firmware_step.dependOn(&run_codegen.step);
    run_codegen.step.dependOn(b.getInstallStep());

    // =========================================================================
    // Emulator — loads firmware.bin and executes it on the virtual CPU
    // =========================================================================
    const emulator_exe = b.addExecutable(.{
        .name = "emulator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/emulator/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // Import codegen module so emulator can use ISA.encode functions
                // (needed by CPU instruction decoding in cpu.zig)
                .{ .name = "codegen", .module = codegen_exe.root_module },
            },
        }),
    });
    b.installArtifact(emulator_exe);

    // `zig build emulate` — run the emulator (reads build/firmware.bin at runtime)
    const run_emulator = b.addRunArtifact(emulator_exe);
    const emulate_step = b.step("emulate", "Run emulator");
    emulate_step.dependOn(&run_emulator.step);
    run_emulator.step.dependOn(b.getInstallStep());

    // =========================================================================
    // Tests — codegen encoding tests + emulator CPU tests
    // =========================================================================

    // Codegen tests: verify ISA encoding functions (encode16, encode32, encodeAlu, etc.)
    const codegen_tests = b.addTest(.{
        .root_module = codegen_exe.root_module,
    });
    const run_codegen_tests = b.addRunArtifact(codegen_tests);

    // Emulator tests: verify CPU instruction execution (32 tests total)
    const emulator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/emulator/test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "codegen", .module = codegen_exe.root_module },
            },
        }),
    });
    const run_emulator_tests = b.addRunArtifact(emulator_tests);

    // `zig build test` — run both codegen and emulator test suites
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_codegen_tests.step);
    test_step.dependOn(&run_emulator_tests.step);
}
