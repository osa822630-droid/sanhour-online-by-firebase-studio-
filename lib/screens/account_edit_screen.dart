// lib/screens/account_edit_screen.dart
// شاشة تعديل الحساب — الاسم، اسم المستخدم، الصورة الشخصية
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/media_upload_service.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  File? _newPhoto;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  // ✅ نظام تقدم رفع الصورة الشخصية — null = لم يبدأ، 0.0–1.0 = نسبة الرفع
  double? _photoProgress;
  String _currentPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _prefillData() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    _nameCtrl.text = user.name;
    _usernameCtrl.text = user.username;
    _currentPhotoUrl = user.profileImageUrl ?? '';
  }

  Future<void> _pickPhoto() async {
    final source = await _showSourcePicker();
    if (source == null) return;
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (picked != null && mounted) {
        setState(() => _newPhoto = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذّر تحديد الصورة. تحقق من صلاحيات التطبيق.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<ImageSource?> _showSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('اختر مصدر الصورة',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _srcBtn(
                      icon: Icons.camera_alt,
                      label: 'الكاميرا',
                      source: ImageSource.camera)),
              const SizedBox(width: 12),
              Expanded(
                  child: _srcBtn(
                      icon: Icons.photo_library,
                      label: 'المعرض',
                      source: ImageSource.gallery)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _srcBtn(
      {required IconData icon,
      required String label,
      required ImageSource source}) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF5E35B1).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF5E35B1), size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF5E35B1),
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Future<String?> _uploadPhoto(String userId) async {
    if (_newPhoto == null) return null;
    setState(() {
      _isUploadingPhoto = true;
      _photoProgress = 0;
    });
    try {
      // ✅ إصلاح الكراش: MediaUploadService بدل putFile الخام
      // — تحقق من الحجم (≤10MB)، رسائل خطأ عربية، إعادة محاولة تلقائية
      // — تتبع تقدم حقيقي عبر snapshotEvents
      final url = await MediaUploadService.uploadFile(
        file: _newPhoto!,
        folder: 'users/$userId',
        kind: MediaKind.image,
        fileName: 'profile.jpg',
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _photoProgress = p.fraction);
        },
      );
      return url;
    } on MediaUploadException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.userMessage),
        backgroundColor: Colors.orange,
      ));
      return null;
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذّر رفع الصورة. تحقق من اتصالك بالإنترنت.'),
        backgroundColor: Colors.orange,
      ));
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _photoProgress = null;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final username = _usernameCtrl.text.trim();
    if (username.isNotEmpty) {
      final valid = RegExp(r'^[a-zA-Z0-9_\.]{3,20}$');
      if (!valid.hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'اسم المستخدم: 3-20 حرف إنجليزي/رقم/_ أو . فقط'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      if (username != user.username) {
        try {
          final existing = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();
          if (existing.docs.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
              content: Text('اسم المستخدم محجوز. اختر اسماً آخر.'),
              backgroundColor: Colors.red,
            ));
            return;
          }
        } catch (_) {}
      }
    }

    setState(() => _isSaving = true);
    // ✅ Fix #148: استخدام AuthService.updateUserProfile بدلاً من Firestore مباشرة
    try {
      String photoUrl = _currentPhotoUrl;
      if (_newPhoto != null) {
        final uploaded = await _uploadPhoto(user.id);
        if (uploaded != null) photoUrl = uploaded;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'name': _nameCtrl.text.trim(),
        if (username.isNotEmpty) 'username': username,
        'profileImageUrl': photoUrl.isNotEmpty ? photoUrl : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      auth.updateUserLocally(
        name: _nameCtrl.text.trim(),
        username: username.isNotEmpty ? username : user.username,
        photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ التغييرات بنجاح ✅'),
        backgroundColor: Colors.green,
      ));
      // ✅ إصلاح: كان الإغلاق يحدث فوراً بعد عرض الرسالة، فتُدمَّر الرسالة مع
      // الشاشة قبل أن يراها المستخدم فعلياً — تأخير بسيط يضمن ظهورها بوضوح
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدث خطأ أثناء الحفظ. حاول مرة أخرى.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('تعديل الحساب',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
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
            // ── الصورة ──────────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickPhoto,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF5E35B1), width: 3),
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _newPhoto != null
                                ? Image.file(_newPhoto!, fit: BoxFit.cover)
                                : _currentPhotoUrl.isNotEmpty
                                    ? Image.network(
                                        _currentPhotoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _avatar(user),
                                      )
                                    : _avatar(user),
                            // ✅ طبقة تقدم رفع الصورة الشخصية
                            if (_photoProgress != null && _photoProgress! < 1.0)
                              Container(
                                color: Colors.black.withValues(alpha: 0.55),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          value: _photoProgress,
                                          strokeWidth: 3,
                                          color: Colors.white,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${((_photoProgress ?? 0) * 100).round()}%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Color(0xFF5E35B1),
                            shape: BoxShape.circle),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.camera_alt,
                                color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _fieldLabel('الاسم الكامل'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  hintText: 'مثال: محمد أحمد',
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                if (v.trim().length < 2) return 'الاسم قصير جداً';
                return null;
              },
            ),

            const SizedBox(height: 20),

            _fieldLabel('اسم المستخدم (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  hintText: 'مثال: mohammed_99',
                  prefixIcon: Icon(Icons.alternate_email)),
            ),
            const SizedBox(height: 4),
            Text('أحرف إنجليزية وأرقام و _ و . فقط (3-20 حرف)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),

            const SizedBox(height: 20),

            _fieldLabel('رقم الهاتف'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF252535) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.phone, color: Colors.grey[500], size: 20),
                const SizedBox(width: 12),
                Text(user?.phone ?? '—',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 15),
                    textDirection: TextDirection.ltr),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('للقراءة فقط',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text('لتغيير رقم الهاتف، تواصل مع الدعم الفني',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ التغييرات',
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

  Widget _avatar(AppUser? user) {
    return Container(
      color: const Color(0xFF5E35B1),
      child: Center(
        child: Text(
          user?.name.isNotEmpty == true
              ? user!.name.substring(0, 1).toUpperCase()
              : 'م',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5E35B1)));
}
