const std = @import("std");

// If this bool is true, we use the getChildren function and we see problems.
// If this bool is false, we index the BoundedArray more directly and everything is fine.
const use_get_children = true;

// If print_full_node is true, we do some more printing of the node.
// If use_get_children is true and this bool is true, our recursion explodes, somehow.
// If use_get_children is true and this bool is false, it doesn't explode but is still wrong.
const print_full_node = true;

const Node = union(enum) {
    const Self = @This();
    const ChildIdxArray = std.BoundedArray(usize, 4);

    leaf: struct { name: []const u8 },
    parent: struct {
        name: []const u8,
        children: ChildIdxArray,
    },

    fn init(name: []const u8) Self {
        return Self{ .leaf = .{ .name = name } };
    }

    fn getName(self: *const Self) []const u8 {
        return switch (self.*) {
            .leaf => |l| l.name,
            .parent => |p| p.name,
        };
    }

    fn getChildren(self: *const Self) []const usize {
        switch (self.*) {
            .parent => |p| return p.children.slice(),
            else => return &.{}, // empty slice
        }
    }

    fn addChild(self: *Self, child_idx: usize) !void {
        if (self.* == .leaf) {
            self.* = .{ .parent = .{
                .name = self.leaf.name,
                .children = try ChildIdxArray.init(0),
            } };
        }
        try self.parent.children.append(child_idx);
    }
};

fn printIndicator(depth: usize, writer: std.io.AnyWriter) !void {
    if (depth > 0) {
        try writer.writeBytesNTimes("│ ", depth -| 1);
        _ = try writer.write("├─");
    }
}

fn printTreeRecurse(nodes: []const Node, writer: std.io.AnyWriter, idx: usize, depth: usize) !void {
    try printIndicator(depth, writer);

    try writer.print("{d}:{s}:\"{s}\"", .{
        idx,
        @tagName(nodes[idx]),
        nodes[idx].getName(),
    });
    if (print_full_node) try writer.print(":{any}", .{nodes[idx]});
    try writer.writeByte('\n');

    if (nodes[idx] == .parent) {
        if (depth < 5) {
            if (use_get_children) {
                for (nodes[idx].getChildren()) |i| try printTreeRecurse(nodes, writer, i, depth + 1);
            } else {
                for (0..nodes[idx].parent.children.len) |i| try printTreeRecurse(
                    nodes,
                    writer,
                    nodes[idx].parent.children.get(i),
                    depth + 1,
                );
            }
        } else {
            // We don't expect trees this deep, so if we get here we've probably gone off the deep end.
            // We stop the recursion.
            try printIndicator(depth + 1, writer);
            try writer.print("... here be dragons\n", .{});
        }
    }
}

fn printTree(nodes: []const Node, writer: std.io.AnyWriter) !void {
    try printTreeRecurse(nodes, writer, 0, 0);
}

pub fn main() !void {
    var nodes = [_]Node{
        Node.init("parent"), // 0
        Node.init("child A"), // 1
        Node.init("child B"), // 2
        Node.init("grandchild AA"), // 3
        Node.init("grandchild AB"), // 4
        Node.init("grandchild BA"), // 5
        Node.init("grandchild BB"), // 6
    };

    try nodes[0].addChild(1);
    try nodes[0].addChild(2);

    try nodes[1].addChild(3);
    try nodes[1].addChild(4);

    try nodes[2].addChild(5);
    try nodes[2].addChild(6);

    try printTree(&nodes, std.io.getStdOut().writer().any());
}
