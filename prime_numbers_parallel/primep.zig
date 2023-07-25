const std = @import("std");

const Pipe = struct {
    mtx: std.Thread.Mutex,
    arr: []u64,
    max: u32,
    pos: u32,

    pub fn init() Pipe {
        return Pipe{
            .arr = &[_]u64{0} ** 10,
            .max = 10,
            .pos = 10,
        };
    }
};

pub fn main() !void {
    const p = Pipe;
    _ = p.init();
}
