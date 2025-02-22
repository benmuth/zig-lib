const std = @import("std");
const metrics = @import("metrics");
const builtin = @import("builtin");
const Instant = std.time.Instant;

const windows = std.os.windows;
const posix = std.posix;
pub fn main() !void {
    // listing 73
    var args = std.process.args();
    _ = args.skip();
    const ms_to_wait_str = args.next() orelse "1_000";
    const ms_to_wait = try std.fmt.parseInt(u64, ms_to_wait_str, 10);

    const os_freq = metrics.getOSTimerFreq();
    std.debug.print("\n\tOS Freq: {d}\n", .{os_freq});

    const cpu_start = metrics.readCPUTimer();
    const os_start = metrics.readOSTimer();
    var os_end: u64 = 0;
    var os_elapsed: u64 = 0;
    const os_wait_time = os_freq * ms_to_wait / 1000;
    while (os_elapsed < os_wait_time) {
        os_end = metrics.readOSTimer();
        os_elapsed = os_end - os_start;
    }

    const cpu_end = metrics.readCPUTimer();
    const cpu_elapsed = cpu_end - cpu_start;
    const cpu_freq = os_freq * cpu_elapsed / os_elapsed;

    std.debug.print("\tOS Timer: {d} -> {d} = {d} elapsed\n", .{ os_start, os_end, os_elapsed });
    std.debug.print(" OS Seconds: {d:.4}\n", .{@as(f64, @floatFromInt(os_elapsed)) / @as(f64, @floatFromInt(os_freq))});

    std.debug.print("  CPU Timer: {d} -> {d} = {d} elapsed\n", .{ cpu_start, cpu_end, cpu_elapsed });
    std.debug.print("\tCPU Freq: {d:.4} (guessed)\n", .{cpu_freq});

    const clock_id = switch (builtin.os.tag) {
        .windows => {
            // QPC on windows doesn't fail on >= XP/2000 and includes time suspended.
            return Instant{ .timestamp = windows.QueryPerformanceCounter() };
        },
        .wasi => {
            var ns: std.os.wasi.timestamp_t = undefined;
            const rc = std.os.wasi.clock_time_get(.MONOTONIC, 1, &ns);
            if (rc != .SUCCESS) return error.Unsupported;
            return .{ .timestamp = ns };
        },
        .uefi => {
            var value: std.os.uefi.Time = undefined;
            const status = std.os.uefi.system_table.runtime_services.getTime(&value, null);
            if (status != .Success) return error.Unsupported;
            return Instant{ .timestamp = value.toEpoch() };
        },
        // On darwin, use UPTIME_RAW instead of MONOTONIC as it ticks while
        // suspended.
        .macos, .ios, .tvos, .watchos, .visionos => posix.CLOCK.UPTIME_RAW,
        // On freebsd derivatives, use MONOTONIC_FAST as currently there's
        // no precision tradeoff.
        .freebsd, .dragonfly => posix.CLOCK.MONOTONIC_FAST,
        // On linux, use BOOTTIME instead of MONOTONIC as it ticks while
        // suspended.
        .linux => posix.CLOCK.BOOTTIME,
        // On other posix systems, MONOTONIC is generally the fastest and
        // ticks while suspended.
        else => posix.CLOCK.MONOTONIC,
    };

    var ts: std.posix.timespec = .{ .tv_sec = 0, .tv_nsec = 0 };
    try std.posix.clock_getres(clock_id, &ts);

    std.debug.print("{d} res: s: {d}; ns: {d}\n", .{ clock_id, ts.tv_sec, ts.tv_nsec });

    posix.clock_gettime(clock_id, &ts) catch return error.Unsupported;
    std.debug.print("{d} time: s: {d}; ns: {d}\n", .{ clock_id, ts.tv_sec, ts.tv_nsec });

    for (1..8) |id_idx| {
        const id: i32 = @intCast(id_idx);
        std.posix.clock_getres(id, &ts) catch continue;
        std.debug.print("{d} res: s: {d}; ns: {d}\n", .{ id, ts.tv_sec, ts.tv_nsec });
        posix.clock_gettime(id, &ts) catch return error.Unsupported;
        std.debug.print("{d} time before: s: {d}; ns: {d}\n", .{ (id), ts.tv_sec, ts.tv_nsec });

        std.time.sleep(12345);

        posix.clock_gettime(id, &ts) catch return error.Unsupported;
        std.debug.print("{d} time after: s: {d}; ns: {d}\n", .{ id, ts.tv_sec, ts.tv_nsec });
    }
}
