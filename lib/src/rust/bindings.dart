@DefaultAsset('package:flutter_smooth_markdown/src/rust/bindings.dart')
library;

import 'dart:ffi';

final class SmrBuffer extends Struct {
  external Pointer<Uint8> data;
  @Size()
  external int length;
  external Pointer<Void> owner;
}

final class SmrMatch extends Struct {
  @Uint32()
  external int consumed;
  @Uint32()
  external int id;
}

typedef InlineCallback =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint16>,
      Size,
      Uint32,
      Uint32,
      Pointer<SmrMatch>,
    );
typedef BlockCallback =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Uint16>>,
      Pointer<Size>,
      Size,
      Uint32,
      Uint32,
      Pointer<SmrMatch>,
    );
typedef InlineContext =
    Int32 Function(Pointer<Void>, Pointer<Uint16>, Size, Int32);
typedef BlockContext =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Uint16>>,
      Pointer<Size>,
      Size,
      Int32,
    );

final class SmrHooks extends Struct {
  external Pointer<Void> context;
  external Pointer<NativeFunction<InlineCallback>> inlineCallback;
  external Pointer<NativeFunction<BlockCallback>> blockCallback;
  external Pointer<NativeFunction<InlineContext>> inlineContext;
  external Pointer<NativeFunction<BlockContext>> blockContext;
}

@Native<Uint32 Function()>(symbol: 'smr_abi_version')
external int abiVersion();
@Native<Int32 Function(Pointer<Uint16>, Size, Uint32, Pointer<SmrBuffer>)>(
  symbol: 'smr_parse_utf16',
)
external int parse(
  Pointer<Uint16> source,
  int length,
  int options,
  Pointer<SmrBuffer> result,
);
@Native<
  Int32 Function(
    Pointer<Uint16>,
    Size,
    Uint32,
    Pointer<SmrHooks>,
    Pointer<SmrBuffer>,
  )
>(symbol: 'smr_parse_with_hooks_utf16')
external int parseWithHooks(
  Pointer<Uint16> source,
  int length,
  int options,
  Pointer<SmrHooks> hooks,
  Pointer<SmrBuffer> result,
);
@Native<
  Int32 Function(
    Pointer<Uint16>,
    Size,
    Uint32,
    Pointer<Uint8>,
    Size,
    Pointer<SmrHooks>,
    Pointer<SmrBuffer>,
  )
>(symbol: 'smr_parse_inline_utf16')
external int parseInline(
  Pointer<Uint16> source,
  int length,
  int options,
  Pointer<Uint8> references,
  int referenceLength,
  Pointer<SmrHooks> hooks,
  Pointer<SmrBuffer> result,
);
@Native<Void Function(Pointer<SmrBuffer>)>(symbol: 'smr_buffer_free')
external void bufferFree(Pointer<SmrBuffer> buffer);
@Native<Int32 Function(Pointer<Uint16>, Size, Uint32, Pointer<SmrBuffer>)>(
  symbol: 'smr_export_html_utf16',
)
external int exportHtml(
  Pointer<Uint16> source,
  int length,
  int options,
  Pointer<SmrBuffer> result,
);
@Native<
  Int32 Function(
    Pointer<Uint16>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<SmrBuffer>,
  )
>(symbol: 'smr_highlight_utf16')
external int highlight(
  Pointer<Uint16> source,
  int length,
  Pointer<Uint8> language,
  int languageLength,
  Pointer<SmrBuffer> result,
);
@Native<Int32 Function(Pointer<Uint8>, Size, Pointer<SmrBuffer>)>(
  symbol: 'smr_highlight_language',
)
external int highlightLanguage(
  Pointer<Uint8> language,
  int length,
  Pointer<SmrBuffer> result,
);
@Native<
  Int32 Function(
    Pointer<Uint16>,
    Size,
    Pointer<Uint8>,
    Size,
    Uint32,
    Pointer<SmrBuffer>,
  )
>(symbol: 'smr_highlight_lines_utf16')
external int highlightLines(
  Pointer<Uint16> source,
  int length,
  Pointer<Uint8> language,
  int languageLength,
  int tabWidth,
  Pointer<SmrBuffer> result,
);
@Native<
  Int32 Function(
    Pointer<Uint16>,
    Size,
    Pointer<Uint8>,
    Size,
    Uint32,
    Pointer<SmrBuffer>,
  )
>(symbol: 'smr_diff_utf16')
external int diff(
  Pointer<Uint16> source,
  int length,
  Pointer<Uint8> language,
  int languageLength,
  int tabWidth,
  Pointer<SmrBuffer> result,
);
@Native<Pointer<Void> Function(Uint32)>(symbol: 'smr_stream_new')
external Pointer<Void> streamNew(int options);
@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Uint16>,
    Size,
    Pointer<SmrBuffer>,
    Pointer<Uint32>,
  )
>(symbol: 'smr_stream_update_utf16')
external int streamUpdate(
  Pointer<Void> session,
  Pointer<Uint16> source,
  int length,
  Pointer<SmrBuffer> result,
  Pointer<Uint32> retained,
);
@Native<Void Function(Pointer<Void>)>(symbol: 'smr_stream_free')
external void streamFree(Pointer<Void> session);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Uint16>,
    Size,
    Pointer<SmrBuffer>,
    Pointer<Uint32>,
  )
>(symbol: 'smr_stream_append_utf16')
external int streamAppend(
  Pointer<Void> session,
  Pointer<Uint16> suffix,
  int length,
  Pointer<SmrBuffer> result,
  Pointer<Uint32> retained,
);
