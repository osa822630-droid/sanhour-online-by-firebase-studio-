// lib/utils/date_helper.dart
// ✅ Pro #221: مركزة منطق تنسيق التواريخ
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static final _dayFmt   = DateFormat('d MMM', 'ar');
  static final _fullFmt  = DateFormat('d MMM yyyy', 'ar');
  static final _timeFmt  = DateFormat('h:mm a', 'ar');
  static final _stampFmt = DateFormat('d/M/yyyy h:mm a', 'ar');

  /// يُحوِّل أي نوع تاريخ (Timestamp / DateTime / String / null) إلى DateTime آمن
  static DateTime? parse(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  /// "اليوم" / "أمس" / "منذ 3 أيام" / تاريخ كامل
  static String relative(dynamic value) {
    final dt = parse(value);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1)   return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)  return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1)   return 'أمس';
    if (diff.inDays < 7)    return 'منذ ${diff.inDays} أيام';
    if (dt.year == now.year) return _dayFmt.format(dt);
    return _fullFmt.format(dt);
  }

  static String day(dynamic value) {
    final dt = parse(value);
    return dt == null ? '' : _dayFmt.format(dt);
  }

  static String full(dynamic value) {
    final dt = parse(value);
    return dt == null ? '' : _fullFmt.format(dt);
  }

  static String stamp(dynamic value) {
    final dt = parse(value);
    return dt == null ? '' : _stampFmt.format(dt);
  }

  static String time(dynamic value) {
    final dt = parse(value);
    return dt == null ? '' : _timeFmt.format(dt);
  }

  /// هل انتهى التاريخ؟
  static bool isExpired(dynamic value) {
    final dt = parse(value);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  /// عدد الأيام المتبقية
  static int daysRemaining(dynamic value) {
    final dt = parse(value);
    if (dt == null) return 0;
    return dt.difference(DateTime.now()).inDays.clamp(0, 9999);
  }
}
