// lib_widgets_cached_image.dart
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
    this.showShimmerEffect = true,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ تفعيل تحسين الذاكرة (Memory Cache Optimization)
    // بنضرب في 2 أو 3 عشان نحافظ على الجودة في شاشات الـ Retina/High DPI
    // مع التأكد إن الأبعاد محددة وليست Infinite
    final int? memCacheWidth =
        (width != null && width!.isFinite) ? (width! * 2.5).toInt() : null;
    final int? memCacheHeight =
        (height != null && height!.isFinite) ? (height! * 2.5).toInt() : null;

    return ClipRRect(
      borderRadius: borderRadius,
      child: imageUrl.isEmpty
          ? _buildErrorWidget()
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,

              // ✅ أهم نقطة للأداء: تحديد حجم الصورة في الذاكرة
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,

              // ✅ تحديد حجم الصورة في التخزين المؤقت (اختياري لتقليل مساحة الديسك)
              // maxWidthDiskCache: 1000,

              placeholder: (context, url) =>
                  placeholder ?? _buildShimmerPlaceholder(),

              errorWidget: (context, url, error) =>
                  errorWidget ?? _buildErrorWidget(),

              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: const Duration(milliseconds: 300),
            ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    if (!showShimmerEffect) {
      return Container(
        color: Colors.grey[200],
        width: width,
        height: height,
      );
    }
    return Shimmer.fromColors(
      baseColor: shimmerBaseColor ?? Colors.grey[300]!,
      highlightColor: shimmerHighlightColor ?? Colors.grey[100]!,
      child: Container(
        color: Colors.white,
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: _getErrorIconSize(), // حجم أيقونة الخطأ متجاوب
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  double _getErrorIconSize() {
    // حساب حجم الأيقونة بناءً على حجم الكونتينر
    if (width != null &&
        height != null &&
        width!.isFinite &&
        height!.isFinite) {
      return (width! + height!) / 6; // كبرت النسبة شوية عشان تبقى أوضح
    }
    return 30.0;
  }
}
