const std = @import("std");

const U64Queue = std.atomic.Queue(u64);
const Node = U64Queue.Node;
const Pool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;

pub fn isPrime(quit: *bool, all: *const std.mem.Allocator, wg: *WaitGroup, toTest: *U64Queue, prime: *U64Queue) void {
    wg.start();
    defer wg.finish();

    while (!quit.*) {
        if (toTest.get()) |val| {
            const val_test = val.data;

            var val_prime = true;
            var i: u64 = 2;
            while (i < val_test) : (i += 1) {
                if (val_test % i == 0) {
                    val_prime = false;
                    break;
                }
            }

            if (val_prime) {
                const node: *Node = all.create(Node) catch {
                    std.log.debug("error out of memory", .{});
                    continue;
                };
                node.* = .{
                    .prev = undefined,
                    .next = undefined,
                    .data = val_test,
                };
                prime.put(node);
            }
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
    std.log.debug("init threads", .{});

    var toTest = U64Queue.init();
    var prime = U64Queue.init();
    std.log.debug("init queue", .{});

    var wg: WaitGroup = undefined;
    wg.reset();

    var thread_id: u32 = 0;
    while (thread_id < nbCpu) : (thread_id += 1) {
        threadPool.spawn(isPrime, .{ &quit, &arena, &wg, &toTest, &prime }) catch |err| {
            return err;
        };
    }
    std.log.debug("spawn pool", .{});

    const i_max: u64 = 1000000;
    var i: u64 = 1;
    while (i < i_max) {
        if (toTest.isEmpty()) {
            const node: *Node = try arena.create(Node);
            node.* = .{
                .prev = undefined,
                .next = undefined,
                .data = i,
            };
            toTest.put(node);
            i += 1;
        }
    }

    quit = true;
    wg.wait();

    while (!prime.isEmpty()) {
        if (prime.get()) |val| {
            std.log.debug("prime={d}", .{val.data});
        }
    }
}
