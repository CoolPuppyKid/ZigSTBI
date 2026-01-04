const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("../include/stb_image.h");
});

pub fn set_flip_vertically_on_load(should_flip: bool) void {
    c.stbi_set_flip_vertically_on_load(if (should_flip) 1 else 0);
}

pub fn load_file(path: []const u8, num_components: u32) !Image {
    var w: u32 = 0;
    var h: u32 = 0;
    var ch: c_int = 0;
    var bytes_per_component: u32 = 0;
    var bytes_per_row: u32 = 0;
    var is_hdr = false;

    std.fs.cwd().access(path, .{}) catch |err| {
        std.debug.print("File not accessible reason: {s}\n", .{@errorName(err)});
        return error.FileNotFailed;
    };

    const allocator = std.heap.c_allocator;

    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    var data: []u8 = undefined; //c.stbi_load(c_path.ptr, &w, &h, &ch, @intCast(num_components));
    if (isHdr(c_path)) {
        var x: c_int = undefined;
        var y: c_int = undefined;
        const img = c.stbi_loadf(c_path.ptr, &x, &y, &ch, @intCast(num_components));
        if (img == null) {
            if (c.stbi_failure_reason()) |err| {
                std.debug.print("{s}\n", .{err});
                return error.StbiError;
            }
            return error.ImageFailedToLoad;
        }
        const components: u32 = @intCast(if (num_components == 0) ch else @as(c_int, @intCast(num_components)));
        w = @as(u32, @intCast(x));
        h = @as(u32, @intCast(y));
        bytes_per_component = 2;
        bytes_per_row = w * components * bytes_per_component;
        is_hdr = true;

        var comp_f16 = @as([*]f16, @ptrCast(img.?));
        const num = w * h * components;
        var i: u32 = 0;
        while (i < num) : (i += 1) {
            comp_f16[i] = @as(f16, @floatCast(img.?[i]));
        }
        data = @as([*]u8, @ptrCast(comp_f16))[0 .. h * bytes_per_row];
    } else {
        var x: c_int = undefined;
        var y: c_int = undefined;
        const img16bit = is16bit(c_path);
        const img = if (img16bit) @as(?[*]u8, @ptrCast(c.stbi_load_16(
            c_path.ptr,
            &x,
            &y,
            &ch,
            @intCast(num_components),
        ))) else c.stbi_load(
            c_path.ptr,
            &x,
            &y,
            &ch,
            @intCast(num_components),
        );
        if (img == null) {
            if (c.stbi_failure_reason()) |err| {
                std.debug.print("{s}\n", .{err});
                return error.StbiError;
            }
            return error.ImageFailedToLoad;
        }

        const components: u32 = @intCast(if (num_components == 0) ch else @as(c_int, @intCast(num_components)));
        w = @as(u32, @intCast(x));
        h = @as(u32, @intCast(y));
        bytes_per_component = if (img16bit) 2 else 1;
        bytes_per_row = w * components * bytes_per_component;
        is_hdr = false;
        data = @as([*]u8, @ptrCast(img))[0 .. h * bytes_per_row];
    }

    return Image{ .bytes = data, .width = @intCast(w), .height = @intCast(h), .channel_number = @intCast(ch) };
}

pub fn isHdr(path: [:0]const u8) bool {
    return c.stbi_is_hdr(path) != 0;
}

pub fn is16bit(path: [:0]const u8) bool {
    return c.stbi_is_16_bit(path) != 0;
}

pub const Image = struct {
    bytes: []u8,
    width: u32,
    height: u32,
    channel_number: u32,

    pub fn deinit(self: *Image) void {
        c.stbi_image_free(@ptrCast(self.bytes.ptr));
    }
};

test "Image load" {
    const allocator = testing.allocator;

    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    const imgPath = try std.fs.path.join(allocator, &[_][]const u8{ cwd, "rock.jpg" });
    defer allocator.free(imgPath);

    std.debug.print("Cwd: {s}, ImgPath: {s}\n", .{ cwd, imgPath });

    var img = try load_file(imgPath, 0);
    defer img.deinit();

    try testing.expect(img.bytes.len > 0);
    try testing.expect(img.width > 0);
    try testing.expect(img.height > 0);
}
