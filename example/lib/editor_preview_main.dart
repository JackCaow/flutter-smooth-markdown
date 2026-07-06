import 'package:flutter/material.dart';

import 'editor_demo.dart';

void main() {
  runApp(const EditorPreviewApp());
}

class EditorPreviewApp extends StatelessWidget {
  const EditorPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Editor Preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const EditorDemoPage(),
    );
  }
}
