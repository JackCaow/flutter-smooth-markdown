import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/stream_eligibility.dart';
import 'package:flutter_smooth_markdown/src/rust/ast_adapter.dart';
import 'package:flutter_smooth_markdown/src/rust/bindings.dart' as ffi;
import 'package:flutter_smooth_markdown/src/rust/wire.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List wireFor(String source) {
  final input = calloc<Uint16>(source.isEmpty ? 1 : source.length);
  final buffer = calloc<ffi.SmrBuffer>();
  try {
    input.asTypedList(source.length).setAll(0, source.codeUnits);
    expect(ffi.parse(input, source.length, 3, buffer), 0);
    return Uint8List.fromList(buffer.ref.data.asTypedList(buffer.ref.length));
  } finally {
    ffi.bufferFree(buffer);
    calloc.free(buffer);
    calloc.free(input);
  }
}

void main() {
  test(
    'text-leaf shortcut retains explicit sources and nonstandard field layouts',
    () {
      for (final info in ['', 'metadata']) {
        for (final literal in <String?>['literal🙂', null]) {
          for (final explicit in [false, true]) {
            final bytes = BytesBuilder();
            void word(int value) {
              bytes.add(
                (ByteData(
                  4,
                )..setUint32(0, value, Endian.little)).buffer.asUint8List(),
              );
            }

            void string(String? value) {
              word(value?.length ?? 0xffffffff);
              if (value != null) {
                for (final unit in value.codeUnits) {
                  bytes.add(
                    (ByteData(
                      2,
                    )..setUint16(0, unit, Endian.little)).buffer.asUint8List(),
                  );
                }
              }
            }

            void node(int kind, int children) {
              for (final value in [kind, 0, 4, 0, 0, 0, children]) {
                word(value);
              }
              if (explicit) {
                string('text');
              } else {
                word(0xfffffffe);
              }
              string(info);
              string('');
              string(null);
              string(kind == 12 ? literal : null);
              string('');
              word(0);
            }

            bytes.add(ascii.encode('SMR1'));
            word(2);
            node(0, 1);
            node(12, 0);
            final wire = bytes.toBytes();
            final expected = adaptNodes(
              CoreWireReader(wire, 'SMR1').tree('text').children,
              const {},
            );
            final actual = CoreWireReader(
              wire,
              'SMR1',
            ).markdown('text', const {});
            expect(
              actual.map((n) => n.toJson()).toList(),
              expected.map((n) => n.toJson()).toList(),
            );
          }
        }
      }
    },
  );

  test(
    'direct AST matches the old adapter for all 676 CommonMark/GFM fixtures',
    () {
      var count = 0;
      for (final file in ['commonmark-0.31.2.tsv', 'gfm-extensions.tsv']) {
        for (final line in File(
          'rust-core/tests/fixtures/$file',
        ).readAsLinesSync()) {
          final fields = line.split('\t');
          final source = utf8.decode(base64.decode(fields[1]));
          final bytes = wireFor(source);
          final expected = adaptNodes(
            CoreWireReader(bytes, 'SMR1').tree(source).children,
            const {},
          );
          final actual = CoreWireReader(
            bytes,
            'SMR1',
          ).markdown(source, const {});
          expect(
            actual.map((n) => n.toJson()).toList(),
            expected.map((n) => n.toJson()).toList(),
            reason: '$file fixture ${fields[0]}',
          );
          count++;
        }
      }
      expect(count, 676);
    },
  );

  test(
    'inactive AI hooks match hook-free parsing across the conformance fixtures',
    () {
      final ai = ParserPluginRegistry()
        ..register(const ThinkingPlugin())
        ..register(const ArtifactPlugin())
        ..register(const ToolCallPlugin());
      final parser = MarkdownParser(plugins: ai);
      var eligible = 0;
      for (final file in ['commonmark-0.31.2.tsv', 'gfm-extensions.tsv']) {
        for (final line in File(
          'rust-core/tests/fixtures/$file',
        ).readAsLinesSync()) {
          final fields = line.split('\t');
          final source = utf8.decode(base64.decode(fields[1]));
          if (!canParseIncrementally(source, ai)) continue;
          eligible++;
          expect(
            CoreWireReader(
              wireFor(source),
              'SMR1',
            ).markdown(source, const {}).map((n) => n.toJson()).toList(),
            parser.parse(source).map((n) => n.toJson()).toList(),
            reason: '$file ${fields[0]}',
          );
        }
      }
      expect(eligible, greaterThan(500));
    },
  );

  test(
    'direct decoding rejects unknown kinds, flags and excessive nesting',
    () {
      final original = wireFor('text');
      for (final (offset, value) in [(8, 33), (24, 256)]) {
        final bytes = Uint8List.fromList(original);
        ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
        expect(
          () => CoreWireReader(bytes, 'SMR1').markdown('text', const {}),
          throwsFormatException,
        );
      }
      final bytes = BytesBuilder();
      void word(int value) {
        final b = ByteData(4)..setUint32(0, value, Endian.little);
        bytes.add(b.buffer.asUint8List());
      }

      bytes.add(ascii.encode('SMR1'));
      word(258);
      for (var i = 0; i < 258; i++) {
        for (final value in [
          i == 0
              ? 0
              : i == 257
              ? 12
              : 1,
          0,
          0,
          0,
          0,
          0,
          i == 257 ? 0 : 1,
          0xfffffffe,
          0,
          0,
          0xffffffff,
          0xffffffff,
          0,
          0,
        ]) {
          word(value);
        }
      }
      expect(
        () => CoreWireReader(bytes.toBytes(), 'SMR1').markdown('', const {}),
        throwsFormatException,
      );
    },
  );

  test(
    'decoder preserves partial UTF16, unaligned byte views and truncation checks',
    () {
      const document =
          '# **中文🙂**\r\n\r\n![alt *label*](url)\n\n- [x] a\n- b\n';
      for (var end = 0; end <= document.length; end++) {
        final source = document.substring(0, end), bytes = wireFor(source);
        final unaligned = Uint8List.sublistView(
          Uint8List.fromList([0, ...bytes]),
          1,
        );
        final expected = adaptNodes(
          CoreWireReader(bytes, 'SMR1').tree(source).children,
          const {},
        );
        expect(
          CoreWireReader(
            unaligned,
            'SMR1',
          ).markdown(source, const {}).map((n) => n.toJson()).toList(),
          expected.map((n) => n.toJson()).toList(),
          reason: 'prefix $end',
        );
      }
      final bytes = wireFor('a **bold** text');
      for (var i = 0; i < bytes.length; i++) {
        expect(
          () => CoreWireReader(
            Uint8List.sublistView(bytes, 0, i),
            'SMR1',
          ).markdown('a **bold** text', const {}),
          throwsFormatException,
        );
      }
    },
  );
}
