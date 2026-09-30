// lib/screens/seeder_screen.dart
// ✅ واجهة رفع البيانات التجريبية — تعرض تقدم كل مرحلة بشكل مرئي واضح
// تُستخدَم فقط في kDebugMode — غير مرئية في الإنتاج
import 'package:flutter/material.dart';
import '../services/database_seeder.dart';

class SeederScreen extends StatefulWidget {
  const SeederScreen({super.key});

  @override
  State<SeederScreen> createState() => _SeederScreenState();
}

class _SeederScreenState extends State<SeederScreen> {
  bool _isRunning = false;
  bool _isDone = false;
  final List<SeederProgress> _log = [];
  SeederProgress? _current;

  // بيانات كل مرحلة لعرضها حتى قبل بدء الرفع
  static const List<String> _phaseNames = [
    'الإعدادات والمناطق',
    'الفئات',
    'المستخدمون',
    'المحلات',
    'المنتجات',
    'العروض',
    'الخدمات والتقييمات',
    'الإعلانات التجارية',
    'وظائف وطلبات وديلر',
    'القوائم والإشعارات والأكواد',
  ];

  static const List<IconData> _phaseIcons = [
    Icons.settings_outlined,
    Icons.category_outlined,
    Icons.people_outline,
    Icons.storefront_outlined,
    Icons.inventory_2_outlined,
    Icons.local_offer_outlined,
    Icons.miscellaneous_services_outlined,
    Icons.campaign_outlined,
    Icons.work_outline,
    Icons.notifications_outlined,
  ];

  Future<void> _startSeed() async {
    // if (!kDebugMode) return;
    setState(() {
      _isRunning = true;
      _isDone = false;
      _log.clear();
      _current = null;
    });

    try {
      await DatabaseSeeder.seedAll(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _current = progress;
            // نُخزِّن آخر تحديث لكل مرحلة في الـ log
            final existing = _log.indexWhere((l) => l.phase == progress.phase);
            if (existing >= 0) {
              _log[existing] = progress;
            } else {
              _log.add(progress);
            }
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ غير متوقع: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() { _isRunning = false; _isDone = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (!kDebugMode) {
    //   return const Scaffold(
    //     body: Center(child: Text('غير متاح في بيئة الإنتاج')),
    //   );
    // }

    final overall = _current?.overallPercent ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('رفع البيانات التجريبية'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── بطاقة التقدم الإجمالي ──────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.cloud_upload_outlined,
                        color: Color(0xFF5E35B1), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isDone
                            ? '✅ اكتملت عملية الرفع'
                            : _isRunning
                                ? 'جارٍ الرفع...'
                                : 'جاهز للبدء',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('$overall%',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E35B1))),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overall / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade200,
                      color: _isDone ? Colors.green : const Color(0xFF5E35B1),
                    ),
                  ),
                  if (_current?.detail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _current!.detail!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── شبكة المراحل ──────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: _phaseNames.length,
            itemBuilder: (ctx, i) {
              final phaseNum = i + 1;
              final log = _log.cast<SeederProgress?>()
                  .firstWhere(
                    (l) => l?.phase == phaseNum,
                    orElse: () => null,
                  );
              final isActive = _current?.phase == phaseNum && _isRunning;
              final isDone = log != null && log.phasePercent >= 100;
              final pct = log?.phasePercent ?? 0;

              Color cardColor;
              Color iconColor;
              if (isDone) {
                cardColor = Colors.green.shade50;
                iconColor = Colors.green;
              } else if (isActive) {
                cardColor = const Color(0xFFF3E5F5);
                iconColor = const Color(0xFF5E35B1);
              } else {
                cardColor = Colors.grey.shade50;
                iconColor = Colors.grey.shade400;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF5E35B1)
                        : isDone
                            ? Colors.green
                            : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(_phaseIcons[i], color: iconColor, size: 18),
                        const SizedBox(width: 4),
                        Text('$phaseNum',
                            style: TextStyle(
                                fontSize: 12,
                                color: iconColor,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (isDone)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16)
                        else if (isActive)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5E35B1),
                            ),
                          ),
                      ]),
                      Text(
                        _phaseNames[i],
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isActive
                                ? const Color(0xFF5E35B1)
                                : isDone
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pct > 0 && !isDone)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 4,
                            backgroundColor: Colors.white,
                            color: const Color(0xFF5E35B1),
                          ),
                        )
                      else if (isDone)
                        Text('100%',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold))
                      else
                        Text('في الانتظار',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── سجل التفاصيل ─────────────────────────────────────────────
          if (_log.isNotEmpty) ...[
            const Text('سجل التفاصيل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(_log.length, (i) {
              final entry = _log[i];
              final hasError =
                  entry.detail != null && entry.detail!.contains('⚠️');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hasError
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 14,
                      color: hasError ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.phaseName}: ${entry.detail ?? ''}',
                        style: TextStyle(
                            fontSize: 11,
                            color: hasError
                                ? Colors.orange.shade700
                                : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── تحذير ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تحذير: هذه العملية تضيف بيانات تجريبية لقاعدة البيانات. '
                  'استخدمها في بيئة الاختبار فقط.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.orange.shade800),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── زر البدء ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _startSeed,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Icon(_isDone
                      ? Icons.refresh
                      : Icons.cloud_upload_outlined),
              label: Text(
                _isRunning
                    ? 'جارٍ الرفع... $overall%'
                    : _isDone
                        ? 'رفع مجدداً'
                        : 'بدء رفع البيانات التجريبية',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isDone ? Colors.green : const Color(0xFF5E35B1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
