const std = @import("std");
const query = @import("./query.zig");
const Parser = @import("./parse.zig").Parser;
const Catalog = @import("./catalog.zig").Catalog;
const Database = @import("./database.zig").Database;
const String = @import("./util.zig").String;

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn();
    var stderr_file = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr_file);

    const reader = stdin.reader();
    var writer = bw.writer();

    while (true) {
        try writer.print("> ", .{});
        try bw.flush();

        // Get user's input.
        const input = reader.readUntilDelimiterAlloc(allocator, '\n', 1024) catch |err| {
            writer.print("\n", .{}) catch {};
            bw.flush() catch {};

            switch (err) {
                error.EndOfStream => return,
                else => |e| return e,
            }
        };
        defer allocator.free(input);

        try runQuery(writer, input);
        try bw.flush();
    }
}

fn runQuery(writer: anytype, queryStr: String) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, queryStr);
    var ast = try parser.parse();

    var catalog = Catalog.init(allocator);
    _ = catalog;

    try bind(allocator, &ast);
    var query_graph = try plan(allocator, ast);

    var r = &query_graph.root;
    _ = r;
    var it = query_graph.root.iterator();
    while (it.next()) |x| {
        try writer.print("iter: {s}\n", .{x});
    }

    const results = try execute(allocator, query_graph);
    try printResults(writer, results);
}

fn bind(allocator: Allocator, ast: *query.AST) !void {
    _ = ast;
    _ = allocator;
}

const QueryPlan = struct {
    root: PlanNode,
};

const PlanNode = union(enum) {
    const Self = @This();

    scan: ScanTableNode,
    project: ProjectNode,

    debug: DebugNode,

    fn iterator(node: *Self) Iterator {
        return switch (node.*) {
            .scan => |*n| n.iterator(),
            .project => |*n| n.iterator(),
            .debug => |*n| n.iterator(),
        };
    }
};

const Iterator = struct {
    const Self = @This();

    ptr: *anyopaque,
    nextFn: *const fn (*anyopaque) ?[]const u8,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const info = @typeInfo(Ptr);

        if (info != .Pointer) @compileError("ptr must be a pointer");
        if (info.Pointer.size != .One) @compileError("ptr must be a single-item pointer");

        const alignment = info.Pointer.alignment;

        const vtable = struct {
            pub fn nextFn(impl: *anyopaque) ?[]const u8 {
                const self = @ptrCast(Ptr, @alignCast(alignment, impl));
                return @call(.always_inline, info.Pointer.child.next, .{self});
            }
        };

        return .{
            .ptr = ptr,
            .nextFn = vtable.nextFn,
        };
    }

    pub inline fn next(self: Self) ?[]const u8 {
        return self.nextFn(self.ptr);
    }
};

const DebugNode = struct {
    const Self = @This();

    data: []const u8,
    i: u8 = 0,

    pub fn iterator(self: *Self) Iterator {
        return Iterator.init(self);
    }

    pub fn next(self: *Self) ?[]const u8 {
        if (self.i > 10) {
            return null;
        }
        self.i += 1;

        return self.data;
    }
};

const ScanTableNode = struct {
    const Self = @This();

    table_name: String,

    pub fn iterator(self: *Self) Iterator {
        return Iterator.init(self);
    }

    pub fn next(self: *Self) ?[]const u8 {
        _ = self;
        // TODO: Implememnt me!
        return null;
    }
};

const ProjectNode = struct {
    const Self = @This();

    in: *PlanNode,
    columns: []String,

    pub fn iterator(self: *Self) Iterator {
        return Iterator.init(self);
    }

    pub fn next(self: *Self) ?[]const u8 {
        _ = self;
        // TODO: Implememnt me!
        return null;
    }
};

fn plan(allocator: Allocator, ast: query.AST) !QueryPlan {

    // FIXME: This is for debugging only. Please remove once we implememnt query planning.
    switch (ast) {
        .select => |q| {
            std.debug.print("SELECT<\n", .{});
            std.debug.print("\ttable = {s}\n", .{q.table_name});
            std.debug.print("\tcolumns =\n", .{});
            for (q.columns) |col| {
                std.debug.print("\t\t{s}\n", .{col});
            }
            std.debug.print(">\n", .{});
        },
        else => {
            unreachable;
        },
    }

    switch (ast) {
        .select => |q| {
            assert(q.table_name.len > 0);
            var curr: PlanNode = undefined;

            // Start by scanning the table from the SELECT statement.
            curr = .{ .scan = .{
                .table_name = q.table_name,
            } };

            // Next, project any columns specified.
            const project_in = try allocator.create(PlanNode);
            project_in.* = curr;
            curr = .{
                .project = .{
                    .in = project_in,
                    .columns = q.columns,
                },
            };

            return .{ .root = curr };
        },
        else => {
            unreachable;
        },
    }
}

fn execute(allocator: Allocator, dataflow: QueryPlan) !String {
    _ = allocator;
    _ = dataflow;
    return "Hello";
}

fn printResults(writer: anytype, results: String) !void {
    _ = results;
    _ = writer;
    // try writer.print("Results: {s}\n", .{results});
}
