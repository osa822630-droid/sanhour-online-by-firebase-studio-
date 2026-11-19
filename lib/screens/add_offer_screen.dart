// lib/screens/add_offer_screen.dart
// ✅ نظام صور متعدد باستخدام MultiImagePickerWidget
// ✅ coverImageIndex + newPrice + bundleDetails + giftDescription + دعم تكرار العرض
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/offer.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/image_helper.dart';
import '../widgets/multi_image_picker_widget.dart';
import '../services/media_upload_service.dart';

class AddOfferScreen extends StatefulWidget {
  final String shopId;
  final String? ownerId;
  final Offer? offerToEdit;

  const AddOfferScreen({
    super.key,
    required this.shopId,
    this.ownerId,
    this.offerToEdit,
  });

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  String _offerType = 'generic';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _newPriceCtrl = TextEditingController();
  final _bundleDetailsCtrl = TextEditingController();
  final _giftDescCtrl = TextEditingController();

  Product? _selectedProduct;
  List<Product> _products = [];
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  // ✅ حالة الصور المتعددة
  List<String> _existingUrls = [];
  List<File> _newImageFiles = [];
  int _coverImageIndex = 0;

  final Map<int, double> _imageProgress = {};

  double get _overallImageProgress {
    if (_newImageFiles.isEmpty) return 0;
    double sum = 0;
    for (int i = 0; i < _newImageFiles.length; i++) {
      sum += _imageProgress[i] ?? 0;
    }
    return sum / _newImageFiles.length;
  }

