// greedy algorithms
// dynamic programming
// depth first
// best first
// least discrepency

const std = @import("std");

const Item = struct {
    value: u32,
    weight: u32
};

const Solution = struct {
    objective_value: u32,
    optimal: u8,
    decision_variables: std.ArrayList(u8)
};

fn value_less_than(values: []const f32, lhs: usize, rhs: usize) bool {
    return values[lhs] < values[rhs];
}

fn value_greater_than(values: []const f32, lhs: usize, rhs: usize) bool {
    return values[lhs] > values[rhs];
}

fn greedy_solution(
    values: []const f32,
    comptime value_comparison_fn: fn (values: []const f32, lhs: usize, rhs: usize) bool,
    items: []const Item,
    max_capacity: u32
) Solution {
    var solution = Solution{
        .objective_value = 0,
        .optimal = 0,
        .decision_variables = std.ArrayList(u8).init(std.heap.page_allocator)
    };

    solution.decision_variables.resize(values.len) catch return solution;   // TODO: be better
    for (0..solution.decision_variables.items.len) |index| {
        solution.decision_variables.items[index] = 0;
    }

    var sorted_indices = std.ArrayList(usize).init(std.heap.page_allocator);
    defer sorted_indices.deinit();
    sorted_indices.resize(values.len) catch return solution;    // TODO: be better
    for (0..values.len) |index| {
        sorted_indices.items[index] = index;
    }

    std.sort.block(usize, sorted_indices.items, values, value_comparison_fn);
    for (sorted_indices.items) |index| {
        std.debug.print("{d}, {}\n", .{values[index], index});
    }

    var capacity: u32 = 0;
    for (sorted_indices.items) |item_index| {
        const item: Item = items[item_index];
        if (capacity + item.weight > max_capacity) {
            continue;
        }

        capacity += item.weight;
        solution.objective_value += item.value;
        solution.decision_variables.items[item_index] = 1;
    }

    return solution;
}

fn dynamic_programming_solution(items: []const Item, max_capacity: u32) Solution {
    var solution = Solution{
        .objective_value = 0,
        .optimal = 0,
        .decision_variables = std.ArrayList(u8).init(std.heap.page_allocator)
    };

    solution.decision_variables.resize(items.len) catch return solution;   // TODO: be better
    for (0..solution.decision_variables.items.len) |index| {
        solution.decision_variables.items[index] = 0;
    }

    const table_width = max_capacity + 1;
    const table_height = items.len + 1;

    var table = std.heap.page_allocator.alloc(u32, table_width * table_height) catch return solution;
    defer std.heap.page_allocator.free(table);

    // set the value to 0 for all capacities when no items
    for (0..table_width) |capacity| {
        table[capacity] = 0;
    }

    for (1..table_height) |row| {
        const item_index: usize = row - 1;
        const item: Item = items[item_index];
        for (0..table_width) |column| {
            const capacity: u32 = @truncate(column);
            const cell_index: usize = row * table_width + column;

            const item_not_picked_cell_index: usize = (row - 1) * table_width + column;
            const item_not_picked_value: u32 = table[item_not_picked_cell_index];

            const remaining_capacity_column: usize = column - @min(item.weight, column);
            const remaining_capacity_cell_index: usize = (row - 1) * table_width + remaining_capacity_column;
            const item_picked_value: u32 = item.value + table[remaining_capacity_cell_index];

            if (item.weight > capacity) {
                table[cell_index] = item_not_picked_value;
            } else {
                table[cell_index] = @max(item_picked_value, item_not_picked_value);
            }
        }
    }

    solution.objective_value = table[items.len * table_width + max_capacity];
    solution.optimal = 1;

    var capacity: usize = max_capacity;
    var row_index: usize = items.len;
    while (row_index > 0) : (row_index -= 1) {
        const cell_value: u32 = table[row_index * table_width + capacity];
        const adjacent_cell_value: u32 = table[(row_index - 1) * table_width + capacity];
        if (cell_value > adjacent_cell_value) {
            const item_index: usize = row_index - 1;
            solution.decision_variables.items[item_index] = 1;
            capacity -= items[item_index].weight;
        }
    }

    // for (0..table_height) |row| {
    //     for (0..table_width) |column| {
    //         const value: u32 = table[table_width * row + column];
    //         std.debug.print("{}\t", .{value});
    //     }
    //     std.debug.print("\n", .{});
    // }

    return solution;
}

fn print_solution(solution: *const Solution) void {
    std.debug.print("{} {}\n", .{solution.objective_value, solution.optimal});
    for (solution.decision_variables.items) |decision_variable| {
        std.debug.print("{} ", .{decision_variable});
    }
    std.debug.print("\n", .{});
}

pub fn main() void {
    // const items = [3]Item{
    //     Item{.value = 5, .weight = 4},
    //     Item{.value = 6, .weight = 5},
    //     Item{.value = 3, .weight = 2}
    // };

    // const max_capacity: u32 = 9;

    const items = [4]Item{
        Item{.value = 16, .weight = 2},
        Item{.value = 19, .weight = 3},
        Item{.value = 23, .weight = 4},
        Item{.value = 28, .weight = 5}
    };

    const max_capacity: u32 = 7;

    // const items = [19]Item{
    //     Item{.value = 1945, .weight = 4990},
    //     Item{.value = 321, .weight = 1142},
    //     Item{.value = 2945, .weight = 7390},
    //     Item{.value = 4136, .weight = 10372},
    //     Item{.value = 1107, .weight = 3114},
    //     Item{.value = 1022, .weight = 2744},
    //     Item{.value = 1101, .weight = 3102},
    //     Item{.value = 2890, .weight = 7280},
    //     Item{.value = 962, .weight = 2624},
    //     Item{.value = 1060, .weight = 3020},
    //     Item{.value = 805, .weight = 2310},
    //     Item{.value = 689, .weight = 2078},
    //     Item{.value = 1513, .weight = 3926},
    //     Item{.value = 3878, .weight = 9656},
    //     Item{.value = 13504, .weight = 32708},
    //     Item{.value = 1865, .weight = 4830},
    //     Item{.value = 667, .weight = 2034},
    //     Item{.value = 1833, .weight = 4766},
    //     Item{.value = 16553, .weight = 40006}
    // };

    // const max_capacity: u32 = 31181;

    var values: [items.len]f32 = undefined;
    for (0..items.len) |index| {
        values[index] = @floatFromInt(items[index].value);
    }

    const greedy_by_value: Solution = greedy_solution(&values, value_greater_than, &items, max_capacity);
    std.debug.print("greedy solution by value:\n", .{});
    print_solution(&greedy_by_value);
    std.debug.print("\n", .{});

    var weights: [items.len]f32 = undefined;
    for (0..items.len) |index| {
        weights[index] = @floatFromInt(items[index].weight);
    }

    const greedy_by_weight: Solution = greedy_solution(&weights, value_less_than, &items, max_capacity);
    std.debug.print("greedy solution by weight:\n", .{});
    print_solution(&greedy_by_weight);
    std.debug.print("\n", .{});

    var value_densities: [items.len]f32 = undefined;
    for (0..items.len) |index| {
        value_densities[index] = values[index] / weights[index];
    }

    const greedy_by_value_density: Solution = greedy_solution(&value_densities, value_greater_than, &items, max_capacity);
    std.debug.print("greedy solution by value density:\n", .{});
    print_solution(&greedy_by_value_density);
    std.debug.print("\n", .{});

    const dynamic_solution: Solution = dynamic_programming_solution(&items, max_capacity);
    std.debug.print("dynamic programming solution:\n", .{});
    print_solution(&dynamic_solution);
}
