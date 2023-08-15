const std = @import("std");

const U64Queue = std.atomic.Queue(u64);
const Node = U64Queue.Node;
const Pool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;

pub fn isPrimeRoutine(wait_group: *WaitGroup, allocator: *const std.mem.Allocator, start: u64, shard_size: u64, int_prime: *U64Queue) void {
    wait_group.start();
    defer wait_group.finish();

    for (start..start + shard_size) |value| {
        if (value == 0) {
            continue;
        }

        var is_value_prime = true;
        var i: u64 = 2;
        while (i < value) : (i += 1) {
            if (value % i == 0) {
                is_value_prime = false;
                break;
            }
        }

        const node: *Node = allocator.create(Node) catch |err| {
            std.log.err("cannot allocate for int: {d}, error: {}\n", .{ value, err });
            continue;
        };
        node.* = .{
            .prev = undefined,
            .next = undefined,
            .data = value,
        };

        if (is_value_prime) {
            node.prev = undefined;
            node.next = undefined;
            int_prime.put(node);
        }
    }
}

pub fn main() !void {
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();

    var thread_safe_arena: std.heap.ThreadSafeAllocator = .{
        .child_allocator = single_threaded_arena.allocator(),
    };
    const arena = thread_safe_arena.allocator();

    var thread_pool: Pool = undefined;
    try thread_pool.init(Pool.Options{
        .allocator = arena,
    });
    defer thread_pool.deinit();

    var int_prime = U64Queue.init();

    var wait_group: WaitGroup = undefined;
    wait_group.reset();

    const value_max: u64 = 1000000;
    const shard_size: u64 = 1000;

    var value: u64 = 0;
    while (value < value_max) : (value += shard_size) {
        try thread_pool.spawn(isPrimeRoutine, .{ &wait_group, &arena, value, shard_size, &int_prime });
    }
    thread_pool.waitAndWork(&wait_group);

    const file = try std.fs.cwd().createFile(
        "prime_numbers.txt",
        .{ .read = true },
    );
    defer file.close();

    while (!int_prime.isEmpty()) {
        if (int_prime.get()) |prime_value| {
            const row = try std.fmt.allocPrint(arena, "{d}\n", .{prime_value.data});
            defer arena.free(row);

            _ = try file.writeAll(row);
        }
    }
}
