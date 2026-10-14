// lib/screens/onboarding_screen.dart
// ✅ إضافة fromSettings: true — يسمح بعرض الشاشة من الإعدادات دون مسح بيانات المستخدم
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interests_screen.dart';

class OnboardingScreen extends StatefulWidget {
  /// fromSettings = true → لا تُمسح بيانات المستخدم، ويظهر زر "إغلاق" بدلاً من "التالي"
  final bool fromSettings;
  const OnboardingScreen({super.key, this.fromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // ✅ Fix #61: dispose PageController لمنع memory leak
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.storefront,
      color: Color(0xFF5E35B1),
      title: 'مرحباً بك في سنهور أونلاين',
      subtitle: 'سنهور كلها في جيبك',
      description:
          'اكتشف جميع محلات وخدمات سنهور القبلية في مكان واحد — بسهولة وسرعة.',
    ),
    _OnboardingPage(
      icon: Icons.search_rounded,
      color: Color(0xFF7B1FA2),
      title: 'ابحث عن أي شيء',
      subtitle: 'بحث متقدم وفلترة ذكية',
      description:
          'ابحث عن محلات، منتجات، خدمات وعروض حسب الفئة أو الموقع أو السعر.',
    ),
    _OnboardingPage(
      icon: Icons.favorite_rounded,
      color: Color(0xFFAD1457),
      title: 'المفضلة والقوائم',
      subtitle: 'احفظ ما يعجبك',
      description:
          'أنشئ قوائم مشتريات مشتركة مع عائلتك وادّخر منتجاتك المفضلة.',
    ),
    _OnboardingPage(
      icon: Icons.local_offer_rounded,
      color: Color(0xFFE65100),
      title: 'عروض وخصومات يومية',
      subtitle: 'لا يفوتك أي خصم',
      description:
          'تابع أحدث العروض من محلات سنهور واستفد من خصومات حصرية.',
    ),
    _OnboardingPage(
      icon: Icons.delivery_dining,
      color: Color(0xFF1B5E20),
      title: 'سنهور ديلر',
      subtitle: 'توصيل لباب بيتك',
      description:
          'اطلب من أي محل وسيوصله الديلر لحد بابك بأسرع وقت وأقل سعر.',
    ),
    _OnboardingPage(
      icon: Icons.handyman,
      color: Color(0xFF006064),
      title: 'طلبات الخدمات والوظائف',
      subtitle: 'مركز الإعلانات المتكامل',
      description:
          'انشر طلبات خدمات واحصل على عروض أسعار، أو تصفّح فرص العمل المتاحة في سنهور.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // إذا فُتحت من الإعدادات: نعود فقط بدون تعديل prefs
    if (widget.fromSettings) {
      Navigator.pop(context);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    // ✅ Item #10: لازم نفس المفتاح اللي SplashScreen بتقراه ('onboarding_done'،
    // زي 'interests_done')، وإلا الأونبوردينج بيتكرر في كل فتحة.
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const InterestsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── الصفحات ──────────────────────────────────────────
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),

          // ── أزرار التنقل ──────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // نقاط التقدم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active ? Colors.white : Colors.white38,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    // تخطي (فقط إذا لم تُفتح من الإعدادات)
                    if (!widget.fromSettings &&
                        _currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _finish,
                        child: const Text(
                          'تخطي',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else if (widget.fromSettings)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'إغلاق',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      const SizedBox(width: 80),

                    const Spacer(),

                    // التالي / إنهاء
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _pages[_currentPage].color,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? (widget.fromSettings ? 'إغلاق' : 'ابدأ الآن')
                            : 'التالي',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [page.color, page.color.withValues(alpha: 0.75)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 72, color: Colors.white),
              ),
              const SizedBox(height: 48),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white60, height: 1.7),
              ),
              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}
