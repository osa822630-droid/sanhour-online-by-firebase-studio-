// lib_widgets_search_bar.dart
import 'dart:async'; // ✅ عشان الـ Timer (Debounce)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../providers/shops_provider.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _controller = TextEditingController();

  // ✅ متغير للتحكم في تأخير البحث (Performance Optimization)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // استرجاع نص البحث القديم لو موجود
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query =
          Provider.of<ShopsProvider>(context, listen: false).searchQuery;
      if (query != null && query.isNotEmpty) {
        _controller.text = query;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // ✅ إلغاء التايمر لمنع أخطاء الذاكرة
    _controller.dispose();
    _speech.stop(); // ✅ التأكد من إيقاف الميكروفون عند الخروج
    super.dispose();
  }

  // ✅ دالة البحث المحسنة (Debounced Search)
  void _onSearchChanged(String query) {
    // 1. تحديث زر المسح (X) فوراً
    setState(() {});

    // 2. إلغاء التايمر القديم لو المستخدم لسه بيكتب
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 3. بدء تايمر جديد (ينفذ البحث بعد 500 مللي ثانية من التوقف عن الكتابة)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Provider.of<ShopsProvider>(context, listen: false).search(query);
    });
  }

  // ✅ دالة مسح البحث
  void _clearSearch() {
    _controller.clear();
    setState(() {}); // تحديث لإخفاء زر المسح
    Provider.of<ShopsProvider>(context, listen: false)
        .search(''); // إعادة القائمة لأصلها
    FocusScope.of(context).unfocus(); // إخفاء الكيبورد
  }

  void _listen() async {
    // التحقق من الصلاحيات
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى السماح بصلاحية الميكروفون')),
        );
      }
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        if (!mounted) return;
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (!mounted) return;
            setState(() {
              _controller.text = val.recognizedWords;
              // تحريك المؤشر للنهاية
              _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length));

              // ✅ البحث الفوري عند الانتهاء من الكلام (بدون Debounce هنا عشان دي نتيجة نهائية)
              Provider.of<ShopsProvider>(context, listen: false)
                  .search(val.recognizedWords);
            });
          },
          listenOptions: stt.SpeechListenOptions(localeId: 'ar_EG'),
        );
      } else {
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        // ✅ إغلاق الكيبورد عند الضغط على زر البحث في اللوحة
        onSubmitted: (value) {
          Provider.of<ShopsProvider>(context, listen: false).search(value);
          FocusScope.of(context).unfocus();
        },
        decoration: InputDecoration(
          hintText: 'ابحث عن محل، منتج، أو خدمة...',
          prefixIcon: const Icon(Icons.search),

          // ✅ إضافة زر مسح (X) بجانب الميكروفون
          suffixIcon: Row(
            mainAxisSize:
                MainAxisSize.min, // مهم جداً عشان الأيقونات تاخد مساحة صغيرة
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _clearSearch,
                ),
              IconButton(
                tooltip: 'البحث الصوتي',
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening
                        ? Theme.of(context).primaryColor
                        : Colors.grey),
                onPressed: _listen,
              ),
            ],
          ),

          contentPadding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        // ✅ استخدام دالة البحث المحسنة
        onChanged: _onSearchChanged,
      ),
    );
  }
}