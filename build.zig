// Copyright (C) 2023-2024  Lightpanda (Selecy SAS)
//
// Francis Bouvier <francis@lightpanda.io>
// Pierre Tachoire <pierre@lightpanda.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const builtin = @import("builtin");

const lightpanda_version = std.SemanticVersion.parse(@import("build.zig.zon").version) catch unreachable;
const min_zig_version = std.SemanticVersion.parse(@import("build.zig.zon").minimum_zig_version) catch unreachable;

const Build = blk: {
    if (builtin.zig_version.order(min_zig_version) == .lt) {
        const message = std.fmt.comptimePrint(
            \\Zig version is too old:
            \\  current Zig version: {f}
            \\  minimum Zig version: {f}
        , .{ builtin.zig_version, min_zig_version });
        @compileError(message);
    } else {
        break :blk std.Build;
    }
};

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const prebuilt_v8_path = b.option([]const u8, "prebuilt_v8_path", "Path to prebuilt libc_v8.a");
    const curl_impersonate_archive = b.option([]const u8, "curl_impersonate_archive", "Path to the static curl-impersonate archive") orelse
        return error.CurlImpersonateArchiveRequired;
    const curl_impersonate_include = b.option([]const u8, "curl_impersonate_include", "Path to the curl-impersonate include directory") orelse
        return error.CurlImpersonateIncludeRequired;
    const snapshot_path = b.option([]const u8, "snapshot_path", "Path to v8 snapshot");
    const wpt_extensions = b.option(bool, "wpt_extensions", "Extend WebAPI with WPT driver behavior") orelse false;

    const version = resolveVersion(b);
    std.debug.print("Lightpanda {f}\n", .{version});

    const version_string = b.fmt("{f}", .{version});
    const version_encoded = std.mem.replaceOwned(u8, b.allocator, version_string, "+", "%2B") catch @panic("OOM");

    var opts = b.addOptions();
    opts.addOption([]const u8, "version", version_string);
    opts.addOption([]const u8, "version_encoded", version_encoded);
    opts.addOption(?[]const u8, "snapshot_path", snapshot_path);
    opts.addOption(bool, "wpt_extensions", wpt_extensions);

    const enable_tsan = b.option(bool, "tsan", "Enable Thread Sanitizer") orelse false;
    const enable_asan = b.option(bool, "asan", "Enable Address Sanitizer") orelse false;
    const enable_csan = b.option(std.zig.SanitizeC, "csan", "Enable C Sanitizers");

    const lightpanda_module = blk: {
        const mod = b.addModule("lightpanda", .{
            .root_source_file = b.path("src/lightpanda.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
            .sanitize_c = enable_csan,
            .sanitize_thread = enable_tsan,
        });
        mod.addImport("lightpanda", mod); // allow circular "lightpanda" import
        mod.addImport("build_config", opts.createModule());

        // Format check
        const fmt_step = b.step("fmt", "Check code formatting");
        const fmt = b.addFmt(.{
            .paths = &.{ "src", "build.zig", "build.zig.zon" },
            .check = true,
        });
        fmt_step.dependOn(&fmt.step);

        // Set default behavior
        b.default_step.dependOn(fmt_step);

        try linkV8(b, mod, enable_asan, enable_tsan, prebuilt_v8_path);
        try linkCurl(b, mod, curl_impersonate_archive, curl_impersonate_include);
        try linkHtml5Ever(b, mod);
        linkZenai(b, mod);
        linkIsocline(b, mod);

        break :blk mod;
    };

    linkSqlite(b, lightpanda_module, enable_csan, enable_tsan);

    // Check compilation
    const check = b.step("check", "Check if lightpanda compiles");

    const check_lib = b.addLibrary(.{
        .name = "lightpanda_check",
        .root_module = lightpanda_module,
    });
    check.dependOn(&check_lib.step);

    // Extras (snapshot_creator) are off the default install to
    // avoid paying for three exe compiles on every edit. Build explicitly
    // with `zig build extras`.
    const extras_step = b.step("extras", "Build snapshot_creator");

    {
        // browser
        const exe = b.addExecutable(.{
            .name = "lightpanda",
            .use_llvm = true,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .sanitize_c = enable_csan,
                .sanitize_thread = enable_tsan,
                .imports = &.{
                    .{ .name = "lightpanda", .module = lightpanda_module },
                },
            }),
        });
        b.installArtifact(exe);

        const exe_check = b.addLibrary(.{
            .name = "lightpanda_exe_check",
            .root_module = exe.root_module,
        });
        check.dependOn(&exe_check.step);

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const version_info_step = b.step("version", "Print the resolved version information");
        const version_info_run = b.addRunArtifact(exe);
        version_info_run.addArg("version");
        version_info_step.dependOn(&version_info_run.step);
    }

    {
        // snapshot creator
        const exe = b.addExecutable(.{
            .name = "lightpanda-snapshot-creator",
            .use_llvm = true,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main_snapshot_creator.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "lightpanda", .module = lightpanda_module },
                },
            }),
        });
        extras_step.dependOn(&b.addInstallArtifact(exe, .{}).step);

        const exe_check = b.addLibrary(.{
            .name = "snapshot_creator_check",
            .root_module = exe.root_module,
        });
        check.dependOn(&exe_check.step);

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("snapshot_creator", "Generate a v8 snapshot");
        run_step.dependOn(&run_cmd.step);
    }

    {
        // skills generator
        const exe = b.addExecutable(.{
            .name = "lightpanda-skills",
            .use_llvm = true,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main_skills.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "lightpanda", .module = lightpanda_module },
                },
            }),
        });

        const exe_check = b.addLibrary(.{
            .name = "skills_check",
            .root_module = exe.root_module,
        });
        check.dependOn(&exe_check.step);

        const run_cmd = b.addRunArtifact(exe);
        const out_dir = run_cmd.addOutputDirectoryArg("skills");
        const install = b.addInstallDirectory(.{
            .source_dir = out_dir,
            .install_dir = .prefix,
            .install_subdir = "skills",
        });
        const skills_step = b.step("skills", "Generate LLM skill docs (zig-out/skills/<name>/SKILL.md)");
        skills_step.dependOn(&install.step);
    }

    {
        // test
        const tests = b.addTest(.{
            .root_module = lightpanda_module,
            .use_llvm = true,
            .test_runner = .{ .path = b.path("src/test_runner.zig"), .mode = .simple },
        });
        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_tests.step);
    }
}

