const std = @import("std");
const Allocator = std.mem.Allocator;

const Item = struct {
    value: u32,
    weight: u32
};

const Problem = struct {
    items: []Item,
    max_capacity: u32
};

const Solution = struct {
    objective_value: u32,
    decision_variables: []u8
};

fn construct_default_solution(item_count: usize, allocator: Allocator) Solution {
    var solution = Solution{
        .objective_value = 0,
        .decision_variables = allocator.alloc(u8, item_count) catch unreachable
    };

    @memset(solution.decision_variables, 0);

    return solution;
}

fn print_solution(solution: *const Solution, optimal: u8) void {
    std.debug.print("{} {}\n", .{solution.objective_value, optimal});
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
    problem: Problem,
    values: []const f32,
    comptime value_comparison_fn: fn (values: []const f32, lhs: usize, rhs: usize) bool,
    allocator: Allocator
) Solution {
    const items: []Item = problem.items;
    var solution: Solution = construct_default_solution(items.len, allocator);

    var sorted_indices: []usize = std.heap.page_allocator.alloc(usize, values.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted_indices);
    for (0..values.len) |index| {
        sorted_indices[index] = index;
    }

    std.sort.block(usize, sorted_indices, values, value_comparison_fn);

    var capacity: u32 = 0;
    const max_capacity: u32 = problem.max_capacity;
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

fn dynamic_programming_solution(problem: Problem, allocator: Allocator) Solution {
    const items: []Item = problem.items;
    var solution: Solution = construct_default_solution(items.len, allocator);

    const max_capacity: u32 = problem.max_capacity;
    const table_width: usize = @as(usize, max_capacity + 1);
    const table_height: usize = items.len + 1;

    var table: []u32 = allocator.alloc(u32, table_width * table_height) catch unreachable;
    defer allocator.free(table);
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

fn exhaustive_search_solution(problem: Problem, allocator: Allocator) Solution {
    const items: []Item = problem.items;
    var current_solution: Solution = construct_default_solution(items.len, allocator);
    defer allocator.free(current_solution.decision_variables);

    var best_solution: Solution = construct_default_solution(items.len, allocator);
    exhaustive_search_solution_impl(items, 0, problem.max_capacity, &current_solution, &best_solution);

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

fn depth_first_branch_and_bound_solution(problem: Problem, allocator: Allocator) Solution {
    const items: []Item = problem.items;
    var sorted_indices: []usize = allocator.alloc(usize, items.len) catch unreachable;
    defer allocator.free(sorted_indices);
    for (0..items.len) |index| {
        sorted_indices[index] = index;
    }
    
    std.sort.block(usize, sorted_indices, items, item_value_density_greater_than);
    
    var sorted_items: []Item = allocator.alloc(Item, items.len) catch unreachable;
    defer allocator.free(sorted_items);

    for (0..items.len) |index| {
        const sorted_item_index: usize = sorted_indices[index];
        sorted_items[index] = items[sorted_item_index];
    }

    var solution: Solution = construct_default_solution(sorted_items.len, allocator);

    var sorted_solution: Solution = construct_default_solution(sorted_items.len, allocator);
    defer allocator.free(sorted_solution.decision_variables);

    const max_capacity: u32 = problem.max_capacity;
    const optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(items, 0, 0, max_capacity);
    depth_first_branch_and_bound_solution_impl(sorted_items, 0, max_capacity, optimistic_max_value, &solution, &sorted_solution);
    
    solution.objective_value = sorted_solution.objective_value;
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

fn best_first_branch_and_bound_solution(problem: Problem, allocator: Allocator) Solution {
    const items: []Item = problem.items;
    var sorted_indices: []usize = allocator.alloc(usize, items.len) catch unreachable;
    defer allocator.free(sorted_indices);
    for (0..items.len) |index| {
        sorted_indices[index] = index;
    }
    
    std.sort.block(usize, sorted_indices, items, item_value_density_greater_than);
    
    var sorted_items: []Item = allocator.alloc(Item, items.len) catch unreachable;
    defer allocator.free(sorted_items);

    for (0..items.len) |index| {
        const sorted_item_index: usize = sorted_indices[index];
        sorted_items[index] = items[sorted_item_index];
    }

    var best_solution: Solution = construct_default_solution(sorted_items.len, allocator);
    defer allocator.free(best_solution.decision_variables);

    var queue = PriorityQueue{.nodes = std.ArrayList(Node).init(allocator)};
    
    const max_capacity: u32 = problem.max_capacity;
    const first_node = Node{
        .solution = construct_default_solution(items.len, allocator),
        .current_item_index = 0,
        .remaining_capacity = max_capacity,
        .optimistic_max_value = calculate_remaining_optimistic_max_value(sorted_items, 0, 0, max_capacity),
    };
    
    push(&queue, first_node);
    while (!is_empty(&queue)) {
        const current_node: Node = pop(&queue);
        defer allocator.free(current_node.solution.decision_variables);

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
                .solution = construct_default_solution(items.len, allocator),
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
            .solution = construct_default_solution(items.len, allocator),
            .current_item_index = current_node.current_item_index + 1,
            .remaining_capacity = current_node.remaining_capacity,
            .optimistic_max_value = new_optimistic_max_value
        };
        
        new_node.solution.objective_value = current_node.solution.objective_value;
        @memcpy(new_node.solution.decision_variables, current_node.solution.decision_variables);
        
        push(&queue, new_node);
    }
    
    for (queue.nodes.items) |node| {
        allocator.free(node.solution.decision_variables);
    }
    
    var solution: Solution = construct_default_solution(items.len, allocator);
    solution.objective_value = best_solution.objective_value;
    for (0..items.len) |index| {
        const original_item_index: usize = sorted_indices[index];
        solution.decision_variables[original_item_index] = best_solution.decision_variables[index];
    }

    return solution;
}

fn least_discrepancy_branch_and_bound_solution_impl(
    items: []const Item,
    current_item_index: usize,
    remaining_capacity: u32,
    optimistic_max_value: u32,
    remaining_accordances: u32,
    remaining_discrepancies: u32,
    current_solution: *Solution,
    best_solution: *Solution
) void {
    if (current_item_index >= items.len or optimistic_max_value <= best_solution.objective_value) {
        return;
    }

    const current_item: Item = items[current_item_index];
    if (current_item.weight <= remaining_capacity and remaining_accordances > 0) {
        current_solution.objective_value += current_item.value;
        current_solution.decision_variables[current_item_index] = 1;

        if (current_solution.objective_value > best_solution.objective_value) {
            best_solution.objective_value = current_solution.objective_value;
            @memcpy(best_solution.decision_variables, current_solution.decision_variables);
        }

        least_discrepancy_branch_and_bound_solution_impl(
            items,
            current_item_index + 1,
            remaining_capacity - current_item.weight,
            optimistic_max_value,
            remaining_accordances - 1,
            remaining_discrepancies,
            current_solution,
            best_solution
        );

        current_solution.objective_value -= current_item.value;
        current_solution.decision_variables[current_item_index] = 0;
    }

    if (remaining_discrepancies > 0) {
        const new_optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(
            items,
            current_item_index + 1,
            current_solution.objective_value,
            remaining_capacity
        );
        
        least_discrepancy_branch_and_bound_solution_impl(
            items,
            current_item_index + 1,
            remaining_capacity,
            new_optimistic_max_value,
            remaining_accordances,
            remaining_discrepancies - 1,
            current_solution,
            best_solution
        );
    }
}

fn least_discrepancy_branch_and_bound_solution(problem: Problem, allocator: Allocator) Solution {
    const items: []Item = problem.items;
    var sorted_indices: []usize = allocator.alloc(usize, items.len) catch unreachable;
    defer allocator.free(sorted_indices);
    for (0..items.len) |index| {
        sorted_indices[index] = index;
    }
    
    std.sort.block(usize, sorted_indices, items, item_value_density_greater_than);

    var sorted_items: []Item = allocator.alloc(Item, items.len) catch unreachable;
    defer allocator.free(sorted_items);

    for (0..items.len) |index| {
        const sorted_item_index: usize = sorted_indices[index];
        sorted_items[index] = items[sorted_item_index];
    }

    var solution: Solution = construct_default_solution(items.len, allocator);

    var sorted_solution: Solution = construct_default_solution(items.len, allocator);
    defer allocator.free(sorted_solution.decision_variables);

    const max_capacity: u32 = problem.max_capacity;
    const initial_optimistic_max_value: u32 = calculate_remaining_optimistic_max_value(sorted_items, 0, 0, max_capacity);
    for (0..items.len + 1) |discrepancy_count| {
        solution.objective_value = 0;
        @memset(solution.decision_variables, 0);

        least_discrepancy_branch_and_bound_solution_impl(
            sorted_items,
            0,
            max_capacity,
            initial_optimistic_max_value,
            @truncate(items.len - discrepancy_count),
            @truncate(discrepancy_count),
            &solution,
            &sorted_solution
        );
    }

    solution.objective_value = sorted_solution.objective_value;
    for (0..items.len) |index| {
        const original_item_index: usize = sorted_indices[index];
        solution.decision_variables[original_item_index] = sorted_solution.decision_variables[index];
    }

    return solution;
}

fn is_whitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

fn parse_u32(text: []u8) u32 {
    var result: u32 = 0;
    var multiplier: u32 = 1;
    var index: isize = @as(isize, @bitCast(text.len)) - 1;
    while (index >= 0) {
        const digit_index: usize = @as(usize, @bitCast(index));
        const digit: u32 = @as(u32, text[digit_index] - '0');
        result += digit * multiplier;
        multiplier *= 10;
        index -= 1;
    }

    return result;
}

fn parse_problem(text: []u8, allocator: Allocator) Problem {
    var index: usize = 0;
    while (is_whitespace(text[index])) {
        index += 1;
    }

    const item_count_start: usize = index;
    while (!is_whitespace(text[index])) {
        index += 1;
    }

    const item_count: u32 = parse_u32(text[item_count_start..index]);

    while (is_whitespace(text[index])) {
        index += 1;
    }

    const max_capacity_start: usize = index;
    while (!is_whitespace(text[index])) {
        index += 1;
    }

    const max_capacity: u32 = parse_u32(text[max_capacity_start..index]);

    var item_index: usize = 0;
    var items: []Item = allocator.alloc(Item, @as(usize, item_count)) catch unreachable;
    while (index < text.len and item_index < @as(usize, item_count)) {
        while (is_whitespace(text[index])) {
            index += 1;
        }

        const value_start: usize = index;
        while (!is_whitespace(text[index])) {
            index += 1;
        }

        const value: u32 = parse_u32(text[value_start..index]);

        while (is_whitespace(text[index])) {
            index += 1;
        }

        const weight_start: usize = index;
        while (!is_whitespace(text[index])) {
            index += 1;
        }

        const weight: u32 = parse_u32(text[weight_start..index]);

        items[item_index].value = value;
        items[item_index].weight = weight;
        item_index += 1;
    }

    return Problem{.items = items, .max_capacity = max_capacity};
}

pub fn main() void {
    const file = std.fs.cwd().openFile("data\\ks_lecture_dp_2", .{}) catch {
        std.debug.print("Failed to open file for reading item values and weights", .{});
        return;
    };
    defer file.close();

    const allocator: Allocator = std.heap.page_allocator;
    const file_size = file.getEndPos() catch unreachable;
    var text: []u8 = allocator.alloc(u8, file_size) catch unreachable;
    _ = file.readAll(text) catch unreachable;

    const problem: Problem = parse_problem(text, allocator);
    const items: []Item = problem.items;

    var values: []f32 = allocator.alloc(f32, items.len) catch unreachable;
    for (0..items.len) |index| {
        values[index] = @floatFromInt(items[index].value);
    }

    const greedy_by_value: Solution = greedy_solution(problem, values, value_greater_than, allocator);
    std.debug.print("greedy solution by value:\n", .{});
    print_solution(&greedy_by_value, 0);
    std.debug.print("\n", .{});

    var weights: []f32 = allocator.alloc(f32, items.len) catch unreachable;
    for (0..items.len) |index| {
        weights[index] = @floatFromInt(items[index].weight);
    }

    const greedy_by_weight: Solution = greedy_solution(problem, weights, value_less_than, allocator);
    std.debug.print("greedy solution by weight:\n", .{});
    print_solution(&greedy_by_weight, 0);
    std.debug.print("\n", .{});

    var value_densities: []f32 = allocator.alloc(f32, items.len) catch unreachable;
    for (0..items.len) |index| {
        value_densities[index] = values[index] / weights[index];
    }

    const greedy_by_value_density: Solution = greedy_solution(problem, value_densities, value_greater_than, allocator);
    std.debug.print("greedy solution by value density:\n", .{});
    print_solution(&greedy_by_value_density, 0);
    std.debug.print("\n", .{});

    const dynamic_programming: Solution = dynamic_programming_solution(problem, allocator);
    std.debug.print("dynamic programming solution:\n", .{});
    print_solution(&dynamic_programming, 1);
    std.debug.print("\n", .{});

    const exhaustive_search: Solution = exhaustive_search_solution(problem, allocator);
    std.debug.print("exhaustive search solution:\n", .{});
    print_solution(&exhaustive_search, 1);
    std.debug.print("\n", .{});
    
    const depth_first_branch_and_bound: Solution = depth_first_branch_and_bound_solution(problem, allocator);
    std.debug.print("depth first solution:\n", .{});
    print_solution(&depth_first_branch_and_bound, 1);
    std.debug.print("\n", .{});
    
    const best_first_branch_and_bound: Solution = best_first_branch_and_bound_solution(problem, allocator);
    std.debug.print("best first solution:\n", .{});
    print_solution(&best_first_branch_and_bound, 1);
    std.debug.print("\n", .{});

    const least_discrepancy_branch_and_bound: Solution = least_discrepancy_branch_and_bound_solution(problem, allocator);
    std.debug.print("least discrepancy solution:\n", .{});
    print_solution(&least_discrepancy_branch_and_bound, 1);
}
