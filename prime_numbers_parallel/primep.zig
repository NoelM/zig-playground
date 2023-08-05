const std = @import("std");

const SafeNumber = struct { set: bool, value: u64, mutex: std.Thread.Mutex };

pub fn isPrime(quit: *bool, sn: *SafeNumber) void {
    var int: u64 = 0;
    while (!quit.*) {
        std.log.debug("here\n", .{});
        sn.mutex.lock();
        if (sn.set) {
            int = sn.value;
            std.log.debug("value={d}\n", .{int});
            sn.mutex.unlock();
        } else {
            sn.mutex.unlock();
        }

        var i: u64 = 2;
        while (i < int) : (i += 1) {
            if (int % i == 0) {
                std.log.debug("is not prime={d}", .{int});
                break;
            }
        }
    }
    std.log.debug("is prime={d}", .{int});
}

pub fn main() !void {
    var quit = false;
    var sn = SafeNumber{
        .mutex = std.Thread.Mutex{},
        .value = 1,
        .set = true,
    };

    const t0 = try std.Thread.spawn(.{}, isPrime, .{ &quit, &sn });

    quit = true;
    t0.join();
}