fn linkV8(
    b: *Build,
    mod: *Build.Module,
    is_asan: bool,
    is_tsan: bool,
    prebuilt_v8_path: ?[]const u8,
) !void {
    const target = mod.resolved_target.?;

    const dep = b.dependency("v8", .{
        .target = target,
        .optimize = mod.optimize.?,
        .is_asan = is_asan,
        .is_tsan = is_tsan,
        .inspector_subtype = false,
        .v8_enable_sandbox = is_tsan,
        .cache_root = b.pathFromRoot(".lp-cache"),
        .prebuilt_v8_path = prebuilt_v8_path,
    });
    mod.addImport("v8", dep.module("v8"));
}

fn linkHtml5Ever(b: *Build, mod: *Build.Module) !void {
    const is_debug = if (mod.optimize.? == .Debug) true else false;

    const exec_cargo = b.addSystemCommand(&.{
        "cargo",           "build",
        "--profile",       if (is_debug) "dev" else "release",
        "--features",      if (is_debug) "memstats" else "",
        "--manifest-path", "src/html5ever/Cargo.toml",
    });

    // Track Rust sources so edits invalidate the cargo step's cache.
    // Without this, Zig keys the step on argv only and won't re-run cargo
    // when lib.rs/Cargo.toml change.
    for ([_][]const u8{
        "src/html5ever/Cargo.toml",
        "src/html5ever/Cargo.lock",
        "src/html5ever/lib.rs",
        "src/html5ever/sink.rs",
        "src/html5ever/types.rs",
        "src/html5ever/url.rs",
    }) |path| {
        exec_cargo.addFileInput(b.path(path));
    }

    // TODO: We can prefer `--artifact-dir` once it become stable.
    const out_dir = exec_cargo.addPrefixedOutputDirectoryArg("--target-dir=", "html5ever");

    const html5ever_step = b.step("html5ever", "Install html5ever dependency (requires cargo)");
    html5ever_step.dependOn(&exec_cargo.step);

    const obj = out_dir.path(b, if (is_debug) "debug" else "release").path(b, "liblitefetch_html5ever.a");
    mod.addObjectFile(obj);
}

