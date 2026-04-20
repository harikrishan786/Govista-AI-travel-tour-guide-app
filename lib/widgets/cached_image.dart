// lib/widgets/cached_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppCachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  const AppCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => _shimmer(isDark),
      errorWidget: (_, __, ___) => errorWidget ?? _placeholder(context),
      fadeInDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _shimmer(bool isDark) {
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      child: Icon(
        Icons.landscape,
        size: 32,
        color: isDark ? Colors.white24 : Colors.grey.shade400,
      ),
    );
  }
}