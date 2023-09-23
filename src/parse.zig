const std = @import("std");
const query = @import("./query.zig");
const String = @import("../util.zig").String;

const Allocator = std.mem.Allocator;

pub const Parser = struct {
    allocator: Allocator,
    input: String,

    pub fn init(allocator: Allocator, input: String) Parser {
        return .{
            .allocator = allocator,
            .input = input,
        };
    }

    pub fn parse(self: *Parser) !query.AST {
        var iter = std.mem.tokenizeScalar(u8, self.input, ' ');
        var columns = std.ArrayList(String).init(self.allocator);

        const ParseState = union(enum) {
            start,
            end,
            err: String,

            parse_select,
            parse_select_from,

            parse_insert,
        };

        var state: ParseState = .start;
        var ast: query.AST = undefined;
        while (iter.next()) |token| {
            switch (state) {
                .start => {
                    if (std.ascii.eqlIgnoreCase(token, "select")) {
                        ast = .{
                            .select = query.SelectStmt{
                                .table_name = "",
                                .columns = undefined,
                            },
                        };
                        state = .parse_select;
                    } else if (std.ascii.eqlIgnoreCase(token, "insert")) {
                        ast = .{
                            .insert = query.InsertStmt{
                                .table_name = "",
                                .columns = undefined,
                                .values = undefined,
                            },
                        };
                        state = .parse_insert;
                    } else {
                        state = .{ .err = "Only insert or select statements allowed" };
                    }
                },

                .parse_select => {
                    if (std.ascii.eqlIgnoreCase(token, "from")) {
                        ast.select.columns = columns.items;
                        state = .parse_select_from;
                        continue;
                    }

                    var len = token.len;
                    if (token[len - 1] == ',') {
                        len -= 1;
                    }

                    try columns.append(token[0..len]);
                },

                .parse_select_from => {
                    ast.select.table_name = token;
                    state = .end;
                },

                .parse_insert => {
                    unreachable;
                },

                .end => {
                    const msg = try std.fmt.allocPrint(self.allocator, "Expected EOF. Got: {s}", .{token});
                    state = .{ .err = msg };
                },

                .err => {
                    break;
                },
            }
        }

        switch (state) {
            .end => {},
            .err => |msg| {
                std.debug.print("Error parsing query: {s}\n", .{msg});
            },
            else => {
                std.debug.print("Unexpected end of query\n", .{});
            },
        }

        return ast;
    }
};
