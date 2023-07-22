const std = @import("std");

const Stats = struct { loops: u64, tries: u64, max_tries: u64, duration: i128, max_duration: i128 };
const Args = struct { max_loops: u64 };
const ArgsError = error{IncompleteArgs};

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

pub fn printStats(s: *Stats) void {
    if (s.loops > 0) {
        const mean_tries: f64 = @intToFloat(f64, s.tries) / @intToFloat(f64, s.loops);
        const mean_duration: f64 = @intToFloat(f64, s.duration) / @intToFloat(f64, s.loops);

        std.debug.print("loops: {d}, mean_tries: {}, max_tries:{d}, mean_dur_ns:{}, max_dur_ns: {d}\n", .{ s.loops, mean_tries, s.max_tries, mean_duration, s.max_duration });
    }
}

pub fn printAndResetStats(s: *Stats) void {
    printStats(s);
    resetStats(s);
}

pub fn parseArgs() !Args {
    var args = Args{ .max_loops = 0 };

    var is_max = false;
    for (std.os.argv) |arg| {
        var str = [_]u8{};
        std.mem.copy(u8, &str, arg[0..arg.len()]);

        if (is_max) {
            args.max_loops = try std.fmt.parseInt(u64, str, 10);
            is_max = false;
        }

        switch (str) {
            "--max"[0..] => {
                is_max = true;
            },
            else => {},
        }
    }

    if (args.max_loops == 0) {
        return ArgsError.IncompleteArgs;
    }

    return args;
}

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

pub fn main() !void {
    const file = try std.fs.cwd().createFile(
        "prime_numbers.txt",
        .{ .read = true },
    );
    defer file.close();

    const args = try parseArgs();
    const alloc = std.heap.page_allocator;

    var local_stats = newStats();
    var global_stats = newStats();

    var i: u64 = 1;
    const i_max: u64 = args.max_loops;

    while (i < i_max) : (i += 1) {
        if (isPrime(i, &local_stats)) {
            const prime = try std.fmt.allocPrint(alloc, "{d}\n", .{i});
            defer alloc.free(prime);

            _ = try file.writeAll(prime);
        } else if (i % 1000 == 0) {
            importStats(&local_stats, &global_stats);
            printAndResetStats(&local_stats);
        }
    }

    importStats(&local_stats, &global_stats);
    printStats(&global_stats);
}
