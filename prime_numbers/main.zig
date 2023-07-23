const std = @import("std");

const Stats = struct { loops: u64, tries: u64, max_tries: u64, duration: i128, max_duration: i128 };

pub fn newStats() Stats {
    return Stats{
        .loops = 0,
        .tries = 0,
        .max_tries = 0,
        .duration = 0,
        .max_duration = 0,
    };
}

pub fn updateStats(s: *Stats, tries: u64, duration: i128) void {
    s.loops += 1;

    s.tries += tries;
    s.max_tries = @max(s.max_tries, tries);

    s.duration += duration;
    s.max_duration = @max(s.max_duration, duration);
}

pub fn importStats(from: *Stats, to: *Stats) void {
    to.loops += from.loops;

    to.tries += from.tries;
    to.max_tries = @max(to.max_tries, from.max_tries);

    to.duration += from.duration;
    to.max_duration = @max(to.max_duration, from.max_duration);
}

pub fn resetStats(s: *Stats) void {
    s.loops = 0;
    s.tries = 0;
    s.max_tries = 0;
    s.duration = 0;
    s.max_duration = 0;
}

pub fn printStats(id: u64, s: *Stats) void {
    if (s.loops > 0) {
        const mean_tries_per_loop: f64 = @intToFloat(f64, s.tries) / @intToFloat(f64, s.loops);
        const mean_duration_per_try: f64 = @intToFloat(f64, s.duration) / @intToFloat(f64, s.tries);

        std.debug.print("{d}, {d}, {}, {d}, {d}, {}, {d}\n", .{ id, s.tries, mean_tries_per_loop, s.max_tries, s.duration, mean_duration_per_try, s.max_duration });
    }
}

pub fn printAndResetStats(id: u64, s: *Stats) void {
    printStats(id, s);
    resetStats(s);
}

pub fn isPrime(int: u64, stats: *Stats) bool {
    const start = std.time.nanoTimestamp();

    var i: u64 = 2;
    var is_prime = true;
    while (i < int) : (i += 1) {
        if (int % i == 0) {
            is_prime = false;
            break;
        }
    }

    updateStats(stats, i - 2, std.time.nanoTimestamp() - start);
    return is_prime;
}

pub fn main() !void {
    var local_stats = newStats();
    var global_stats = newStats();

    const alloc = std.heap.page_allocator;

    var primeNumbers = std.ArrayList(u64).init(alloc);
    defer primeNumbers.deinit();

    var i: u64 = 1;
    const i_max: u64 = 1_000_000;

    while (i < i_max) : (i += 1) {
        if (isPrime(i, &local_stats)) {
            try primeNumbers.append(i);
        }

        if (i % 1000 == 0) {
            importStats(&local_stats, &global_stats);
            printAndResetStats(i, &local_stats);
        }
    }

    const file = try std.fs.cwd().createFile(
        "prime_numbers.txt",
        .{ .read = true },
    );
    defer file.close();

    for (primeNumbers.items) |number| {
        const row = try std.fmt.allocPrint(alloc, "{d}\n", .{number});
        defer alloc.free(row);

        _ = try file.writeAll(row);
    }

    importStats(&local_stats, &global_stats);
    printStats(i, &global_stats);
}
