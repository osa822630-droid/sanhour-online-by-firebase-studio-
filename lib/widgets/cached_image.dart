// lib/widgets/cached_image.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final IconData fallbackIcon;
  final bool showShimmerEffect;
  final Color? shimmerBaseColor;
  final Color? shimmerHighlightColor;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
    this.errorWidget,
    this.fallbackIcon = Icons.image_outlined,
    this.showShimmerEffect = true,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.5, 3.0);

    final int? memCacheWidth =
        (width != null && width!.isFinite && width! > 0)
            ? (width! * dpr).round()
            : null;
    final int? memCacheHeight =
        (height != null && height!.isFinite && height! > 0)
            ? (height! * dpr).round()
            : null;

    return ClipRRect(
      borderRadius: borderRadius,
      child: imageUrl.trim().isEmpty
          ? (errorWidget ?? _buildErrorWidget(isDark))
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,
              placeholder: (context, url) =>
                  placeholder ?? _buildShimmerPlaceholder(isDark),
              errorWidget: (context, url, error) =>
                  errorWidget ?? _buildErrorWidget(isDark),
              fadeInDuration: const Duration(milliseconds: 250),
              fadeOutDuration: const Duration(milliseconds: 250),
            ),
    );
  }

  Widget _buildShimmerPlaceholder(bool isDark) {
    final baseColor =
        shimmerBaseColor ?? (isDark ? Colors.grey[850]! : Colors.grey[300]!);
    final highlightColor = shimmerHighlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    if (!showShimmerEffect) {
      return Container(
        color: baseColor,
        width: width,
        height: height,
      );
    }
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF252538) : Colors.grey[200],
      child: Center(
        child: Icon(
          fallbackIcon,
          size: _getErrorIconSize(),
          color: isDark ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
    );
  }

  double _getErrorIconSize() {
    if (width != null &&
        height != null &&
        width!.isFinite &&
        height!.isFinite) {
      return ((width! + height!) / 6).clamp(18.0, 48.0);
    }
    return 30.0;
  }
}
