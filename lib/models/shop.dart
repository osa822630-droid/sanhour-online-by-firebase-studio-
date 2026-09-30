// lib/models/shop.dart
// ✅ Phase 1 Fix #06b: إضافة حقل searchKeywords وتضمينه في toMap().
// كذلك تم توحيد قراءة createdAt لتدعم Firestore Timestamp وString وint
// لتجنب crash من "type 'Timestamp' is not a subtype of type 'String'".
class Shop {
  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String location;
  final String imageUrl;
  final String coverUrl;
  final double rating;
  final int views;
  final String description;
  final String phone;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? whatsapp;
  final String? tiktokUrl;
  final String? telegramUrl;
  final int reviewCount;
  final List<String> reviews;
  final int uniqueVisitors;
  final bool isFeatured;
  final List<String> workingDays;
  final String workingHours;
  final Map<String, String> socialMedia;
  final int favoriteCount;
  final DateTime createdAt;
  final int rank;
  final bool isFavorite;
  // ✅ گاليري وسائط المحل (صور + فيديوهات)
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  // ✅ Phase 1 Fix #06b: كلمات البحث — الآن تُحفظ في Firestore
  final List<String>? searchKeywords;

  Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.location,
    required this.imageUrl,
    this.coverUrl = '',
    this.rating = 0.0,
    this.views = 0,
    this.description = '',
    this.phone = '',
    this.facebookUrl,
    this.instagramUrl,
    this.whatsapp,
    this.tiktokUrl,
    this.telegramUrl,
    this.reviewCount = 0,
    this.reviews = const [],
    this.uniqueVisitors = 0,
    this.isFeatured = false,
    this.workingDays = const [],
    this.workingHours = '',
    this.socialMedia = const {},
    this.favoriteCount = 0,
    DateTime? createdAt,
    this.rank = 0,
    this.isFavorite = false,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.searchKeywords,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Shop.fromMap(Map<String, dynamic> map, String id) {
    // ✅ قراءة آمنة لـ createdAt — يدعم Timestamp وString وint ومنع Crash
    DateTime parsedCreatedAt = DateTime.now();
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt != null) {
      try {
        if (rawCreatedAt.runtimeType.toString().contains('Timestamp')) {
          parsedCreatedAt = (rawCreatedAt as dynamic).toDate() as DateTime;
        } else if (rawCreatedAt is String) {
          parsedCreatedAt =
              DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
        } else if (rawCreatedAt is int) {
          parsedCreatedAt =
              DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
        }
      } catch (_) {
        parsedCreatedAt = DateTime.now();
      }
    }

    return Shop(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      views: map['views'] ?? 0,
      description: map['description'] ?? '',
      phone: map['phone'] ?? '',
      facebookUrl: map['facebookUrl'],
      instagramUrl: map['instagramUrl'],
      whatsapp: map['whatsapp'],
      tiktokUrl: map['tiktokUrl'],
      telegramUrl: map['telegramUrl'],
      reviewCount: map['reviewCount'] ?? 0,
      reviews: List<String>.from(map['reviews'] ?? []),
      uniqueVisitors: map['uniqueVisitors'] ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      workingDays: List<String>.from(map['workingDays'] ?? []),
      workingHours: map['workingHours'] ?? '',
      socialMedia: Map<String, String>.from(map['socialMedia'] ?? {}),
      favoriteCount: map['favoriteCount'] ?? 0,
      createdAt: parsedCreatedAt,
      rank: map['rank'] ?? 0,
      isFavorite: map['isFavorite'] ?? false,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(map['mediaTypes'] ?? []),
      searchKeywords: map['searchKeywords'] != null
          ? List<String>.from(map['searchKeywords'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'category': category,
      'location': location,
      'imageUrl': imageUrl,
      'coverUrl': coverUrl,
      'rating': rating,
      'views': views,
      'description': description,
      'phone': phone,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'whatsapp': whatsapp,
      'tiktokUrl': tiktokUrl,
      'telegramUrl': telegramUrl,
      'reviewCount': reviewCount,
      'reviews': reviews,
      'uniqueVisitors': uniqueVisitors,
      'isFeatured': isFeatured,
      'workingDays': workingDays,
      'workingHours': workingHours,
      'socialMedia': socialMedia,
      'favoriteCount': favoriteCount,
      'createdAt': createdAt.toIso8601String(),
      'rank': rank,
      'isFavorite': isFavorite,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      // ✅ Phase 1 Fix #06b: searchKeywords تُحفظ الآن في Firestore
      'searchKeywords': searchKeywords ?? <String>[],
    };
  }

  Map<String, dynamic> toMapWithId() {
    final map = toMap();
    map['id'] = id;
    return map;
  }

  Shop copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? category,
    String? location,
    String? imageUrl,
    String? coverUrl,
    double? rating,
    int? views,
    String? description,
    String? phone,
    String? facebookUrl,
    String? instagramUrl,
    String? whatsapp,
    String? tiktokUrl,
    String? telegramUrl,
    int? reviewCount,
    List<String>? reviews,
    int? uniqueVisitors,
    bool? isFeatured,
    List<String>? workingDays,
    String? workingHours,
    Map<String, String>? socialMedia,
    int? favoriteCount,
    DateTime? createdAt,
    int? rank,
    bool? isFavorite,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    List<String>? searchKeywords,
  }) {
    return Shop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      rating: rating ?? this.rating,
      views: views ?? this.views,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      whatsapp: whatsapp ?? this.whatsapp,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      telegramUrl: telegramUrl ?? this.telegramUrl,
      reviewCount: reviewCount ?? this.reviewCount,
      reviews: reviews ?? this.reviews,
      uniqueVisitors: uniqueVisitors ?? this.uniqueVisitors,
      isFeatured: isFeatured ?? this.isFeatured,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      socialMedia: socialMedia ?? this.socialMedia,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      createdAt: createdAt ?? this.createdAt,
      rank: rank ?? this.rank,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }
}
