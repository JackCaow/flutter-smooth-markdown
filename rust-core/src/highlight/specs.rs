//! Language tables for the C-family / scripting engine.

use super::clike::{Annot, Interp, Params, Spec, Str, BASE};

const C_STRINGS: &[Str] = &[Str::new("\"", "\""), Str::new("'", "'")];

const JS_KEYWORDS: &[&str] = &["async", "await", "debugger", "delete", "get", "set", "static", "with", "yield", "of", "accessor", "constructor"];
const JS_CONTROL: &[&str] = &["break", "case", "catch", "continue", "default", "do", "else", "finally", "for", "if", "return", "switch", "throw", "try", "while"];
const JS_STRINGS: &[Str] = &[
    Str::new("`", "`").multi().interp(Interp::DollarBrace),
    Str::new("\"", "\""),
    Str::new("'", "'"),
];

pub(crate) const JAVASCRIPT: Spec = Spec {
    name: "javascript",
    strings: JS_STRINGS,
    keywords: JS_KEYWORDS,
    control: JS_CONTROL,
    declaration: &["const", "export", "extends", "let", "var"],
    import: &["import", "from", "as"],
    operator_words: &["in", "instanceof", "new", "typeof", "void", "delete"],
    constants: &["null", "undefined", "NaN", "Infinity"],
    special_vars: &["this", "super", "arguments"],
    builtin_types: &["Array", "Boolean", "Date", "Error", "Function", "Map", "Number", "Object", "Promise", "RegExp", "Set", "String", "Symbol", "WeakMap", "WeakSet", "BigInt", "JSON", "Math"],
    fn_decl: &["function"],
    type_decl: &["class"],
    var_decl: &["const", "let", "var"],
    type_after: &["new"],
    params: Params::Names,
    annotation: Annot::At,
    capitalized_types: false,
    jsx: true,
    regex: true,
    ..BASE
};

const TS_DECL: &[&str] = &["const", "export", "extends", "implements", "let", "var", "declare", "abstract", "readonly", "public", "private", "protected", "override", "namespace", "module", "enum"];
const TS_TYPES: &[&str] = &["any", "unknown", "never", "string", "number", "boolean", "bigint", "symbol", "object", "void", "undefined", "null",
    "Array", "Record", "Partial", "Required", "Readonly", "Pick", "Omit", "Promise", "Map", "Set", "ReadonlyArray", "Exclude", "Extract", "ReturnType", "Awaited", "NonNullable", "Parameters"];

pub(crate) const TYPESCRIPT: Spec = Spec {
    name: "typescript",
    keywords: &["async", "await", "debugger", "delete", "get", "set", "static", "with", "yield", "of", "asserts", "infer", "is", "satisfies", "unique", "accessor", "constructor"],
    declaration: TS_DECL,
    operator_words: &["in", "instanceof", "new", "typeof", "keyof", "void", "delete", "as"],
    import: &["import", "from"],
    builtin_types: TS_TYPES,
    type_decl: &["class", "interface", "type", "enum", "namespace"],
    type_after: &["new", "extends", "implements", "as", "satisfies", "keyof", "is"],
    params: Params::NameColonType,
    arrow_return: false,
    jsx: false,
    capitalized_types: true,
    ..JAVASCRIPT
};

pub(crate) const TSX: Spec = Spec { name: "tsx", jsx: true, ..TYPESCRIPT };

