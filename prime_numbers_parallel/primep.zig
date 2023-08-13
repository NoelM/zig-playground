const std = @import("std");

const U64Queue = std.atomic.Queue(u64);
const Node = U64Queue.Node;
const Pool = std.Thread.Pool;

pub fn isPrime(quit: *bool, toTest: *U64Queue, prime: *U64Queue) void {
    while (!quit.*) {
        if (toTest.get()) |val| {
            if (!toTest.remove(val)) {
                continue;
            }

            var i: u64 = 2;
            while (i < val.data) : (i += 1) {
                if (val.data % i == 0) {
                    break;
                }
            }

            prime.put(val);
        }
    }
}

pub fn main() !void {
    var quit = false;

    const nbCpu: u32 = @intCast(try std.Thread.getCpuCount());
    std.log.debug("number of CPU={d}", .{nbCpu});

    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();
    var thread_safe_arena: std.heap.ThreadSafeAllocator = .{
        .child_allocator = single_threaded_arena.allocator(),
    };
    const arena = thread_safe_arena.allocator();

    var threadPool: Pool = undefined;
    try threadPool.init(Pool.Options{
        .allocator = arena,
        .n_jobs = nbCpu,
    });
    defer threadPool.deinit();

    var toTest = U64Queue.init();
    var prime = U64Queue.init();

    threadPool.spawn(isPrime, .{ &quit, &toTest, &prime }) catch |err| {
        return err;
    };

    const i_max: u64 = 1000;
    var i: u64 = 1;
    while (i < i_max) : (i += 1) {
        if (toTest.isEmpty()) {
            const node: *Node = try single_threaded_arena.allocator().create(Node);
            node.* = .{
                .prev = undefined,
                .next = undefined,
                .data = i,
            };
            toTest.put(node);
        }
    }

    quit = true;
    threadPool.deinit();

    while (!prime.isEmpty()) {
        if (prime.get()) |val| {
            std.log.debug("prime={d}", .{val.data});
        }
    }
}
