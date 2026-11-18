// lib/models/offer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class Offer {
  final String id;
  final String shopId;
  final String type;
  final String? productId;
  final String title;
  final String description;
  final int discount;
  final double? oldPrice;
  final double? newPrice;
  final String? giftDescription;
  final String? bundleDetails;
  final DateTime validUntil;

  // ✅ نظام الصور المتعدد
  final List<String> imageUrls;
  final int coverImageIndex;

  final bool isActive;
  final int views;
  final bool isFavorite;
  final int favoriteCount;
  final double rating;
  final int reviewCount;
  final List<String> reviews;
  final bool isVisible;
  final bool isShopHidden;
  final List<String>? searchKeywords;
  final DateTime? createdAt;

  Offer({
    required this.id,
    required this.shopId,
    required this.type,
    this.productId,
    required this.title,
    required this.description,
    required this.discount,
    this.oldPrice,
    this.newPrice,
    this.giftDescription,
    this.bundleDetails,
    required this.validUntil,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    required this.isActive,
    required this.views,
    this.isFavorite = false,
    int? favoriteCount,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.reviews = const [],
    this.isVisible = true,
    this.isShopHidden = false,
    this.searchKeywords,
    this.createdAt,
  }) : favoriteCount = favoriteCount ?? (isFavorite ? 1 : 0);

  // ✅ Getter للتوافق مع الكود الذي يقرأ offer.imageUrl أو displayImageUrl
  String get imageUrl {
    if (imageUrls.isEmpty) return '';
    final idx = coverImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  String get displayImageUrl => imageUrl;

  bool get isExpired => validUntil.isBefore(DateTime.now());
  bool get isAboutToExpire =>
      validUntil.difference(DateTime.now()).inDays <= 3;

  Offer copyWith({
    String? id,
    String? shopId,
    String? type,
    String? productId,
    String? title,
    String? description,
    int? discount,
    double? oldPrice,
    double? newPrice,
    String? giftDescription,
    String? bundleDetails,
    DateTime? validUntil,
    List<String>? imageUrls,
    int? coverImageIndex,
    bool? isActive,
    int? views,
    bool? isFavorite,
    int? favoriteCount,
    double? rating,
    int? reviewCount,
    List<String>? reviews,
    bool? isVisible,
    bool? isShopHidden,
    List<String>? searchKeywords,
    DateTime? createdAt,
  }) {
    return Offer(
      id: (id != null && id.isEmpty) ? '' : (id ?? this.id),
      shopId: shopId ?? this.shopId,
      type: type ?? this.type,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      discount: discount ?? this.discount,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
      giftDescription: giftDescription ?? this.giftDescription,
      bundleDetails: bundleDetails ?? this.bundleDetails,
      validUntil: validUntil ?? this.validUntil,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      reviews: reviews ?? this.reviews,
      isVisible: isVisible ?? this.isVisible,
      isShopHidden: isShopHidden ?? this.isShopHidden,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      createdAt: createdAt ?? this.createdAt,
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
      if (oldPrice != null) 'oldPrice': oldPrice,
      if (newPrice != null) 'newPrice': newPrice,
      if (giftDescription != null) 'giftDescription': giftDescription,
      if (bundleDetails != null) 'bundleDetails': bundleDetails,
      'validUntil': Timestamp.fromDate(validUntil),
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'views': views,
      'isFavorite': isFavorite,
      'favoriteCount': favoriteCount,
      'rating': rating,
      'reviewCount': reviewCount,
      'reviews': reviews,
      'isVisible': isVisible,
      'isShopHidden': isShopHidden,
      'searchKeywords': searchKeywords ?? <String>[],
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  Map<String, dynamic> toMapWithId() {
    final map = toMap();
    map['id'] = id;
    map['validUntil'] = validUntil.toIso8601String();
    if (createdAt != null) {
      map['createdAt'] = createdAt!.toIso8601String();
    }
    return map;
  }

  factory Offer.fromMap(Map<String, dynamic> map, String id) {
    final DateTime parsedValidUntil = DateParser.parse(
      map['validUntil'],
      fallback: DateTime.now().add(const Duration(days: 30)),
    );
    final DateTime? parsedCreatedAt = DateParser.tryParse(map['createdAt']);

    List<String> parsedImageUrls = [];
    final rawImageUrls = map['imageUrls'];
    if (rawImageUrls is List) {
      parsedImageUrls = List<String>.from(rawImageUrls);
    }
    if (parsedImageUrls.isEmpty) {
      final legacyUrl = map['imageUrl'] as String? ?? '';
      if (legacyUrl.isNotEmpty) parsedImageUrls = [legacyUrl];
    }

    final int rawCover = (map['coverImageIndex'] as num?)?.toInt() ?? 0;
    final int parsedCoverIndex = parsedImageUrls.isEmpty
        ? 0
        : rawCover.clamp(0, parsedImageUrls.length - 1);

    final bool fav = map['isFavorite'] as bool? ?? false;
    final int favCount =
        (map['favoriteCount'] as num?)?.toInt() ?? (fav ? 1 : 0);

    return Offer(
      id: id,
      shopId: map['shopId'] ?? '',
      type: map['type'] ?? 'generic',
      productId: map['productId'] as String?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      oldPrice: (map['oldPrice'] as num?)?.toDouble(),
      newPrice: (map['newPrice'] as num?)?.toDouble(),
      giftDescription: map['giftDescription'] as String?,
      bundleDetails: map['bundleDetails'] as String?,
      validUntil: parsedValidUntil,
      imageUrls: parsedImageUrls,
      coverImageIndex: parsedCoverIndex,
      isActive: map['isActive'] ?? true,
      views: (map['views'] as num?)?.toInt() ?? 0,
      isFavorite: fav,
      favoriteCount: favCount,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      reviews: List<String>.from(map['reviews'] ?? []),
      isVisible: map['isVisible'] ?? true,
      isShopHidden: map['isShopHidden'] as bool? ?? false,
      searchKeywords: map['searchKeywords'] != null
          ? List<String>.from(map['searchKeywords'] as List)
          : null,
      createdAt: parsedCreatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
