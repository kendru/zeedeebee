const String = @import("../util.zig").String;

pub const AST = union(enum) {
    select: SelectStmt,
    insert: InsertStmt,
};

pub const SelectStmt = struct {
    table_name: MaybeAnnotated(String),
    columns: []MaybeAnnotated(String),
};

pub const InsertStmt = struct {
    table_name: String,
    columns: []String,
    values: []i64,
};

const Bindable(T: comptime type) type {
    return union(enum) {
        unbound: T,
        bound: Binding(T),
    }
};

const Binding(T: comptime type) type {
    return struct {
        value: T,
        data_type: DataType,
        obj_ref: ObjectRef,
    };
}

const DataType = enum {
    .int64,
    .float64,
    .bool,
    .string,
};

const ObjRef = u64;
