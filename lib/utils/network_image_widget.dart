import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constant/constant.dart';
import 'app_image_cache.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;

  final bool showShimmer;

  const NetworkImageWidget({super.key, this.height, this.width, this.fit, required this.imageUrl, this.borderRadius, this.errorWidget, this.color, this.showShimmer = true});

  /// The width, in physical pixels, this image should be *decoded* at.
  ///
  /// The photographs on this project are full-size camera and upload output -
  /// measured on live, 512x768, 594x292, 754x670, 1152x768, and one 1.8 MB
  /// file. Flutter decodes to uncompressed ARGB, so a 1152x768 photo occupies
  /// about **3.5 MB of RAM** no matter how small the card drawing it is, and a
  /// home screen holding 45 of them asks for far more than the 100 MB Flutter
  /// gives its image cache. Past that limit the cache evicts and the next scroll
  /// decodes the same picture again - which is the stutter, and part of why a
  /// long browse got slower the longer it went on.
  ///
  /// Decoding straight to the size actually drawn removes that. This is a
  /// bound, never an enlargement: an image smaller than the bound is untouched,
  /// and the bound itself is the full width the widget could occupy, so nothing
  /// is ever decoded smaller than it is displayed.
  int _decodeWidthFor(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double devicePixelRatio = media.devicePixelRatio <= 0 ? 1.0 : media.devicePixelRatio;
    final double screenWidth = media.size.width <= 0 ? 1080.0 : media.size.width;

    // An unconstrained widget can be laid out at most as wide as the screen.
    final double logicalWidth = (width != null && width!.isFinite && width! > 0) ? math.min(width!, screenWidth) : screenWidth;

    return (logicalWidth * devicePixelRatio).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final int decodeWidth = _decodeWidthFor(context);
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppImageCache.manager,
      memCacheWidth: decodeWidth,
      fit: fit ?? BoxFit.fitWidth,
      height: height,
      width: width,
      color: color,
      placeholder:
          (context, url) =>
              showShimmer
                  ? Shimmer.fromColors(
                    baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                    highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
                    child: Container(height: height, width: width, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
                  )
                  : SizedBox(height: height, width: width),
      errorWidget:
          (context, url, error) =>
              errorWidget ??
              CachedNetworkImage(
                imageUrl: Constant.placeHolderImage,
                cacheManager: AppImageCache.manager,
                memCacheWidth: decodeWidth,
                fit: fit ?? BoxFit.fitWidth,
                height: height,
                width: width,
              ),
    );
  }
}
