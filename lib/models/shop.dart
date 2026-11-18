// lib/models/shop.dart
// ✅ حفظ createdAt كـ Timestamp في toMap() بدلاً من String لكسر مشكلة ترتيب Firestore
// ✅ تضمين كافة حقول الحالة والعدادات (isActive, isSuspended, phoneClicks, whatsappClicks, tiktokClicks, telegramClicks, subscriptionStatus, subscriptionEndDate)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

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
  final bool isActive;
  final bool isSuspended;
  final List<String> workingDays;
  final String workingHours;
  final Map<String, String> socialMedia;
  final int favoriteCount;
  final int phoneClicks;
  final int whatsappClicks;
  final int facebookClicks;
  final int instagramClicks;
  final int tiktokClicks;
  final int telegramClicks;
  final DateTime createdAt;
  final int rank;
  final bool isFavorite;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final List<String>? searchKeywords;
  final String? pendingOwnerPhone;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndDate;

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
    this.isActive = true,
    this.isSuspended = false,
    this.workingDays = const [],
    this.workingHours = '',
    this.socialMedia = const {},
    this.favoriteCount = 0,
    this.phoneClicks = 0,
    this.whatsappClicks = 0,
    this.facebookClicks = 0,
    this.instagramClicks = 0,
    this.tiktokClicks = 0,
    this.telegramClicks = 0,
    DateTime? createdAt,
    this.rank = 0,
    this.isFavorite = false,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.searchKeywords,
    this.pendingOwnerPhone,
    this.subscriptionStatus,
    this.subscriptionEndDate,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Shop.fromMap(Map<String, dynamic> map, String id) {
    final DateTime parsedCreatedAt = DateParser.parse(map['createdAt']);
    final DateTime? parsedSubEnd = map['subscriptionEndDate'] != null
        ? DateParser.parse(map['subscriptionEndDate'])
        : null;

    return Shop(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      rating: (map['rating'] as num? ?? 0.0).toDouble(),
      views: (map['views'] as num? ?? 0).toInt(),
      description: map['description'] ?? '',
      phone: map['phone'] ?? '',
      facebookUrl: map['facebookUrl'],
      instagramUrl: map['instagramUrl'],
      whatsapp: map['whatsapp'],
      tiktokUrl: map['tiktokUrl'],
      telegramUrl: map['telegramUrl'],
      reviewCount: (map['reviewCount'] as num? ?? 0).toInt(),
      reviews: List<String>.from(map['reviews'] ?? []),
      uniqueVisitors: (map['uniqueVisitors'] as num? ?? 0).toInt(),
      isFeatured: map['isFeatured'] ?? false,
      isActive: map['isActive'] ?? true,
      isSuspended: map['isSuspended'] ?? false,
      workingDays: List<String>.from(map['workingDays'] ?? []),
      workingHours: map['workingHours'] ?? '',
      socialMedia: Map<String, String>.from(map['socialMedia'] ?? {}),
      favoriteCount: (map['favoriteCount'] as num? ?? 0).toInt(),
      phoneClicks: (map['phoneClicks'] as num? ?? 0).toInt(),
      whatsappClicks: (map['whatsappClicks'] as num? ?? 0).toInt(),
      facebookClicks: (map['facebookClicks'] as num? ?? 0).toInt(),
      instagramClicks: (map['instagramClicks'] as num? ?? 0).toInt(),
      tiktokClicks: (map['tiktokClicks'] as num? ?? 0).toInt(),
      telegramClicks: (map['telegramClicks'] as num? ?? 0).toInt(),
      createdAt: parsedCreatedAt,
      rank: (map['rank'] as num? ?? 0).toInt(),
      isFavorite: map['isFavorite'] ?? false,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(map['mediaTypes'] ?? []),
      searchKeywords: map['searchKeywords'] != null
          ? List<String>.from(map['searchKeywords'])
          : null,
      pendingOwnerPhone: map['pendingOwnerPhone'] as String?,
      subscriptionStatus: map['subscriptionStatus'] as String?,
      subscriptionEndDate: parsedSubEnd,
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
      'isActive': isActive,
      'isSuspended': isSuspended,
      'workingDays': workingDays,
      'workingHours': workingHours,
      'socialMedia': socialMedia,
      'favoriteCount': favoriteCount,
      'phoneClicks': phoneClicks,
      'whatsappClicks': whatsappClicks,
      'facebookClicks': facebookClicks,
      'instagramClicks': instagramClicks,
      'tiktokClicks': tiktokClicks,
      'telegramClicks': telegramClicks,
      'createdAt': Timestamp.fromDate(createdAt),
      'rank': rank,
      'isFavorite': isFavorite,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      'searchKeywords': searchKeywords ?? <String>[],
      if (pendingOwnerPhone != null) 'pendingOwnerPhone': pendingOwnerPhone,
      if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus,
      if (subscriptionEndDate != null)
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate!),
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
    bool? isActive,
    bool? isSuspended,
    List<String>? workingDays,
    String? workingHours,
    Map<String, String>? socialMedia,
    int? favoriteCount,
    int? phoneClicks,
    int? whatsappClicks,
    int? facebookClicks,
    int? instagramClicks,
    int? tiktokClicks,
    int? telegramClicks,
    DateTime? createdAt,
    int? rank,
    bool? isFavorite,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    List<String>? searchKeywords,
    String? pendingOwnerPhone,
    String? subscriptionStatus,
    DateTime? subscriptionEndDate,
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
      isActive: isActive ?? this.isActive,
      isSuspended: isSuspended ?? this.isSuspended,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      socialMedia: socialMedia ?? this.socialMedia,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      phoneClicks: phoneClicks ?? this.phoneClicks,
      whatsappClicks: whatsappClicks ?? this.whatsappClicks,
      facebookClicks: facebookClicks ?? this.facebookClicks,
      instagramClicks: instagramClicks ?? this.instagramClicks,
      tiktokClicks: tiktokClicks ?? this.tiktokClicks,
      telegramClicks: telegramClicks ?? this.telegramClicks,
      createdAt: createdAt ?? this.createdAt,
      rank: rank ?? this.rank,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      pendingOwnerPhone: pendingOwnerPhone ?? this.pendingOwnerPhone,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
    );
  }
}
