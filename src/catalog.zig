const std = @import("std");
const String = @import("../util.zig").String;

const Allocator = std.mem.Allocator;

const ReplaceMeTableMap = std.StringHashMap(Table);

pub const Catalog = struct {
    temp_storage: ReplaceMeTableMap,

    pub fn init(allocator: Allocator) Catalog {
        var tables = ReplaceMeTableMap.init(allocator);
        var table_data = allocator.alloc(u8, 1024 * 4) catch unreachable;
        std.mem.copy(u8, table_data, &[_]u8{
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
        });

        tables.put("foo", .{
            .data = table_data,
        }) catch unreachable;

        return .{
            .temp_storage = tables,
        };
    }

    pub fn loadTable(self: Catalog, tbl_name: String) ?*Table {
        return self.temp_storage.getPtr(tbl_name);
    }
};

pub const Table = struct {
    data: []u8,
};
