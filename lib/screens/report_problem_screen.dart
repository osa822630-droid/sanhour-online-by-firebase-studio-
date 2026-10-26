// lib/screens/report_problem_screen.dart
// ✅ إضافة رابط "تتبع شكاواك" في أعلى الشاشة
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'my_complaints_screen.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;

  String _type = 'شكوى';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = Provider.of<AuthProvider>(context, listen: false).user;

    try {
      await ApiService.submitComplaint({
        'userId': user?.id ?? 'guest',
        'userName': user?.name ?? 'زائر',
        'userPhone': user?.phone ?? 'غير مسجل',
        'type': _type,
        'title': _titleController.text.trim(),
        'details': _detailsController.text.trim(),
        'status': 'pending',
        'reply': '',
        // ✅ Fix #25: createdAt بيتحدد على السيرفر جوه AdminService.submitComplaint (serverTimestamp)
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رسالتك بنجاح! سنرد خلال 24-48 ساعة ✅'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في الإرسال، حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('تواصل معنا',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        // ✅ رابط لشاشة تتبع الشكاوى
        actions: [
          if (!auth.isGuest)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MyComplaintsScreen()),
              ),
              icon: const Icon(Icons.inbox_outlined,
                  color: Colors.white70, size: 18),
              label: const Text('شكاواي',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── بانر تتبع الشكاوى ─────────────────────────────
              if (!auth.isGuest)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyComplaintsScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color:
                          Colors.deepPurple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.deepPurple
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inbox_outlined,
                          color: Colors.deepPurple, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('لديك رسائل سابقة؟',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text('اضغط لتتبع حالة شكاواك ومعرفة الردود',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_back_ios,
                          size: 14, color: Colors.deepPurple),
                    ]),
                  ),
                ),

              // ── أيقونة ──────────────────────────────────────────
              const Icon(Icons.headset_mic, size: 72, color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text(
                'هل واجهت مشكلة؟ أو لديك اقتراح؟',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text('نحن هنا للاستماع إليك.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 28),

              // نوع الرسالة
              DropdownButtonFormField<String>(
                // ✅ إصلاح API قديم: value مُهملة لصالح initialValue (Flutter 3.32+)
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'نوع الرسالة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  'شكوى', 'اقتراح', 'إبلاغ عن تاجر', 'مشكلة تقنية'
                ]
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),

              // العنوان
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عنوان الموضوع *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // التفاصيل
              TextFormField(
                controller: _detailsController,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'التفاصيل *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 5,
                validator: (v) =>
                    v!.trim().isEmpty ? 'التفاصيل مطلوبة' : null,
              ),
              const SizedBox(height: 24),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send),
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('إرسال للإدارة',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
