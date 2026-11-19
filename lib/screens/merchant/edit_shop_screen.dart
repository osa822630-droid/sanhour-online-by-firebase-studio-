// lib/screens/merchant/edit_shop_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/shop.dart';
import '../../providers/shops_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/media_gallery_picker_widget.dart';
import '../../services/media_upload_service.dart';
import '../../services/shop_service.dart';

class EditShopScreen extends StatefulWidget {
  final Shop shop;
  const EditShopScreen({super.key, required this.shop});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _hoursCtrl;
  late TextEditingController _facebookCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _tiktokCtrl;
  late TextEditingController _telegramCtrl;
  late TextEditingController _ownerTargetCtrl;

  File? _newLogoFile;
  File? _newCoverFile;
  String _selectedCategory = '';
  List<String> _approvedRegions = [
    'وسط البلد',
    'الشارع العام',
    'شارع البحر',
    'الموقف',
    'سنهور القبلية',
  ];

  double? _logoProgress;
  double? _coverProgress;

  MediaGalleryState? _mediaState;

  final Map<int, double> _galleryImageProgress = {};
  final Map<int, double> _galleryVideoProgress = {};

  double get _overallGalleryProgress {
    final state = _mediaState;
    if (state == null) return 0;
    final total = state.newImages.length + state.newVideos.length;
    if (total == 0) return 0;
    double sum = 0;
    for (int i = 0; i < state.newImages.length; i++) {
      sum += _galleryImageProgress[i] ?? 0;
    }
    for (int i = 0; i < state.newVideos.length; i++) {
      sum += _galleryVideoProgress[i] ?? 0;
    }
    return sum / total;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.shop.name);
    _phoneCtrl = TextEditingController(text: widget.shop.phone);
    _whatsappCtrl = TextEditingController(text: widget.shop.whatsapp ?? '');
    _locationCtrl = TextEditingController(text: widget.shop.location);
    _descCtrl = TextEditingController(text: widget.shop.description);
    _hoursCtrl = TextEditingController(text: widget.shop.workingHours);
    _facebookCtrl = TextEditingController(text: widget.shop.facebookUrl ?? '');
    _instagramCtrl =
        TextEditingController(text: widget.shop.instagramUrl ?? '');
    _tiktokCtrl = TextEditingController(text: widget.shop.tiktokUrl ?? '');
    _telegramCtrl = TextEditingController(text: widget.shop.telegramUrl ?? '');
    _ownerTargetCtrl =
        TextEditingController(text: widget.shop.pendingOwnerPhone ?? '');
    _selectedCategory = widget.shop.category;
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
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _telegramCtrl.dispose();
    _ownerTargetCtrl.dispose();
    super.dispose();
  }

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
          _newLogoFile = file;
        } else {
          _newCoverFile = file;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _logoProgress = _newLogoFile != null ? 0 : null;
      _coverProgress = _newCoverFile != null ? 0 : null;
      _galleryImageProgress.clear();
      _galleryVideoProgress.clear();
    });

    try {
      await ApiService.updateShop(
        widget.shop.id,
        {
          'name': _nameCtrl.text.trim(),
          'category': _selectedCategory,
          'phone': _phoneCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'workingHours': _hoursCtrl.text.trim(),
          'whatsapp': _whatsappCtrl.text.trim(),
          'facebookUrl': _facebookCtrl.text.trim(),
          'instagramUrl': _instagramCtrl.text.trim(),
          'tiktokUrl': _tiktokCtrl.text.trim(),
          'telegramUrl': _telegramCtrl.text.trim(),
          if (context.read<AuthProvider>().userRole == UserRole.admin &&
              _ownerTargetCtrl.text.trim().isNotEmpty)
            'targetOwnerIdentifier': _ownerTargetCtrl.text.trim(),
        },
        _newLogoFile,
        _newCoverFile,
        onLogoProgress: (f) {
          if (!mounted) return;
          setState(() => _logoProgress = f);
        },
        onCoverProgress: (f) {
          if (!mounted) return;
          setState(() => _coverProgress = f);
        },
      );

      final media = _mediaState;
      if (media != null &&
          (media.newImages.isNotEmpty ||
              media.newVideos.isNotEmpty ||
              media.removedUrls.isNotEmpty)) {
        await ShopService.updateShopMedia(
          shopId: widget.shop.id,
          keptUrls: media.keptUrls,
          keptTypes: media.keptTypes,
          newImages: media.newImages,
          newVideos: media.newVideos,
          removedUrls: media.removedUrls,
          onImageProgress: (i, f) {
            if (!mounted) return;
            setState(() => _galleryImageProgress[i] = f);
          },
          onVideoProgress: (i, f) {
            if (!mounted) return;
            setState(() => _galleryVideoProgress[i] = f);
          },
        );
      }

      if (!mounted) return;
      context.read<ShopsProvider>().fetchShops(refresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم تحديث بيانات المتجر ✅'),
            backgroundColor: Colors.green),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is MediaUploadException
          ? e.userMessage
          : 'فشل الحفظ، تحقق من البيانات وحاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    final catNames = categories.isNotEmpty
        ? categories.map((c) => c.name).toList()
        : [
            'مأكولات ومشروبات',
            'ملابس',
            'أجهزة إلكترونية',
            'خدمات طبية',
            'أخرى'
          ];
    final effectiveCategory = catNames.contains(_selectedCategory)
        ? _selectedCategory
        : catNames.first;
    if (_selectedCategory.isEmpty) _selectedCategory = effectiveCategory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل بيانات المتجر'),
        backgroundColor: const Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── الصور ───────────────────────────────────────────────
              const Text('صور المتجر',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: _isLoading ? null : () => _pickImage(isLogo: true),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF232927)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _newLogoFile != null
                              ? Image.file(_newLogoFile!, fit: BoxFit.cover)
                              : widget.shop.imageUrl.isNotEmpty
                                  ? CachedImage(
                                      imageUrl: widget.shop.imageUrl,
                                      fit: BoxFit.cover)
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                          const Icon(Icons.add_a_photo,
                                              color: Colors.grey),
                                          Text('الشعار',
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12)),
                                        ]),
                          if (_logoProgress != null && _logoProgress! < 1.0)
                            _buildUploadOverlay(_logoProgress!),
                        ],
                      ),
                    ),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap:
                          _isLoading ? null : () => _pickImage(isLogo: false),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Color(0xFF232927)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  isDark ? Colors.white24 : Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _newCoverFile != null
                                  ? Image.file(_newCoverFile!,
                                      fit: BoxFit.cover)
                                  : widget.shop.coverUrl.isNotEmpty
                                      ? CachedImage(
                                          imageUrl: widget.shop.coverUrl,
                                          fit: BoxFit.cover)
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                              const Icon(
                                                  Icons.add_photo_alternate,
                                                  color: Colors.grey),
                                              Text('صورة الغلاف',
                                                  style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12)),
                                            ]),
                              if (_coverProgress != null &&
                                  _coverProgress! < 1.0)
                                _buildUploadOverlay(_coverProgress!),
                            ],
                          ),
                        ),
                      ),
                    )),
              ]),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 8),
              MediaGalleryPickerWidget(
                initialUrls: widget.shop.mediaUrls,
                initialTypes: widget.shop.mediaTypes,
                maxItems: 8,
                imageProgress: _isLoading ? _galleryImageProgress : null,
                videoProgress: _isLoading ? _galleryVideoProgress : null,
                isUploading: _isLoading,
                onChanged: (state) => setState(() => _mediaState = state),
              ),

              if (_isLoading &&
                  (_mediaState?.newImages.isNotEmpty == true ||
                      _mediaState?.newVideos.isNotEmpty == true)) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _overallGalleryProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: Color(0xFF3D6B5E),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'جارٍ رفع الوسائط... ${(_overallGalleryProgress * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3D6B5E),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              const Divider(height: 32),

              // ─── البيانات الأساسية ────────────────────────────────────
              _buildField('اسم المتجر *', _nameCtrl, Icons.store_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: effectiveCategory,
                decoration: const InputDecoration(
                    labelText: 'التصنيف *',
                    prefixIcon: Icon(Icons.category_outlined)),
                items: catNames
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),

              _buildField('رقم الهاتف *', _phoneCtrl, Icons.phone_outlined,
                  type: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'رقم غير صحيح'
                      : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_approvedRegions.join(',')),
                initialValue:
                    _approvedRegions.contains(_locationCtrl.text.trim())
                        ? _locationCtrl.text.trim()
                        : null,
                decoration: const InputDecoration(
                  labelText: 'اختر المنطقة المعتمدة',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: _approvedRegions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _locationCtrl.text = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildField('العنوان / المنطقة', _locationCtrl,
                  Icons.location_on_outlined),
              const SizedBox(height: 12),
              _buildField(
                  'الوصف', _descCtrl, Icons.description_outlined,
                  maxLines: 3),
              const SizedBox(height: 12),
              _buildField(
                  'مواعيد العمل', _hoursCtrl, Icons.access_time_outlined),
              const SizedBox(height: 16),

              const Text('روابط التواصل الاجتماعي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              _buildField('واتساب', _whatsappCtrl, FontAwesomeIcons.whatsapp,
                  type: TextInputType.phone, isFa: true),
              const SizedBox(height: 12),
              _buildField('فيسبوك', _facebookCtrl, FontAwesomeIcons.facebook,
                  type: TextInputType.url, isFa: true),
              const SizedBox(height: 12),
              _buildField(
                  'انستجرام', _instagramCtrl, FontAwesomeIcons.instagram,
                  type: TextInputType.url, isFa: true),
              const SizedBox(height: 12),
              _buildField('تيك توك', _tiktokCtrl, FontAwesomeIcons.tiktok,
                  type: TextInputType.url, isFa: true),
              const SizedBox(height: 12),
              _buildField(
                  'تيليجرام', _telegramCtrl, FontAwesomeIcons.telegram,
                  type: TextInputType.url, isFa: true),
              if (context.watch<AuthProvider>().userRole == UserRole.admin) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('تعيين / تغيير مالك المحل (خاص بالأدمن)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ownerTargetCtrl,
                  decoration: InputDecoration(
                    labelText:
                        'رقم هاتف أو يوزر المالك (أو اكتب "بدون" لإلغاء المالك)',
                    helperText: widget.shop.ownerId.isEmpty
                        ? (widget.shop.pendingOwnerPhone != null
                            ? 'منتظر تسجيل الرقم: ${widget.shop.pendingOwnerPhone}'
                            : 'المحل حالياً بدون مالك')
                        : 'معرّف المالك الحالي: ${widget.shop.ownerId}',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.manage_accounts_outlined,
                        color: Color(0xFF3D6B5E)),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('حفظ التعديلات',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay(double progress) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
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

  Widget _buildField(String label, TextEditingController ctrl, Object icon,
      {TextInputType? type,
      int maxLines = 1,
      FormFieldValidator<String>? validator,
      bool isFa = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: (isFa && icon is FaIconData)
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: FaIcon(icon, size: 18))
            : Icon(icon as IconData),
      ),
      validator: validator,
    );
  }
}