fn linkSqlite(b: *Build, mod: *Build.Module, enable_csan: ?std.zig.SanitizeC, is_tsan: bool) void {
    const dep = b.dependency("sqlite3", .{
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
    });

    const lib = dep.artifact("sqlite3");
    lib.root_module.sanitize_c = enable_csan;
    lib.root_module.sanitize_thread = is_tsan;

    const macros = [_]struct { []const u8, []const u8 }{
        .{ "SQLITE_DEFAULT_FILE_PERMISSIONS", "0600" },
        .{ "SQLITE_DEFAULT_MEMSTATUS", "0" },
        .{ "SQLITE_DEFAULT_WAL_SYNCHRONOUS", "1" },
        .{ "SQLITE_DQS", "0" },
        .{ "SQLITE_ENABLE_API_ARMOR", "1" },
        .{ "SQLITE_ENABLE_UNLOCK_NOTIFY", "1" },
        .{ "SQLITE_TEMP_STORE", "3" },
        .{ "SQLITE_THREADSAFE", "1" },
        .{ "SQLITE_UNTESTABLE", "1" },
        .{ "SQLITE_USE_ALLOCA", "1" },
        .{ "SQLITE_OMIT_AUTHORIZATION", "1" },
        .{ "SQLITE_OMIT_AUTOMATIC_INDEX", "1" },
        .{ "SQLITE_OMIT_AUTORESET", "1" },
        .{ "SQLITE_OMIT_AUTOVACUUM", "1" },
        .{ "SQLITE_OMIT_BETWEEN_OPTIMIZATION", "1" },
        .{ "SQLITE_OMIT_CASE_SENSITIVE_LIKE_PRAGMA", "1" },
        .{ "SQLITE_OMIT_COMPLETE", "1" },
        .{ "SQLITE_OMIT_DECLTYPE", "1" },
        .{ "SQLITE_OMIT_DEPRECATED", "1" },
        .{ "SQLITE_OMIT_DESERIALIZE", "1" },
        .{ "SQLITE_OMIT_GET_TABLE", "1" },
        .{ "SQLITE_OMIT_INCRBLOB", "1" },
        .{ "SQLITE_OMIT_JSON", "1" },
        .{ "SQLITE_OMIT_LIKE_OPTIMIZATION", "1" },
        .{ "SQLITE_OMIT_LOAD_EXTENSION", "1" },
        .{ "SQLITE_OMIT_PROGRESS_CALLBACK", "1" },
        .{ "SQLITE_OMIT_SHARED_CACHE", "1" },
        .{ "SQLITE_OMIT_TCL_VARIABLE", "1" },
        .{ "SQLITE_OMIT_TEMPDB", "1" },
        .{ "SQLITE_OMIT_TRACE", "1" },
        .{ "SQLITE_OMIT_UTF16", "1" },
        .{ "SQLITE_OMIT_XFER_OPT", "1" },
    };
    for (macros) |m| {
        lib.root_module.addCMacro(m[0], m[1]);
    }

    mod.linkLibrary(lib);

    const translate_c = b.addTranslateC(.{
        .root_source_file = lib.getEmittedIncludeTree().path(b, "sqlite3.h"),
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
    });
    mod.addImport("sqlite3", translate_c.createModule());
}