pub(crate) const KOTLIN: Spec = Spec {
    name: "kotlin",
    nested_comments: true,
    doc_comments: &["/**"],
    strings: &[
        Str::new("\"\"\"", "\"\"\"").raw().multi().interp(Interp::DollarIdent),
        Str::new("\"", "\"").interp(Interp::DollarIdent),
        Str::new("'", "'"),
    ],
    keywords: &["by", "companion", "constructor", "init", "get", "set", "field", "where", "out", "vararg", "reified", "crossinline", "noinline", "tailrec", "operator", "infix", "inline", "suspend", "external", "expect", "actual", "lateinit", "const", "dynamic"],
    control: &["break", "continue", "do", "else", "for", "if", "return", "throw", "try", "catch", "finally", "when", "while"],
    declaration: &["abstract", "annotation", "data", "enum", "final", "inner", "internal", "open", "override", "private", "protected", "public", "sealed", "value"],
    import: &["import", "package", "as"],
    operator_words: &["in", "is", "as", "!in", "!is"],
    constants: &["null"],
    special_vars: &["this", "super", "it", "field"],
    builtin_types: &["Any", "Unit", "Nothing", "Int", "Long", "Short", "Byte", "Double", "Float", "Char", "Boolean", "String", "Array", "List", "MutableList", "Map", "MutableMap", "Set", "MutableSet", "Sequence", "Pair", "Triple", "IntArray", "ByteArray", "Number", "Comparable", "Iterable", "Collection", "CharSequence", "Throwable", "Exception"],
    fn_decl: &["fun"],
    type_decl: &["class", "interface", "object", "typealias"],
    var_decl: &["val", "var"],
    type_after: &["is", "as", "as?", ":"],
    params: Params::NameColonType,
    annotation: Annot::At,
    ..BASE
};

