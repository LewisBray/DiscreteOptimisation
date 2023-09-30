const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = struct {
    neighbours: []u16
};

const Edge = struct {
    start_node_index: u16,
    end_node_index: u16
};

fn is_whitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

fn parse_u16(text: []const u8) u16 {
    var result: u16 = 0;
    var multiplier: u16 = 1;
    var index: isize = @as(isize, @bitCast(text.len)) - 1;
    while (index >= 0) {
        const digit_index: usize = @as(usize, @bitCast(index));
        const digit: u16 = @as(u16, text[digit_index] - '0');
        result += digit * multiplier;
        multiplier *= 10;
        index -= 1;
    }

    return result;
}

fn parse_input(text: []const u8, allocator: Allocator) []Node {
    var index: usize = 0;
    while (is_whitespace(text[index])) {
        index += 1;
    }

    const node_count_start: usize = index;
    while (!is_whitespace(text[index])) {
        index += 1;
    }

    const node_count: u16 = parse_u16(text[node_count_start..index]);

    while (is_whitespace(text[index])) {
        index += 1;
    }

    const edge_count_start: usize = index;
    while (!is_whitespace(text[index])) {
        index += 1;
    }

    const edge_count: u16 = parse_u16(text[edge_count_start..index]);

    var node_neighbour_counts: []u16 = allocator.alloc(u16, @as(usize, node_count)) catch unreachable;
    defer allocator.free(node_neighbour_counts);
    @memset(node_neighbour_counts, 0);

    var edges: []Edge = allocator.alloc(Edge, @as(usize, edge_count)) catch unreachable;
    defer allocator.free(edges);

    var edge_index: usize = 0;
    while (index < text.len and edge_index < @as(usize, edge_count)) {
        while (is_whitespace(text[index])) {
            index += 1;
        }

        const start_node_start: usize = index;
        while (!is_whitespace(text[index])) {
            index += 1;
        }

        const start_node_index: u16 = parse_u16(text[start_node_start..index]);
        node_neighbour_counts[start_node_index] += 1;

        while (is_whitespace(text[index])) {
            index += 1;
        }

        const end_node_start: usize = index;
        while (!is_whitespace(text[index])) {
            index += 1;
        }

        const end_node_index: u16 = parse_u16(text[end_node_start..index]);
        node_neighbour_counts[end_node_index] += 1;

        edges[edge_index] = Edge{.start_node_index = start_node_index, .end_node_index = end_node_index};
        edge_index += 1;
    }

    var node_neighbour_arena_offsets: []u16 = allocator.alloc(u16, @as(usize, node_count)) catch unreachable;
    defer allocator.free(node_neighbour_arena_offsets);

    var offset: u16 = 0;
    for (node_neighbour_counts, 0..) |neighbour_count, node_index| {
        node_neighbour_arena_offsets[node_index] = offset;
        offset += neighbour_count;
    }

    var indices: []u16 = allocator.alloc(u16, @as(usize, node_count)) catch unreachable;
    defer allocator.free(indices);
    @memset(indices, 0);

    var node_neighbour_arena: []u16 = allocator.alloc(u16, 2 * @as(usize, edge_count)) catch unreachable;
    for (edges) |edge| {
        const start_node_index: usize = @as(usize, edge.start_node_index);
        const end_node_index: usize = @as(usize, edge.end_node_index);

        const start_node_arena_offset: usize = @as(usize, node_neighbour_arena_offsets[start_node_index] + indices[start_node_index]);
        const end_node_arena_offset: usize = @as(usize, node_neighbour_arena_offsets[end_node_index] + indices[end_node_index]);

        node_neighbour_arena[start_node_arena_offset] = edge.end_node_index;
        node_neighbour_arena[end_node_arena_offset] = edge.start_node_index;

        indices[start_node_index] += 1;
        indices[end_node_index] += 1;
    }

    var nodes: []Node = allocator.alloc(Node, @as(usize, node_count)) catch unreachable;
    for (0..@as(usize, node_count)) |node_index| {
        const arena_offset: usize = @as(usize, node_neighbour_arena_offsets[node_index]);
        const neighbour_count: usize = @as(usize, node_neighbour_counts[node_index]);
        nodes[node_index].neighbours = node_neighbour_arena[arena_offset..(arena_offset + neighbour_count)];
    }

    return nodes;
}

pub fn print_nodes(nodes: []Node) void {
    for (nodes, 0..) |node, node_index| {
        std.debug.print("{}: ", .{node_index});
        for (node.neighbours) |neighbour_index| {
            std.debug.print("{} ", .{neighbour_index});
        }

        std.debug.print("\n", .{});
    }
}

pub fn main() void {
    const text =
        \\4 3
        \\0 1
        \\1 2
        \\1 3
        \\
    ;

    const nodes: []Node = parse_input(text, std.heap.page_allocator);
    print_nodes(nodes);
}
