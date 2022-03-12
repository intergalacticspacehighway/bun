const std = @import("std");
const Environment = @import("./env.zig");

const Output = @import("output.zig");
const use_mimalloc = @import("./global.zig").use_mimalloc;
const StringTypes = @import("./string_types.zig");

pub const build_id = std.fmt.parseInt(u64, std.mem.trim(u8, @embedFile("../build-id"), "\n \r\t"), 10) catch unreachable;
pub const package_json_version = if (Environment.isDebug)
    std.fmt.comptimePrint("0.0.{d}_debug", .{build_id})
else
    std.fmt.comptimePrint("0.0.{d}", .{build_id});
pub const os_name = if (Environment.isWindows)
    "win32"
else if (Environment.isMac)
    "darwin"
else if (Environment.isLinux)
    "linux"
else if (Environment.isWasm)
    "wasm"
else
    "unknown";

pub const arch_name = if (Environment.isX64)
    "x64"
else if (Environment.isAarch64)
    "arm64"
else
    "unknown";

pub inline fn getStartTime() i128 {
    if (Environment.isTest) return 0;
    return @import("root").start_time;
}

pub fn setThreadName(name: StringTypes.stringZ) void {
    if (Environment.isLinux) {
        _ = std.os.prctl(.SET_NAME, .{@ptrToInt(name.ptr)}) catch 0;
    } else if (Environment.isMac) {
        _ = std.c.pthread_setname_np(name);
    }
}

pub fn exit(code: u8) noreturn {
    Output.flush();
    std.os.exit(code);
}

pub const AllocatorConfiguration = struct {
    verbose: bool = false,
    long_running: bool = false,
};

pub inline fn mimalloc_cleanup(force: bool) void {
    if (comptime use_mimalloc) {
        const Mimalloc = @import("./allocators/mimalloc.zig");
        Mimalloc.mi_collect(force);
    }
}
pub const versions = @import("./generated_versions_list.zig");

// Enabling huge pages slows down bun by 8x or so
// Keeping this code for:
// 1. documentation that an attempt was made
// 2. if I want to configure allocator later
pub inline fn configureAllocator(_: AllocatorConfiguration) void {
    // if (comptime !use_mimalloc) return;
    // const Mimalloc = @import("./allocators/mimalloc.zig");
    // Mimalloc.mi_option_set_enabled(Mimalloc.mi_option_verbose, config.verbose);
    // Mimalloc.mi_option_set_enabled(Mimalloc.mi_option_large_os_pages, config.long_running);
    // if (!config.long_running) Mimalloc.mi_option_set(Mimalloc.mi_option_reset_delay, 0);
}

pub fn panic(comptime fmt: string, args: anytype) noreturn {
    @setCold(true);
    if (comptime Environment.isWasm) {
        Output.printErrorln(fmt, args);
        Output.flush();
        @panic(fmt);
    } else {
        Output.prettyErrorln(fmt, args);
        Output.flush();
        std.debug.panic(fmt, args);
    }
}

// std.debug.assert but happens at runtime
pub fn invariant(condition: bool, comptime fmt: string, args: anytype) void {
    if (!condition) {
        _invariant(fmt, args);
    }
}

inline fn _invariant(comptime fmt: string, args: anytype) noreturn {
    @setCold(true);

    if (comptime Environment.isWasm) {
        Output.printErrorln(fmt, args);
        Output.flush();
        @panic(fmt);
    } else {
        Output.prettyErrorln(fmt, args);
        Output.flush();
        Global.exit(1);
    }
}

pub fn notimpl() noreturn {
    @setCold(true);
    Global.panic("Not implemented yet!!!!!", .{});
}

// Make sure we always print any leftover
pub fn crash() noreturn {
    @setCold(true);
    Output.flush();
    Global.exit(1);
}

const Global = @This();
const string = @import("./global.zig").string;