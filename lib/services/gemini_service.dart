// lib/services/gemini_service.dart
// ✅ P0-8 Fix: إزالة المسار المباشر والمفتاح المحلي بالكامل وتوجيه كافة الطلبات عبر Cloud Function (askGemini)
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
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

  DateTime? _lastRequestTime;
  static const Duration _minInterval = Duration(seconds: 2);

  Future<String?> _callCloudGemini(Map<String, dynamic> payload) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('askGemini');
      final res = await callable.call({
        'model': AppConstants.geminiModel,
        'payload': payload,
      });
      final data = res.data as Map?;
      final reply = data?['text']?.toString().trim() ?? '';
      if (reply.isNotEmpty) return reply;
    } catch (e) {
      debugPrint('askGemini Cloud Function error: $e');
    }
    return null;
  }

  Future<String> sendMessage({
    required String userMessage,
    required List<GeminiMessage> history,
    required GeminiUserType userType,
    String? shopName,
    Map<String, dynamic>? context,
  }) async {
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < _minInterval) {
      return 'يرجى الانتظار قليلاً قبل إرسال رسالة أخرى.';
    }
    _lastRequestTime = now;

    try {
      final systemPrompt =
          _buildSystemPrompt(userType, shopName: shopName, context: context);

      final contents = <Map<String, dynamic>>[];

      for (final msg in history.take(10)) {
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text}
          ],
        });
      }

      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ],
      });

      final requestPayload = {
        'system_instruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 512,
          'topK': 40,
          'topP': 0.95,
        },
      };

      final cloudReply = await _callCloudGemini(requestPayload);
      if (cloudReply != null) {
        return cloudReply;
      }

      return 'خدمة المساعد الذكي غير متاحة حالياً، يرجى المحاولة لاحقاً.';
    } catch (e) {
      debugPrint('Gemini Exception: $e');
      return 'تعذّر الاتصال بالمساعد الذكي. تحقق من اتصالك.';
    }
  }

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

  Future<String> smartSearch({
    required String query,
    required List<Map<String, dynamic>> shopsSnapshot,
    required List<Map<String, dynamic>> productsSnapshot,
    required GeminiUserType userType,
  }) async {
    final shopsText = shopsSnapshot
        .take(30)
        .map((s) =>
            '- ${s['name']} (${s['category']}) تقييم:${s['rating']} موقع:${s['location']}')
        .join('\n');

    final productsText = productsSnapshot
        .take(50)
        .map((p) =>
            '- ${p['name']} سعر:${p['price']}ج قسم:${p['category']} محل:${p['shopId']}')
        .join('\n');

    final systemPrompt = '''أنت مساعد بحث ذكي في تطبيق "سنهور أونلاين".
بناءً على البيانات التالية، أجب على طلب المستخدم بشكل مباشر ومفيد باللغة العربية.
اذكر أسماء المحلات والمنتجات المناسبة مع أسعارها. كن محدداً وعملياً.

المحلات المتاحة:
$shopsText

المنتجات المتاحة:
$productsText

قواعد: تجيب بالعربية — تذكر الأسماء والأسعار الحقيقية — لا تخترع بيانات غير موجودة.
''';

    final requestPayload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': query}
          ]
        }
      ],
      'generationConfig': {'maxOutputTokens': 512, 'temperature': 0.4},
    };

    try {
      final cloudReply = await _callCloudGemini(requestPayload);
      if (cloudReply != null) {
        return cloudReply;
      }
      return 'لم أتمكن من الاتصال بالمساعد الذكي حالياً، جرّب البحث بالكلمات المفتاحية.';
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
