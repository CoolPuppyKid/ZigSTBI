const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("../include/stb_image.h");
});

pub fn load_file(path: []const u8, num_components: u32) !Image {
    var w: c_int = 0;
    var h: c_int = 0;
    var ch: c_int = 0;

    std.fs.cwd().access(path, .{}) catch |err| {
        std.debug.print("File not accessible reason: {s}\n", .{@errorName(err)});
        return error.FileNotFailed;
    };

    const allocator = std.heap.c_allocator;

    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    const data = c.stbi_load(c_path.ptr, &w, &h, &ch, @intCast(num_components));
    const stbiError = c.stbi_failure_reason();

    if (stbiError) |err| {
        std.debug.print("{s}\n", .{err});
    }

    const components = if (num_components == 0) ch else @as(c_int, @intCast(num_components));
    const byte_count = @as(usize, @intCast(w * h * components));

    const bytes: []u8 = data[0..byte_count];

    return Image{ .bytes = bytes, .width = @intCast(w), .height = @intCast(h), .channel_number = @intCast(ch) };
}

pub const Image = struct {
    bytes: []u8,
    width: u32,
    height: u32,
    channel_number: u32,

    fn deinit(self: *Image) void {
        c.stbi_image_free(@ptrCast(self.bytes.ptr));
    }
};

test "Load Image" {
    var img = try load_file("C:\\Users\\theja\\Code\\ZigSTBI\\Will-it-hurt.png", 0);
    defer img.deinit();
    try testing.expect(img.bytes.len > 0);
}
