// lib/widgets/seasonal_overlay.dart
// ✅ Fix #179: الزينة الموسمية تُعرض للجميع ماعدا الأدمن (لا تُشتِّت في لوحة الإدارة)
// ✅ Fix #180: Image.network → Image.asset لضمان العمل بدون إنترنت + صور محددة مسبقاً
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SeasonalOverlay extends StatelessWidget {
  final Widget child;
  const SeasonalOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final season = Provider.of<ThemeProvider>(context).currentSeason;

    // ✅ Fix #179: لا زينة في لوحة الأدمن — تُشتِّت وتُبطئ
    final authRole = context.select<AuthProvider, UserRole>(
        (a) => a.userRole);
    if (authRole == UserRole.admin) return child;

    return Stack(
      children: [
        child,
        if (season == 'ramadan') _buildRamadanTheme(),
        if (season == 'eid_fitr') _buildEidFitrTheme(),
        if (season == 'eid_adha') _buildEidAdhaTheme(),
      ],
    );
  }

  // ✅ Fix #180: نستخدم Icon بدلاً من Image.network — موثوق بدون إنترنت
  // (عند توفر assets إبدل بـ Image.asset)

  // 🌙 ثيم رمضان
  Widget _buildRamadanTheme() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: 20,
            child: Opacity(
              opacity: 0.7,
              child: Icon(Icons.light_mode_outlined,
                  size: 80, color: Colors.amber.shade300),
            ),
          ),
          Positioned(
            top: -10,
            left: 20,
            child: Opacity(
              opacity: 0.5,
              child: Icon(Icons.light_mode,
                  size: 50, color: Colors.amber.shade200),
            ),
          ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(Icons.nightlight_round,
                    size: 200, color: Colors.amber.shade100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎈 ثيم عيد الفطر
  Widget _buildEidFitrTheme() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: 0.7,
              child: Icon(Icons.celebration,
                  size: 100, color: Colors.green.shade400),
            ),
          ),
          Positioned(
            top: 20,
            right: 0,
            child: Opacity(
              opacity: 0.6,
              child: Icon(Icons.celebration,
                  size: 80, color: Colors.teal.shade300),
            ),
          ),
        ],
      ),
    );
  }

  // 🐑 ثيم عيد الأضحى
  Widget _buildEidAdhaTheme() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            bottom: 80,
            left: 10,
            child: Opacity(
              opacity: 0.8,
              child: Icon(Icons.park,
                  size: 60, color: Colors.green.shade600),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('عيد أضحى مبارك',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
