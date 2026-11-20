import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for image nodes
class ImageBuilder extends MarkdownWidgetBuilder {
  /// Creates a new image builder
  const ImageBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ImageNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final imageNode = node as ImageNode;

    // Use custom builder if provided
    if (context.imageBuilder != null) {
      return _wrapTap(
        context,
        imageNode,
        context.imageBuilder!(imageNode.url, imageNode.alt, imageNode.title),
      );
    }

    if (_embeddedBitmap.hasMatch(imageNode.url)) {
      return _wrapTap(context, imageNode, _EmbeddedBitmap(url: imageNode.url));
    }

    // Check if it's an SVG
    final isSvg = imageNode.url.toLowerCase().endsWith('.svg');
    final isNetwork = imageNode.url.startsWith('http://') ||
        imageNode.url.startsWith('https://');

    // SVG rendering
    if (isSvg) {
      final svgWidget = isNetwork
          ? SvgPicture.network(
              imageNode.url,
              placeholderBuilder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : SvgPicture.asset(
              imageNode.url,
              placeholderBuilder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );
      return _wrapTap(context, imageNode, svgWidget);
    }

    // Default bitmap image rendering
    if (isNetwork) {
      return _wrapTap(
        context,
        imageNode,
        CachedNetworkImage(
          imageUrl: imageNode.url,
          placeholder: (ctx, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (ctx, url, error) => const Icon(Icons.error),
        ),
      );
    }

    // Local image
    return _wrapTap(
      context,
      imageNode,
      Image.asset(
        imageNode.url,
        errorBuilder: (ctx, error, stackTrace) {
          return const Icon(Icons.broken_image);
        },
      ),
    );
  }

  Widget _wrapTap(
    MarkdownRenderContext context,
    ImageNode imageNode,
    Widget child,
  ) {
    // Apply explicit dimensions from HTML <img width/height> attributes.
    var sizedChild = child;
    if (imageNode.width != null || imageNode.height != null) {
      sizedChild = SizedBox(
        width: imageNode.width,
        height: imageNode.height,
        child: child,
      );
    }
    final semanticChild = Semantics(
      image: true,
      label:
          imageNode.alt.isNotEmpty ? imageNode.alt : imageNode.title ?? 'Image',
      child: sizedChild,
    );
    final onTap = context.onTapImage;
    if (onTap == null) return semanticChild;
    return Semantics(
      button: true,
      label: 'Tap to open image',
      child: GestureDetector(
        onTap: () => onTap(imageNode.url, imageNode.alt, imageNode.title),
        child: semanticChild,
      ),
    );
  }
}

final _embeddedBitmap =
    RegExp(r'^data:image/(?:png|jpeg|gif|webp);base64,', caseSensitive: false);

class _EmbeddedBitmap extends StatefulWidget {
  const _EmbeddedBitmap({required this.url});
  final String url;

  @override
  State<_EmbeddedBitmap> createState() => _EmbeddedBitmapState();
}

class _EmbeddedBitmapState extends State<_EmbeddedBitmap> {
  late Uint8List? _bytes = _decode();

  Uint8List? _decode() {
    try {
      return UriData.parse(widget.url).contentAsBytes();
    } on FormatException {
      return null;
    }
  }

  @override
  void didUpdateWidget(_EmbeddedBitmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _bytes = _decode();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return const Icon(Icons.broken_image);
    return Image.memory(bytes,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image));
  }
}
