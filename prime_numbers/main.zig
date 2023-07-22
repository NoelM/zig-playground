const std = @import("std");

const Stats = struct { loops: u64, tries: u64, max_tries: u64, duration: i128, max_duration: i128 };

pub fn isPrime(int: u64, stats: *Stats) bool {
    const start = std.time.nanoTimestamp();

    var i: u64 = 2;
    var is_prime = false;
    while (i < int) : (i += 1) {
        if (int % i == 0) break;
    }

    updateStats(stats, i - 2, std.time.nanoTimestamp() - start);
    return is_prime;
}

pub fn updateStats(s: *Stats, tries: u64, duration: i128) void {
    s.loops += 1;

    s.tries += tries;
    s.max_tries = @max(s.max_tries, tries);

    s.duration += duration;
    s.max_duration = @max(s.max_duration, duration);
}

pub fn printAndResetStats(cur_int: u64, s: *Stats) void {
    if (s.loops > 0) {
        const mean_tries: f64 = @intToFloat(f64, s.tries) / @intToFloat(f64, s.loops);
        const mean_duration: f64 = @intToFloat(f64, s.duration) / @intToFloat(f64, s.loops);

        std.debug.print("last_int: {d}, mean_tries: {}, max_tries:{d}, mean_dur_ns:{}, max_dur_ns: {d}\n", .{ cur_int, mean_tries, s.max_tries, mean_duration, s.max_duration });
    }

    s.loops = 0;
    s.tries = 0;
    s.max_tries = 0;
    s.duration = 0;
    s.max_duration = 0;
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile(
        "prime_numbers.txt",
        .{ .read = true },
    );
    defer file.close();

    const alloc = std.heap.page_allocator;

    var stats = Stats{
        .tries = 0,
        .max_tries = 0,
        .loops = 0,
        .duration = 0,
        .max_duration = 0,
    };

    var i: u64 = 1;
    const i_max: u64 = 1_000_000;

    const global_start = std.time.nanoTimestamp();
    while (i < i_max) : (i += 1) {
        if (isPrime(i, &stats)) {
            const prime = try std.fmt.allocPrint(alloc, "{d}\n", .{i});
            defer alloc.free(prime);

            _ = try file.writeAll(prime);
        } else if (i % 1000 == 0) {
            printAndResetStats(i, &stats);
        }
    }
    var global_duration = std.time.nanoTimestamp() - global_start;
    std.debug.print("total duration ms: {d}\n", .{@divTrunc(global_duration, @as(i128, 1000))});
}
