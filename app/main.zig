const std = @import("std");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

const BencodedResult = struct {
    const Payload = union(enum) {
        string: []const u8,
        int: i64,
        list: []const BencodedResult,
    };

    payload: Payload,
    bytes_read: usize,
};

const BencodeError = error{
    InvalidArgument,
    OutOfMemory, // needed for ArrayList operations
};

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try stdout.print("Usage: your_bittorrent.zig <command> <args>\n", .{});
        std.process.exit(1);
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "decode")) {
        // You can use print statements as follows for debugging, they'll be visible when running tests.
        // try stdout.print("Logs from your program will appear here\n", .{});

        // Uncomment this block to pass the first stage
        const encodedStr = args[2];
        const decodedStr = decodeBencode(encodedStr) catch {
            try stdout.print("Invalid encoded value\n", .{});
            std.process.exit(1);
        };
        var string = std.ArrayList(u8).init(allocator);
        switch (decodedStr.payload) {
            inline .int,
            .string,
            .list,
            => |payload| try std.json.stringify(payload, .{}, string.writer()),
        }

        const jsonStr = try string.toOwnedSlice();
        try stdout.print("{s}\n", .{jsonStr});
    }
}

fn parseInt(encodedValue: []const u8, startIdx: usize) BencodeError!BencodedResult {
    var result: i64 = 0;
    var idx = startIdx;
    var factor: i64 = 1;

    if (encodedValue[idx] == '-') {
        factor = -1;
        idx += 1;
    }

    while (idx < encodedValue.len and encodedValue[idx] != 'e') {
        result *= 10;
        result += (encodedValue[idx] - '0');
        idx += 1;
    }

    idx += 1;

    return BencodedResult{
        .payload = .{
            .int = result * factor,
        },
        .bytes_read = idx - startIdx,
    };
}

fn decodeBencode(encodedValue: []const u8) BencodeError!BencodedResult {
    var idx: usize = 0;

    if (encodedValue[idx] >= '0' and encodedValue[idx] <= '9') {
        const firstColon = std.mem.indexOf(u8, encodedValue, ":");
        if (firstColon == null) {
            return error.InvalidArgument;
        }
        return BencodedResult{
            .payload = .{
                .string = encodedValue[firstColon.? + 1 ..],
            },
            .bytes_read = firstColon.? + 1,
        };
    } else if (encodedValue[idx] == 'i') {
        idx += 1;
        return parseInt(encodedValue, idx);
    } else if (encodedValue[idx] == 'l') {
        idx += 1;
        return decodeList(encodedValue, idx);
    }
    // else if (encodedValue[idx] == 'd') {
    //     idx += 1;
    //     return decodeDict(encodedValue, idx);
    // }
    else {
        return error.InvalidArgument;
    }
}

// fn decodeDict(encodedValue: []const u8, startIdx: usize) !BencodedResult {
//     var idx = startIdx;
//     var dict = std.HashMap(BencodedResult, BencodedResult, std.hash.SipHash, 10).init(allocator);
// }

fn decodeList(encodedValue: []const u8, startIdx: usize) BencodeError!BencodedResult {
    var idx = startIdx;
    var list = std.ArrayList(BencodedResult).init(allocator);
    errdefer list.deinit();

    while (encodedValue[idx] != 'e') {
        const decoded = try decodeBencode(encodedValue[idx..]);
        try list.append(decoded);
        idx += decoded.bytes_read;
    }

    return BencodedResult{
        .payload = .{ .list = try list.toOwnedSlice() },
        .bytes_read = idx - startIdx,
    };
}
