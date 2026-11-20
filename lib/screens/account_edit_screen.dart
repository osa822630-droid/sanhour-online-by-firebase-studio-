// lib/screens/account_edit_screen.dart
// شاشة تعديل الحساب — الاسم، اسم المستخدم، الصورة الشخصية، وكود الدعوة
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import '../widgets/motion/sanhour_motion_kit.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/media_upload_service.dart';
import '../services/referral_service.dart';
import '../widgets/cached_image.dart';

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
  double? _photoProgress;
  String _currentPhotoUrl = '';
  String _referralCode = '';
  int _referralCount = 0;
  bool _loadingReferral = false;

  @override
  void initState() {
    super.initState();
    _prefillData();
    _loadReferralInfo();
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

  Future<void> _loadReferralInfo() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || user.id.isEmpty) return;
    setState(() => _loadingReferral = true);
    try {
      final code = await ReferralService.getOrCreateCode(user.id);
      final count = await ReferralService.getReferralCount(user.id);
      if (mounted) {
        setState(() {
          _referralCode = code;
          _referralCount = count;
          _loadingReferral = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReferral = false);
    }
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          color: const Color(0xFF3D6B5E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF3D6B5E).withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF3D6B5E), size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF3D6B5E), fontWeight: FontWeight.w600)),
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

    final rawUsername = _usernameCtrl.text.trim();
    final usernameLower = rawUsername.toLowerCase();
    final oldUsernameLower = user.username.trim().toLowerCase();

    if (rawUsername.isNotEmpty) {
      final valid = RegExp(r'^[a-zA-Z0-9_\.]{3,20}$');
      if (!valid.hasMatch(rawUsername)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('اسم المستخدم: 3-20 حرف إنجليزي/رقم/_ أو . فقط'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      if (usernameLower != oldUsernameLower) {
        try {
          final usernameDoc = await FirebaseFirestore.instance
              .collection('usernames')
              .doc(usernameLower)
              .get();
          if (usernameDoc.exists &&
              usernameDoc.data()?['uid'] != user.id) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('اسم المستخدم محجوز. اختر اسماً آخر.'),
              backgroundColor: Colors.red,
            ));
            return;
          }

        } catch (_) {}
      }
    }

    setState(() => _isSaving = true);
    try {
      String photoUrl = _currentPhotoUrl;
      if (_newPhoto != null) {
        final storageUid = FirebaseAuth.instance.currentUser?.uid ?? user.id;
        final uploaded = await _uploadPhoto(storageUid);
        if (uploaded != null) photoUrl = uploaded;
      }

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // تحديث حجز اسم المستخدم ذرياً في مجموعة usernames
      if (rawUsername.isNotEmpty && usernameLower != oldUsernameLower) {
        batch.set(db.collection('usernames').doc(usernameLower), {
          'uid': user.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (oldUsernameLower.isNotEmpty) {
          batch.delete(db.collection('usernames').doc(oldUsernameLower));
        }
      }

      batch.update(db.collection('users').doc(user.id), {
        'name': _nameCtrl.text.trim(),
        if (rawUsername.isNotEmpty) 'username': rawUsername,
        'profileImageUrl': photoUrl.isNotEmpty ? photoUrl : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(const Duration(seconds: 12));

      auth.updateUserLocally(
        name: _nameCtrl.text.trim(),
        username: rawUsername.isNotEmpty ? rawUsername : user.username,
        photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ التغييرات بنجاح ✅'),
        backgroundColor: Colors.green,
      ));
      await Future.delayed(const Duration(milliseconds: 250));
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
          isDark ? const Color(0xFF121514) : const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: const Text('تعديل الحساب',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF3D6B5E),
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
                            color: Color(0xFF3D6B5E), width: 3),
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _newPhoto != null
                                ? Image.file(_newPhoto!, fit: BoxFit.cover)
                                : _currentPhotoUrl.isNotEmpty
                                    ? CachedImage(
                                        imageUrl: _currentPhotoUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: _avatar(user),
                                      )
                                    : _avatar(user),
                            if (_photoProgress != null &&
                                _photoProgress! < 1.0)
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
                                            fontSize: 11.5,
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
                            color: Color(0xFF3D6B5E), shape: BoxShape.circle),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232927) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.phone, color: Colors.grey[500], size: 20),
                const SizedBox(width: 12),
                Text(user?.phone ?? '—',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 15),
                    textDirection: TextDirection.ltr),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('للقراءة فقط',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text('لتغيير رقم الهاتف، تواصل مع الدعم الفني',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),

            // ── بطاقة كود الدعوة الخاص بالمستخدم ───────────────────────
            if (user != null && _referralCode.isNotEmpty) ...[
              const SizedBox(height: 24),
              _fieldLabel('كود الدعوة الخاص بك'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D6B5E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF3D6B5E).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Color(0xFF3D6B5E)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            _referralCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                              color: Color(0xFF3D6B5E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'عدد الأصدقاء المدعوين: $_referralCount',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'نسخ الكود',
                      icon: const Icon(Icons.copy,
                          size: 20, color: Color(0xFF3D6B5E)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ كود الدعوة ✅'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else if (_loadingReferral) ...[
              const SizedBox(height: 16),
              const Center(child: LinearProgressIndicator()),
            ],

            const SizedBox(height: 40),

            DynamicButton(
              state: _isSaving
                  ? DynamicButtonState.loading
                  : DynamicButtonState.idle,
              idleLabel: 'حفظ التغييرات',
              loadingLabel: 'جاري الحفظ...',
              onPressed: _save,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _avatar(AppUser? user) {
    return Container(
      color: const Color(0xFF3D6B5E),
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
          color: Color(0xFF3D6B5E)));
}
