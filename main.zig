// least discrepency

const std = @import("std");

const Item = struct {
    value: u32,
    weight: u32
};

const Solution = struct {
    objective_value: u32,
    optimal: u8,
    decision_variables: []u8
};

fn construct_default_solution(item_count: usize) Solution {
    var solution = Solution{
        .objective_value = 0,
        .optimal = 0,
        .decision_variables = std.heap.page_allocator.alloc(u8, item_count) catch unreachable
    };

    @memset(solution.decision_variables, 0);

    return solution;
}

fn print_solution(solution: *const Solution) void {
    std.debug.print("{} {}\n", .{solution.objective_value, solution.optimal});
    for (solution.decision_variables) |decision_variable| {
        std.debug.print("{} ", .{decision_variable});
    }
    std.debug.print("\n", .{});
}

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
    var solution: Solution = construct_default_solution(items.len);

    var sorted_indices: []usize = std.heap.page_allocator.alloc(usize, values.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_indices);
    for (0..values.len) |index| {
        sorted_indices[index] = index;
    }

    std.sort.block(usize, sorted_indices, values, value_comparison_fn);

    var capacity: u32 = 0;
    for (sorted_indices) |item_index| {
        const item: Item = items[item_index];
        if (capacity + item.weight > max_capacity) {
            continue;
        }

        capacity += item.weight;
        solution.objective_value += item.value;
        solution.decision_variables[item_index] = 1;
    }

    return solution;
}

