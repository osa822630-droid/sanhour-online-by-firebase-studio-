// lib/services/deep_link_service.dart
// ✅ نظام الروابط الديناميكية — يدعم كل أنواع المحتوى
// الفكرة: رابط يُفتح في المتصفح ويوجّه لصفحة في التطبيق أو App Store
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// أنواع المحتوى القابل للمشاركة
enum ShareableType {
  shop,
  product,
  offer,
  service,
  ad,
  collection,
  category,
}

class DeepLinkService {
  // النطاق الأساسي — يُغيَّر عند الإطلاق الحقيقي
  static const String _baseUrl = 'https://sanhour.online';
  static const String _appName = 'سنهور أونلاين';

  // ──────────────────────────────────────────────────────────────────
  // 1. بناء الرابط
  // ──────────────────────────────────────────────────────────────────

  /// ✅ Fix #128: التحقق من صحة id لمنع path traversal
  static bool _isValidId(String id) =>
      id.isNotEmpty && id.length <= 100 && !id.contains('/') && !id.contains('..');

  /// بناء رابط ديناميكي لأي نوع محتوى
  static String buildLink({
    required ShareableType type,
    required String id,
    String? extraParam,
  }) {
    final safeId = _isValidId(id) ? Uri.encodeComponent(id) : 'invalid';
    final path = _pathFor(type);
    final uri = Uri.parse('$_baseUrl/$path/$safeId');
    if (extraParam != null) {
      return uri.replace(queryParameters: {'ref': extraParam}).toString();
    }
    return uri.toString();
  }

  static String _pathFor(ShareableType t) {
    switch (t) {
      case ShareableType.shop:       return 'shop';
      case ShareableType.product:    return 'product';
      case ShareableType.offer:      return 'offer';
      case ShareableType.service:    return 'service';
      case ShareableType.ad:         return 'ad';
      case ShareableType.collection: return 'collection';
      case ShareableType.category:   return 'category';
    }
  }

  static String _arabicLabelFor(ShareableType t) {
    switch (t) {
      case ShareableType.shop:       return 'محل';
      case ShareableType.product:    return 'منتج';
      case ShareableType.offer:      return 'عرض';
      case ShareableType.service:    return 'خدمة';
      case ShareableType.ad:         return 'إعلان';
      case ShareableType.collection: return 'قائمة مشتريات';
      case ShareableType.category:   return 'فئة';
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 2. مشاركة المحتوى
  // ──────────────────────────────────────────────────────────────────

  /// مشاركة محل
  static Future<void> shareShop({
    required String id,
    required String name,
    required String category,
    String? location,
  }) async {
    final link = buildLink(type: ShareableType.shop, id: id);
    final msg = '''
🏪 *$name*
📂 $category${location != null ? '\n📍 $location' : ''}

اكتشف هذا المحل على $_appName:
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: '$name — $_appName');
  }

  /// مشاركة منتج
  static Future<void> shareProduct({
    required String id,
    required String name,
    required double price,
    String? shopName,
  }) async {
    final link = buildLink(type: ShareableType.product, id: id);
    final msg = '''
🛍️ *$name*
💰 ${price.toStringAsFixed(0)} جنيه${shopName != null ? '\n🏪 $shopName' : ''}

شاهد المنتج على $_appName:
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: '$name — $_appName');
  }

  /// مشاركة عرض
  static Future<void> shareOffer({
    required String id,
    required String title,
    required int discount,
    String? shopName,
  }) async {
    final link = buildLink(type: ShareableType.offer, id: id);
    final msg = '''
🏷️ *$title*
🔥 خصم $discount%!${shopName != null ? '\n🏪 $shopName' : ''}

اغتنم العرض على $_appName:
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: '$title — $_appName');
  }

  /// مشاركة خدمة
  static Future<void> shareService({
    required String id,
    required String name,
    String? shopName,
    double? price,
  }) async {
    final link = buildLink(type: ShareableType.service, id: id);
    final msg = '''
🔧 *$name*
${price != null ? '💰 ${price.toStringAsFixed(0)} جنيه\n' : ''}${shopName != null ? '🏪 $shopName\n' : ''}
اكتشف هذه الخدمة على $_appName:
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: '$name — $_appName');
  }

  /// مشاركة قائمة مفضلة
  static Future<void> shareCollection({
    required String id,
    required String name,
    required int itemCount,
  }) async {
    final link = buildLink(type: ShareableType.collection, id: id);
    final msg = '''
🛒 *$name* — قائمة مشتريات سنهور أونلاين
📦 $itemCount عنصر في القائمة

شاهد قائمتي على التطبيق:
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: 'قائمة "$name" — $_appName');
  }

  /// مشاركة فئة
  static Future<void> shareCategory({
    required String id,
    required String name,
  }) async {
    final link = buildLink(type: ShareableType.category, id: id);
    final msg = '''
📂 *$name* — استكشف على $_appName
$link

📲 سنهور كلها في جيبك!
''';
    await _share(msg.trim(), subject: '$name — $_appName');
  }

  // ──────────────────────────────────────────────────────────────────
  // 3. تسجيل نقرة الرابط في Firestore (تحليلات)
  // ──────────────────────────────────────────────────────────────────

  static Future<void> recordShareClick({
    required ShareableType type,
    required String id,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('share_analytics')
          .add({
        'type': type.name,
        'targetId': id,
        'clickedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
    } catch (_) {
      // لا نوقف التطبيق لأسباب التحليلات
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 4. دالة المشاركة الداخلية
  // ──────────────────────────────────────────────────────────────────

  static Future<void> _share(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: subject,
    ));
  }

  // ──────────────────────────────────────────────────────────────────
  // 5. Bottom Sheet موحّد للمشاركة
  // ──────────────────────────────────────────────────────────────────

  /// يعرض قائمة خيارات المشاركة بطريقة موحدة لجميع أنواع المحتوى
  static Future<void> showShareSheet(
    BuildContext context, {
    required ShareableType type,
    required String id,
    required String title,
    String? subtitle,
    required VoidCallback onShare,
  }) async {
    final link = buildLink(type: ShareableType.shop, id: id);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.share, color: Color(0xFF5E35B1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مشاركة ${_arabicLabelFor(type)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (subtitle != null)
                          Text(subtitle,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // عرض الرابط مع نسخ
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        buildLink(type: type, id: id),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: buildLink(type: type, id: id)));
                        // ✅ Fix #97: تخزين messenger قبل pop
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ الرابط ✅'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E35B1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'نسخ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // زر المشاركة عبر التطبيقات
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onShare();
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('مشاركة عبر التطبيقات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // واتساب مباشر
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final text = Uri.encodeComponent(
                        '🔗 $title\n${buildLink(type: type, id: id)}');
                    final whatsappUrl =
                        Uri.parse('https://wa.me/?text=$text');
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.message, color: Color(0xFF25D366)),
                  label: const Text('مشاركة عبر واتساب',
                      style: TextStyle(color: Color(0xFF25D366))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
