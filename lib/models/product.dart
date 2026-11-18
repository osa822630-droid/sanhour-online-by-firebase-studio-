// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class Product {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final List<String> imageUrls;
  final int coverImageIndex;
  final String category;
  final bool isFavorite;
  final int favoriteCount;
  final double rating;
  final bool hasPriceDrop;
  final double oldPrice;
  final bool hasDiscount;
  final double discountPercentage;
  final List<String> colors;
  final List<String> sizes;
  final String material;
  final List<String> reviews;
  final int views;
  final int reviewCount;
  final bool isVisible;
  final bool isShopHidden;
  final int sortOrder;
  final String listName;
  final List<String>? searchKeywords;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.description = '',
    required this.price,
    this.originalPrice = 0.0,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    this.category = '',
    this.isFavorite = false,
    int? favoriteCount,
    this.rating = 0.0,
    this.hasPriceDrop = false,
    this.oldPrice = 0.0,
    this.hasDiscount = false,
    this.discountPercentage = 0.0,
    this.colors = const [],
    this.sizes = const [],
    this.material = '',
    this.reviews = const [],
    this.views = 0,
    this.reviewCount = 0,
    this.isVisible = true,
    this.isShopHidden = false,
    this.sortOrder = 0,
    this.listName = '',
    this.searchKeywords,
    this.createdAt,
  }) : favoriteCount = favoriteCount ?? (isFavorite ? 1 : 0);

  /// يعود بصورة الغلاف المختارة للمنتج بأمان (يحترم [coverImageIndex])
  String get displayImageUrl {
    if (imageUrls.isEmpty) return '';
    final idx = coverImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  /// للتوافق الخلفي مع أي كود يقرأ imageUrl
  String get imageUrl => displayImageUrl;

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      'imageUrl': displayImageUrl,
      'category': category,
      'isFavorite': isFavorite,
      'favoriteCount': favoriteCount,
      'rating': rating,
      'hasPriceDrop': hasPriceDrop,
      'oldPrice': oldPrice,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'colors': colors,
      'sizes': sizes,
      'material': material,
      'reviews': reviews,
      'views': views,
      'reviewCount': reviewCount,
      'isVisible': isVisible,
      'isShopHidden': isShopHidden,
      'sortOrder': sortOrder,
      'listName': listName,
      'searchKeywords': searchKeywords ?? <String>[],
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    final DateTime? parsedCreatedAt = DateParser.tryParse(map['createdAt']);

    List<String> parsedImageUrls = [];
    if (map['imageUrls'] is List) {
      parsedImageUrls = List<String>.from(map['imageUrls'] as List);
    }
    if (parsedImageUrls.isEmpty) {
      final legacyUrl = map['imageUrl'] as String? ?? '';
      if (legacyUrl.isNotEmpty) parsedImageUrls = [legacyUrl];
    }

    final int rawCover = (map['coverImageIndex'] as num?)?.toInt() ?? 0;
    final int safeCoverIndex = parsedImageUrls.isEmpty
        ? 0
        : rawCover.clamp(0, parsedImageUrls.length - 1);

    final bool fav = map['isFavorite'] as bool? ?? false;
    final int favCount =
        (map['favoriteCount'] as num?)?.toInt() ?? (fav ? 1 : 0);

    return Product(
      id: id,
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrls: parsedImageUrls,
      coverImageIndex: safeCoverIndex,
      category: (map['category'] as String?) ?? '',
      isFavorite: fav,
      favoriteCount: favCount,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      hasPriceDrop: map['hasPriceDrop'] as bool? ?? false,
      oldPrice: (map['oldPrice'] as num?)?.toDouble() ?? 0.0,
      hasDiscount: map['hasDiscount'] as bool? ?? false,
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      colors: List<String>.from(map['colors'] ?? []),
      sizes: List<String>.from(map['sizes'] ?? []),
      material: (map['material'] as String?) ?? '',
      reviews: List<String>.from(map['reviews'] ?? []),
      views: (map['views'] as num?)?.toInt() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isVisible: map['isVisible'] as bool? ?? true,
      isShopHidden: map['isShopHidden'] as bool? ?? false,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      listName: (map['listName'] as String?) ?? '',
      searchKeywords: map['searchKeywords'] != null
          ? List<String>.from(map['searchKeywords'] as List)
          : null,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMapWithId() {
    final map = toMap();
    map['id'] = id;
    map['createdAt'] = createdAt?.toIso8601String();
    return map;
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    List<String>? imageUrls,
    int? coverImageIndex,
    String? category,
    bool? isFavorite,
    int? favoriteCount,
    double? rating,
    bool? hasPriceDrop,
    double? oldPrice,
    bool? hasDiscount,
    double? discountPercentage,
    List<String>? colors,
    List<String>? sizes,
    String? material,
    List<String>? reviews,
    int? views,
    int? reviewCount,
    bool? isVisible,
    bool? isShopHidden,
    int? sortOrder,
    String? listName,
    List<String>? searchKeywords,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      rating: rating ?? this.rating,
      hasPriceDrop: hasPriceDrop ?? this.hasPriceDrop,
      oldPrice: oldPrice ?? this.oldPrice,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      material: material ?? this.material,
      reviews: reviews ?? this.reviews,
      views: views ?? this.views,
      reviewCount: reviewCount ?? this.reviewCount,
      isVisible: isVisible ?? this.isVisible,
      isShopHidden: isShopHidden ?? this.isShopHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      listName: listName ?? this.listName,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
