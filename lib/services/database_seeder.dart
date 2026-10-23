// lib/services/database_seeder.dart
// ✅ إصلاح شامل للـ seeder — ثلاثة محاور رئيسية:
//
// 1. PHASED STAGES: يُنفَّذ الـ seed على 10 مراحل متسلسلة (categories →
//    users → shops → products → offers → services → reviews → ads → job_ads
//    → service_requests → dealer_listings → wishlists → notifications →
//    settings/locations) — كل مرحلة مستقلة وتُسجِّل خطأها دون إيقاف
//    المراحل التالية.
//
// 2. PROGRESS CALLBACK: كل مرحلة تُرسل تحديثاً لـ [onProgress] مع:
//    - [phase]: رقم المرحلة (1-10)
//    - [phaseName]: اسمها بالعربية
//    - [phasePercent]: نسبة اكتمالها داخل المرحلة (0-100)
//    - [overallPercent]: النسبة الإجمالية الكاملة (0-100)
//    الواجهة تعرض المعلومات كاملةً بدلاً من الـ spinner الذي لا يعطي أي تغذية راجعة.
//
// 3. FULL COVERAGE: يُغطي الآن كل مجموعات Firestore المستخدمة في التطبيق:
//    categories, users, shops, products, offers, services, reviews, ads,
//    job_ads, service_requests, service_bids, dealer_listings,
//    wishlists, notifications, notification_queue,
//    settings (general + locations), referrals, admin_audit_log
//
// 4. ANTI-FREEZE: batches ≤ 25 عنصراً + تأخير 150ms بين كل batch
//    + try/catch مستقل لكل خطوة داخل المرحلة.
//
// 5. Schema Bug Fixes (مقارنةً بالنسخة القديمة):
//    - dealer_listings (وليس dealer_ads) — اسم المجموعة الصحيح
//    - offers.validUntil → Timestamp (وليس ISO String)
//    - job_ads → يطابق JobAdModel.fromMap fields تماماً
//    - service_bids → sub-collection داخل service_requests (وليس top-level)
//    - notification_queue → expiresAt + data.channel + data.route
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

// ── نموذج تقدم المرحلة ────────────────────────────────────────────────────
class SeederProgress {
  final int phase;
  final int totalPhases;
  final String phaseName;

  /// نسبة اكتمال هذه المرحلة تحديداً (0–100)
  final int phasePercent;

  /// النسبة الإجمالية الكاملة (0–100)
  final int overallPercent;

  /// رسالة وصفية اختيارية (مثل "تم رفع 3 من 6 محلات")
  final String? detail;

  const SeederProgress({
    required this.phase,
    required this.totalPhases,
    required this.phaseName,
    required this.phasePercent,
    required this.overallPercent,
    this.detail,
  });

  @override
  String toString() =>
      'Phase $phase/$totalPhases ($phaseName): $phasePercent% — Overall: $overallPercent%';
}

typedef ProgressCallback = void Function(SeederProgress progress);

/// ✅ Item #4: استثناء رسالته جاهزة للعرض في الواجهة. toString() بيرجّع الرسالة
/// بس (من غير بادئة "Exception:" ومن غير تفاصيل Firebase الخام).
class SeederException implements Exception {
  final String message;
  const SeederException(this.message);

  @override
  String toString() => message;
}

// ── الـ seeder الرئيسي ────────────────────────────────────────────────────
class DatabaseSeeder {
  DatabaseSeeder._();

  static final _db = FirebaseFirestore.instance;
  static const _batchSize = 25;
  static const _batchDelay = Duration(milliseconds: 150);

  // إجمالي المراحل
  static const int _totalPhases = 10;

