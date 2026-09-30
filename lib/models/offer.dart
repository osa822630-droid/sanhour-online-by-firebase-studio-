// lib/models/offer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ إضافة دعم الصور المتعددة: imageUrls (List<String>) + coverImageIndex (int)
// ✅ توافق خلفي كامل: الـ getter imageUrl يعود بصورة الغلاف المختارة
// ✅ fromMap() يقرأ imageUrls أو يُحوِّل imageUrl القديمة لقائمة تلقائياً
class Offer {
  final String id;
  final String shopId;
  final String type;
  final String? productId;
  final String title;
  final String description;
  final int discount;
  final DateTime validUntil;

  // ✅ نظام الصور المتعدد
  final List<String> imageUrls;
  final int coverImageIndex;

  final bool isActive;
  final int views;
  final bool isFavorite;
  final double rating;
  final int reviewCount;
  final List<String> reviews;
  final bool isVisible;
  final List<String>? searchKeywords;

  Offer({
    required this.id,
    required this.shopId,
    required this.type,
    this.productId,
    required this.title,
    required this.description,
    required this.discount,
    required this.validUntil,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    required this.isActive,
    required this.views,
    this.isFavorite = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.reviews = const [],
    this.isVisible = true,
    this.searchKeywords,
  });

  // ✅ Getter للتوافق مع الكود القديم الذي يقرأ offer.imageUrl مباشرة
  String get imageUrl {
    if (imageUrls.isEmpty) return '';
    final idx = coverImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  int get favoriteCount => isFavorite ? 1 : 0;
  bool get isExpired => validUntil.isBefore(DateTime.now());
  bool get isAboutToExpire =>
      validUntil.difference(DateTime.now()).inDays <= 3;

  // ✅ Fix #201: id في copyWith — القيمة الفارغة '' تعني "إنشاء جديد"
  // القيمة null تعني "احتفظ بالـ id الحالي"
  Offer copyWith({
    String? id,
    String? shopId,
    String? type,
    String? productId,
    String? title,
    String? description,
    int? discount,
    DateTime? validUntil,
    List<String>? imageUrls,
    int? coverImageIndex,
    bool? isActive,
    int? views,
    bool? isFavorite,
    double? rating,
    int? reviewCount,
    List<String>? reviews,
    bool? isVisible,
    List<String>? searchKeywords,
  }) {
    return Offer(
      // id == '' يعني "عرض جديد" — id == null يعني "استخدم الحالي"
      id: (id != null && id.isEmpty) ? '' : (id ?? this.id),
      shopId: shopId ?? this.shopId,
      type: type ?? this.type,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      discount: discount ?? this.discount,
      validUntil: validUntil ?? this.validUntil,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      reviews: reviews ?? this.reviews,
      isVisible: isVisible ?? this.isVisible,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'type': type,
      'productId': productId,
      'title': title,
      'description': description,
      'discount': discount,
      // ✅ Fix #162: Timestamp بدلاً من ISO String لاتساق مع Firestore
      'validUntil': Timestamp.fromDate(validUntil),
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      // ✅ توافق خلفي: نحفظ imageUrl للأجزاء التي تقرأه مباشرة
      'imageUrl': imageUrl,
      'isActive': isActive,
      'views': views,
      'isFavorite': isFavorite,
      'rating': rating,
      'reviewCount': reviewCount,
      'reviews': reviews,
      'isVisible': isVisible,
      'searchKeywords': searchKeywords ?? <String>[],
    };
  }

  Map<String, dynamic> toMapWithId() {
    final map = toMap();
    map['id'] = id;
    return map;
  }

  factory Offer.fromMap(Map<String, dynamic> map, String id) {
    // قراءة آمنة لـ validUntil — يدعم Timestamp وString وint
    DateTime parsedValidUntil = DateTime.now().add(const Duration(days: 30));
    final rawValidUntil = map['validUntil'];
    if (rawValidUntil != null) {
      try {
        if (rawValidUntil.runtimeType.toString().contains('Timestamp')) {
          parsedValidUntil = (rawValidUntil as dynamic).toDate() as DateTime;
        } else if (rawValidUntil is String) {
          parsedValidUntil =
              DateTime.tryParse(rawValidUntil) ?? parsedValidUntil;
        } else if (rawValidUntil is int) {
          parsedValidUntil =
              DateTime.fromMillisecondsSinceEpoch(rawValidUntil);
        }
      } catch (_) {}
    }

    // ✅ قراءة imageUrls مع التوافق الخلفي لـ imageUrl القديمة
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

    return Offer(
      id: id,
      shopId: map['shopId'] ?? '',
      type: map['type'] ?? 'generic',
      productId: map['productId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      validUntil: parsedValidUntil,
      imageUrls: parsedImageUrls,
      coverImageIndex: parsedCoverIndex,
      isActive: map['isActive'] ?? false,
      views: (map['views'] as num?)?.toInt() ?? 0,
      isFavorite: map['isFavorite'] ?? false,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      reviews: List<String>.from(map['reviews'] ?? []),
      isVisible: map['isVisible'] ?? true,
      searchKeywords: map['searchKeywords'] != null
          ? List<String>.from(map['searchKeywords'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
