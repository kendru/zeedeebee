const Catalog = @import("./catalog.zig").Catalog;
const query = @import("./query.zig");

const Binder = struct {
    catalog: *const Catalog,

    pub fn bind(ast: *query.AST) !void {
        _ = ast;
    }
};
