import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder?.call(context) ?? const SizedBox();
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget?.call(context) ?? const SizedBox();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => placeholder?.call(context) ?? const SizedBox(),
      errorWidget: (context, url, error) =>
          errorWidget?.call(context) ?? const SizedBox(),
    );
  }
}

ImageProvider appNetworkImageProvider(String url) {
  if (kIsWeb) {
    return NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.prefer);
  }
  return CachedNetworkImageProvider(url);
}
