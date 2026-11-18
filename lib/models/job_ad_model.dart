// lib/models/job_ad_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

enum JobCategory {
  workers,       // عمال يومية
  sales,         // مندوبين مبيعات
  drivers,       // سواقين
  delivery,      // توصيل
  office,        // أعمال مكتبية
  technical,     // فنيين وكهربائيين
  cleaning,      // عمال نظافة
  security,      // حراسة
  teaching,      // تدريس ودروس
  other,         // أخرى
}

class JobAdModel {
  final String id;
  final String posterId;       // uid الشخص اللي نزّل الإعلان
  final String posterName;
  final String posterPhone;
  final String title;
  final String description;
  final JobCategory category;
  final String location;       // المنطقة
  final String salary;         // المرتب (نص حر: "يُتفق عليه" أو "800 جنيه/شهر")
  final String workType;       // دوام كامل / جزئي / يومية
  final int requiredCount;     // عدد المطلوبين
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int viewCount;
  final int applicationCount;

  JobAdModel({
    required this.id,
    required this.posterId,
    required this.posterName,
    required this.posterPhone,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.salary,
    required this.workType,
    required this.requiredCount,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
    this.viewCount = 0,
    this.applicationCount = 0,
  });

  static JobCategory _categoryFromString(String? s) {
    switch (s) {
      case 'workers':   return JobCategory.workers;
      case 'sales':     return JobCategory.sales;
      case 'drivers':   return JobCategory.drivers;
      case 'delivery':  return JobCategory.delivery;
      case 'office':    return JobCategory.office;
      case 'technical': return JobCategory.technical;
      case 'cleaning':  return JobCategory.cleaning;
      case 'security':  return JobCategory.security;
      case 'teaching':  return JobCategory.teaching;
      default:          return JobCategory.other;
    }
  }

  static String categoryToString(JobCategory c) {
    return c.name;
  }

  static String categoryLabel(JobCategory c) {
    const map = {
      JobCategory.workers:   '👷 عمال يومية',
      JobCategory.sales:     '🤝 مندوبين مبيعات',
      JobCategory.drivers:   '🚗 سواقين',
      JobCategory.delivery:  '📦 توصيل',
      JobCategory.office:    '💼 أعمال مكتبية',
      JobCategory.technical: '🔧 فنيين وكهربائيين',
      JobCategory.cleaning:  '🧹 عمال نظافة',
      JobCategory.security:  '🛡️ حراسة',
      JobCategory.teaching:  '📚 تدريس ودروس',
      JobCategory.other:     '📋 أخرى',
    };
    return map[c] ?? 'أخرى';
  }

  factory JobAdModel.fromMap(Map<String, dynamic> m) {
    final DateTime? expiresAt =
        m['expiresAt'] != null ? DateParser.parse(m['expiresAt']) : null;
    final DateTime createdAt =
        m['createdAt'] != null ? DateParser.parse(m['createdAt']) : DateTime.now();

    return JobAdModel(
      id: m['id'] as String? ?? '',
      posterId: m['posterId'] as String? ?? '',
      posterName: m['posterName'] as String? ?? '',
      posterPhone: m['posterPhone'] as String? ?? '',
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      category: _categoryFromString(m['category'] as String?),
      location: m['location'] as String? ?? '',
      salary: m['salary'] as String? ?? 'يُتفق عليه',
      workType: m['workType'] as String? ?? 'دوام كامل',
      requiredCount: (m['requiredCount'] as num?)?.toInt() ?? 1,
      isActive: m['isActive'] as bool? ?? true,
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewCount: (m['viewCount'] as num?)?.toInt() ?? 0,
      applicationCount: (m['applicationCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ✅ استخدام serverTimestamp افتراضياً عند الإنشاء مع إمكانية الحفاظ على createdAt عند التعديل
  Map<String, dynamic> toMap({bool isNew = true}) => {
    'id': id,
    'posterId': posterId,
    'posterName': posterName,
    'posterPhone': posterPhone,
    'title': title,
    'description': description,
    'category': categoryToString(category),
    'location': location,
    'salary': salary,
    'workType': workType,
    'requiredCount': requiredCount,
    'isActive': isActive,
    'createdAt': isNew ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'searchKeywords': _buildKeywords(),
    'viewCount': viewCount,
    'applicationCount': applicationCount,
  };

  List<String> _buildKeywords() {
    final keywords = <String>{};
    for (final text in [title.toLowerCase(), location.toLowerCase(),
        categoryToString(category).toLowerCase()]) {
      final words = text.split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.length >= 2) keywords.add(w);
        for (int i = 2; i < w.length && i <= 6; i++) {
          keywords.add(w.substring(0, i));
        }
      }
    }
    return keywords.take(30).toList();
  }
}
