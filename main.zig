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
    decision_variables: [3]u8
};

fn value_greater_than(values: *const [3]f32, lhs: usize, rhs: usize) bool {
    return values[lhs] > values[rhs];
}

fn greedy_solution(values: *const [3]f32, items: *const [3]Item, max_capacity: u32) Solution {
    var sorted_indices: [3]usize = undefined;
    for (0..3) |index| {
        sorted_indices[index] = index;
    }

    std.sort.block(usize, &sorted_indices, values, comptime value_greater_than);
    // for (sorted_indices) |index| {
    //     std.debug.print("{}, {}\n", .{values[index], index});
    // }

    var solution = Solution{
        .objective_value = 0,
        .optimal = 0,
        .decision_variables = .{0, 0, 0}
    };

    var capacity: u32 = 0;
    for (sorted_indices) |item_index| {
        const item: Item = items[item_index];
        capacity += item.weight;
        if (capacity > max_capacity) {
            break;
        }

        solution.objective_value += item.value;
        solution.decision_variables[item_index] = 1;
    }

    return solution;
}

fn print_solution(solution: *const Solution) void {
    std.debug.print(
        "{} {}\n{} {} {}\n",
        .{
            solution.objective_value,
            solution.optimal,
            solution.decision_variables[0],
            solution.decision_variables[1],
            solution.decision_variables[2]
        }
    );
}

pub fn main() void {
    const items = [3]Item{
        Item{.value = 5, .weight = 4},
        Item{.value = 6, .weight = 5},
        Item{.value = 3, .weight = 2}
    };

    const max_capacity: u32 = 9;

    const values = [3]f32{
        @floatFromInt(items[0].value),
        @floatFromInt(items[1].value),
        @floatFromInt(items[2].value)
    };

    const greedy_by_value: Solution = greedy_solution(&values, &items, max_capacity);
    print_solution(&greedy_by_value);

    const weights = [3]f32{
        @floatFromInt(items[0].weight),
        @floatFromInt(items[1].weight),
        @floatFromInt(items[2].weight)
    };

    const greedy_by_weight: Solution = greedy_solution(&weights, &items, max_capacity);
    print_solution(&greedy_by_weight);

    const value_densities = [3]f32{
        values[0] / weights[0],
        values[1] / weights[1],
        values[2] / weights[2]
    };

    const greedy_by_value_density: Solution = greedy_solution(&value_densities, &items, max_capacity);
    print_solution(&greedy_by_value_density);
}