fn dynamic_programming_solution(items: []const Item, max_capacity: u32) Solution {
    var solution: Solution = construct_default_solution(items.len);

    const table_width: usize = @as(usize, max_capacity + 1);
    const table_height: usize = items.len + 1;

    var table: []u32 = std.heap.page_allocator.alloc(u32, table_width * table_height) catch unreachable;
    defer std.heap.page_allocator.free(table);
    @memset(table, 0);

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

            const max_value: u32 = @max(item_picked_value, item_not_picked_value);
            table[cell_index] = if (item.weight > capacity) item_not_picked_value else max_value;
        }
    }

    solution.objective_value = table[table.len - 1];
    solution.optimal = 1;

    var capacity: usize = max_capacity;
    var row_index: usize = items.len;
    while (row_index > 0) : (row_index -= 1) {
        const cell_value: u32 = table[row_index * table_width + capacity];
        const adjacent_cell_value: u32 = table[(row_index - 1) * table_width + capacity];
        if (cell_value > adjacent_cell_value) {
            const item_index: usize = row_index - 1;
            solution.decision_variables[item_index] = 1;
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

fn exhaustive_search_solution_impl(
    items: []const Item,
    current_item_index: usize,
    remaining_capacity: u32,
    current_solution: *Solution,
    best_solution: *Solution
) void {
    if (current_item_index >= items.len) {
        return;
    }

    const current_item: Item = items[current_item_index];
    if (current_item.weight <= remaining_capacity) {
        current_solution.objective_value += current_item.value;
        current_solution.decision_variables[current_item_index] = 1;

        if (current_solution.objective_value > best_solution.objective_value) {
            best_solution.objective_value = current_solution.objective_value;
            @memcpy(best_solution.decision_variables, current_solution.decision_variables);
        }

        exhaustive_search_solution_impl(items, current_item_index + 1, remaining_capacity - current_item.weight, current_solution, best_solution);

        current_solution.objective_value -= current_item.value;
        current_solution.decision_variables[current_item_index] = 0;
    }

    exhaustive_search_solution_impl(items, current_item_index + 1, remaining_capacity, current_solution, best_solution);
}

fn exhaustive_search_solution(items: []const Item, max_capacity: u32) Solution {
    var current_solution: Solution = construct_default_solution(items.len);
    defer std.heap.page_allocator.free(current_solution.decision_variables);

    var best_solution: Solution = construct_default_solution(items.len);
    exhaustive_search_solution_impl(items, 0, max_capacity, &current_solution, &best_solution);
    best_solution.optimal = 1;

    return best_solution;
}

fn item_value_density_greater_than(items: []const Item, lhs: usize, rhs: usize) bool {
    const lhs_item: Item = items[lhs];
    const lhs_value: f32 = @floatFromInt(lhs_item.value);
    const lhs_weight: f32 = @floatFromInt(lhs_item.weight);
    const lhs_value_density: f32 = lhs_value / lhs_weight;
    
    const rhs_item: Item = items[rhs];
    const rhs_value: f32 = @floatFromInt(rhs_item.value);
    const rhs_weight: f32 = @floatFromInt(rhs_item.weight);
    const rhs_value_density: f32 = rhs_value / rhs_weight;
    
    return lhs_value_density > rhs_value_density;
}

fn calculate_remaining_optimistic_max_value(items: []const Item, starting_item_index: usize, current_value: u32, current_capacity: u32) u32 {
    var result: u32 = current_value;
    var remaining_capacity: u32 = current_capacity;
    for (starting_item_index..items.len) |item_index| {
        const item: Item = items[item_index];
        if (item.weight <= remaining_capacity) {
            result += item.value;
            remaining_capacity -= item.weight;
        } else {
            const ratio: f32 = @as(f32, @floatFromInt(remaining_capacity)) / @as(f32, @floatFromInt(item.weight));
            const fractional_value: f32 = ratio * @as(f32, @floatFromInt(item.value));
            result += @intFromFloat(fractional_value);
            break;
        }
    }

    return result;
}

fn depth_first_branch_and_bound_solution_impl(
    items: []const Item,
    current_item_index: usize,
    remaining_capacity: u32,
    optimistic_max_value: u32,
    current_solution: *Solution,
    best_solution: *Solution
) void {
    if (current_item_index >= items.len or optimistic_max_value <= best_solution.objective_value) {
        return;
    }
    
    const current_item: Item = items[current_item_index];
    if (current_item.weight <= remaining_capacity) {
        current_solution.objective_value += current_item.value;
        current_solution.decision_variables[current_item_index] = 1;

        if (current_solution.objective_value > best_solution.objective_value) {
            best_solution.objective_value = current_solution.objective_value;
            @memcpy(best_solution.decision_variables, current_solution.decision_variables);
        }

        depth_first_branch_and_bound_solution_impl(items, current_item_index + 1, remaining_capacity - current_item.weight, optimistic_max_value, current_solution, best_solution);

        current_solution.objective_value -= current_item.value;
        current_solution.decision_variables[current_item_index] = 0;
    }

    const new_optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(items, current_item_index + 1, current_solution.objective_value, remaining_capacity);
    depth_first_branch_and_bound_solution_impl(items, current_item_index + 1, remaining_capacity, new_optimistic_max_value, current_solution, best_solution);
}

fn depth_first_branch_and_bound_solution(items: []const Item, max_capacity: u32) Solution {
    var sorted_indices: []usize = std.heap.page_allocator.alloc(usize, items.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_indices);
    for (0..items.len) |index| {
        sorted_indices[index] = index;
    }
    
    std.sort.block(usize, sorted_indices, items, item_value_density_greater_than);
    
    var sorted_items: []Item = std.heap.page_allocator.alloc(Item, items.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_items);

    for (0..items.len) |index| {
        const sorted_item_index: usize = sorted_indices[index];
        sorted_items[index] = items[sorted_item_index];
    }

    var solution: Solution = construct_default_solution(sorted_items.len);

    var sorted_solution: Solution = construct_default_solution(sorted_items.len);
    defer std.heap.page_allocator.free(sorted_solution.decision_variables);

    const optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(items, 0, 0, max_capacity);
    depth_first_branch_and_bound_solution_impl(sorted_items, 0, max_capacity, optimistic_max_value, &solution, &sorted_solution);
    
    solution.objective_value = sorted_solution.objective_value;
    solution.optimal = 1;
    for (0..items.len) |index| {
        const original_item_index: usize = sorted_indices[index];
        solution.decision_variables[original_item_index] = sorted_solution.decision_variables[index];
    }

    return solution;
}

const Node = struct {
    solution: Solution,
    current_item_index: u32,
    remaining_capacity: u32,
    optimistic_max_value: u32
};

const PriorityQueue = struct {
    nodes: std.ArrayList(Node)
};

fn swap(lhs: *Node, rhs: *Node) void {
    const temp: Node = lhs.*;
    lhs.* = rhs.*;
    rhs.* = temp;
}

fn push(queue: *PriorityQueue, new_node: Node) void {
    queue.nodes.append(new_node) catch unreachable;
    
    var node_index: usize = queue.nodes.items.len - 1;
    while (node_index != 0) {
        const node: *Node = &queue.nodes.items[node_index];
        const parent_node_index: usize = (node_index - 1) / 2;
        const parent_node: *Node = &queue.nodes.items[parent_node_index];
        if (node.optimistic_max_value > parent_node.optimistic_max_value) {
            swap(node, parent_node);
            node_index = parent_node_index;
        } else {
            break;
        }
    }
}

fn pop(queue: *PriorityQueue) Node {
    const result: Node = queue.nodes.items[0];
    queue.nodes.items[0] = queue.nodes.items[queue.nodes.items.len - 1];
    _ = queue.nodes.pop();
    
    var node_index: usize = 0;
    const nodes: []Node = queue.nodes.items;
    const node_count: usize = nodes.len;
    while (node_index < node_count) {
        const node: *Node = &nodes[node_index];
        const child_node_1_index: usize = @min(2 * node_index + 1, node_count - 1);
        const child_node_1: *Node = &nodes[child_node_1_index];
        const child_node_2_index: usize = @min(2 * node_index + 2, node_count - 1);
        const child_node_2: *Node = &nodes[child_node_2_index];
        const child_node_1_is_larger: bool = child_node_1.optimistic_max_value > child_node_2.optimistic_max_value;
        const largest_child_node_index: usize = if (child_node_1_is_larger) child_node_1_index else child_node_2_index;
        const largest_child_node: *Node = &nodes[largest_child_node_index];
        const smallest_child_node_index: usize = if (child_node_1_is_larger) child_node_2_index else child_node_1_index;
        const smallest_child_node: *Node = &nodes[smallest_child_node_index];
        if (node.optimistic_max_value < largest_child_node.optimistic_max_value) {
            swap(node, largest_child_node);
            node_index = largest_child_node_index;
        } else if (node.optimistic_max_value < smallest_child_node.optimistic_max_value) {
            swap(node, smallest_child_node);
            node_index = smallest_child_node_index;
        } else {
            break;
        }
    }
    
    return result;
}

fn is_empty(queue: *PriorityQueue) bool {
    return queue.nodes.items.len == 0;
}

fn best_first_branch_and_bound_solution(items: []const Item, max_capacity: u32) Solution {
    var sorted_indices: []usize = std.heap.page_allocator.alloc(usize, items.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_indices);
    for (0..items.len) |index| {
        sorted_indices[index] = index;
    }
    
    std.sort.block(usize, sorted_indices, items, item_value_density_greater_than);
    
    var sorted_items: []Item = std.heap.page_allocator.alloc(Item, items.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_items);

    for (0..items.len) |index| {
        const sorted_item_index: usize = sorted_indices[index];
        sorted_items[index] = items[sorted_item_index];
    }

    var best_solution: Solution = construct_default_solution(sorted_items.len);
    defer std.heap.page_allocator.free(best_solution.decision_variables);

    var queue = PriorityQueue{.nodes = std.ArrayList(Node).init(std.heap.page_allocator)};
    
    const first_node = Node{
        .solution = construct_default_solution(items.len),
        .current_item_index = 0,
        .remaining_capacity = max_capacity,
        .optimistic_max_value = calculate_remaining_optimistic_max_value(sorted_items, 0, 0, max_capacity),
    };
    
    push(&queue, first_node);
    while (!is_empty(&queue)) {
        const current_node: Node = pop(&queue);
        defer std.heap.page_allocator.free(current_node.solution.decision_variables);

        if (current_node.solution.objective_value > best_solution.objective_value) {
            best_solution.objective_value = current_node.solution.objective_value;
            @memcpy(best_solution.decision_variables, current_node.solution.decision_variables);
        }

        if (current_node.current_item_index >= items.len or current_node.optimistic_max_value <= best_solution.objective_value) {
            break;
        }
        
        const current_item: Item = sorted_items[current_node.current_item_index];
        if (current_item.weight <= current_node.remaining_capacity) {
            var new_node = Node{
                .solution = construct_default_solution(items.len),
                .current_item_index = current_node.current_item_index + 1,
                .remaining_capacity = current_node.remaining_capacity - current_item.weight,
                .optimistic_max_value = current_node.optimistic_max_value
            };
            
            new_node.solution.objective_value = current_node.solution.objective_value + current_item.value;
            @memcpy(new_node.solution.decision_variables, current_node.solution.decision_variables);
            new_node.solution.decision_variables[current_node.current_item_index] = 1;
            
            push(&queue, new_node);
        }
        
        const new_optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(
            sorted_items,
            current_node.current_item_index + 1,
            current_node.solution.objective_value,
            current_node.remaining_capacity
        );
        
        var new_node = Node{
            .solution = construct_default_solution(items.len),
            .current_item_index = current_node.current_item_index + 1,
            .remaining_capacity = current_node.remaining_capacity,
            .optimistic_max_value = new_optimistic_max_value
        };
        
        new_node.solution.objective_value = current_node.solution.objective_value;
        @memcpy(new_node.solution.decision_variables, current_node.solution.decision_variables);
        
        push(&queue, new_node);
    }
    
    for (queue.nodes.items) |node| {
        std.heap.page_allocator.free(node.solution.decision_variables);
    }
    
    var solution: Solution = construct_default_solution(items.len);
    solution.objective_value = best_solution.objective_value;
    solution.optimal = 1;
    for (0..items.len) |index| {
        const original_item_index: usize = sorted_indices[index];
        solution.decision_variables[original_item_index] = best_solution.decision_variables[index];
    }

    return solution;
}

pub fn main() void {
//    const items = [3]Item{
//       Item{.value = 5, .weight = 4},
//       Item{.value = 6, .weight = 5},
//       Item{.value = 3, .weight = 2}
//    };
//
//    const max_capacity: u32 = 9;

    const items = [4]Item{
        Item{.value = 16, .weight = 2},
        Item{.value = 19, .weight = 3},
        Item{.value = 23, .weight = 4},
        Item{.value = 28, .weight = 5}
    };

    const max_capacity: u32 = 7;

//    const items = [19]Item{
//        Item{.value = 1945, .weight = 4990},
//        Item{.value = 321, .weight = 1142},
//        Item{.value = 2945, .weight = 7390},
//        Item{.value = 4136, .weight = 10372},
//        Item{.value = 1107, .weight = 3114},
//        Item{.value = 1022, .weight = 2744},
//        Item{.value = 1101, .weight = 3102},
//        Item{.value = 2890, .weight = 7280},
//        Item{.value = 962, .weight = 2624},
//        Item{.value = 1060, .weight = 3020},
//        Item{.value = 805, .weight = 2310},
//        Item{.value = 689, .weight = 2078},
//        Item{.value = 1513, .weight = 3926},
//        Item{.value = 3878, .weight = 9656},
//        Item{.value = 13504, .weight = 32708},
//        Item{.value = 1865, .weight = 4830},
//        Item{.value = 667, .weight = 2034},
//        Item{.value = 1833, .weight = 4766},
//        Item{.value = 16553, .weight = 40006}
//    };
//
//    const max_capacity: u32 = 31181;

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

    const dynamic_programming: Solution = dynamic_programming_solution(&items, max_capacity);
    std.debug.print("dynamic programming solution:\n", .{});
    print_solution(&dynamic_programming);
    std.debug.print("\n", .{});

    const exhaustive_search: Solution = exhaustive_search_solution(&items, max_capacity);
    std.debug.print("exhaustive search solution:\n", .{});
    print_solution(&exhaustive_search);
    std.debug.print("\n", .{});
    
    const depth_first_branch_and_bound: Solution = depth_first_branch_and_bound_solution(&items, max_capacity);
    std.debug.print("depth first solution:\n", .{});
    print_solution(&depth_first_branch_and_bound);
    std.debug.print("\n", .{});
    
    const best_first_branch_and_bound: Solution = best_first_branch_and_bound_solution(&items, max_capacity);
    std.debug.print("best first solution:\n", .{});
    print_solution(&best_first_branch_and_bound);
}
