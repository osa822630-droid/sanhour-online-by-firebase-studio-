// lib/models/service_request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceRequestCategory {
  plumbing,      // سباكة
  electrical,    // كهرباء
  carpentry,     // نجارة
  moving,        // نقل عفش
  transport,     // مشاوير / ميني باص
  painting,      // دهانات
  cleaning,      // تنظيف
  ac,            // تكييفات
  mobile,        // تصليح موبايل
  internet,      // إنترنت وشبكات
  tailoring,     // خياطة
  other,         // أخرى
}

enum ServiceRequestStatus {
  open,       // مفتوح — يقبل عروض
  accepted,   // تم القبول — مخفي عن العامة
  closed,     // مغلق بدون قبول (انتهى)
}

class ServiceRequestModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String title;
  final String description;
  final ServiceRequestCategory category;
  final String location;
  final double? suggestedPrice;
  final String priceNote;      // "يُتفق عليه" أو "حد أقصى 500 جنيه"
  final bool urgent;
  final ServiceRequestStatus status;
  final String? acceptedBidId; // id العرض المقبول
  final int bidsCount;
  final DateTime createdAt;
  final DateTime? expiresAt;

  ServiceRequestModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.suggestedPrice,
    required this.priceNote,
    required this.urgent,
    required this.status,
    this.acceptedBidId,
    required this.bidsCount,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isOpen => status == ServiceRequestStatus.open;
  bool get isAccepted => status == ServiceRequestStatus.accepted;

  static ServiceRequestCategory _catFromString(String? s) {
    switch (s) {
      case 'plumbing':   return ServiceRequestCategory.plumbing;
      case 'electrical': return ServiceRequestCategory.electrical;
      case 'carpentry':  return ServiceRequestCategory.carpentry;
      case 'moving':     return ServiceRequestCategory.moving;
      case 'transport':  return ServiceRequestCategory.transport;
      case 'painting':   return ServiceRequestCategory.painting;
      case 'cleaning':   return ServiceRequestCategory.cleaning;
      case 'ac':         return ServiceRequestCategory.ac;
      case 'mobile':     return ServiceRequestCategory.mobile;
      case 'internet':   return ServiceRequestCategory.internet;
      case 'tailoring':  return ServiceRequestCategory.tailoring;
      default:           return ServiceRequestCategory.other;
    }
  }

  static ServiceRequestStatus _statusFromString(String? s) {
    switch (s) {
      case 'accepted': return ServiceRequestStatus.accepted;
      case 'closed':   return ServiceRequestStatus.closed;
      default:         return ServiceRequestStatus.open;
    }
  }

  static String categoryLabel(ServiceRequestCategory c) {
    const map = {
      ServiceRequestCategory.plumbing:   '🔧 سباكة',
      ServiceRequestCategory.electrical: '⚡ كهرباء',
      ServiceRequestCategory.carpentry:  '🪚 نجارة',
      ServiceRequestCategory.moving:     '🚛 نقل عفش',
      ServiceRequestCategory.transport:  '🚗 مشاوير وتوصيل',
      ServiceRequestCategory.painting:   '🎨 دهانات',
      ServiceRequestCategory.cleaning:   '🧹 تنظيف',
      ServiceRequestCategory.ac:         '❄️ تكييفات',
      ServiceRequestCategory.mobile:     '📱 تصليح موبايل',
      ServiceRequestCategory.internet:   '📡 إنترنت وشبكات',
      ServiceRequestCategory.tailoring:  '🧵 خياطة',
      ServiceRequestCategory.other:      '📋 أخرى',
    };
    return map[c] ?? 'أخرى';
  }

  factory ServiceRequestModel.fromMap(Map<String, dynamic> m) {
    DateTime createdAt = DateTime.now();
    if (m['createdAt'] is Timestamp) {
      createdAt = (m['createdAt'] as Timestamp).toDate();
    }
    DateTime? expiresAt;
    if (m['expiresAt'] is Timestamp) {
      expiresAt = (m['expiresAt'] as Timestamp).toDate();
    }
    return ServiceRequestModel(
      id: m['id'] as String? ?? '',
      clientId: m['clientId'] as String? ?? '',
      clientName: m['clientName'] as String? ?? '',
      clientPhone: m['clientPhone'] as String? ?? '',
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      category: _catFromString(m['category'] as String?),
      location: m['location'] as String? ?? '',
      suggestedPrice: (m['suggestedPrice'] as num?)?.toDouble(),
      priceNote: m['priceNote'] as String? ?? 'يُتفق عليه',
      urgent: m['urgent'] as bool? ?? false,
      status: _statusFromString(m['status'] as String?),
      acceptedBidId: m['acceptedBidId'] as String?,
      bidsCount: (m['bidsCount'] as int?) ?? 0,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'title': title,
    'description': description,
    'category': category.name,
    'location': location,
    'suggestedPrice': suggestedPrice,
    'priceNote': priceNote,
    'urgent': urgent,
    'status': status.name,
    'acceptedBidId': acceptedBidId,
    'bidsCount': bidsCount,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
  };
}
