// lib/utils/date_parser.dart
// ✅ Phase 2 Fix #13: أداة DateParser مشتركة.
// قبل هذا الإصلاح، كانت كل موديل تحتوي على نسخة مستقلة من منطق parse للتاريخ.
// النتيجة: 3 أماكن لنفس الـ bug. الحل: مكتبة مركزية يستخدمها الجميع.
import 'package:cloud_firestore/cloud_firestore.dart';

class DateParser {
  DateParser._(); // ← لا instantiation — كلاس utility خالص

  /// يحوّل أي نوع من بيانات التاريخ (Timestamp, String, int, DateTime) إلى DateTime.
  /// يرجع [fallback] إذا كانت القيمة null أو تعذّر التحويل.
  static DateTime parse(dynamic value, {DateTime? fallback}) {
    final fb = fallback ?? DateTime.now();
    if (value == null) return fb;

    // ── Firestore Timestamp (الحالة الأشيع في Firestore) ──
    if (value is Timestamp) return value.toDate();

    // ── DateTime مباشرة ──
    if (value is DateTime) return value;

    // ── String ISO-8601 ──
    if (value is String) return DateTime.tryParse(value) ?? fb;

    // ── Unix milliseconds (int) ──
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);

    return fb;
  }

  /// نسخة تُرجع null عند الفشل بدل الـ fallback.
  static DateTime? tryParse(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (_) {}
    return null;
  }
}
