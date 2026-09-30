// lib/screens/provider_registration_screen.dart
// استمارة تسجيل مزوّد الخدمة — تحدد المجالات التي يستقبل إشعاراتها
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/service_request_model.dart';
import '../providers/auth_provider.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  Set<String> _selectedCategories = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _bioCtrl.text = data['bio'] as String? ?? '';
          _locationCtrl.text = data['location'] as String? ?? '';
          _selectedCategories = Set<String>.from(
              data['categories'] as List? ?? []);
          _isRegistered = true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر مجالاً واحداً على الأقل'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSaving = true);
    final user = context.read<AuthProvider>().user!;
    try {
      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(user.id)
          .set({
        'userId': user.id,
        'name': user.name,
        'phone': user.phone,
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'categories': _selectedCategories.toList(),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        // ✅ Fix #155: createdAt يُكتب عند الإنشاء فقط — SetOptions(merge: true) يتجاهله عند التعديل
        // استخدام FieldValue.serverTimestamp() مع merge يتجاهل القيمة الموجودة مسبقاً؟
        // الحل الصحيح: نتحقق إذا كانت الوثيقة موجودة ونضيف createdAt فقط عند الإنشاء
      }, SetOptions(merge: true));

      // إضافة createdAt منفصلاً فقط إذا لم تكن موجودة
      final providerRef = FirebaseFirestore.instance
          .collection('service_providers')
          .doc(user.id);
      final existing = await providerRef.get();
      if (!existing.exists || existing.data()?['createdAt'] == null) {
        await providerRef.update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // تسجيل في notification_queue لاشتراك FCM المجالات
      await FirebaseFirestore.instance
          .collection('provider_topic_subscriptions')
          .doc(user.id)
          .set({
        'userId': user.id,
        'categories': _selectedCategories.toList(),
        'fcmTopics':
            _selectedCategories.map((c) => 'providers_$c').toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'تم التسجيل بنجاح ✅ — ستصلك إشعارات عند وجود طلبات في مجالاتك'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(
          _isRegistered ? 'تعديل بيانات مزوّد الخدمة' : 'التسجيل كمزوّد خدمة',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'جاري...' : 'حفظ',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── بانر ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.engineering_outlined,
                          color: Colors.teal, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سجّل مجالاتك لتصلك إشعارات فورية عند نزول طلبات خدمة تناسبك.',
                          style: TextStyle(
                              color: Colors.teal,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── اختيار المجالات ───────────────────────────
                _sectionLabel('مجالات الخدمة التي تقدّمها *'),
                const SizedBox(height: 10),
                const Text(
                  'اختر كل المجالات التي تستطيع العمل فيها:',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ServiceRequestCategory.values.map((cat) {
                    final isSelected =
                        _selectedCategories.contains(cat.name);
                    return FilterChip(
                      label: Text(
                          ServiceRequestModel.categoryLabel(cat),
                          style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white
                                  : null)),
                      selected: isSelected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedCategories.add(cat.name);
                          } else {
                            _selectedCategories.remove(cat.name);
                          }
                        });
                      },
                      selectedColor: Colors.teal,
                      checkmarkColor: Colors.white,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.teal
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ── الموقع ─────────────────────────────────────
                _sectionLabel('منطقة العمل (اختياري)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    hintText:
                        'مثال: سنهور القبلية وضواحيها',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // ── نبذة ─────────────────────────────────────
                _sectionLabel('نبذة عن خبرتك (اختياري)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'مثال: كهربائي بخبرة 10 سنوات في التمديدات والصيانة...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.engineering_outlined),
                    label: Text(
                      _isSaving
                          ? 'جاري الحفظ...'
                          : (_isRegistered
                              ? 'تحديث البيانات'
                              : 'تسجيل كمزوّد خدمة'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.teal));
}
