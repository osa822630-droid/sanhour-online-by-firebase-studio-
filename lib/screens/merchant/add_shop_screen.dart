// lib/screens/merchant/add_shop_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shops_provider.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
import '../../services/media_upload_service.dart';

class AddShopScreen extends StatefulWidget {
  // ✅ يمكن أن يكون فارغاً (المستخدم يدخله في النموذج)
  final String activationCode;
  const AddShopScreen({super.key, this.activationCode = ''});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();

  File? _logoFile;
  File? _coverFile;

  String _name = '';
  String _category = '';
  String _phone = '';
  String _location = '';
  String _description = '';
  String _activationCode = '';
  String? _whatsapp;
  String? _facebookUrl;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _telegramUrl;
  String _workingHours = '';

  bool _isSubmitting = false;
  bool _isValidatingCode = false;

  // ✅ نظام تقدم الرفع — null = لم يبدأ بعد، 0.0–1.0 = نسبة الرفع
  double? _logoProgress;
  double? _coverProgress;

  Future<void> _pickImage({required bool isLogo}) async {
    final source = await ImageHelper.showSourcePicker(context);
    if (source == null) return;
    if (!mounted) return;
    final file = await ImageHelper.pickAndCrop(
      context: context,
      source: source,
      ratio: isLogo ? ImageRatio.square : ImageRatio.cover,
      hint: isLogo
          ? '💡 يُنصح بإضافة شعار (لوجو) المحل — مربع 1:1'
          : '💡 يُنصح بإضافة صورة حقيقية للمحل من الخارج — أبعاد 3:2',
    );
    if (file != null) {
      setState(() {
        if (isLogo) {
          _logoFile = file;
        } else {
          _coverFile = file;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_logoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار شعار للمحل'), backgroundColor: Colors.red),
      );
      return;
    }

    _formKey.currentState!.save();

    // ✅ التحقق من كود التفعيل
    setState(() => _isValidatingCode = true);
    try {
      await ApiService.validateActivationCode(_activationCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidatingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('كود التفعيل غير صحيح أو مستخدم'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isValidatingCode = false;
      _isSubmitting = true;
      _logoProgress = 0;
      _coverProgress = _coverFile != null ? 0 : null;
    });

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      await ApiService.createShop({
        'name': _name,
        'category': _category,
        'phone': _phone,
        'location': _location,
        'description': _description,
        'ownerId': user.id,
        'activationCode': _activationCode,
        'createdAt': DateTime.now().toIso8601String(),
        'whatsapp': _whatsapp,
        'facebookUrl': _facebookUrl,
        'instagramUrl': _instagramUrl,
        'tiktokUrl': _tiktokUrl,
        'telegramUrl': _telegramUrl,
        'workingHours': _workingHours,
        'workingDays': <String>[],
        'socialMedia': <String, String>{},
        'isFeatured': false,
        'rank': 0,
        'reviews': <String>[],
        'isFavorite': false,
        'coverUrl': '',
        'imageUrl': '',
      },
          _logoFile,
          _coverFile,
          // ✅ نظام تقدم الرفع — يُحدِّث الواجهة مباشرةً مع كل دفعة بايتات
          onLogoProgress: (f) {
            if (!mounted) return;
            setState(() => _logoProgress = f);
          },
          onCoverProgress: (f) {
            if (!mounted) return;
            setState(() => _coverProgress = f);
          });

      // ✅ تحديث قائمة المحلات في Provider
      if (mounted) {
        Provider.of<ShopsProvider>(context, listen: false).fetchShops(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 تم إنشاء المحل بنجاح!'), backgroundColor: Colors.green),
        );
        // ✅ إصلاح: تأخير بسيط قبل الإغلاق حتى تظهر رسالة النجاح فعلياً
        // للمستخدم بدلاً من أن تُدمَّر مع الشاشة فوراً
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      // ✅ MediaUploadException يحمل رسالة عربية جاهزة للعرض مباشرة
      final msg = e is MediaUploadException
          ? e.userMessage
          : 'فشل إنشاء المحل، تحقق من البيانات وحاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _logoProgress = null;
          _coverProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ الفئات من Provider مباشرة
    final categories = context.watch<ShopsProvider>().categories;
    final categoryNames = categories.map((c) => c.name).toList();
    if (_category.isEmpty && categoryNames.isNotEmpty) _category = categoryNames.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات المحل الجديد'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── صور المحل ────────────────────────────────────────────
              Center(
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // الغلاف
                      GestureDetector(
                        onTap: _isSubmitting ? null : () => _pickImage(isLogo: false),
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          margin: const EdgeInsets.only(bottom: 40),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            image: _coverFile != null
                                ? DecorationImage(image: FileImage(_coverFile!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _coverFile == null
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.camera_alt, color: Colors.grey[400], size: 32),
                                  const SizedBox(height: 6),
                                  Text('صورة الغلاف (اختياري)',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ])
                              // ✅ طبقة تقدم رفع الغلاف
                              : (_coverProgress != null && _coverProgress! < 1.0)
                                  ? _uploadOverlay(_coverProgress!, borderRadius: 12)
                                  : null,
                        ),
                      ),
                      // اللوجو
                      Positioned(
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : () => _pickImage(isLogo: true),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey[100],
                                  backgroundImage: _logoFile != null ? FileImage(_logoFile!) : null,
                                  child: _logoFile == null
                                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Icon(Icons.add_a_photo, size: 24, color: Colors.grey[500]),
                                          Text('شعار *', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                                        ])
                                      : null,
                                ),
                                // ✅ طبقة تقدم رفع اللوجو
                                if (_logoFile != null &&
                                    _logoProgress != null &&
                                    _logoProgress! < 1.0)
                                  ClipOval(
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: _uploadOverlay(_logoProgress!, borderRadius: 40),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── البيانات الأساسية ────────────────────────────────────
              _buildField(label: 'اسم المحل *', icon: Icons.store, onSaved: (v) => _name = v!,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 14),

              // ✅ الفئات من Firestore
              DropdownButtonFormField<String>(
                initialValue: _category.isEmpty ? null : _category,
                decoration: const InputDecoration(
                  labelText: 'التصنيف *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: categoryNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                validator: (v) => (v == null || v.isEmpty) ? 'اختر تصنيفاً' : null,
                onChanged: (v) => setState(() => _category = v!),
                onSaved: (v) => _category = v ?? '',
              ),
              const SizedBox(height: 14),

              _buildField(label: 'رقم هاتف المحل *', icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => _phone = v!,
                  validator: (v) => v!.length < 10 ? 'رقم غير صحيح' : null),
              const SizedBox(height: 14),

              _buildField(label: 'العنوان *', icon: Icons.location_on,
                  onSaved: (v) => _location = v!,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 14),

              _buildField(label: 'وصف المحل', icon: Icons.description,
                  maxLines: 3, onSaved: (v) => _description = v ?? ''),
              const SizedBox(height: 20),

              // ─── بيانات إضافية ────────────────────────────────────────
              const Text('معلومات التواصل (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              _buildField(label: 'مواعيد العمل (مثال: 9 ص - 11 م)',
                  icon: Icons.access_time, onSaved: (v) => _workingHours = v ?? ''),
              const SizedBox(height: 14),

              _buildField(label: 'رقم الواتساب', icon: FontAwesomeIcons.whatsapp,
                  keyboardType: TextInputType.phone, onSaved: (v) => _whatsapp = v),
              const SizedBox(height: 14),

              _buildField(label: 'رابط فيسبوك', icon: FontAwesomeIcons.facebook,
                  keyboardType: TextInputType.url, onSaved: (v) => _facebookUrl = v),
              const SizedBox(height: 14),

              _buildField(label: 'رابط انستجرام', icon: FontAwesomeIcons.instagram,
                  keyboardType: TextInputType.url, onSaved: (v) => _instagramUrl = v),
              const SizedBox(height: 14),

              _buildField(label: 'رابط تيك توك', icon: FontAwesomeIcons.tiktok,
                  keyboardType: TextInputType.url, onSaved: (v) => _tiktokUrl = v),
              const SizedBox(height: 14),

              _buildField(label: 'رابط تيليجرام', icon: FontAwesomeIcons.telegram,
                  keyboardType: TextInputType.url, onSaved: (v) => _telegramUrl = v),
              const SizedBox(height: 24),

              // ─── كود التفعيل ──────────────────────────────────────────
              const Text('كود التفعيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('احصل على الكود من الإدارة لتفعيل متجرك',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              TextFormField(
                initialValue: widget.activationCode.isNotEmpty ? widget.activationCode : null,
                decoration: InputDecoration(
                  labelText: 'كود التفعيل *',
                  hintText: 'SHOP-XXXX-XXXX',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.deepPurple),
                  suffixIcon: _isValidatingCode
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'كود التفعيل مطلوب';
                  if (!v.trim().toUpperCase().startsWith('SHOP-')) return 'الكود يجب أن يبدأ بـ SHOP-';
                  return null;
                },
                onSaved: (v) => _activationCode = v!.trim().toUpperCase(),
              ),

              const SizedBox(height: 32),

              // ✅ نص تقدم الرفع الإجمالي أثناء الحفظ
              if (_isSubmitting && (_logoProgress != null || _coverProgress != null)) ...[
                Builder(builder: (_) {
                  final values = <double>[
                    if (_logoFile != null) (_logoProgress ?? 0),
                    if (_coverFile != null) (_coverProgress ?? 0),
                  ];
                  final overall = values.isEmpty
                      ? 0.0
                      : values.reduce((a, b) => a + b) / values.length;
                  return Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overall,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'جارٍ رفع الصور... ${(overall * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                  ]);
                }),
              ],

              // ─── زرار الحفظ ───────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting || _isValidatingCode ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('إنشاء المحل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ طبقة شفافة تعرض دائرة تقدم رفع فوق الصورة (غلاف/لوجو)
  Widget _uploadOverlay(double progress, {required double borderRadius}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required dynamic icon,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon is IconData
            ? Icon(icon)
            : FaIcon(icon as IconData, size: 18),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
    );
  }
}
