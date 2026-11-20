// lib/screens/interests_screen.dart
// ✅ Item #47: مطابقة مسميات الاهتمامات مع الفئات الفعلية للمحلات في قاعدة البيانات
// ✅ Item #52: دعم الفتح من الإعدادات (fromSettings: true) لتعديل الاهتمامات لاحقاً
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InterestsScreen extends StatefulWidget {
  final bool fromSettings;
  const InterestsScreen({super.key, this.fromSettings = false});
  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selected = {};

  static const List<Map<String, dynamic>> _interests = [
    {'label': 'مأكولات ومشروبات', 'icon': Icons.restaurant,        'color': 0xFFE53935},
    {'label': 'ملابس وأزياء',     'icon': Icons.checkroom,         'color': 0xFF8E24AA},
    {'label': 'أجهزة إلكترونية',  'icon': Icons.phone_android,     'color': 0xFF1E88E5},
    {'label': 'صحة وجمال',        'icon': Icons.health_and_safety, 'color': 0xFF43A047},
    {'label': 'خدمات منزلية',     'icon': Icons.handyman,          'color': 0xFFFB8C00},
    {'label': 'تعليم وتدريب',     'icon': Icons.school,            'color': 0xFF4B5E6F},
    {'label': 'مواصلات وسيارات',  'icon': Icons.directions_car,    'color': 0xFF6D4C41},
    {'label': 'خدمات مهنية',      'icon': Icons.gavel,             'color': 0xFF546E7A},
    {'label': 'ذهب ومجوهرات',     'icon': Icons.diamond,           'color': 0xFFFFB300},
    {'label': 'عقارات',           'icon': Icons.home_work,         'color': 0xFF00897B},
    {'label': 'أثاث وديكور',      'icon': Icons.chair,             'color': 0xFFFF8F00},
    {'label': 'رياضة ولياقة',     'icon': Icons.sports_soccer,     'color': 0xFF00ACC1},
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingInterests();
  }

  Future<void> _loadExistingInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_interests');
    if (raw != null && mounted) {
      try {
        final saved = List<String>.from(jsonDecode(raw) as List);
        setState(() {
          _selected.addAll(saved);
        });
      } catch (_) {}
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('interests_done', true);
    await prefs.setString('user_interests', jsonEncode(_selected.toList()));
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.pop(context, true);
    } else {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn || auth.isGuest) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF26483F), Color(0xFF3D6B5E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (widget.fromSettings)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              else
                const SizedBox(height: 32),
              const Text('ما الذي يهمك؟',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('اختر اهتماماتك لنعرض لك المحتوى المناسب في قسم اخترنا لك',
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, childAspectRatio: 0.85,
                            crossAxisSpacing: 12, mainAxisSpacing: 12,
                          ),
                          itemCount: _interests.length,
                          itemBuilder: (_, i) {
                            final item = _interests[i];
                            final label = item['label'] as String;
                            final icon = item['icon'] as IconData;
                            final color = Color(item['color'] as int);
                            final selected = _selected.contains(label);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (selected) {
                                  _selected.remove(label);
                                } else {
                                  _selected.add(label);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: selected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected ? color : Colors.grey.withValues(alpha: 0.2),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(alignment: Alignment.center, children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: selected ? 0.2 : 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Icon(icon, color: color, size: 26),
                                      if (selected)
                                        Positioned(top: 0, right: 0,
                                          child: Container(
                                            width: 16, height: 16,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                            child: const Icon(Icons.check, color: Colors.white, size: 10),
                                          )),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text(label,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w600,
                                          color: selected ? color : null,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(children: [
                          if (_selected.isNotEmpty)
                            Text('اخترت ${_selected.length} اهتمام',
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3D6B5E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _finish,
                              child: Text(
                                widget.fromSettings
                                    ? 'حفظ الاهتمامات'
                                    : (_selected.isEmpty ? 'تخطي الآن' : 'متابعة (${_selected.length})'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
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
