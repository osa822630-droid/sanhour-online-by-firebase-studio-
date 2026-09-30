// lib/screens/add_product_screen.dart
// ✅ نظام صور متعدد باستخدام MultiImagePickerWidget مع اختيار صورة الغلاف
// ✅ coverImageIndex مُحفوظ ومُمرَّر للـ ProductService
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../utils/image_helper.dart';
import '../widgets/multi_image_picker_widget.dart';
import '../services/media_upload_service.dart';

class AddProductScreen extends StatefulWidget {
  final String shopId;
  final String shopCategory;
  final Product? productToEdit;

  const AddProductScreen({
    super.key,
    required this.shopId,
    required this.shopCategory,
    this.productToEdit,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();

  final List<String> _colors = [];
  final List<String> _sizes = [];
  String _selectedCategory = '';
  bool _isLoading = false;

  // ✅ حالة الصور المتعددة
  List<String> _existingUrls = [];
  List<File> _newImageFiles = [];
  int _coverImageIndex = 0;

  // ✅ نظام تقدم الرفع — المفتاح index ضمن _newImageFiles
  final Map<int, double> _imageProgress = {};

  /// المتوسط الإجمالي لتقدم رفع كل الصور الجديدة (0.0–1.0)
  double get _overallImageProgress {
    if (_newImageFiles.isEmpty) return 0;
    double sum = 0;
    for (int i = 0; i < _newImageFiles.length; i++) {
      sum += _imageProgress[i] ?? 0;
    }
    return sum / _newImageFiles.length;
  }

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.shopCategory;
    if (_isEditing) {
      final p = widget.productToEdit!;
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toStringAsFixed(0);
      _oldPriceCtrl.text =
          p.oldPrice > 0 ? p.oldPrice.toStringAsFixed(0) : '';
      _descCtrl.text = p.description;
      _existingUrls = List.from(p.imageUrls);
      // ✅ coverImageIndex = 0 دائماً عند التعديل لأن الـ service يضع الغلاف أولاً
      _coverImageIndex = 0;
      _colors.addAll(p.colors);
      _sizes.addAll(p.sizes);
      _selectedCategory = p.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _oldPriceCtrl.dispose();
    _descCtrl.dispose();
    _colorCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final scaffoldMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_existingUrls.isEmpty && _newImageFiles.isEmpty) {
      scaffoldMsg.showSnackBar(const SnackBar(
        content: Text('يرجى إضافة صورة واحدة على الأقل'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() {
      _isLoading = true;
      _imageProgress.clear();
    });

    try {
      final price = double.parse(_priceCtrl.text.trim());
      final oldPrice = double.tryParse(_oldPriceCtrl.text.trim()) ?? 0.0;
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'price': price,
        'oldPrice': oldPrice,
        'hasPriceDrop': oldPrice > price && oldPrice > 0,
        'hasDiscount': oldPrice > price && oldPrice > 0,
        'discountPercentage': (oldPrice > price && oldPrice > 0)
            ? double.parse(
                ((1 - price / oldPrice) * 100).toStringAsFixed(1))
            : 0.0,
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory,
        'colors': _colors,
        'sizes': _sizes,
        'shopId': widget.shopId,
        // ✅ تمرير الصور الموجودة والـ coverIndex للـ service
        'existingImages': _existingUrls,
        'coverImageIndex': _coverImageIndex,
      };

      // ✅ نظام تقدم الرفع — يُحدِّث الواجهة مباشرةً مع كل دفعة بايتات
      void onProgress(int fileIndex, double fraction) {
        if (!mounted) return;
        setState(() => _imageProgress[fileIndex] = fraction);
      }

      if (_isEditing) {
        await ApiService.updateProduct(
          widget.productToEdit!.id,
          data,
          _newImageFiles.isEmpty ? null : _newImageFiles,
          onImageProgress: onProgress,
        );
      } else {
        await ApiService.addProduct(data, _newImageFiles,
            onImageProgress: onProgress);
      }

      if (!mounted) return;
      context
          .read<ShopsProvider>()
          .fetchProducts(shopId: widget.shopId, refresh: true);
      scaffoldMsg.showSnackBar(SnackBar(
        content: Text(_isEditing ? '✅ تم تعديل المنتج' : '✅ تم إضافة المنتج'),
        backgroundColor: Colors.green,
      ));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      // ✅ MediaUploadException يحمل رسالة عربية جاهزة للعرض مباشرة
      final msg = e is MediaUploadException
          ? e.userMessage
          : 'فشل الحفظ، تحقق من البيانات وحاول مجدداً';
      scaffoldMsg.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ShopsProvider>().categories;
    final catNames = categories.isNotEmpty
        ? categories.map((c) => c.name).toList()
        : ['عام', 'مأكولات', 'مشروبات', 'ملابس', 'أجهزة', 'أخرى'];
    if (!catNames.contains(_selectedCategory) && catNames.isNotEmpty) {
      _selectedCategory = catNames.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        // ✅ validation تظهر أثناء الكتابة لا عند الإرسال فقط
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── ✅ صور متعددة مع اختيار الغلاف ──────────────
              MultiImagePickerWidget(
                initialUrls: _existingUrls,
                initialFiles: _newImageFiles,
                initialCoverIndex: _coverImageIndex,
                ratio: ImageRatio.square,
                maxImages: 6,
                label: 'صور المنتج *',
                // ✅ تقدم رفع كل صورة + قفل التفاعل أثناء الحفظ
                uploadProgress: _isLoading ? _imageProgress : null,
                isUploading: _isLoading,
                onChanged: (state) {
                  _existingUrls = List.from(state.existingUrls);
                  _newImageFiles = List.from(state.newFiles);
                  _coverImageIndex = state.coverIndex;
                },
              ),
              const SizedBox(height: 20),

              // ─── البيانات الأساسية ───────────────────────────
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'السعر * (ج.م)',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'مطلوب';
                      if (double.tryParse(v.trim()) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _oldPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر قديم (اختياري)',
                      prefixIcon: Icon(Icons.price_change_outlined),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: catNames.contains(_selectedCategory)
                    ? _selectedCategory
                    : catNames.first,
                decoration: const InputDecoration(
                  labelText: 'القسم',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: catNames
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // ─── الألوان والمقاسات ──────────────────────────
              _buildChipInput(
                'الألوان (مثال: أحمر، أزرق)',
                _colorCtrl,
                _colors,
                Icons.color_lens_outlined,
              ),
              const SizedBox(height: 12),
              _buildChipInput(
                'المقاسات (مثال: S, M, L)',
                _sizeCtrl,
                _sizes,
                Icons.straighten_outlined,
              ),
              const SizedBox(height: 28),

              // ✅ شريط تقدم رفع الصور — يظهر فقط عند وجود صور جديدة قيد الرفع
              if (_isLoading && _newImageFiles.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _overallImageProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF5E35B1),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'جارٍ رفع الصور... ${(_overallImageProgress * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5E35B1),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],

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
                  label: Text(
                    _isLoading
                        ? 'جارٍ الحفظ...'
                        : (_isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipInput(
    String label,
    TextEditingController ctrl,
    List<String> list,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFF5E35B1)),
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.isNotEmpty && !list.contains(v)) {
                  setState(() {
                    list.add(v);
                    ctrl.clear();
                  });
                }
              },
            ),
          ),
          onFieldSubmitted: (v) {
            if (v.trim().isNotEmpty && !list.contains(v.trim())) {
              setState(() {
                list.add(v.trim());
                ctrl.clear();
              });
            }
          },
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: list
                .map((item) => Chip(
                      label: Text(item,
                          style: const TextStyle(fontSize: 12)),
                      deleteIcon:
                          const Icon(Icons.close, size: 14),
                      backgroundColor: const Color(0xFF5E35B1)
                          .withValues(alpha: 0.1),
                      side: BorderSide(
                          color: const Color(0xFF5E35B1)
                              .withValues(alpha: 0.3)),
                      onDeleted: () =>
                          setState(() => list.remove(item)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
