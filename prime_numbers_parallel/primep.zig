const std = @import("std");

const i64Chan = std.event.Channel(i64);

pub fn isPrime(quit: *bool, toComputeChan: *i64Chan, computedChan: *i64Chan) bool {
    while (!*quit) {
        const int = await toComputeChan.get();
        var i: u64 = 2;
        while (i < int) : (i += 1) {
            if (int % i == 0) {
                break;
            }
        }
        computedChan.put(int);
    }
}

pub fn main() !void {
    const toComputeBuf = []i64;
    const toComputeChan = std.event.Channel(i64);
    toComputeChan.init(toComputeBuf);

    const computedBuf = []i64;
    const computedChan = std.event.Channel(i64);
    computedChan.init(computedBuf);

    var quit = false;
    var config = std.Thread.SpawnConfig{};
    std.Thread.spawn(config, isPrime, &quit, &toComputeChan, &computedChan);

    var value: i64 = 0;
    while (true) {
        toComputeChan.put(value);
        const c = await computedChan.get();
        std.log.debug("prime: %d", .{c});
    }
}
