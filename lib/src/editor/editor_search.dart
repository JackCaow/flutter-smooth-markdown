/// Matches a literal editor query on the original UTF-16 source offsets.
RegExp editorSearchPattern(String query, {bool caseSensitive = false}) =>
    RegExp(RegExp.escape(query), caseSensitive: caseSensitive, unicode: true);
