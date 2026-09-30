// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

enum GeminiUserType { customer, merchant, admin }

class GeminiMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  GeminiMessage({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();
}

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  String _apiKey = AppConstants.geminiApiKey;
  // ✅ Fix #126: rate limiting — حد أدنى ثانيتان بين الطلبات
  DateTime? _lastRequestTime;
  static const Duration _minInterval = Duration(seconds: 2);

  void setApiKey(String key) => _apiKey = key;

  // ✅ إرسال رسالة مع تاريخ المحادثة
  Future<String> sendMessage({
    required String userMessage,
    required List<GeminiMessage> history,
    required GeminiUserType userType,
    String? shopName,
    Map<String, dynamic>? context,
  }) async {
    // ✅ Fix #129: guard against placeholder API key
    if (_apiKey.isEmpty || _apiKey.contains('YOUR_GEMINI')) {
      return 'جاري تحميل المساعد الذكي، يرجى المحاولة مجدداً...';
    }

    // ✅ Fix #126: client-side rate limiting
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < _minInterval) {
      return 'يرجى الانتظار قليلاً قبل إرسال رسالة أخرى.';
    }
    _lastRequestTime = now;

    try {
      final systemPrompt = _buildSystemPrompt(userType, shopName: shopName, context: context);

      // بناء محادثة بالتنسيق الصحيح
      final contents = <Map<String, dynamic>>[];

      // إضافة التاريخ
      for (final msg in history.take(10)) {
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [{'text': msg.text}],
        });
      }

      // إضافة رسالة المستخدم الحالية
      contents.add({
        'role': 'user',
        'parts': [{'text': userMessage}],
      });

      final url =
          // ✅ Phase 2 Missing Fix #2: API Key نُقل من URL query param لـ HTTP Header
          // قبل الإصلاح: ?key=xxx → مرئي في كل network log (Charles/Fiddler/Wireshark)
          // بعد الإصلاح: x-goog-api-key header → لا يظهر في الـ URL
          '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey, // ✅ Header بدل URL query param
        },
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': systemPrompt}]
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
            'topK': 40,
            'topP': 0.95,
          },
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
            {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) return text.trim();
        return 'عذراً، لم أستطع معالجة ردك. حاول مرة أخرى.';
      } else {
        debugPrint('Gemini Error: ${response.statusCode} ${response.body}');
        return 'حدث خطأ في الاتصال. تأكد من الإنترنت وحاول مجدداً.';
      }
    } catch (e) {
      debugPrint('Gemini Exception: $e');
      return 'تعذّر الاتصال بالمساعد الذكي. تحقق من اتصالك.';
    }
  }

  // ✅ رد سريع (اقتراحات جاهزة)
  Future<List<String>> getQuickSuggestions(GeminiUserType userType) async {
    switch (userType) {
      case GeminiUserType.merchant:
        return [
          'كيف أزيد مبيعات متجري؟',
          'اكتب وصفاً جذاباً لمنتج',
          'أفضل وقت لنشر العروض؟',
          'حلّل أداء متجري',
        ];
      case GeminiUserType.admin:
        return [
          'ملخص وضع التطبيق',
          'كيف أتعامل مع شكوى؟',
          'اقتراح استراتيجية نمو',
          'تحليل نمط غير طبيعي',
        ];
      default:
        return [
          '🎁 هدية بـ 250 جنيه',
          '👗 طقم زفاف بـ 1500 ج',
          '🔧 خدمة صيانة قريبة',
          '🍕 أفضل مطعم في سنهور',
        ];
    }
  }

  /// ✅ بحث ذكي حقيقي: يُمرَّر له ملخص بيانات المحلات والمنتجات
  Future<String> smartSearch({
    required String query,
    required List<Map<String, dynamic>> shopsSnapshot,
    required List<Map<String, dynamic>> productsSnapshot,
    required GeminiUserType userType,
  }) async {
    final shopsText = shopsSnapshot.take(30).map((s) =>
        '- ${s['name']} (${s['category']}) تقييم:${s['rating']} موقع:${s['location']}').join('\n');

    final productsText = productsSnapshot.take(50).map((p) =>
        '- ${p['name']} سعر:${p['price']}ج قسم:${p['category']} محل:${p['shopId']}').join('\n');

    final systemPrompt = '''أنت مساعد بحث ذكي في تطبيق "سنهور أونلاين".
بناءً على البيانات التالية، أجب على طلب المستخدم بشكل مباشر ومفيد باللغة العربية.
اذكر أسماء المحلات والمنتجات المناسبة مع أسعارها. كن محدداً وعملياً.

المحلات المتاحة:
$shopsText

المنتجات المتاحة:
$productsText

قواعد: تجيب بالعربية — تذكر الأسماء والأسعار الحقيقية — لا تخترع بيانات غير موجودة.
''';

    try {
      final url =
          // ✅ smartSearch: API Key في Header أيضاً
          '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey, // ✅ Header بدل URL query param
        },
        body: jsonEncode({
          'system_instruction': {'parts': [{'text': systemPrompt}]},
          'contents': [{'role': 'user', 'parts': [{'text': query}]}],
          'generationConfig': {'maxOutputTokens': 600, 'temperature': 0.4},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?? 'لم أجد نتائج مناسبة، جرّب البحث بكلمات أخرى.';
      }
      return 'تعذّر الاتصال بالمساعد، حاول مجدداً.';
    } catch (e) {
      debugPrint('smartSearch error: $e');
      return 'حدث خطأ، حاول مجدداً.';
    }
  }

  String _buildSystemPrompt(GeminiUserType userType,
      {String? shopName, Map<String, dynamic>? context}) {
    const base = '''أنت مساعد ذكي داخل تطبيق "سنهور أونلاين"، وهو منصة تجارية تجمع محلات وخدمات سنهور القبلية بالفيوم، مصر.
قواعد يجب الالتزام بها:
- تجيب بالعربية دائماً
- تكون موجزاً وعملياً
- تركز على ما يفيد المستخدم داخل التطبيق
- لا تذكر منافسين أو مصادر خارجية
- إذا سُئلت عن شيء خارج نطاقك، وجّه المستخدم للإدارة
''';

    switch (userType) {
      case GeminiUserType.merchant:
        return '''$base
دورك مع التاجر:
- تقدم نصائح تسويقية وتجارية لتحسين أداء متجره: ${shopName ?? 'المتجر'}
- تساعده في كتابة أوصاف منتجات جذابة
- تقترح استراتيجيات لزيادة المبيعات والتقييمات
- توضح له كيفية استخدام لوحة التاجر بشكل أمثل
- تحلل إحصائياته وتقترح تحسينات${context != null ? '\nبيانات المتجر: ${jsonEncode(context)}' : ''}''';

      case GeminiUserType.admin:
        return '''$base
دورك مع المدير:
- تساعده في اتخاذ قرارات إدارية مدروسة
- تقترح كيفية التعامل مع الشكاوى والمشكلات
- تحلل أداء التطبيق وتقترح تحسينات
- تنبهه لأي أنماط غير طبيعية في البيانات
- تقدم تقارير موجزة عن الوضع العام${context != null ? '\nإحصائيات التطبيق: ${jsonEncode(context)}' : ''}''';

      default:
        return '''$base
دورك مع المستخدم:
- تساعده في إيجاد محلات ومنتجات وعروض مناسبة
- تقترح أفضل الخيارات بناءً على احتياجاته
- تشرح كيفية استخدام مميزات التطبيق
- تجيب على أسئلة عامة عن سنهور وخدماتها''';
    }
  }
}
