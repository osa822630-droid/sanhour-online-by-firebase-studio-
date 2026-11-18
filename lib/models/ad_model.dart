// lib/models/ad_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class AdModel {
  final String id;

  final List<String> imageUrls;
  final int coverImageIndex;

  final String? videoUrl;
  final String mediaType;
  final String? status;
  final bool isPaid;
  final double? costEGP;

  final String text;
  final String actionButtonText;
  final String targetType;
  final String? targetId;
  final String? externalUrl;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isActive;
  final int clickCount;
  final String? shopId;
  final bool isMainActive;
  final List<String> displayLocations;

  AdModel({
    required this.id,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    this.videoUrl,
    this.mediaType = 'image',
    this.status,
    this.isPaid = true,
    this.costEGP,
    this.text = '',
    this.actionButtonText = 'اذهب للتفاصيل',
    this.targetType = 'none',
    this.targetId,
    this.externalUrl,
    this.expiresAt,
    this.createdAt,
    this.isActive = true,
    this.clickCount = 0,
    this.shopId,
    this.isMainActive = false,
    this.displayLocations = const ['home', 'splash', 'ads_screen'],
  });

  bool get isVideo =>
      mediaType == 'video' || (videoUrl != null && videoUrl!.isNotEmpty);

  DateTime get startDate => createdAt ?? DateTime.now();
  DateTime? get endDate => expiresAt;

  String get imageUrl {
    if (imageUrls.isEmpty) return '';
    final idx = coverImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  factory AdModel.fromMap(Map<String, dynamic> map, String id) {
    List<String> parsedImageUrls = [];
    final rawImageUrls = map['imageUrls'];
    if (rawImageUrls != null && rawImageUrls is List) {
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

    final rawCreated = map['createdAt'] ?? map['startDate'];
    final rawExpires = map['expiresAt'] ?? map['endDate'];

    return AdModel(
      id: id,
      imageUrls: parsedImageUrls,
      coverImageIndex: parsedCoverIndex,
      videoUrl: map['videoUrl'] as String?,
      mediaType: (map['mediaType'] as String?) ??
          ((map['videoUrl'] != null && (map['videoUrl'] as String).isNotEmpty)
              ? 'video'
              : 'image'),
      status: map['status'] as String?,
      isPaid: map['isPaid'] as bool? ?? true,
      costEGP: (map['costEGP'] as num?)?.toDouble(),
      text: (map['text'] ?? map['description'] ?? '').toString(),
      actionButtonText: map['actionButtonText'] ?? 'اذهب للتفاصيل',
      targetType: (map['targetType'] as String?) ?? 'none',
      targetId: map['targetId'] as String?,
      externalUrl: map['externalUrl'] as String?,
      expiresAt: rawExpires != null ? DateParser.parse(rawExpires) : null,
      createdAt: rawCreated != null ? DateParser.parse(rawCreated) : null,
      isActive: map['isActive'] ?? true,
      clickCount: (map['clickCount'] as num?)?.toInt() ?? 0,
      shopId: map['shopId'] as String?,
      isMainActive: map['isMainActive'] ?? false,
      displayLocations: List<String>.from(
          map['displayLocations'] ?? ['home', 'splash', 'ads_screen']),
    );
  }

  Map<String, dynamic> toMap() {
    final createdTs = createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp();
    final expiresTs =
        expiresAt != null ? Timestamp.fromDate(expiresAt!) : null;
    return {
      'id': id,
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'mediaType': mediaType,
      if (status != null) 'status': status,
      'isPaid': isPaid,
      if (costEGP != null) 'costEGP': costEGP,
      'text': text,
      'actionButtonText': actionButtonText,
      'targetType': targetType,
      'targetId': targetId,
      if (externalUrl != null) 'externalUrl': externalUrl,
      'expiresAt': expiresTs,
      'endDate': expiresTs,
      'isActive': isActive,
      'clickCount': clickCount,
      'shopId': shopId,
      'isMainActive': isMainActive,
      'displayLocations': displayLocations,
      'createdAt': createdTs,
      'startDate': createdTs,
    };
  }
}
