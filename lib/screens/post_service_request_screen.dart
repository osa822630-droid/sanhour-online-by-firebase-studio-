// lib/screens/post_service_request_screen.dart
// نشر طلب خدمة — متاح لأي مستخدم مسجّل
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/service_request_model.dart';
import '../providers/auth_provider.dart';

class PostServiceRequestScreen extends StatefulWidget {
  const PostServiceRequestScreen({super.key});

  @override
  State<PostServiceRequestScreen> createState() =>
      _PostServiceRequestScreenState();
}

class _PostServiceRequestScreenState
    extends State<PostServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  ServiceRequestCategory _category = ServiceRequestCategory.plumbing;
  bool _urgent = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final user = context.read<AuthProvider>().user!;
    final db = FirebaseFirestore.instance;

    try {
      final ref = db.collection('service_requests').doc();
      final suggestedPrice = double.tryParse(_priceCtrl.text.trim());

      final request = ServiceRequestModel(
        id: ref.id,
        clientId: user.id,
        clientName: user.name,
        clientPhone: user.phone,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        location: _locationCtrl.text.trim(),
        suggestedPrice: suggestedPrice,
        priceNote: suggestedPrice != null
            ? 'مقترح: ${suggestedPrice.toStringAsFixed(0)} جنيه'
            : 'يُتفق عليه',
        urgent: _urgent,
        status: ServiceRequestStatus.open,
        bidsCount: 0,
        createdAt: DateTime.now(),
      );

      await ref.set(request.toMap());

      // ✅ Fix #32: تصحيح الـ route في notification payload ليوجه لطلبات الخدمة
      await db.collection('notification_queue').add({
        'title':
            '🔧 طلب خدمة جديد: ${ServiceRequestModel.categoryLabel(_category)}',
        'body': _titleCtrl.text.trim(),
        'topic': 'providers_${_category.name}',
        'data': {
          'route': 'service_requests',
          'requestId': ref.id,
          'channel': 'service_requests',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم نشر طلبك بنجاح ✅ — سيتواصل معك مزوّدو الخدمة قريباً'),
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
        title: const Text('نشر طلب خدمة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _submit,
            child: Text(
              _isSaving ? 'جاري...' : 'نشر',
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
        // ✅ validation تظهر أثناء الكتابة
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── بانر تعريفي ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.teal, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'انشر طلبك، وسيتواصل معك مزوّدو الخدمة المهتمون بعرض أسعارهم. أنت من يختار من يناسبك.',
                    style: TextStyle(
                        color: Colors.teal, fontSize: 12, height: 1.5),
                  ),
                ),
              ]),
            ),

            // ── نوع الخدمة ────────────────────────────────────
            _label('نوع الخدمة المطلوبة *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceRequestCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman_outlined)),
              items: ServiceRequestCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                            ServiceRequestModel.categoryLabel(c)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 20),

            // ── العنوان ───────────────────────────────────────
            _label('وصف مختصر للمشكلة *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText:
                    'مثال: محتاج سباك لتصليح حنفية، عربية نقل لـ عيادة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'الوصف مطلوب' : null,
            ),
            const SizedBox(height: 20),

            // ── التفاصيل ──────────────────────────────────────
            _label('تفاصيل إضافية (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'اذكر أي تفاصيل مهمة: الحجم، الموعد المناسب، المواصفات...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 20),

            // ── المنطقة ───────────────────────────────────────
            _label('المنطقة / الموقع *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'مثال: سنهور القبلية - حي الزهور',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'الموقع مطلوب' : null,
            ),
            const SizedBox(height: 20),

            // ── السعر المقترح ─────────────────────────────────
            _label('السعر المقترح (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'مثال: 150',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'جنيه',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اترك الحقل فارغاً إذا كنت تريد مقارنة الأسعار أولاً',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            // ── زر العاجل ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: _urgent
                        ? Colors.red
                        : Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
                color: _urgent
                    ? Colors.red.withValues(alpha: 0.06)
                    : null,
              ),
              child: SwitchListTile(
                title: const Text('طلب عاجل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'سيظهر إعلانك في أعلى القائمة',
                    style: TextStyle(fontSize: 12)),
                secondary: Icon(Icons.flash_on,
                    color: _urgent ? Colors.red : Colors.grey),
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                activeThumbColor: Colors.red,
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('نشر الطلب',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5E35B1)));
}
