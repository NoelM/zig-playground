const std = @import("std");

const U64Queue = std.atomic.Queue(u64);
const Node = U64Queue.Node;
const Pool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;

pub fn isPrimeRoutine(quit: *bool, wait_group: *WaitGroup, int_to_test: *U64Queue, int_prime: *U64Queue) void {
    wait_group.start();
    defer wait_group.finish();

    while (!quit.*) {
        if (int_to_test.get()) |node| {
            const value = node.data;

            var is_value_prime = true;
            var i: u64 = 2;
            while (i < value) : (i += 1) {
                if (value % i == 0) {
                    is_value_prime = false;
                    break;
                }
            }

            if (is_value_prime) {
                node.prev = undefined;
                node.next = undefined;
                int_prime.put(node);
            }
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

    const cpu_count: u32 = @intCast(try std.Thread.getCpuCount());

    var thread_pool: Pool = undefined;
    try thread_pool.init(Pool.Options{
        .allocator = arena,
        .n_jobs = cpu_count,
    });
    defer thread_pool.deinit();

    var int_to_test = U64Queue.init();
    var int_prime = U64Queue.init();

    var wait_group: WaitGroup = undefined;
    wait_group.reset();

    var quit = false;
    var thread_id: u32 = 0;
    while (thread_id < cpu_count) : (thread_id += 1) {
        thread_pool.spawn(isPrimeRoutine, .{ &quit, &wait_group, &int_to_test, &int_prime }) catch |err| {
            return err;
        };
    }

    const value_max: u64 = 1000;
    var value: u64 = 1;
    while (value < value_max) {
        if (int_to_test.isEmpty()) {
            const node: *Node = try arena.create(Node);
            node.* = .{
                .prev = undefined,
                .next = undefined,
                .data = value,
            };
            int_to_test.put(node);
            value += 1;
        }
    }

    quit = true;
    wait_group.wait();

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
