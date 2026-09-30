// lib/models/service_bid_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum BidStatus {
  pending,   // بانتظار الرد
  accepted,  // مقبول
  rejected,  // مرفوض
}

class ServiceBidModel {
  final String id;
  final String requestId;     // id الطلب
  final String providerId;    // id مقدّم العرض
  final String providerName;
  final String providerPhone;
  final double offeredPrice;
  final String note;           // ملاحظة للعرض
  final BidStatus status;
  final DateTime createdAt;

  ServiceBidModel({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.offeredPrice,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  bool get isPending  => status == BidStatus.pending;
  bool get isAccepted => status == BidStatus.accepted;

  static BidStatus _statusFromString(String? s) {
    switch (s) {
      case 'accepted': return BidStatus.accepted;
      case 'rejected': return BidStatus.rejected;
      default:         return BidStatus.pending;
    }
  }

  factory ServiceBidModel.fromMap(Map<String, dynamic> m) {
    DateTime createdAt = DateTime.now();
    if (m['createdAt'] is Timestamp) {
      createdAt = (m['createdAt'] as Timestamp).toDate();
    }
    return ServiceBidModel(
      id: m['id'] as String? ?? '',
      requestId: m['requestId'] as String? ?? '',
      providerId: m['providerId'] as String? ?? '',
      providerName: m['providerName'] as String? ?? '',
      providerPhone: m['providerPhone'] as String? ?? '',
      offeredPrice: (m['offeredPrice'] as num?)?.toDouble() ?? 0,
      note: m['note'] as String? ?? '',
      status: _statusFromString(m['status'] as String?),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'requestId': requestId,
    'providerId': providerId,
    'providerName': providerName,
    'providerPhone': providerPhone,
    'offeredPrice': offeredPrice,
    'note': note,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
