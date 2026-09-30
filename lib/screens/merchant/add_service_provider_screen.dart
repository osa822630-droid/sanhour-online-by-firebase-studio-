// lib/screens/merchant/add_service_provider_screen.dart
// شاشة تسجيل مزوّد الخدمة المتنقّل — تُعرَض بعد اختيار "مزوّد خدمة" من merchant_type_screen
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';

class AddServiceProviderScreen extends StatefulWidget {
  const AddServiceProviderScreen({super.key});

  @override
  State<AddServiceProviderScreen> createState() =>
      _AddServiceProviderScreenState();
}

class _AddServiceProviderScreenState extends State<AddServiceProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final Set<String> _selectedCategories = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر خدمة واحدة على الأقل'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSaving = true);

    final user = context.read<AuthProvider>().user!;
    try {
      final db = FirebaseFirestore.instance;

      // تسجيل كمزوّد خدمة
      await db.collection('service_providers').doc(user.id).set({
        'userId': user.id,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'categories': _selectedCategories.toList(),
        'isActive': true,
        'businessType': 'service_provider',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // تحديث businessType في users
      await db.collection('users').doc(user.id).update({
        'businessType': 'service_provider',
      });

      // تسجيل اشتراكات FCM للمجالات
      await db.collection('provider_topic_subscriptions').doc(user.id).set({
        'userId': user.id,
        'categories': _selectedCategories.toList(),
        'fcmTopics': _selectedCategories.map((c) => 'providers_$c').toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تسجيل بياناتك بنجاح ✅ — ستصلك إشعارات طلبات الخدمات'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
      // الانتقال للشاشة الرئيسية
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
        title: const Text('تسجيل بيانات الخدمة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // بانر توضيحي
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.engineering_outlined, color: Colors.teal, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'سجّل خدماتك لتصلك طلبات من العملاء مباشرة على هاتفك.',
                      style: TextStyle(color: Colors.teal, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            _label('الاسم الكامل *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v!.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),

            const SizedBox(height: 20),

            _label('رقم الهاتف *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone)),
              validator: (v) => v!.trim().isEmpty ? 'الهاتف مطلوب' : null,
            ),

            const SizedBox(height: 20),

            _label('منطقة العمل *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'مثال: سنهور القبلية وضواحيها',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => v!.trim().isEmpty ? 'المنطقة مطلوبة' : null,
            ),

            const SizedBox(height: 20),

            _label('الخدمات التي تقدّمها *'),
            const SizedBox(height: 10),
            const Text('اختر كل الخدمات التي تستطيع تقديمها:',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ServiceRequestCategory.values.map((cat) {
                final isSelected = _selectedCategories.contains(cat.name);
                return FilterChip(
                  label: Text(ServiceRequestModel.categoryLabel(cat),
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : null)),
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
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
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

            const SizedBox(height: 20),

            _label('نبذة عن خبرتك (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'مثال: كهربائي بخبرة 10 سنوات في التمديدات والصيانة...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
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
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.engineering_outlined),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'تسجيل كمزوّد خدمة',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.teal));
}
