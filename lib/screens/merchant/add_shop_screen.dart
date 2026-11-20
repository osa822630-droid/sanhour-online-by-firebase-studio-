// lib/screens/merchant/add_shop_screen.dart
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shops_provider.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
import '../../services/media_upload_service.dart';

class AddShopScreen extends StatefulWidget {
  final String activationCode;
  final bool adminBypass;

  const AddShopScreen({
    super.key,
    this.activationCode = '',
    this.adminBypass = false,
  });

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  late final bool _adminBypass;

  List<String> _approvedRegions = [
    'وسط البلد',
    'الشارع العام',
    'شارع البحر',
    'الموقف',
    'سنهور القبلية',
  ];
  String? _selectedRegionOption;

  @override
  void initState() {
    super.initState();
    _adminBypass = widget.adminBypass &&
        Provider.of<AuthProvider>(context, listen: false).userRole ==
            UserRole.admin;
    _selectedRegionOption = _approvedRegions.first;
    _location = _approvedRegions.first;
    _loadApprovedRegions();
  }

  Future<void> _loadApprovedRegions() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('settings')
            .doc('locations')
            .get(),
        FirebaseFirestore.instance.collection('settings').doc('general').get(),
      ]);
      final locData = results[0].data() ?? {};
      final genData = results[1].data() ?? {};
      final raw =
          locData['areas'] ?? locData['regions'] ?? genData['regions'];
      if (raw is List && raw.isNotEmpty && mounted) {
        setState(() {
          _approvedRegions = raw.map((e) => e.toString()).toSet().toList();
          if (_selectedRegionOption == null ||
              (!_approvedRegions.contains(_selectedRegionOption) &&
                  _selectedRegionOption != '__custom__')) {
            _selectedRegionOption = _approvedRegions.first;
            _location = _selectedRegionOption!;
          }
        });
      }
    } catch (_) {}
  }

  File? _logoFile;
  File? _coverFile;

  String _name = '';
  String _category = '';
  String _phone = '';
  String _location = '';
  String _description = '';
  String _activationCode = '';
  String _targetOwnerIdentifier = '';
  String? _whatsapp;
  String? _facebookUrl;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _telegramUrl;
  String _workingHours = '';

  bool _isSubmitting = false;
  bool _isValidatingCode = false;

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
        const SnackBar(
            content: Text('يرجى اختيار شعار للمحل'),
            backgroundColor: Colors.red),
      );
      return;
    }

    _formKey.currentState!.save();

    if (!_adminBypass) {
      setState(() => _isValidatingCode = true);
      try {
        await ApiService.validateActivationCode(_activationCode);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isValidatingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('كود التفعيل غير صحيح أو مستخدم'),
              backgroundColor: Colors.red),
        );
        return;
      }
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

      await ApiService.createShop(
        {
          'name': _name,
          'category': _category,
          'phone': _phone,
          'location': _location,
          'description': _description,
          'ownerId': user.id,
          'activationCode': _activationCode,
          if (_adminBypass) 'targetOwnerIdentifier': _targetOwnerIdentifier,
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
          'coverUrl': '',
          'imageUrl': '',
        },
        _logoFile,
        _coverFile,
        adminBypass: _adminBypass,
        onLogoProgress: (f) {
          if (!mounted) return;
          setState(() => _logoProgress = f);
        },
        onCoverProgress: (f) {
          if (!mounted) return;
          setState(() => _coverProgress = f);
        },
      );

      if (mounted) {
        Provider.of<ShopsProvider>(context, listen: false)
            .fetchShops(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 تم إنشاء المحل بنجاح!'),
              backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      final rawErr = e.toString();
      final msg = e is MediaUploadException
          ? e.userMessage
          : (rawErr.contains('unavailable') || rawErr.contains('deadline-exceeded'))
              ? 'تعذّر الاتصال بخادم البيانات حالياً. تأكد من استقرار الإنترنت وحاول مرة أخرى.'
              : 'فشل إنشاء المحل: ${rawErr.replaceFirst('Exception: ', '')}';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = context.watch<ShopsProvider>().categories;
    final categoryNames = categories.isNotEmpty
        ? categories.map((c) => c.name).toList()
        : [
            'مأكولات ومشروبات',
            'ملابس',
            'أجهزة إلكترونية',
            'خدمات طبية',
            'أخرى'
          ];
    final effectiveCategory = categoryNames.contains(_category)
        ? _category
        : categoryNames.first;
    if (_category.isEmpty) _category = effectiveCategory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات المحل الجديد'),
        backgroundColor: const Color(0xFF3D6B5E),
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
                      GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () => _pickImage(isLogo: false),
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          margin: const EdgeInsets.only(bottom: 40),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF232927)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            image: _coverFile != null
                                ? DecorationImage(
                                    image: FileImage(_coverFile!),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: _coverFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Icon(Icons.camera_alt,
                                          color: Colors.grey[400], size: 32),
                                      const SizedBox(height: 6),
                                      Text('صورة الغلاف (اختياري)',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12)),
                                    ])
                              : (_coverProgress != null &&
                                      _coverProgress! < 1.0)
                                  ? _uploadOverlay(_coverProgress!,
                                      borderRadius: 12)
                                  : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => _pickImage(isLogo: true),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF121514)
                                    : Colors.white,
                                shape: BoxShape.circle),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: isDark
                                      ? const Color(0xFF232927)
                                      : Colors.grey[100],
                                  backgroundImage: _logoFile != null
                                      ? FileImage(_logoFile!)
                                      : null,
                                  child: _logoFile == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                              Icon(Icons.add_a_photo,
                                                  size: 24,
                                                  color: Colors.grey[500]),
                                              Text('شعار *',
                                                  style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 11.5)),
                                            ])
                                      : null,
                                ),
                                if (_logoFile != null &&
                                    _logoProgress != null &&
                                    _logoProgress! < 1.0)
                                  ClipOval(
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: _uploadOverlay(_logoProgress!,
                                          borderRadius: 40),
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
              _buildField(
                  label: 'اسم المحل *',
                  icon: Icons.store,
                  onSaved: (v) => _name = v!,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: effectiveCategory,
                decoration: const InputDecoration(
                  labelText: 'التصنيف *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: categoryNames
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'اختر تصنيفاً' : null,
                onChanged: (v) => setState(() => _category = v!),
                onSaved: (v) => _category = v ?? '',
              ),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رقم هاتف المحل *',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => _phone = v!,
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'رقم غير صحيح'
                      : null),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                key: ValueKey(_approvedRegions.join(',')),
                initialValue: _selectedRegionOption ??
                    (_approvedRegions.isNotEmpty
                        ? _approvedRegions.first
                        : null),
                decoration: const InputDecoration(
                  labelText: 'المنطقة / الحي *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: [
                  ..._approvedRegions.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  ),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('أخرى (كتابة عنوان مخصص)'),
                  ),
                ],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'اختر المنطقة' : null,
                onChanged: (v) {
                  setState(() {
                    _selectedRegionOption = v;
                    if (v != null && v != '__custom__') {
                      _location = v;
                    }
                  });
                },
                onSaved: (v) {
                  if (v != null && v != '__custom__') {
                    _location = v;
                  }
                },
              ),
              if (_selectedRegionOption == '__custom__') ...[
                const SizedBox(height: 14),
                _buildField(
                  label: 'العنوان التفصيلي *',
                  icon: Icons.location_on,
                  onSaved: (v) => _location = v!.trim(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
              ],
              const SizedBox(height: 14),

              _buildField(
                  label: 'وصف المحل',
                  icon: Icons.description,
                  maxLines: 3,
                  onSaved: (v) => _description = v ?? ''),
              const SizedBox(height: 20),

              const Text('معلومات التواصل (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              _buildField(
                  label: 'مواعيد العمل (مثال: 9 ص - 11 م)',
                  icon: Icons.access_time,
                  onSaved: (v) => _workingHours = v ?? ''),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رقم الواتساب',
                  icon: FontAwesomeIcons.whatsapp,
                  isFa: true,
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => _whatsapp = v),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رابط فيسبوك',
                  icon: FontAwesomeIcons.facebook,
                  isFa: true,
                  keyboardType: TextInputType.url,
                  onSaved: (v) => _facebookUrl = v),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رابط انستجرام',
                  icon: FontAwesomeIcons.instagram,
                  isFa: true,
                  keyboardType: TextInputType.url,
                  onSaved: (v) => _instagramUrl = v),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رابط تيك توك',
                  icon: FontAwesomeIcons.tiktok,
                  isFa: true,
                  keyboardType: TextInputType.url,
                  onSaved: (v) => _tiktokUrl = v),
              const SizedBox(height: 14),

              _buildField(
                  label: 'رابط تيليجرام',
                  icon: FontAwesomeIcons.telegram,
                  isFa: true,
                  keyboardType: TextInputType.url,
                  onSaved: (v) => _telegramUrl = v),
              const SizedBox(height: 24),

              // ─── كود التفعيل ──────────────────────────────────────────
              if (_adminBypass) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'إنشاء محل بصلاحية الأدمن — لا يحتاج كود تفعيل',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف أو يوزر مالك المحل (اختياري)',
                    hintText:
                        '01xxxxxxxxx أو @username — اتركه فارغاً ليبقى بدون مالك',
                    helperText:
                        'لو الرقم غير مسجّل بعد، سيُربط المحل بصاحبه تلقائياً فور تسجيله في التطبيق',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_pin_outlined,
                        color: Color(0xFF3D6B5E)),
                  ),
                  onSaved: (v) => _targetOwnerIdentifier = (v ?? '').trim(),
                ),
              ] else ...[
                const Text('كود التفعيل',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('احصل على الكود من الإدارة لتفعيل متجرك',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.activationCode.isNotEmpty
                      ? widget.activationCode
                      : null,
                  decoration: InputDecoration(
                    labelText: 'كود التفعيل *',
                    hintText: 'SHP-XXXX-XXXX أو SHOP-XXXX-XXXX',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.vpn_key,
                        color: Color(0xFF3D6B5E)),
                    suffixIcon: _isValidatingCode
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'كود التفعيل مطلوب';
                    }
                    final upper = v.trim().toUpperCase();
                    if (!upper.startsWith('SHOP-') &&
                        !upper.startsWith('SHP-')) {
                      return 'الكود يجب أن يبدأ بـ SHP- أو SHOP-';
                    }
                    return null;
                  },
                  onSaved: (v) => _activationCode = v!.trim().toUpperCase(),
                ),
              ],

              const SizedBox(height: 32),

              if (_isSubmitting &&
                  (_logoProgress != null || _coverProgress != null)) ...[
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
                        color: const Color(0xFF3D6B5E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'جارٍ رفع الصور... ${(overall * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3D6B5E),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                  ]);
                }),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isSubmitting || _isValidatingCode ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D6B5E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('إنشاء المحل',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

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
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required Object icon,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isFa = false,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: (isFa && icon is FaIconData)
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: FaIcon(icon, size: 18),
              )
            : Icon(icon as IconData),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
    );
  }
}
