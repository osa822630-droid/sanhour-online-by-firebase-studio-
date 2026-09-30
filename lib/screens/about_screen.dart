// lib/screens/about_screen.dart
// شاشة "عن التطبيق" — معلومات المشروع وتفاصيل الإصدار
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'report_problem_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'عن التطبيق',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // هيدر التطبيق
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5E35B1), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront,
                      size: 50,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'سنهور أونلاين',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'سنهور كلها في جيبك',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'الإصدار $_version (بناء $_buildNumber)',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // وصف التطبيق
            _buildSection(
              context,
              isDark,
              icon: Icons.info_outline,
              title: 'عن التطبيق',
              child: const Text(
                'سنهور أونلاين هو دليل شامل يجمع كل محلات وخدمات سنهور القبلية في مكان واحد، '
                'هدفه تيسير التواصل بين أبناء القرية والتجار المحليين دون الحاجة للبحث الطويل.',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            ),

            // المميزات
            _buildSection(
              context,
              isDark,
              icon: Icons.star_outline,
              title: 'مميزات التطبيق',
              child: Column(
                children: const [
                  _FeatureRow(
                      icon: Icons.store,
                      text: 'دليل شامل لمحلات وخدمات سنهور'),
                  _FeatureRow(
                      icon: Icons.local_offer,
                      text: 'عروض وتخفيضات حصرية من التجار'),
                  _FeatureRow(
                      icon: Icons.favorite,
                      text: 'قوائم مفضلة ومشاركة مع العائلة'),
                  _FeatureRow(
                      icon: Icons.motorcycle,
                      text: 'سنهور ديلر — خدمة توصيل محلية'),
                  _FeatureRow(
                      icon: Icons.campaign,
                      text: 'إعلانات ذكية ومحلية'),
                  _FeatureRow(
                      icon: Icons.auto_awesome,
                      text: 'مساعد ذكي مدعوم بالذكاء الاصطناعي'),
                ],
              ),
            ),

            // معلومات التواصل
            _buildSection(
              context,
              isDark,
              icon: Icons.location_on_outlined,
              title: 'الموقع',
              child: Row(
                children: const [
                  Icon(Icons.location_on, color: Color(0xFF5E35B1), size: 20),
                  SizedBox(width: 8),
                  Text('الفيوم — سنهور القبلية، مصر',
                      style: TextStyle(fontSize: 14)),
                ],
              ),
            ),

            // تواصل معنا
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReportProblemScreen()),
                  ),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('تواصل معنا'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5E35B1),
                    side: const BorderSide(color: Color(0xFF5E35B1)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // حقوق الملكية
            Text(
              '© ٢٠٢٦ سنهور أونلاين — جميع الحقوق محفوظة',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF5E35B1), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5E35B1), size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
