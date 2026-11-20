/// Parser selection for staged upgrades and compatibility rollback.
///
/// Widget/controller/AST APIs are unchanged across backends. Automatic uses
/// Rust on native targets and the established Dart parser on Web. Rust still
/// delegates the Flutter safe-HTML/disclosure extensions to their host parser.
enum MarkdownParserBackend {
  /// Native Rust where available, Dart on Web.
  automatic,

  /// Established Dart behavior, useful when migrating existing content.
  legacyDart,

  /// Require the native shared core; unsupported targets throw explicitly.
  rust,
}