fn linkCurl(
    b: *Build,
    mod: *Build.Module,
    curl_impersonate_archive: []const u8,
    curl_impersonate_include: []const u8,
) !void {
    const target = mod.resolved_target.?;

    mod.addObjectFile(.{ .cwd_relative = curl_impersonate_archive });

    const translate_c = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ curl_impersonate_include, "curl/curl.h" }) },
        .target = target,
        .optimize = mod.optimize.?,
    });
    translate_c.addIncludePath(.{ .cwd_relative = curl_impersonate_include });
    mod.addImport("curl", translate_c.createModule());

    switch (target.result.os.tag) {
        .macos => {
            // needed for proxying on mac
            mod.addSystemFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });
            mod.linkFramework("CoreFoundation", .{});
            mod.linkFramework("CoreServices", .{});
            mod.linkFramework("SystemConfiguration", .{});
            mod.linkSystemLibrary("icucore", .{ .use_pkg_config = .no });
            mod.linkSystemLibrary("iconv", .{ .use_pkg_config = .no });
        },
        else => {},
    }
}

fn linkZenai(b: *Build, mod: *Build.Module) void {
    const dep = b.dependency("zenai", .{});
    mod.addImport("zenai", dep.module("zenai"));
}

fn linkIsocline(b: *Build, mod: *Build.Module) void {
    const dep = b.dependency("isocline", .{});
    mod.addIncludePath(dep.path("include"));
    mod.addCSourceFile(.{
        .file = dep.path("src/isocline.c"),
    });

    const translate_c = b.addTranslateC(.{
        .root_source_file = dep.path("include/isocline.h"),
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
    });
    mod.addImport("isocline", translate_c.createModule());
}

/// Resolves the semantic version of the build.
///
/// The base version is read from `build.zig.zon`. This can be overridden
/// using the `-Dversion` command-line flag:
/// - If the flag contains a full semantic version (e.g., `1.2.3`), it replaces
///   the base version entirely.
/// - If the flag contains a simple string (e.g., `nightly`), it replaces only
///   the pre-release tag of the base version (e.g., `1.0.0-dev` -> `1.0.0-nightly`).
///
/// For versions that have a pre-release tag and no explicit build metadata,
/// this function automatically enriches the version with the git commit count
/// and short hash (e.g., `1.0.0-dev.5243+dbe45229`).
fn resolveVersion(b: *std.Build) std.SemanticVersion {
    const opt_version = b.option([]const u8, "version", "Override the version of this build");

    const version = if (opt_version) |v|
        std.SemanticVersion.parse(v) catch blk: {
            var fallback = lightpanda_version;
            fallback.pre = v;
            break :blk fallback;
        }
    else
        lightpanda_version;

    // Only enrich versions that have a pre-release field and no explicit build metadata.
    if (version.pre == null or version.build != null) return version;

    // For dev/nightly versions, calculate the commit count and hash
    const git_hash_raw = runGit(b, &.{ "rev-parse", "--short", "HEAD" }) catch return version;
    const commit_hash = std.mem.trim(u8, git_hash_raw, " \n\r");

    const git_count_raw = runGit(b, &.{ "rev-list", "--count", "HEAD" }) catch return version;
    const commit_count = std.mem.trim(u8, git_count_raw, " \n\r");

    return .{
        .major = version.major,
        .minor = version.minor,
        .patch = version.patch,
        .pre = b.fmt("{s}.{s}", .{ version.pre.?, commit_count }),
        .build = commit_hash,
    };
}

/// Helper function to run git commands and return stdout
fn runGit(b: *std.Build, args: []const []const u8) ![]const u8 {
    var code: u8 = undefined;
    const dir = b.pathFromRoot(".");
    var command: std.ArrayList([]const u8) = .empty;
    defer command.deinit(b.allocator);
    try command.appendSlice(b.allocator, &.{ "git", "-C", dir });
    try command.appendSlice(b.allocator, args);
    return b.runAllowFail(command.items, &code, .ignore);
}