pub(crate) const SWIFT: Spec = Spec {
    name: "swift",
    nested_comments: true,
    doc_comments: &["/**", "///"],
    strings: &[
        Str::new("\"\"\"", "\"\"\"").multi().interp(Interp::BackslashParen),
        Str::new("\"", "\"").interp(Interp::BackslashParen),
    ],
    keywords: &["associatedtype", "async", "await", "convenience", "didSet", "dynamic", "get", "set", "indirect", "init", "deinit", "inout", "lazy", "mutating", "nonmutating", "optional", "required", "rethrows", "throws", "weak", "unowned", "willSet", "some", "any", "subscript", "where", "consuming", "borrowing", "isolated", "nonisolated", "macro"],
    control: &["break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "repeat", "return", "switch", "throw", "try", "while", "in"],
    declaration: &["fileprivate", "final", "internal", "open", "override", "private", "public", "static", "class", "extension", "operator", "precedencegroup"],
    import: &["import"],
    operator_words: &["is", "as"],
    constants: &["nil"],
    special_vars: &["self", "Self", "super"],
    builtin_types: &["Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Double", "Float", "CGFloat", "Bool", "String", "Character", "Array", "Dictionary", "Set", "Optional", "Result", "Void", "Never", "Any", "AnyObject", "Error", "Data", "URL", "Date", "UUID", "Substring"],
    fn_decl: &["func"],
    type_decl: &["struct", "enum", "protocol", "actor", "typealias", "class", "extension"],
    var_decl: &["let", "var"],
    type_after: &["is", "as"],
    params: Params::NameColonType,
    annotation: Annot::At,
    arrow_return: true,
    swift_raw: true,
    ..BASE
};

const JAVA_CONTROL: &[&str] = &["break", "case", "catch", "continue", "default", "do", "else", "finally", "for", "if", "return", "switch", "throw", "try", "while", "yield"];

pub(crate) const JAVA: Spec = Spec {
    name: "java",
    strings: &[Str::new("\"\"\"", "\"\"\"").multi(), Str::new("\"", "\""), Str::new("'", "'")],
    keywords: &["assert", "native", "strictfp", "synchronized", "transient", "volatile", "throws", "permits", "sealed", "non-sealed", "var", "default"],
    control: JAVA_CONTROL,
    declaration: &["abstract", "extends", "final", "implements", "private", "protected", "public", "static"],
    import: &["import", "package"],
    operator_words: &["instanceof", "new"],
    constants: &["null"],
    special_vars: &["this", "super"],
    builtin_types: &["boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String", "Object", "Integer", "Long", "Double", "Boolean", "List", "Map", "Set", "Optional"],
    type_decl: &["class", "interface", "enum", "record", "@interface"],
    type_after: &["new", "extends", "implements", "instanceof", "throws"],
    params: Params::TypeName,
    annotation: Annot::At,
    ..BASE
};

pub(crate) const GROOVY: Spec = Spec {
    name: "groovy",
    strings: &[
        Str::new("\"\"\"", "\"\"\"").multi().interp(Interp::DollarIdent),
        Str::new("'''", "'''").multi(),
        Str::new("\"", "\"").interp(Interp::DollarIdent),
        Str::new("'", "'"),
    ],
    keywords: &["def", "as", "in", "trait", "assert", "threadsafe"],
    builtin_types: &["boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String", "Object", "List", "Map"],
    fn_decl: &["def"],
    params: Params::TypeName,
    capitalized_types: true,
    ..JAVA
};

pub(crate) const SCALA: Spec = Spec {
    name: "scala",
    nested_comments: true,
    strings: &[
        Str::new("s\"\"\"", "\"\"\"").multi().interp(Interp::DollarIdent),
        Str::new("f\"", "\"").interp(Interp::DollarIdent),
        Str::new("s\"", "\"").interp(Interp::DollarIdent),
        Str::new("\"\"\"", "\"\"\"").raw().multi(),
        Str::new("\"", "\""),
        Str::new("'", "'"),
    ],
    keywords: &["implicit", "lazy", "given", "using", "extension", "inline", "opaque", "transparent", "derives", "forSome", "with"],
    control: &["case", "catch", "do", "else", "finally", "for", "if", "match", "return", "then", "throw", "try", "while", "yield"],
    declaration: &["abstract", "final", "override", "private", "protected", "sealed", "extends"],
    import: &["import", "package", "export"],
    operator_words: &["new"],
    constants: &["null"],
    special_vars: &["this", "super"],
    builtin_types: &["Int", "Long", "Double", "Float", "Boolean", "Char", "String", "Unit", "Any", "AnyRef", "Nothing", "Option", "Some", "List", "Seq", "Map", "Set", "Vector", "Either", "Future"],
    fn_decl: &["def"],
    type_decl: &["class", "trait", "object", "enum", "type"],
    var_decl: &["val", "var"],
    type_after: &["extends", "with", "new"],
    params: Params::NameColonType,
    annotation: Annot::At,
    ..BASE
};

const C_KEYWORDS: &[&str] = &["auto", "const", "extern", "inline", "register", "restrict", "sizeof", "static", "volatile", "_Atomic", "_Alignas", "_Noreturn", "typedef"];
const C_CONTROL: &[&str] = &["break", "case", "continue", "default", "do", "else", "for", "goto", "if", "return", "switch", "while"];
const C_TYPES: &[&str] = &["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "bool", "_Bool", "size_t", "ssize_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "uintptr_t", "intptr_t", "ptrdiff_t", "FILE", "wchar_t"];

pub(crate) const C: Spec = Spec {
    name: "c",
    strings: C_STRINGS,
    keywords: C_KEYWORDS,
    control: C_CONTROL,
    constants: &["NULL", "EOF", "true", "false"],
    builtin_types: C_TYPES,
    type_decl: &["struct", "union", "enum"],
    params: Params::TypeName,
    capitalized_types: false,
    preproc: true,
    ..BASE
};

pub(crate) const CPP: Spec = Spec {
    name: "cpp",
    keywords: &["alignas", "alignof", "auto", "const", "constexpr", "consteval", "constinit", "decltype", "explicit", "extern", "friend", "inline", "mutable", "noexcept", "operator", "register", "static", "static_assert", "template", "thread_local", "typedef", "typename", "using", "virtual", "volatile", "concept", "requires", "co_await", "co_return", "co_yield", "override", "final"],
    control: &["break", "case", "catch", "continue", "default", "do", "else", "for", "goto", "if", "return", "switch", "throw", "try", "while"],
    declaration: &["private", "protected", "public"],
    import: &["namespace", "import", "module", "export"],
    operator_words: &["new", "delete", "sizeof", "typeid", "static_cast", "dynamic_cast", "const_cast", "reinterpret_cast", "and", "or", "not"],
    constants: &["nullptr", "NULL"],
    special_vars: &["this"],
    builtin_types: &["void", "char", "char8_t", "char16_t", "char32_t", "short", "int", "long", "float", "double", "signed", "unsigned", "bool", "wchar_t", "size_t", "string", "vector", "map", "unordered_map", "set", "unique_ptr", "shared_ptr", "optional", "string_view", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"],
    type_decl: &["class", "struct", "union", "enum"],
    type_after: &["new"],
    cpp_raw: true,
    capitalized_types: true,
    ..C
};

pub(crate) const OBJC: Spec = Spec {
    name: "objectivec",
    strings: &[Str::new("@\"", "\""), Str::new("\"", "\""), Str::new("'", "'")],
    keywords: &["@interface", "@implementation", "@end", "@property", "@synthesize", "@protocol", "@class", "@selector", "@autoreleasepool", "nonatomic", "atomic", "strong", "weak", "assign", "copy", "readonly", "readwrite", "nullable", "nonnull", "instancetype", "id"],
    constants: &["nil", "Nil", "NULL", "YES", "NO"],
    special_vars: &["self", "super"],
    builtin_types: &["void", "char", "short", "int", "long", "float", "double", "BOOL", "NSInteger", "NSUInteger", "CGFloat", "NSString", "NSArray", "NSDictionary", "NSNumber", "NSObject", "id", "SEL"],
    capitalized_types: true,
    ..C
};

pub(crate) const CSHARP: Spec = Spec {
    name: "csharp",
    strings: &[
        Str::new("\"\"\"", "\"\"\"").multi(),
        Str::new("$@\"", "\"").raw().multi().interp(Interp::Brace),
        Str::new("@$\"", "\"").raw().multi().interp(Interp::Brace),
        Str::new("$\"", "\"").interp(Interp::Brace),
        Str::new("@\"", "\"").raw().multi(),
        Str::new("\"", "\""),
        Str::new("'", "'"),
    ],
    keywords: &["abstract", "async", "await", "base", "checked", "const", "event", "explicit", "extern", "fixed", "implicit", "in", "out", "ref", "params", "readonly", "sealed", "stackalloc", "unchecked", "unsafe", "virtual", "volatile", "get", "set", "init", "value", "where", "partial", "required", "record", "with", "dynamic", "operator", "global"],
    control: &["break", "case", "catch", "continue", "default", "do", "else", "finally", "for", "foreach", "goto", "if", "lock", "return", "switch", "throw", "try", "while", "yield", "when"],
    declaration: &["internal", "override", "private", "protected", "public", "static", "var", "delegate"],
    import: &["using", "namespace"],
    operator_words: &["as", "is", "new", "typeof", "sizeof", "nameof", "default"],
    constants: &["null"],
    special_vars: &["this", "base"],
    builtin_types: &["bool", "byte", "sbyte", "char", "decimal", "double", "float", "int", "uint", "long", "ulong", "short", "ushort", "object", "string", "void", "nint", "nuint", "String", "List", "Dictionary", "Task", "IEnumerable"],
    type_decl: &["class", "struct", "interface", "enum", "record"],
    type_after: &["new", "as", "is", ":"],
    params: Params::TypeName,
    annotation: Annot::None,
    capitalized_types: true,
    preproc: true,
    ..BASE
};

pub(crate) const GO: Spec = Spec {
    name: "go",
    doc_comments: &[],
    strings: &[Str::new("`", "`").raw().multi(), Str::new("\"", "\""), Str::new("'", "'")],
    keywords: &["chan", "defer", "go", "map", "select", "fallthrough"],
    control: &["break", "case", "continue", "default", "else", "for", "goto", "if", "range", "return", "switch"],
    declaration: &["const", "var"],
    import: &["import", "package"],
    constants: &["nil", "iota"],
    builtin_types: &["bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "any", "comparable"],
    fn_decl: &["func"],
    type_decl: &["type", "struct", "interface"],
    var_decl: &["var", "const"],
    params: Params::NameType,
    capitalized_types: false,
    ..BASE
};

pub(crate) const RUST: Spec = Spec {
    name: "rust",
    nested_comments: true,
    doc_comments: &["///", "//!", "/**", "/*!"],
    strings: &[Str::new("b\"", "\"").multi(), Str::new("\"", "\"").multi()],
    keywords: &["as", "async", "await", "const", "crate", "dyn", "extern", "move", "mut", "ref", "static", "unsafe", "where", "macro_rules", "union", "default"],
    control: &["break", "continue", "else", "for", "if", "in", "loop", "match", "return", "while", "yield"],
    declaration: &["pub", "impl"],
    import: &["use", "mod", "extern"],
    constants: &["None"],
    special_vars: &["self", "Self", "super", "crate"],
    builtin_types: &["bool", "char", "str", "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64", "String", "Vec", "Option", "Result", "Box", "Rc", "Arc", "HashMap", "HashSet", "BTreeMap", "Cow", "Some", "Ok", "Err"],
    fn_decl: &["fn"],
    type_decl: &["struct", "enum", "trait", "type", "union", "impl"],
    var_decl: &["let"],
    type_after: &["as", "dyn", "impl"],
    params: Params::NameColonType,
    annotation: Annot::RustAttr,
    arrow_return: true,
    rust: true,
    ..BASE
};

pub(crate) const PYTHON: Spec = Spec {
    name: "python",
    line_comments: &["#"],
    block_comment: None,
    doc_comments: &[],
    strings: &[
        Str::new("f\"\"\"", "\"\"\"").multi().interp(Interp::Brace),
        Str::new("f'''", "'''").multi().interp(Interp::Brace),
        Str::new("rf\"", "\"").raw().interp(Interp::Brace),
        Str::new("fr\"", "\"").raw().interp(Interp::Brace),
        Str::new("f\"", "\"").interp(Interp::Brace),
        Str::new("f'", "'").interp(Interp::Brace),
        Str::new("r\"\"\"", "\"\"\"").raw().multi(),
        Str::new("r'''", "'''").raw().multi(),
        Str::new("b\"\"\"", "\"\"\"").multi(),
        Str::new("\"\"\"", "\"\"\"").multi(),
        Str::new("'''", "'''").multi(),
        Str::new("rb\"", "\"").raw(),
        Str::new("br\"", "\"").raw(),
        Str::new("r\"", "\"").raw(),
        Str::new("r'", "'").raw(),
        Str::new("b\"", "\""),
        Str::new("b'", "'"),
        Str::new("\"", "\""),
        Str::new("'", "'"),
    ],
    keywords: &["async", "await", "global", "nonlocal", "assert", "del", "pass", "lambda", "with", "yield", "match", "case", "type"],
    control: &["break", "continue", "elif", "else", "except", "finally", "for", "if", "raise", "return", "try", "while"],
    import: &["import", "from", "as"],
    operator_words: &["and", "in", "is", "not", "or"],
    booleans: &["True", "False"],
    constants: &["None", "NotImplemented", "Ellipsis", "__name__", "__file__"],
    special_vars: &["self", "cls"],
    builtin_types: &["int", "float", "complex", "str", "bytes", "bytearray", "bool", "list", "tuple", "dict", "set", "frozenset", "object", "type", "Any", "Optional", "Union", "List", "Dict", "Tuple", "Callable", "Iterable", "Iterator", "Sequence", "Mapping"],
    fn_decl: &["def"],
    type_decl: &["class"],
    params: Params::NameColonType,
    annotation: Annot::At,
    arrow_return: true,
    ..BASE
};

pub(crate) const RUBY: Spec = Spec {
    name: "ruby",
    line_comments: &["#"],
    block_comment: Some(("=begin", "=end")),
    doc_comments: &[],
    strings: &[
        Str::new("\"", "\"").multi().interp(Interp::HashBrace),
        Str::new("'", "'").multi(),
        Str::new("`", "`").interp(Interp::HashBrace),
        Str::new("%w[", "]").raw(),
        Str::new("%i[", "]").raw(),
    ],
    keywords: &["alias", "begin", "defined?", "end", "ensure", "rescue", "retry", "redo", "undef", "yield", "then", "do", "attr_reader", "attr_writer", "attr_accessor", "private", "protected", "public", "include", "extend", "require", "require_relative"],
    control: &["break", "case", "else", "elsif", "for", "if", "in", "next", "return", "unless", "until", "when", "while", "raise"],
    operator_words: &["and", "not", "or"],
    constants: &["nil", "__FILE__", "__LINE__"],
    special_vars: &["self", "super"],
    fn_decl: &["def"],
    type_decl: &["class", "module"],
    params: Params::Names,
    capitalized_types: true,
    regex: true,
    ..BASE
};

pub(crate) const PHP: Spec = Spec {
    name: "php",
    line_comments: &["//", "#"],
    strings: &[Str::new("\"", "\"").multi().interp(Interp::DollarIdent), Str::new("'", "'").multi()],
    keywords: &["abstract", "clone", "const", "echo", "enum", "final", "global", "insteadof", "list", "print", "readonly", "static", "trait", "var", "yield", "match", "fn"],
    control: &["break", "case", "catch", "continue", "declare", "default", "do", "else", "elseif", "endfor", "endforeach", "endif", "endswitch", "endwhile", "finally", "for", "foreach", "goto", "if", "return", "switch", "throw", "try", "while"],
    declaration: &["extends", "implements", "private", "protected", "public"],
    import: &["namespace", "use", "require", "require_once", "include", "include_once"],
    operator_words: &["and", "or", "xor", "instanceof", "new", "as", "insteadof"],
    booleans: &["true", "false", "TRUE", "FALSE"],
    constants: &["null", "NULL"],
    special_vars: &["$this", "self", "parent", "static"],
    builtin_types: &["int", "float", "string", "bool", "array", "object", "callable", "iterable", "void", "mixed", "never"],
    fn_decl: &["function"],
    type_decl: &["class", "interface", "trait", "enum"],
    type_after: &["new", "extends", "implements", "instanceof"],
    params: Params::Names,
    annotation: Annot::None,
    dollar_idents: true,
    ..BASE
};

pub(crate) const DART: Spec = Spec {
    name: "dart",
    strings: &[
        Str::new("r\"\"\"", "\"\"\"").raw().multi(),
        Str::new("r'''", "'''").raw().multi(),
        Str::new("\"\"\"", "\"\"\"").multi().interp(Interp::DollarIdent),
        Str::new("'''", "'''").multi().interp(Interp::DollarIdent),
        Str::new("r\"", "\"").raw(),
        Str::new("r'", "'").raw(),
        Str::new("\"", "\"").interp(Interp::DollarIdent),
        Str::new("'", "'").interp(Interp::DollarIdent),
    ],
    keywords: &["async", "await", "covariant", "external", "factory", "get", "set", "late", "operator", "required", "sync", "yield", "with", "on", "show", "hide", "deferred", "base", "sealed", "interface", "mixin"],
    control: &["assert", "break", "case", "catch", "continue", "default", "do", "else", "finally", "for", "if", "rethrow", "return", "switch", "throw", "try", "while"],
    declaration: &["abstract", "const", "extends", "final", "implements", "static", "var", "typedef"],
    import: &["import", "export", "library", "part", "as"],
    operator_words: &["is", "as", "in", "new"],
    constants: &["null"],
    special_vars: &["this", "super"],
    builtin_types: &["int", "double", "num", "bool", "String", "List", "Map", "Set", "Future", "Stream", "void", "dynamic", "Object", "Iterable", "Never", "Null", "Function"],
    type_decl: &["class", "enum", "extension", "mixin"],
    type_after: &["new", "extends", "implements", "with", "is", "as", "on"],
    params: Params::TypeName,
    annotation: Annot::At,
    ..BASE
};

pub(crate) const LUA: Spec = Spec {
    name: "lua",
    line_comments: &["--"],
    block_comment: Some(("--[[", "]]")),
    doc_comments: &["---"],
    strings: &[Str::new("[[", "]]").raw().multi(), Str::new("\"", "\""), Str::new("'", "'")],
    keywords: &["local", "end", "do", "then", "goto"],
    control: &["break", "else", "elseif", "for", "if", "in", "repeat", "return", "until", "while"],
    operator_words: &["and", "not", "or"],
    constants: &["nil"],
    special_vars: &["self"],
    fn_decl: &["function"],
    var_decl: &["local"],
    params: Params::Names,
    capitalized_types: false,
    ..BASE
};

pub(crate) const R: Spec = Spec {
    name: "r",
    line_comments: &["#"],
    block_comment: None,
    doc_comments: &["#'"],
    strings: C_STRINGS,
    keywords: &["function", "in", "next", "repeat"],
    control: &["break", "else", "for", "if", "return", "while"],
    booleans: &["TRUE", "FALSE", "T", "F"],
    constants: &["NULL", "NA", "NaN", "Inf", "NA_integer_", "NA_real_", "NA_character_"],
    params: Params::Names,
    capitalized_types: false,
    ..BASE
};

pub(crate) const SQL: Spec = Spec {
    name: "sql",
    line_comments: &["--", "#"],
    doc_comments: &[],
    strings: &[Str::new("'", "'"), Str::new("\"", "\"").special(), Str::new("`", "`").special()],
    keywords: &["add", "all", "alter", "any", "asc", "between", "by", "cascade", "check", "column", "constraint", "create", "cross", "database", "default", "delete", "desc", "distinct", "drop", "exists", "foreign", "from", "full", "group", "having", "index", "inner", "insert", "into", "join", "key", "left", "limit", "offset", "on", "order", "outer", "primary", "references", "right", "select", "set", "table", "top", "truncate", "union", "unique", "update", "values", "view", "where", "with", "returning", "begin", "commit", "rollback", "transaction", "grant", "revoke", "trigger", "procedure", "function", "returns", "replace", "if", "temporary", "temp", "auto_increment", "autoincrement", "over", "partition", "window", "recursive", "conflict", "do", "nothing", "using", "lateral", "fetch", "first", "next", "rows", "only", "explain", "analyze"],
    control: &["case", "when", "then", "else", "end", "return", "loop", "while", "for"],
    operator_words: &["and", "or", "not", "in", "is", "like", "ilike", "as", "between", "exists"],
    booleans: &["true", "false"],
    constants: &["null", "current_timestamp", "current_date"],
    builtin_types: &["int", "integer", "bigint", "smallint", "tinyint", "serial", "bigserial", "decimal", "numeric", "real", "float", "double", "char", "varchar", "text", "blob", "boolean", "bool", "date", "time", "timestamp", "timestamptz", "interval", "json", "jsonb", "uuid", "bytea"],
    params: Params::Names,
    capitalized_types: false,
    case_insensitive: true,
    ..BASE
};

pub(crate) const GRAPHQL: Spec = Spec {
    name: "graphql",
    line_comments: &["#"],
    block_comment: None,
    doc_comments: &[],
    strings: &[Str::new("\"\"\"", "\"\"\"").multi().special(), Str::new("\"", "\"")],
    keywords: &["query", "mutation", "subscription", "fragment", "on", "schema", "extend", "directive", "repeatable", "implements"],
    constants: &["null"],
    builtin_types: &["Int", "Float", "String", "Boolean", "ID"],
    type_decl: &["type", "interface", "union", "enum", "input", "scalar"],
    type_after: &["on", "implements"],
    params: Params::NameColonType,
    annotation: Annot::At,
    ..BASE
};

pub(crate) const PROTO: Spec = Spec {
    name: "proto",
    strings: C_STRINGS,
    keywords: &["syntax", "option", "repeated", "optional", "required", "reserved", "returns", "stream", "to", "max", "extensions", "oneof", "map", "edition"],
    import: &["import", "package", "public", "weak"],
    builtin_types: &["double", "float", "int32", "int64", "uint32", "uint64", "sint32", "sint64", "fixed32", "fixed64", "sfixed32", "sfixed64", "bool", "string", "bytes"],
    fn_decl: &["rpc"],
    type_decl: &["message", "enum", "service", "extend"],
    params: Params::TypeName,
    ..BASE
};

pub(crate) const ZIG: Spec = Spec {
    name: "zig",
    block_comment: None,
    doc_comments: &["///", "//!"],
    strings: &[Str::new("\"", "\""), Str::new("'", "'")],
    keywords: &["align", "allowzero", "and", "anyframe", "anytype", "asm", "async", "await", "callconv", "comptime", "defer", "errdefer", "export", "extern", "inline", "noalias", "noinline", "nosuspend", "or", "packed", "pub", "threadlocal", "usingnamespace", "volatile", "linksection"],
    control: &["break", "catch", "continue", "else", "for", "if", "orelse", "resume", "return", "suspend", "switch", "try", "unreachable", "while"],
    declaration: &["const", "var"],
    constants: &["null", "undefined"],
    builtin_types: &["bool", "f16", "f32", "f64", "f128", "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "void", "noreturn", "type", "anyerror", "comptime_int", "comptime_float"],
    fn_decl: &["fn"],
    type_decl: &["struct", "enum", "union", "error", "opaque"],
    var_decl: &["const", "var"],
    params: Params::NameColonType,
    ..BASE
};
