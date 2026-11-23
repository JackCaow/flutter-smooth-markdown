import '../parser/ast/markdown_node.dart';

/// The built-in disclosure that owns the visibility of its Markdown body.
abstract interface class ReaderDisclosure {
  DetailsNode get details;
  bool expandForReader();
}
