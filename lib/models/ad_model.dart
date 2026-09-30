// lib/models/ad_model.dart
// ✅ إضافة دعم الصور المتعددة: imageUrls (List<String>) + coverImageIndex (int)
// ✅ توافق خلفي كامل: getter imageUrl يعود بصورة الغلاف دائماً
// ✅ fromMap() يقرأ imageUrls أو يُحوِّل imageUrl القديمة لقائمة تلقائياً
import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;

  // ✅ نظام الصور المتعدد
  final List<String> imageUrls;
  final int coverImageIndex;

  final String text;
  final String actionButtonText;
  final String? targetType;
  final String? targetId;
  final DateTime? expiresAt;
  final bool isActive;
  final int clickCount;
  final String? shopId;
  final bool isMainActive;
  final List<String> displayLocations;

  AdModel({
    required this.id,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    this.text = '',
    this.actionButtonText = 'اذهب للتفاصيل',
    this.targetType = 'none',
    this.targetId,
    this.expiresAt,
    this.isActive = true,
    this.clickCount = 0,
    this.shopId,
    this.isMainActive = false,
    this.displayLocations = const ['home', 'splash', 'ads_screen'],
  });

  // ✅ Getter للتوافق مع الكود القديم الذي يقرأ ad.imageUrl مباشرة
  String get imageUrl {
    if (imageUrls.isEmpty) return '';
    final idx = coverImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  factory AdModel.fromMap(Map<String, dynamic> map, String id) {
    // قراءة imageUrls مع التوافق الخلفي
    List<String> parsedImageUrls = [];
    final rawImageUrls = map['imageUrls'];
    if (rawImageUrls != null) {
      parsedImageUrls = List<String>.from(rawImageUrls as List);
    }
    if (parsedImageUrls.isEmpty) {
      final legacyUrl = map['imageUrl'] as String? ?? '';
      if (legacyUrl.isNotEmpty) parsedImageUrls = [legacyUrl];
    }

    final int rawCover = (map['coverImageIndex'] as int? ?? 0);
    final int parsedCoverIndex = parsedImageUrls.isEmpty
        ? 0
        : rawCover.clamp(0, parsedImageUrls.length - 1);

    return AdModel(
      id: id,
      imageUrls: parsedImageUrls,
      coverImageIndex: parsedCoverIndex,
      text: map['text'] ?? '',
      actionButtonText: map['actionButtonText'] ?? 'اذهب للتفاصيل',
      targetType: map['targetType'] ?? 'none',
      targetId: map['targetId'],
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      clickCount: map['clickCount'] ?? 0,
      shopId: map['shopId'],
      isMainActive: map['isMainActive'] ?? false,
      displayLocations: List<String>.from(
          map['displayLocations'] ?? ['home', 'splash', 'ads_screen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      // ✅ توافق خلفي: نحفظ imageUrl للأجزاء التي تقرأه مباشرة
      'imageUrl': imageUrl,
      'text': text,
      'actionButtonText': actionButtonText,
      'targetType': targetType,
      'targetId': targetId,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'clickCount': clickCount,
      'shopId': shopId,
      'isMainActive': isMainActive,
      'displayLocations': displayLocations,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
