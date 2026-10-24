// lib/screens/post_job_ad_screen.dart
// نشر إعلان وظيفة — متاح لأي مستخدم مسجّل
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/job_ad_model.dart';
import '../providers/auth_provider.dart';

class PostJobAdScreen extends StatefulWidget {
  const PostJobAdScreen({super.key});

  @override
  State<PostJobAdScreen> createState() => _PostJobAdScreenState();
}

class _PostJobAdScreenState extends State<PostJobAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  JobCategory _category = JobCategory.workers;
  String _workType = 'دوام كامل';
  int _requiredCount = 1;
  bool _isSaving = false;

  final List<String> _workTypes = [
    'دوام كامل',
    'دوام جزئي',
    'يومية',
    'بالقطعة',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _salaryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ✅ Item #11: الضيف (وغير المسجّل) ملوش user، فـ user! كانت بتكراش وكانت
    // جاية بعد _isSaving = true وبره الـ try فالـ spinner كان بيفضل شغال.
    // الفحص هنا أولًا: قبل الـ validation وقبل تشغيل الـ loading.
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب تسجيل الدخول لنشر إعلان وظيفة'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final ref = FirebaseFirestore.instance.collection('job_ads').doc();
      final job = JobAdModel(
        id: ref.id,
        posterId: user.id,
        posterName: user.name,
        posterPhone: user.phone,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        location: _locationCtrl.text.trim(),
        salary: _salaryCtrl.text.trim().isEmpty
            ? 'يُتفق عليه'
            : _salaryCtrl.text.trim(),
        workType: _workType,
        requiredCount: _requiredCount,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // ✅ Fix #31: إلغاء تفعيل الإعلانات السابقة لنفس المستخدم في batch ذرية
      final prevAds = await FirebaseFirestore.instance
          .collection('job_ads')
          .where('posterId', isEqualTo: user.id)
          .where('isActive', isEqualTo: true)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in prevAds.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      batch.set(ref, job.toMap());
      await batch.commit();

      // ✅ Fix #30: تصحيح route في notification payload ليوجه لإعلانات الوظائف
      await FirebaseFirestore.instance
          .collection('notification_queue')
          .add({
        'title': '💼 وظيفة جديدة: ${JobAdModel.categoryLabel(_category)}',
        'body': _titleCtrl.text.trim(),
        'topic': 'jobs_${JobAdModel.categoryToString(_category)}',
        'data': {
          'route': 'job_ads',
          'jobId': ref.id,
          'channel': 'job_alerts',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم نشر إعلان الوظيفة بنجاح ✅'),
        backgroundColor: Colors.green,
      ));
      // ✅ إصلاح: تأخير بسيط قبل الإغلاق حتى تظهر رسالة النجاح فعلياً
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
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
        title: const Text('نشر إعلان وظيفة',
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
            // ── نوع الوظيفة ──────────────────────────────────
            _label('نوع الوظيفة *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<JobCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline)),
              items: JobCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(JobAdModel.categoryLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 20),

            // ── عنوان الوظيفة ─────────────────────────────────
            _label('عنوان الوظيفة *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'مثال: مطلوب عامل بناء ماهر',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 20),

            // ── تفاصيل الوظيفة ────────────────────────────────
            _label('تفاصيل الوظيفة *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'المهام المطلوبة، الخبرة، الشروط، أوقات العمل...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'التفاصيل مطلوبة' : null,
            ),
            const SizedBox(height: 20),

            // ── المنطقة ─────────────────────────────────────
            _label('المنطقة *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'مثال: سنهور القبلية - الشارع الرئيسي',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'المنطقة مطلوبة' : null,
            ),
            const SizedBox(height: 20),

            // ── المرتب ─────────────────────────────────────
            _label('المرتب أو الأجر (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _salaryCtrl,
              decoration: const InputDecoration(
                hintText: 'مثال: 800 جنيه/شهر أو يُتفق عليه',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // ── نوع الدوام ─────────────────────────────────
            _label('نوع الدوام'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _workType,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule_outlined)),
              items: _workTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _workType = v!),
            ),
            const SizedBox(height: 20),

            // ── العدد المطلوب ──────────────────────────────
            _label('عدد المطلوبين'),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(
                onPressed: () {
                  if (_requiredCount > 1) {
                    setState(() => _requiredCount--);
                  }
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: Color(0xFF5E35B1)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_requiredCount',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _requiredCount++),
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF5E35B1)),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لما تلاقي الشخص المناسب، ادخل على الإعلان واحذفه عشان يُعلن اتمليء.',
                    style:
                        TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ]),
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
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('نشر الإعلان',
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
