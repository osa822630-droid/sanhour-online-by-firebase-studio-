// lib/widgets/app_footer.dart
import 'package:flutter/material.dart';
import '../screens/report_problem_screen.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B201E) : const Color(0xFF1F3B33);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFF3D6B5E),
                    child: const Icon(Icons.storefront,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'سنهور أونلاين',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'هدفنا ربط القرية ببعضها عن طريق تجميع كل محلات وخدمات سنهور في مكان واحد',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text(
                'الفيوم - سنهور القبلية',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportProblemScreen()),
                );
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('لديك شكوى أو اقتراح؟ تواصل معنا'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© ٢٠٢٦ سنهور أونلاين — جميع الحقوق محفوظة',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