  // ✅ التعديل الحقيقي يشترط وجود معرّف غير فارغ، بينما تكرار العرض يمرر id فارغاً
  bool get _isEditing =>
      widget.offerToEdit != null && widget.offerToEdit!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.offerToEdit != null) {
      final offer = widget.offerToEdit!;
      _offerType = offer.type;
      _titleCtrl.text = offer.title;
      _descCtrl.text = offer.description;
      _discountCtrl.text = offer.discount.toString();
      if (offer.newPrice != null && offer.newPrice! > 0) {
        _newPriceCtrl.text = offer.newPrice!.toStringAsFixed(0);
      }
      if (offer.bundleDetails != null) {
        _bundleDetailsCtrl.text = offer.bundleDetails!;
      }
      if (offer.giftDescription != null) {
        _giftDescCtrl.text = offer.giftDescription!;
      }
      _expiryDate = offer.validUntil;
      _existingUrls = List.from(offer.imageUrls);
      _coverImageIndex = offer.coverImageIndex;
    } else {
      final d = DateTime.now().add(const Duration(days: 7));
      _expiryDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _newPriceCtrl.dispose();
    _bundleDetailsCtrl.dispose();
    _giftDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final list = await ApiService.getProducts(shopId: widget.shopId);
    Product? foundProduct;
    if (widget.offerToEdit?.productId != null) {
      try {
        foundProduct =
            list.firstWhere((p) => p.id == widget.offerToEdit!.productId);
      } catch (_) {
        foundProduct = null;
      }
    }
    if (mounted) {
      setState(() {
        _products = list;
        _selectedProduct = foundProduct;
      });
    }
  }

  // ── تقديم العرض ──────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('يرجى إدخال عنوان العرض', Colors.red);
      return;
    }
    final totalImages = _existingUrls.length + _newImageFiles.length;
    if (totalImages == 0) {
      _snack('يرجى إضافة صورة واحدة على الأقل', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _imageProgress.clear();
    });
    try {
      final discountVal = int.tryParse(_discountCtrl.text.trim()) ?? 0;
      if (_offerType == 'discount' &&
          (discountVal < 0 || discountVal > 100)) {
        setState(() => _isLoading = false);
        _snack('نسبة الخصم يجب أن تكون بين 0 و 100', Colors.red);
        return;
      }

      final data = <String, dynamic>{
        'shopId': widget.shopId,
        'ownerId': widget.ownerId ?? '',
        'type': _offerType,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'discount': discountVal,
        'validUntil': Timestamp.fromDate(DateTime(_expiryDate.year,
            _expiryDate.month, _expiryDate.day, 23, 59, 59)),
        'isActive': true,
        'isVisible': true,
        'productId': _selectedProduct?.id,
        'existingImages': _existingUrls,
        'bundleDetails': _bundleDetailsCtrl.text.trim().isNotEmpty
            ? _bundleDetailsCtrl.text.trim()
            : null,
        'giftDescription': _giftDescCtrl.text.trim().isNotEmpty
            ? _giftDescCtrl.text.trim()
            : null,
      };

      if (_offerType == 'price_drop' &&
          _newPriceCtrl.text.trim().isNotEmpty) {
        data['newPrice'] = double.tryParse(_newPriceCtrl.text.trim()) ?? 0;
        data['oldPrice'] = _selectedProduct?.price ??
            widget.offerToEdit?.oldPrice ??
            0;
      }

      void onProgress(int fileIndex, double fraction) {
        if (!mounted) return;
        setState(() => _imageProgress[fileIndex] = fraction);
      }

      if (_isEditing) {
        await ApiService.updateOffer(
          widget.offerToEdit!.id,
          data,
          _newImageFiles,
          coverIndex: _coverImageIndex,
          onImageProgress: onProgress,
        );
      } else {
        await ApiService.addOffer(
          data,
          _newImageFiles,
          coverIndex: _coverImageIndex,
          onImageProgress: onProgress,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? '✅ تم تحديث العرض' : '✅ تم نشر العرض'),
        backgroundColor: Colors.green,
      ));
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is MediaUploadException
          ? e.userMessage
          : 'حدث خطأ، يُرجى المحاولة مرة أخرى';
      _snack(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل العرض' : 'إضافة عرض جديد'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('نوع العرض:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              _typeChip('generic', 'عرض عام', Icons.campaign, isDark),
              _typeChip('discount', 'خصم ٪', Icons.percent, isDark),
              _typeChip('price_drop', 'حرق سعر', Icons.trending_down, isDark),
              _typeChip('bundle', 'تجميعة', Icons.inventory_2, isDark),
            ]),
            const Divider(height: 30),

            if (_offerType == 'discount' || _offerType == 'price_drop') ...[
              DropdownButtonFormField<Product>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(
                    labelText: 'اختر المنتج', border: OutlineInputBorder()),
                items: _products
                    .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProduct = val;
                    if (val != null) {
                      _titleCtrl.text = _offerType == 'price_drop'
                          ? 'تخفيض على ${val.name}'
                          : 'خصم على ${val.name}';
                      _descCtrl.text = _offerType == 'price_drop'
                          ? 'كان بـ ${val.price.toStringAsFixed(0)} جنيه'
                          : '';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_offerType == 'price_drop') ...[
              TextFormField(
                controller: _newPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'السعر الجديد بعد التخفيض',
                    border: OutlineInputBorder(),
                    suffixText: 'ج.م'),
                onChanged: (v) {
                  if (_selectedProduct != null && v.isNotEmpty) {
                    final newP = double.tryParse(v) ?? 0;
                    final oldP = _selectedProduct!.price;
                    if (oldP > 0) {
                      final pct =
                          ((oldP - newP) / oldP * 100).clamp(0.0, 100.0);
                      _discountCtrl.text = pct.toStringAsFixed(0);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_offerType != 'price_drop') ...[
              TextFormField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'نسبة الخصم',
                    border: OutlineInputBorder(),
                    suffixText: '٪'),
              ),
              const SizedBox(height: 16),
            ],

            if (_offerType == 'bundle') ...[
              TextFormField(
                controller: _bundleDetailsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'مكونات التجميعة / الباقة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined)),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _giftDescCtrl,
              decoration: const InputDecoration(
                  labelText: 'هدية إضافية مع العرض (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard_outlined)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'عنوان العرض *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'تفاصيل العرض', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: _expiryDate.isBefore(DateTime.now())
                      ? DateTime.now()
                      : _expiryDate,
                );
                if (picked != null && mounted) {
                  setState(() => _expiryDate = DateTime(
                      picked.year, picked.month, picked.day, 23, 59, 59));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark ? Colors.grey[600]! : Colors.grey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Text('تاريخ انتهاء العرض:'),
                    const Spacer(),
                    Text(
                      '${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            MultiImagePickerWidget(
              initialUrls: _existingUrls,
              initialFiles: _newImageFiles,
              initialCoverIndex: _coverImageIndex,
              ratio: ImageRatio.square,
              maxImages: 6,
              label: 'صور العرض',
              uploadProgress: _isLoading ? _imageProgress : null,
              isUploading: _isLoading,
              onChanged: (state) {
                _existingUrls = List.from(state.existingUrls);
                _newImageFiles = List.from(state.newFiles);
                _coverImageIndex = state.coverIndex;
              },
            ),

            const SizedBox(height: 16),

            if (_isLoading && _newImageFiles.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _overallImageProgress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'جارٍ رفع الصور... ${(_overallImageProgress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 14),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _isLoading
                        ? 'جارٍ الحفظ...'
                        : (_isEditing ? 'حفظ التعديلات' : 'نشر العرض'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submit,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon, bool isDark) {
    final selected = _offerType == type;
    final unselectedColor = isDark ? Colors.white70 : Colors.black87;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: selected ? Colors.white : unselectedColor),
        const SizedBox(width: 4),
        Text(label),
      ]),
      selected: selected,
      onSelected: (_) => setState(() => _offerType = type),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : unselectedColor),
    );
  }
}
