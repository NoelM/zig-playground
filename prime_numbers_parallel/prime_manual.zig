const std = @import("std");

const U64Queue = std.atomic.Queue(u64);
const Node = U64Queue.Node;

pub fn isPrimeRoutine(int_to_test: *U64Queue, int_prime: *U64Queue) void {
    while (true) {
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
        } else {
            return;
        }
    }
}

pub fn main() !void {
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var arena = single_threaded_arena.allocator();
    defer single_threaded_arena.deinit();

    const cpu_count = try std.Thread.getCpuCount();

    var int_to_test = U64Queue.init();
    var int_prime = U64Queue.init();

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

    var pool = try arena.alloc(std.Thread, cpu_count);
    defer arena.free(pool);

    for (pool) |*thread| {
        thread.* = try std.Thread.spawn(.{}, isPrimeRoutine, .{ &int_to_test, &int_prime });
    }

    for (pool) |thread| {
        thread.join();
    }

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