  // ─────────────────────────────────────────────────────────────────────────
  // نقطة الدخول الرئيسية
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> seedAll({
    ProgressCallback? onProgress,
  }) async {
    // ✅ إصلاح مشكلة #5: تتجاوز الـ seeder تلقائياً إلا في وضع الاختبار
    // (Debug عادي أو --dart-define=ENABLE_MOCK_MODE=true صراحةً)
    if (!BuildFlags.mockModeEnabled) {
      developer.log('DatabaseSeeder: skipped (mock mode disabled)',
          name: 'DatabaseSeeder');
      return;
    }

    developer.log('DatabaseSeeder: starting full seed', name: 'DatabaseSeeder');

    void report(int phase, String name, int phasePercent, {String? detail}) {
      // النسبة الإجمالية: كل مرحلة تساوي (100 / totalPhases) نقطة
      final basePercent = ((phase - 1) * 100 ~/ _totalPhases);
      final phaseContrib = (phasePercent * 100 ~/ (_totalPhases * 100));
      final overall = (basePercent + phaseContrib).clamp(0, 99);
      onProgress?.call(SeederProgress(
        phase: phase,
        totalPhases: _totalPhases,
        phaseName: name,
        phasePercent: phasePercent,
        overallPercent: overall,
        detail: detail,
      ));
    }

    // المراحل بالترتيب — كل مرحلة مستقلة
    await _phase1Settings(report);
    await _phase2Categories(report);
    await _phase3Users(report);
    await _phase4Shops(report);
    await _phase5Products(report);
    await _phase6Offers(report);
    await _phase7Services(report); // الخدمات + التقييمات (reviews بتتزرع هنا)
    await _phase8Ads(report);
    await _phase9CommunityContent(report);
    await _phase10CommunityContent(report);

    // اكتمال كامل
    onProgress?.call(const SeederProgress(
      phase: _totalPhases,
      totalPhases: _totalPhases,
      phaseName: 'اكتمل',
      phasePercent: 100,
      overallPercent: 100,
      detail: '✅ تم رفع جميع البيانات التجريبية',
    ));

    developer.log('DatabaseSeeder: completed', name: 'DatabaseSeeder');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // تنظيف المحتوى (✅ Item #4)
  // ─────────────────────────────────────────────────────────────────────────

  /// حجم الصفحة عند المسح (حد Firestore للـ batch الواحد = 500 عملية).
  static const int _deletePageSize = 100;

  /// المجموعات اللي بيمسحها [cleanDatabase]. المفتاح = اسم المجموعة، والقيمة =
  /// الـ subcollections اللي لازم تتمسح قبل المستند الأب (Firestore مبيمسحهاش
  /// تلقائيًا، ولو اتسابت هتفضل يتيمة).
  ///
  /// ⚠️ محتوى التطبيق فقط. مقصود إنها مش بتشمل: users، settings، activation_codes،
  /// notifications، wishlists، complaints، referrals، admin_audit_log.
  static const Map<String, List<String>> _cleanableCollections = {
    'shops': ['daily_stats'],
    'products': [],
    'categories': [],
    'offers': [],
    'ads': [],
    'reviews': [],
    'services': [],
    'job_ads': [],
    'dealer_listings': [],
    // ✅ Fix #15: العروض الآن collection أعلى مستوى. تنظيف subcollection
    // service_requests/{id}/service_bids يبقى لمسح بيانات قديمة زُرعت قبل التوحيد.
    'service_bids': [],
    'service_requests': ['service_bids'],
  };

  /// ✅ Item #4: يمسح محتوى التطبيق نهائيًا (محلات، منتجات، فئات، عروض، إعلانات،
  /// تقييمات، خدمات، وظائف، قوائم الديلر، طلبات الخدمة) ويسيب الحسابات والإعدادات
  /// وأكواد التفعيل، زي ما بتوعد رسالة التأكيد في تاب إعدادات الأدمن.
  ///
  /// عملية مدمّرة ونهائية → محمية بنفس شرط الـ seeder (BuildFlags.mockModeEnabled).
  /// بترمي [SeederException] برسالة جاهزة للعرض عند الفشل.
  static Future<void> cleanDatabase() async {
    if (!BuildFlags.mockModeEnabled) {
      developer.log(
          'DatabaseSeeder.cleanDatabase: blocked (mock mode disabled)',
          name: 'DatabaseSeeder');
      throw const SeederException('غير متاح في بيئة الإنتاج');
    }

    developer.log('DatabaseSeeder: cleaning content collections',
        name: 'DatabaseSeeder');

    for (final entry in _cleanableCollections.entries) {
      try {
        await _deleteCollection(_db.collection(entry.key),
            subcollections: entry.value);
      } on FirebaseException catch (e) {
        developer.log('DatabaseSeeder: failed to clean ${entry.key}',
            name: 'DatabaseSeeder', error: e);
        throw SeederException('تعذّر حذف "${entry.key}" (${e.code})');
      } catch (e) {
        developer.log('DatabaseSeeder: failed to clean ${entry.key}',
            name: 'DatabaseSeeder', error: e);
        throw SeederException('تعذّر حذف "${entry.key}"');
      }
    }

    developer.log('DatabaseSeeder: clean completed', name: 'DatabaseSeeder');
  }

  /// يمسح كل مستندات [col] على صفحات، ومعاها الـ [subcollections] تحت كل مستند.
  static Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col, {
    List<String> subcollections = const [],
  }) async {
    while (true) {
      final snap = await col.limit(_deletePageSize).get();
      if (snap.docs.isEmpty) return;

      for (final doc in snap.docs) {
        for (final sub in subcollections) {
          await _deleteCollection(doc.reference.collection(sub));
        }
      }

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // أقل من حجم الصفحة = كل المستندات اتمسحت.
      if (snap.docs.length < _deletePageSize) return;
      await _delay();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 1 — إعدادات التطبيق (settings + locations)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase1Settings(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 1;
    const name = 'الإعدادات والمناطق';
    report(phase, name, 0);

    try {
      // ✅ settings/general — إعدادات عامة مقروءة للعالم. لا يُكتَب geminiApiKey
      // بالكود أبداً ولا هنا أصلاً (Fix #17): المفتاح في settings_private/gemini
      // ويُعبَّأ يدوياً من لوحة الأدمن.
      await _db.collection('settings').doc('general').set({
        'appName': 'سنهور أونلاين',
        'appVersion': '1.0.0',
        'maintenanceMode': false,
        'maxShopsPerUser': 3,
        'maxProductsPerShop': 100,
        'defaultSubscriptionDays': 30,
        'contactEmail': 'support@sanhour.online',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      report(phase, name, 50, detail: 'تم: الإعدادات العامة');

      // ✅ settings/locations — فهرس المناطق للفلترة في الرئيسية
      await _db.collection('settings').doc('locations').set({
        'areas': [
          'سنهور القبلية',
          'المراشدة',
          'المحلة الكبرى',
          'السنطة',
          'كفر الزيات',
          'طنطا',
          'شبين الكوم',
          'الجيزة',
          'القاهرة',
          'الإسكندرية',
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      report(phase, name, 100, detail: 'تم: الإعدادات + 10 مناطق');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 2 — الفئات والفئات الفرعية
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase2Categories(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 2;
    const name = 'الفئات';
    report(phase, name, 0);

    // ✅ إصلاح جوهري: الحقول الآن تطابق CategoryModel.fromMap تماماً —
    // iconName (وليس iconEmoji) + colorValue (رقم Hex) + subCategories
    // (بحرف S كبير، وليس subcategories) — الاختلاف في حالة الأحرف كان
    // يمنع تحميل الفئات الفرعية في التطبيق نهائياً رغم كتابتها في القاعدة.
    // ✅ إضافة subSubCategories فعلية — المستوى الثالث اللازم لنظام الـ
    // chips الهرمي الجديد في categories_screen.dart
    final categories = [
      {
        'name': 'مأكولات ومشروبات',
        'iconName': 'restaurant',
        'colorValue': 0xFFE53935,
        'subCategories': ['مطاعم', 'حلويات', 'عصائر ومشروبات', 'بقالة', 'فرن ومخبز'],
        'subSubCategories': {
          'مطاعم': ['مطاعم شرقية', 'مطاعم مشويات', 'مطاعم بحري', 'وجبات سريعة'],
          'حلويات': ['حلويات شرقية', 'كيك وتورت', 'حلويات غربية'],
          'عصائر ومشروبات': ['عصائر طازجة', 'مشروبات ساخنة', 'سموزي وميلك شيك'],
        },
      },
      {
        'name': 'ملابس وأزياء',
        'iconName': 'checkroom',
        'colorValue': 0xFFAB47BC,
        'subCategories': ['ملابس رجالي', 'ملابس حريمي', 'ملابس أطفال', 'أحذية وحقائب', 'ملابس رياضية'],
        'subSubCategories': {
          'ملابس حريمي': ['فساتين', 'عبايات', 'ملابس محجبات', 'ملابس سواريه'],
          'ملابس رجالي': ['قمصان', 'بدل رسمية', 'ملابس كاجوال'],
          'أحذية وحقائب': ['أحذية رجالي', 'أحذية حريمي', 'حقائب يد', 'شنط سفر'],
        },
      },
      {
        'name': 'أجهزة إلكترونية',
        'iconName': 'phone_android',
        'colorValue': 0xFF1E88E5,
        'subCategories': ['موبايلات', 'أجهزة كمبيوتر', 'أجهزة منزلية', 'إكسسوارات', 'صيانة إلكترونيات'],
        'subSubCategories': {
          'موبايلات': ['آيفون', 'سامسونج', 'شاومي', 'إكسسوارات موبايل'],
          'أجهزة كمبيوتر': ['لابتوب', 'أجهزة مكتبية', 'طابعات وسكانر'],
        },
      },
      {
        'name': 'صحة وجمال',
        'iconName': 'health_and_safety',
        'colorValue': 0xFF43A047,
        'subCategories': ['صيدليات', 'عيادات أسنان', 'عيادات عامة', 'مستحضرات تجميل', 'صالونات'],
        'subSubCategories': {
          'صيدليات': ['أدوية', 'فيتامينات ومكملات', 'مستلزمات أطفال'],
          'صالونات': ['صالونات حريمي', 'صالونات رجالي', 'سبا ومساج'],
        },
      },
      {
        'name': 'خدمات منزلية',
        'iconName': 'handyman',
        'colorValue': 0xFFFB8C00,
        'subCategories': ['كهرباء وسباكة', 'نجارة وديكور', 'تكييف وتبريد', 'نظافة', 'صيانة عامة'],
        'subSubCategories': {
          'كهرباء وسباكة': ['فني كهرباء', 'فني سباكة', 'صيانة عدادات'],
          'تكييف وتبريد': ['تركيب تكييف', 'صيانة تكييف', 'ثلاجات وفريزر'],
        },
      },
      {
        'name': 'تعليم وتدريب',
        'iconName': 'school',
        'colorValue': 0xFF3949AB,
        'subCategories': ['مراكز تعليمية', 'دروس خصوصية', 'لغات أجنبية', 'تدريب مهني', 'روضة وحضانة'],
        'subSubCategories': {
          'دروس خصوصية': ['رياضيات', 'لغة عربية', 'علوم', 'دروس ابتدائي'],
          'لغات أجنبية': ['إنجليزي', 'فرنساوي', 'ألماني'],
        },
      },
      {
        'name': 'مواصلات وسيارات',
        'iconName': 'directions_car',
        'colorValue': 0xFF6D4C41,
        'subCategories': ['ميكانيكا سيارات', 'غيار وقطع', 'كراج', 'أوناش', 'نقل أثاث'],
        'subSubCategories': <String, List<String>>{},
      },
      {
        'name': 'خدمات مهنية',
        'iconName': 'gavel',
        'colorValue': 0xFF546E7A,
        'subCategories': ['محاسبة وقانون', 'تصميم وطباعة', 'تصوير', 'ترجمة', 'استشارات'],
        'subSubCategories': <String, List<String>>{},
      },
      {
        'name': 'ذهب ومجوهرات',
        'iconName': 'diamond',
        'colorValue': 0xFFFFB300,
        'subCategories': ['ذهب وفضة', 'ساعات', 'إكسسوارات فاخرة'],
        'subSubCategories': <String, List<String>>{},
      },
      {
        'name': 'عقارات',
        'iconName': 'home_work',
        'colorValue': 0xFF00897B,
        'subCategories': ['شقق للإيجار', 'شقق للبيع', 'محلات تجارية', 'أراضي', 'مكاتب عقارية'],
        'subSubCategories': <String, List<String>>{},
      },
    ];

    try {
      await _batchWrite(
        collection: 'categories',
        items: categories,
        getDocId: (item) => (item['name'] as String)
            .replaceAll(' ', '_')
            .replaceAll('ة', 'a'),
        buildData: (item) => {
          ...item,
          'createdAt': FieldValue.serverTimestamp(),
        },
        onBatchDone: (done, total) =>
            report(phase, name, (done * 100 ~/ total), detail: 'تم $done/$total فئة'),
      );
      report(phase, name, 100, detail: 'تم: ${categories.length} فئة (مع فئات دقيقة)');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 3 — المستخدمون
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase3Users(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 3;
    const name = 'المستخدمون';
    report(phase, name, 0);

    // ✅ يطابق _normalizePhone في AuthProvider
    final users = [
      {
        'id': 'mock_admin',
        'name': 'أحمد سنهور',
        'username': 'admin_sanhour',
        'phone': '+201008908728',
        'email': '',
        'userType': 'admin',
        'shopRole': 'owner',
        'profileImageUrl': 'https://ui-avatars.com/api/?name=Admin&background=5E35B1&color=fff',
        'fcmToken': '',
        'referralCode': 'ADMIN001',
        'linkedShopId': '',
        'isSuspended': false,
        'isDeleted': false,
        'isMockUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'mock_merchant',
        'name': 'محمد التاجر',
        'username': 'merchant_sanhour',
        'phone': '+201234567890',
        'email': '',
        'userType': 'merchant',
        'shopRole': 'owner',
        'profileImageUrl': 'https://ui-avatars.com/api/?name=Merchant&background=1E88E5&color=fff',
        'fcmToken': '',
        'referralCode': 'MERCH001',
        'linkedShopId': 'shop_bakery',
        'isSuspended': false,
        'isDeleted': false,
        'isMockUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'mock_user',
        'name': 'سارة العميلة',
        'username': 'sara_user',
        'phone': '+201112223334',
        'email': '',
        'userType': 'customer',
        'shopRole': null,
        'profileImageUrl': 'https://ui-avatars.com/api/?name=Sara&background=E53935&color=fff',
        'fcmToken': '',
        'referralCode': 'USER001',
        'linkedShopId': '',
        'isSuspended': false,
        'isDeleted': false,
        'isMockUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'user_002',
        'name': 'علي العطار',
        'username': 'ali_attar',
        'phone': '+201555123456',
        'email': '',
        'userType': 'customer',
        'shopRole': null,
        'profileImageUrl': 'https://ui-avatars.com/api/?name=Ali&background=00897B&color=fff',
        'fcmToken': '',
        'referralCode': 'USER002',
        'linkedShopId': '',
        'isSuspended': false,
        'isDeleted': false,
        'isMockUser': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'user_003',
        'name': 'فاطمة محمود',
        'username': 'fatma_mahmoud',
        'phone': '+201666789012',
        'email': '',
        'userType': 'merchant',
        'shopRole': 'owner',
        'profileImageUrl': 'https://ui-avatars.com/api/?name=Fatma&background=F44336&color=fff',
        'fcmToken': '',
        'referralCode': 'USER003',
        'linkedShopId': 'shop_fashion',
        'isSuspended': false,
        'isDeleted': false,
        'isMockUser': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      for (int i = 0; i < users.length; i++) {
        final u = users[i];
        await _db.collection('users').doc(u['id'] as String).set(
            u, SetOptions(merge: true));
        await _delay();
        report(phase, name, ((i + 1) * 100 ~/ users.length),
            detail: 'تم ${i + 1}/${users.length} مستخدم');
      }
      report(phase, name, 100, detail: 'تم: ${users.length} مستخدمين');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 4 — المحلات
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase4Shops(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 4;
    const name = 'المحلات';
    report(phase, name, 0);

    final now = DateTime.now();
    final shops = [
      {
        'id': 'shop_bakery',
        'name': 'فرن سنهور الذهبي',
        'ownerId': 'mock_merchant',
        'category': 'مأكولات ومشروبات',
        'location': 'سنهور القبلية — الشارع الرئيسي',
        'description': 'أفضل فرن في سنهور — خبز طازج وحلويات شرقية يومياً منذ 1995',
        'phone': '01234567890',
        'whatsapp': '201234567890',
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
        'coverUrl': 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=800',
        'mediaUrls': [
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
          'https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=600',
        ],
        'mediaTypes': ['image', 'image'],
        'rating': 4.7,
        'reviewCount': 12,
        'views': 340,
        'favoriteCount': 28,
        'isSuspended': false,
        'isFeatured': true,
        'rank': 1,
        'workingHours': '6 ص — 10 م',
        'workingDays': ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'],
        'subscriptionPlan': 'gold',
        'subscriptionStatus': 'active',
        'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
        'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 10))),
        'searchKeywords': _keywords('فرن سنهور ذهبي مأكولات خبز حلويات'),
        'facebookUrl': '',
        'instagramUrl': '',
        'tiktokUrl': '',
        'telegramUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'shop_fashion',
        'name': 'بوتيك الأناقة',
        'ownerId': 'user_003',
        'category': 'ملابس وأزياء',
        'location': 'سنهور القبلية — ميدان المحطة',
        'description': 'آخر صيحات الموضة النسائية والأطفال — ملابس محجبات وسواريه',
        'phone': '01112223334',
        'whatsapp': '201112223334',
        'imageUrl': 'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=400',
        'coverUrl': 'https://images.unsplash.com/photo-1441984904996-e0b6ba687e04?w=800',
        'mediaUrls': [
          'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=600',
        ],
        'mediaTypes': ['image'],
        'rating': 4.2,
        'reviewCount': 8,
        'views': 210,
        'favoriteCount': 19,
        'isSuspended': false,
        'isFeatured': false,
        'rank': 2,
        'workingHours': '10 ص — 11 م',
        'workingDays': ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الجمعة'],
        'subscriptionPlan': 'silver',
        'subscriptionStatus': 'active',
        'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 25))),
        'searchKeywords': _keywords('بوتيك أناقة ملابس حريمي أطفال محجبات'),
        'facebookUrl': '',
        'instagramUrl': '',
        'tiktokUrl': '',
        'telegramUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'shop_pharmacy',
        'name': 'صيدلية الشفاء',
        'ownerId': 'user_002',
        'category': 'صحة وجمال',
        'location': 'سنهور القبلية — أمام المستشفى',
        'description': 'جميع الأدوية والمستلزمات الطبية — خدمة 24 ساعة',
        'phone': '01555123456',
        'whatsapp': '201555123456',
        'imageUrl': 'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=400',
        'coverUrl': 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800',
        'mediaUrls': [],
        'mediaTypes': [],
        'rating': 4.9,
        'reviewCount': 22,
        'views': 520,
        'favoriteCount': 45,
        'isSuspended': false,
        'isFeatured': true,
        'rank': 3,
        'workingHours': '24 ساعة',
        'workingDays': ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'],
        'subscriptionPlan': 'gold',
        'subscriptionStatus': 'active',
        'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 29))),
        'searchKeywords': _keywords('صيدلية شفاء دواء أدوية طب صحة'),
        'facebookUrl': '',
        'instagramUrl': '',
        'tiktokUrl': '',
        'telegramUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      for (int i = 0; i < shops.length; i++) {
        final s = Map<String, dynamic>.from(shops[i]);
        final id = s.remove('id') as String;
        await _db.collection('shops').doc(id).set(s, SetOptions(merge: true));
        await _delay();
        report(phase, name, ((i + 1) * 100 ~/ shops.length),
            detail: 'تم ${i + 1}/${shops.length} محل');
      }
      report(phase, name, 100, detail: 'تم: ${shops.length} محلات');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 5 — المنتجات
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase5Products(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 5;
    const name = 'المنتجات';
    report(phase, name, 0);

    final products = [
      // فرن سنهور الذهبي — 4 منتجات
      {
        'shopId': 'shop_bakery',
        'name': 'كعك عيد الفطر',
        'price': 25.0, 'oldPrice': 30.0,
        'hasPriceDrop': true, 'hasDiscount': true, 'discountPercentage': 16.7,
        'description': 'كعك مصري أصيل بالعجوة والمكسرات — يُباع بالكيلو',
        'imageUrls': ['https://images.unsplash.com/photo-1605980625600-88d6716abe44?w=400'],
        'coverImageIndex': 0, 'category': 'مأكولات ومشروبات',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.8, 'reviewCount': 6, 'views': 95,
        'searchKeywords': _keywords('كعك عيد فطر مصري عجوة مكسرات'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_bakery',
        'name': 'خبز بلدي — ربطة',
        'price': 4.0, 'oldPrice': 0.0,
        'hasPriceDrop': false, 'hasDiscount': false, 'discountPercentage': 0.0,
        'description': 'خبز بلدي طازج يومياً — ربطة 10 أرغفة',
        'imageUrls': ['https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400'],
        'coverImageIndex': 0, 'category': 'مأكولات ومشروبات',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.5, 'reviewCount': 15, 'views': 220,
        'searchKeywords': _keywords('خبز بلدي رغيف طازج'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_bakery',
        'name': 'تورتة شوكولاتة — 1 كيلو',
        'price': 150.0, 'oldPrice': 180.0,
        'hasPriceDrop': true, 'hasDiscount': true, 'discountPercentage': 16.7,
        'description': 'تورتة شوكولاتة بلجيكية بالكريمة والفراولة — طازجة يومياً',
        'imageUrls': ['https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400'],
        'coverImageIndex': 0, 'category': 'مأكولات ومشروبات',
        'isVisible': true, 'isShopHidden': false,
        'rating': 5.0, 'reviewCount': 4, 'views': 68,
        'searchKeywords': _keywords('تورتة شوكولاتة كريمة فراولة'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_bakery',
        'name': 'بسكويت زبدة — علبة',
        'price': 35.0, 'oldPrice': 0.0,
        'hasPriceDrop': false, 'hasDiscount': false, 'discountPercentage': 0.0,
        'description': 'بسكويت زبدة هولندي الطعم — علبة 500 جرام',
        'imageUrls': ['https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400'],
        'coverImageIndex': 0, 'category': 'مأكولات ومشروبات',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.3, 'reviewCount': 3, 'views': 44,
        'searchKeywords': _keywords('بسكويت زبدة هولندي علبة'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      // بوتيك الأناقة — 3 منتجات
      {
        'shopId': 'shop_fashion',
        'name': 'فستان سواريه أزرق',
        'price': 450.0, 'oldPrice': 600.0,
        'hasPriceDrop': true, 'hasDiscount': true, 'discountPercentage': 25.0,
        'description': 'فستان سواريه أزرق ملكي مع زركشة ذهبية — مقاسات S/M/L/XL',
        'imageUrls': ['https://images.unsplash.com/photo-1566174053879-31528523f8ae?w=400'],
        'coverImageIndex': 0, 'category': 'ملابس وأزياء',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.6, 'reviewCount': 5, 'views': 88,
        'searchKeywords': _keywords('فستان سواريه أزرق ملكي زركشة ذهبية'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_fashion',
        'name': 'حجاب شيفون مطبوع',
        'price': 80.0, 'oldPrice': 0.0,
        'hasPriceDrop': false, 'hasDiscount': false, 'discountPercentage': 0.0,
        'description': 'حجاب شيفون مطبوع بالورود — متوفر 12 لون — خامة عالية الجودة',
        'imageUrls': ['https://images.unsplash.com/photo-1541698444083-023c97d3f4b6?w=400'],
        'coverImageIndex': 0, 'category': 'ملابس وأزياء',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.1, 'reviewCount': 7, 'views': 67,
        'searchKeywords': _keywords('حجاب شيفون مطبوع ورود لون'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      // صيدلية الشفاء — 2 منتجات
      {
        'shopId': 'shop_pharmacy',
        'name': 'مرهم فولتارين 2%',
        'price': 45.0, 'oldPrice': 0.0,
        'hasPriceDrop': false, 'hasDiscount': false, 'discountPercentage': 0.0,
        'description': 'مرهم ديكلوفيناك لتخفيف آلام المفاصل والعضلات — 50 جرام',
        'imageUrls': ['https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400'],
        'coverImageIndex': 0, 'category': 'صحة وجمال',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.7, 'reviewCount': 9, 'views': 130,
        'searchKeywords': _keywords('فولتارين مرهم ألم مفاصل عضلات'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_pharmacy',
        'name': 'فيتامين سي 1000 ملجم — 30 قرص',
        'price': 65.0, 'oldPrice': 70.0,
        'hasPriceDrop': true, 'hasDiscount': true, 'discountPercentage': 7.1,
        'description': 'فيتامين ج تركيز عالي لتقوية المناعة — 30 قرص فوار',
        'imageUrls': ['https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=400'],
        'coverImageIndex': 0, 'category': 'صحة وجمال',
        'isVisible': true, 'isShopHidden': false,
        'rating': 4.9, 'reviewCount': 14, 'views': 195,
        'searchKeywords': _keywords('فيتامين ج سي مناعة قرص فوار'),
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      await _batchWrite(
        collection: 'products',
        items: products,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, (done * 100 ~/ total), detail: 'تم $done/$total منتج'),
      );
      report(phase, name, 100, detail: 'تم: ${products.length} منتجات');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 6 — العروض
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase6Offers(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 6;
    const name = 'العروض';
    report(phase, name, 0);

    final now = DateTime.now();
    final offers = [
      {
        'shopId': 'shop_bakery',
        'type': 'discount',
        'title': 'خصم 20% على الكيك في المواسم',
        'description': 'احتفل بمناسباتك معنا — خصم 20% على جميع الكيك بالطلب المسبق',
        'discount': 20,
        // ✅ Fix: Timestamp بدلاً من ISO String
        'validUntil': Timestamp.fromDate(now.add(const Duration(days: 14))),
        'imageUrls': ['https://images.unsplash.com/photo-1606890737304-57a1ca8a5b62?w=600'],
        'coverImageIndex': 0,
        'isActive': true, 'isShopHidden': false,
        'searchKeywords': _keywords('خصم كيك مناسبات احتفال'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_fashion',
        'type': 'price_drop',
        'title': 'تخفيض جنوني — فستان سواريه',
        'description': 'الفستان الأزرق بـ 450 بدلاً من 600 — العرض لفترة محدودة جداً',
        'discount': 25,
        'validUntil': Timestamp.fromDate(now.add(const Duration(days: 5))),
        'imageUrls': ['https://images.unsplash.com/photo-1566174053879-31528523f8ae?w=600'],
        'coverImageIndex': 0,
        'isActive': true, 'isShopHidden': false,
        'searchKeywords': _keywords('فستان سواريه تخفيض عرض'),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_pharmacy',
        'type': 'special',
        'title': 'عرض مميز — فيتامينات الشتاء',
        'description': 'اشتري فيتامين ج + زنك + كالسيوم بخصم 15% على الفاتورة الإجمالية',
        'discount': 15,
        'validUntil': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'imageUrls': ['https://images.unsplash.com/photo-1559757175-0eb30cd8c063?w=600'],
        'coverImageIndex': 0,
        'isActive': true, 'isShopHidden': false,
        'searchKeywords': _keywords('فيتامينات شتاء عرض خصم صيدلية'),
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      await _batchWrite(
        collection: 'offers',
        items: offers,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, (done * 100 ~/ total), detail: 'تم $done/$total عرض'),
      );
      report(phase, name, 100, detail: 'تم: ${offers.length} عروض');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 7 — الخدمات والتقييمات
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase7Services(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 7;
    const name = 'الخدمات والتقييمات';
    report(phase, name, 0);

    try {
      // ── خدمات ────────────────────────────────────────────────────────────
      final services = [
        {
          'shopId': 'shop_bakery', 'ownerId': 'mock_merchant',
          'name': 'طلب كيكة مخصصة',
          'description': 'نصنع لك كيكة بالاسم والمناسبة في أقل من 24 ساعة',
          'price': 200.0, 'isVisible': true, 'isShopHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'shopId': 'shop_bakery', 'ownerId': 'mock_merchant',
          'name': 'توصيل طلبات الأفراح',
          'description': 'توصيل الكيكات والحلويات لقاعات الأفراح داخل سنهور',
          'price': 100.0, 'isVisible': true, 'isShopHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'shopId': 'shop_pharmacy', 'ownerId': 'user_002',
          'name': 'توصيل الأدوية للمنزل',
          'description': 'نوصل أدويتك لمنزلك في أقل من ساعة داخل سنهور',
          'price': 20.0, 'isVisible': true, 'isShopHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'shopId': 'shop_pharmacy', 'ownerId': 'user_002',
          'name': 'قياس ضغط الدم مجاناً',
          'description': 'خدمة مجانية لقياس ضغط الدم بدون موعد',
          'price': 0.0, 'isVisible': true, 'isShopHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      await _batchWrite(
        collection: 'services',
        items: services,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, (done * 50 ~/ total), detail: 'خدمات: $done/$total'),
      );

      await _delay();

      // ── تقييمات ───────────────────────────────────────────────────────────
      final reviews = [
        {
          'userId': 'mock_user', 'targetId': 'shop_bakery', 'targetType': 'shop',
          'rating': 5.0, 'comment': 'فرن رائع! الخبز طازج دايماً والكيك ولا أجمل ✨',
          'hasReply': true, 'reply': 'شكراً جزيلاً يا سارة! يسعدنا دايماً خدمتك 🙏',
          'repliedAt': FieldValue.serverTimestamp(),
          'images': [], 'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'userId': 'user_002', 'targetId': 'shop_bakery', 'targetType': 'shop',
          'rating': 4.0, 'comment': 'خبز طيب ومتوفر بكرة بكرة، بس أحياناً بيخلص بدري الصبح',
          'hasReply': false, 'reply': null, 'repliedAt': null,
          'images': [], 'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'userId': 'mock_user', 'targetId': 'shop_pharmacy', 'targetType': 'shop',
          'rating': 5.0, 'comment': 'أحسن صيدلية! عندهم كل حاجة والتوصيل سريع جداً',
          'hasReply': false, 'reply': null, 'repliedAt': null,
          'images': [], 'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'userId': 'user_002', 'targetId': 'shop_fashion', 'targetType': 'shop',
          'rating': 4.0, 'comment': 'أسعار مناسبة وتشكيلة كويسة، بس المحل بيبقى زحمة يوم الجمعة',
          'hasReply': false, 'reply': null, 'repliedAt': null,
          'images': [], 'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      await _batchWrite(
        collection: 'reviews',
        items: reviews,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, 50 + (done * 50 ~/ total),
                detail: 'تقييمات: $done/$total'),
      );

      report(phase, name, 100, detail: 'تم: ${services.length} خدمات + ${reviews.length} تقييمات');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 8 — الإعلانات التجارية
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase8Ads(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 8;
    const name = 'الإعلانات التجارية';
    report(phase, name, 0);

    final now = DateTime.now();
    final ads = [
      {
        'shopId': 'shop_bakery',
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
        'imageUrls': ['https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800'],
        'coverImageIndex': 0,
        'text': '🥐 فرن سنهور الذهبي — خبز وحلويات طازجة كل يوم من 1995',
        'targetType': 'shop',
        'targetId': 'shop_bakery',
        'displayLocations': ['home', 'splash', 'ads_screen'],
        'isActive': true,
        'clickCount': 42,
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 10))),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'shopId': 'shop_fashion',
        'imageUrl': 'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=800',
        'imageUrls': ['https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=800'],
        'coverImageIndex': 0,
        'text': '👗 بوتيك الأناقة — خصومات تصل لـ 25% على الفساتين طول الشهر',
        'targetType': 'shop',
        'targetId': 'shop_fashion',
        'displayLocations': ['home', 'ads_screen'],
        'isActive': true,
        'clickCount': 18,
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 25))),
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      await _batchWrite(
        collection: 'ads',
        items: ads,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, (done * 100 ~/ total), detail: 'تم $done/$total إعلان'),
      );
      report(phase, name, 100, detail: 'تم: ${ads.length} إعلانات');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 9 — إعلانات الوظائف وطلبات الخدمات وقوائم الديلر
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase9CommunityContent(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 9;
    const name = 'وظائف وطلبات وديلر';
    report(phase, name, 0);

    final now = DateTime.now();

    try {
      // ── إعلانات الوظائف ✅ يطابق JobAdModel.fromMap fields تماماً ──────────
      final jobAds = [
        {
          'posterId': 'mock_merchant',
          'posterName': 'محمد التاجر — فرن سنهور الذهبي',
          'posterPhone': '01234567890',
          'title': 'مطلوب عامل فرن خبرة',
          'description': 'مطلوب عامل فرن خبرة في العجن والإنتاج — الدوام من 4 ص لـ 12 ظ',
          'category': 'مأكولات ومشروبات',
          'location': 'سنهور القبلية',
          'salary': 3500.0,
          'salaryDisplay': '3,500 جنيه / شهر',
          'workType': 'full_time',
          'isActive': true,
          'requiredCount': 2,
          'applicationCount': 5,
          'viewCount': 67,
          // ✅ Fix: expiresAt بدلاً من deadline
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'searchKeywords': _keywords('وظيفة عامل فرن خبرة مأكولات'),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'posterId': 'user_003',
          'posterName': 'فاطمة محمود — بوتيك الأناقة',
          'posterPhone': '01112223334',
          'title': 'مندوبة مبيعات ملابس',
          'description': 'مطلوبة مندوبة مبيعات محجبة خبرة في ملابس الحريمي — لبق وشاطرة',
          'category': 'ملابس وأزياء',
          'location': 'سنهور القبلية',
          'salary': 2800.0,
          'salaryDisplay': 'يُتفق عليه',
          'workType': 'full_time',
          'isActive': true,
          'requiredCount': 1,
          'applicationCount': 8,
          'viewCount': 112,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 20))),
          'searchKeywords': _keywords('وظيفة مندوبة مبيعات ملابس حريمي'),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'posterId': 'mock_user',
          'posterName': 'سارة العميلة',
          'posterPhone': '01112223334',
          'title': 'مدرس/ة رياضيات لجميع المراحل',
          'description': 'مطلوب مدرس رياضيات دروس خصوصية — ابتدائي وإعدادي وثانوي',
          'category': 'تعليم وتدريب',
          'location': 'سنهور القبلية',
          'salary': 0.0,
          'salaryDisplay': 'يُتفق عليه بالساعة',
          'workType': 'part_time',
          'isActive': true,
          'requiredCount': 1,
          'applicationCount': 3,
          'viewCount': 45,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 14))),
          'searchKeywords': _keywords('دروس رياضيات مدرس تعليم خصوصي'),
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      await _batchWrite(
        collection: 'job_ads',
        items: jobAds,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, (done * 30 ~/ total), detail: 'وظائف: $done/$total'),
      );

      await _delay();

      // ── طلبات الخدمات ─────────────────────────────────────────────────────
      final serviceRequests = [
        {
          'id': 'req_001',
          'clientId': 'mock_user',
          'clientPhone': '01112223334',
          'title': 'تصليح مكيف كاريير',
          'description': 'المكيف ما بيبردش وبيصدر صوت غريب — مكيف كاريير 1.5 حصان',
          'category': 'خدمات منزلية',
          'location': 'سنهور القبلية',
          'status': 'open',
          'bidsCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'req_002',
          'clientId': 'user_002',
          'clientPhone': '01555123456',
          'title': 'مطلوب تصميم شعار لمحل',
          'description': 'محتاج مصمم جرافيك يعمل لوجو لمحل ملابس — الأجر مفتوح',
          'category': 'خدمات مهنية',
          'location': 'سنهور القبلية',
          'status': 'open',
          'bidsCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (int i = 0; i < serviceRequests.length; i++) {
        final req = Map<String, dynamic>.from(serviceRequests[i]);
        final docId = req.remove('id') as String;
        final ref = _db.collection('service_requests').doc(docId);
        await ref.set(req, SetOptions(merge: true));

        // ✅ Fix #15: service_bids collection أعلى مستوى (كما تكتب الشاشات وتحرس
        // القواعد وكما يقرأ ServiceBidModel) — لا subcollection تحت الطلب.
        // معرّف ثابت وحقل id مطابق له حتى لا يتكرر العرض عند إعادة الزرع.
        if (docId == 'req_001') {
          const bidId = 'bid_req_001_user_003';
          await _db.collection('service_bids').doc(bidId).set({
            'id': bidId,
            'requestId': 'req_001',
            'providerId': 'user_003',
            'providerName': 'فاطمة محمود',
            'providerPhone': '01112223334',
            'offeredPrice': 350.0,
            'note': 'عندي خبرة 5 سنين في تصليح التكييفات، أقدر أجيلك النهارده',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await _delay();
        report(phase, name, 30 + (i + 1) * 30 ~/ serviceRequests.length,
            detail: 'طلبات: ${i + 1}/${serviceRequests.length}');
      }

      await _delay();

      // ── ✅ dealer_listings (وليس dealer_ads) — اسم المجموعة الصحيح ─────────
      final dealerListings = [
        {
          'sellerId': 'mock_user',
          'title': 'موبايل سامسونج S22 — استعمال سنة',
          'description': 'موبايل Samsung Galaxy S22 128GB — استعمال سنة واحدة بس، شاشة سليمة بالكامل',
          'price': 8500.0,
          'category': 'أجهزة إلكترونية',
          'condition': 'used_excellent',
          'imageUrls': ['https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=400'],
          'phone': '01112223334',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'sellerId': 'user_002',
          'title': 'طاولة مطبخ خشب زان',
          'description': 'طاولة مطبخ خشب زان اصلي 6 كراسي — بحالة ممتازة، سبب البيع: فرنيشة جديدة',
          'price': 3200.0,
          'category': 'خدمات منزلية',
          'condition': 'used_good',
          'imageUrls': ['https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400'],
          'phone': '01555123456',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'sellerId': 'mock_merchant',
          'title': 'دراجة أطفال 16 بوصة',
          'description': 'دراجة أطفال وردي — مستخدمة موسم واحد بس، عجلة كبيرة مع تدريب',
          'price': 850.0,
          'category': 'ملابس وأزياء',
          'condition': 'used_good',
          'imageUrls': ['https://images.unsplash.com/photo-1571188654248-7a89213915f7?w=400'],
          'phone': '01234567890',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      await _batchWrite(
        collection: 'dealer_listings',
        items: dealerListings,
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, 60 + (done * 40 ~/ total), detail: 'ديلر: $done/$total'),
      );

      report(phase, name, 100, detail:
          'تم: ${jobAds.length} وظائف + ${serviceRequests.length} طلبات + ${dealerListings.length} ديلر');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // المرحلة 10 — القوائم والإشعارات وكودات التفعيل وسجل التدقيق
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _phase10CommunityContent(
      void Function(int, String, int, {String? detail}) report) async {
    const phase = 10;
    const name = 'القوائم والإشعارات والأكواد';
    report(phase, name, 0);

    final now = DateTime.now();

    try {
      // ── Wishlists ──────────────────────────────────────────────────────────
      await _db.collection('wishlists').doc('wishlist_sara_001').set({
        'name': 'قائمة الموضة',
        'ownerId': 'mock_user',
        'isPublic': false,
        'collaborators': [],
        'items': [
          {
            'id': 'shop_fashion',
            'itemId': 'shop_fashion',
            'type': 'shop',
            'name': 'بوتيك الأناقة',
            'imageUrl': 'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=400',
            'price': 0.0,
            'addedAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      report(phase, name, 20, detail: 'تم: قوائم المفضلة');
      await _delay();

      // ── Notifications (in-app) ─────────────────────────────────────────────
      final notifications = [
        {
          'targetUserId': 'mock_user',
          'fromUserId': 'system',
          'title': '🎉 مرحباً بك في سنهور أونلاين',
          'body': 'اكتشف أفضل المحلات والعروض في سنهور القبلية',
          'type': 'welcome',
          'isRead': false,
          'data': {'route': 'home', 'channel': 'general'},
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'targetUserId': 'mock_user',
          'fromUserId': 'system',
          'title': '🏷️ عرض جديد: خصم 25% فستان سواريه',
          'body': 'بوتيك الأناقة أضاف عرضاً جديداً — استغله قبل ما ينتهي!',
          'type': 'new_offer',
          'isRead': false,
          'data': {'route': 'shop_detail', 'targetId': 'shop_fashion', 'channel': 'offers'},
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'targetUserId': 'mock_merchant',
          'fromUserId': 'system',
          'title': '📊 إحصائيات محلك هذا الأسبوع',
          'body': 'فرن سنهور الذهبي — 340 مشاهدة هذا الأسبوع. استمر!',
          'type': 'merchant_stats',
          'isRead': true,
          'data': {'route': 'merchant', 'channel': 'merchant_stats'},
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      // ✅ Fix #14: الصندوق الداخلي الموحّد هو notifications (وليس
      // user_notifications الذي لا يقرؤه أحد). معرّف ثابت لكل إشعار حتى لا
      // تتكرر الإشعارات عند إعادة تشغيل الزرع.
      await _batchWrite(
        collection: 'notifications',
        items: notifications,
        getDocId: (item) => 'seed_${item['type']}_${item['targetUserId']}',
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, 20 + (done * 20 ~/ total), detail: 'إشعارات: $done/$total'),
      );

      await _delay();

      // ── Activation Codes (صالحة للاستخدام في الاختبار) ───────────────────
      final codes = [
        {
          'code': 'SHOP-TEST-0001',
          'type': 'shop_activation',
          'isUsed': false,
          'usedBy': null,
          'usedAt': null,
          'shopId': null,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'code': 'SHOP-TEST-0002',
          'type': 'shop_activation',
          'isUsed': false,
          'usedBy': null,
          'usedAt': null,
          'shopId': null,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'code': 'SHOP-TEST-USED',
          'type': 'shop_activation',
          'isUsed': true,
          'usedBy': 'mock_merchant',
          'usedAt': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
          'shopId': 'shop_bakery',
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 10))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        // ✅ Fix #16: أكواد إعلان تجريبية (type: ad_activation) لاختبار تفعيل
        // الإعلانات من شاشة التسويق عند التاجر
        {
          'code': 'AD-TEST-0001',
          'type': 'ad_activation',
          'isUsed': false,
          'usedBy': null,
          'usedAt': null,
          'shopId': null,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'code': 'AD-TEST-0002',
          'type': 'ad_activation',
          'isUsed': false,
          'usedBy': null,
          'usedAt': null,
          'shopId': null,
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      await _batchWrite(
        collection: 'activation_codes',
        items: codes,
        getDocId: (item) => (item['code'] as String),
        buildData: (item) => item,
        onBatchDone: (done, total) =>
            report(phase, name, 40 + (done * 20 ~/ total), detail: 'أكواد: $done/$total'),
      );

      await _delay();

      // ── Referrals ──────────────────────────────────────────────────────────
      await _db.collection('referrals').add({
        'referrerId': 'mock_merchant',
        'referredId': 'user_003',
        'bonusDays': 7,
        'createdAt': FieldValue.serverTimestamp(),
      });

      report(phase, name, 70, detail: 'تم: الإحالات');
      await _delay();

      // ── Admin Audit Log ────────────────────────────────────────────────────
      await _db.collection('admin_audit_log').add({
        'action': 'SEED_DATABASE',
        'adminUid': 'mock_admin',
        'adminId': 'mock_admin',
        'targetId': 'all',
        'targetType': 'database',
        'targetName': 'DatabaseSeeder',
        'metadata': {
          'seededAt': now.toIso8601String(),
          'phases': 10,
          'environment': 'debug',
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      report(phase, name, 90, detail: 'تم: سجل التدقيق');
      await _delay();

      // ── Complaints (لاختبار شاشة الشكاوى) ────────────────────────────────
      await _db.collection('complaints').add({
        'userId': 'mock_user',
        'type': 'suggestion',
        'title': 'اقتراح: إضافة فئة مزارع ودواجن',
        'body': 'أقترح إضافة فئة "مزارع ودواجن" لأن في سنهور ناس كتير بتبيع منتجات الفلاحة',
        'status': 'pending',
        'adminReply': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      report(phase, name, 100, detail:
          'تم: قوائم + إشعارات + أكواد + إحالات + شكاوى + سجل تدقيق');
    } catch (e, s) {
      developer.log('Phase $phase error: $e', name: 'DatabaseSeeder', error: e, stackTrace: s);
      report(phase, name, 100, detail: '⚠️ خطأ: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // أدوات مساعدة
  // ─────────────────────────────────────────────────────────────────────────

  /// ✅ Anti-freeze: batch write بحجم ≤ _batchSize مع تأخير بين كل batch
  static Future<void> _batchWrite({
    required String collection,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> Function(Map<String, dynamic> item) buildData,
    String Function(Map<String, dynamic> item)? getDocId,
    void Function(int done, int total)? onBatchDone,
  }) async {
    int done = 0;
    final total = items.length;

    for (int start = 0; start < items.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, items.length);
      final chunk = items.sublist(start, end);

      final batch = _db.batch();
      for (final item in chunk) {
        final data = buildData(item);
        final ref = getDocId != null
            ? _db.collection(collection).doc(getDocId(item))
            : _db.collection(collection).doc();
        batch.set(ref, data, SetOptions(merge: true));
      }
      await batch.commit();
      done += chunk.length;
      onBatchDone?.call(done, total);

      if (end < items.length) await _delay();
    }
  }

  static Future<void> _delay() async {
    await Future.delayed(_batchDelay);
  }

  /// توليد keywords من نص — يأخذ أول 40 prefix فقط
  static List<String> _keywords(String text) {
    final words = text.toLowerCase().split(' ');
    final keywords = <String>{};
    for (final word in words) {
      for (int i = 1; i <= word.length && keywords.length < 40; i++) {
        keywords.add(word.substring(0, i));
      }
      if (keywords.length >= 40) break;
    }
    return keywords.toList();
  }
}
