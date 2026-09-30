// lib/models/product.dart
// ✅ Phase 1 Fix #06: إضافة 'searchKeywords' إلى toMap().
// كان الحقل موجوداً في الكلاس ويُقرأ في fromMap()، لكنه لم يُحفظ عند الكتابة.
// النتيجة: كل منتج جديد يُحفظ في Firestore بدون searchKeywords → لا يظهر في البحث أبدًا.
class Product {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final List<String> imageUrls;
  final String category;
  final bool isFavorite;
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
  final int sortOrder;
  final String listName;
  // ✅ كلمات البحث — الآن تُحفظ وتُقرأ بشكل صحيح
  final List<String>? searchKeywords;
  // ✅ تاريخ الإنشاء — ضروري لـ newProducts getter (Phase 1 Fix #11)
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.description = '',
    required this.price,
    this.originalPrice = 0.0,
    this.imageUrls = const [],
    this.category = '',
    this.isFavorite = false,
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
    this.sortOrder = 0,
    this.listName = '',
    this.searchKeywords,
    this.createdAt,
  });

  int get favoriteCount => isFavorite ? 1 : 0;

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrls': imageUrls,
      'category': category,
      'isFavorite': isFavorite,
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
      'sortOrder': sortOrder,
      'listName': listName,
      // ✅ Phase 1 Fix #06: searchKeywords تُحفظ الآن في Firestore
      'searchKeywords': searchKeywords ?? <String>[],
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    // ✅ قراءة آمنة لتاريخ الإنشاء — يدعم Timestamp وString وint
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt != null) {
      try {
        if (rawCreatedAt.runtimeType.toString().contains('Timestamp')) {
          // Firestore Timestamp
          parsedCreatedAt = (rawCreatedAt as dynamic).toDate() as DateTime;
        } else if (rawCreatedAt is String) {
          parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
        } else if (rawCreatedAt is int) {
          parsedCreatedAt =
              DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
        }
      } catch (_) {
        parsedCreatedAt = null;
      }
    }

    return Product(
      id: id,
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      category: (map['category'] as String?) ?? '',
      isFavorite: map['isFavorite'] as bool? ?? false,
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
    String? category,
    bool? isFavorite,
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
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
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
      sortOrder: sortOrder ?? this.sortOrder,
      listName: listName ?? this.listName,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
