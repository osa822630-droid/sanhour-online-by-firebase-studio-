// lib/screens/merchant/merchant_products_tab.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/shop.dart';
import '../../models/product.dart';
import '../../widgets/cached_image.dart';
import '../add_product_screen.dart';
import '../excel_upload_screen.dart';
import 'product_order_screen.dart';

class MerchantProductsTab extends StatefulWidget {
  final Shop currentShop;

  const MerchantProductsTab({super.key, required this.currentShop});

  @override
  State<MerchantProductsTab> createState() => _MerchantProductsTabState();
}

class _MerchantProductsTabState extends State<MerchantProductsTab> {
  bool _isSelectionMode = false;
  final Set<String> _selectedProductIds = {};
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  final TextEditingController _searchController = TextEditingController();

  // ✅ QA Fix #05: استبدال FutureBuilder بتحميل يدوي مرة واحدة فقط
  List<Product>? _allProducts;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await ApiService.getProducts(shopId: widget.currentShop.id);
      if (mounted) {
        setState(() { _allProducts = data; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذّر تحميل المنتجات. اضغط للمحاولة مجدداً.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar يظهر فقط في وضع التحديد
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('${_selectedProductIds.length} عنصر محدد'),
              backgroundColor: Colors.grey[800],
              leading: IconButton(
                  icon: const Icon(Icons.close), onPressed: _exitSelectionMode),
              actions: _buildSelectionActions(),
            )
          : null,

      body: Column(
        children: [
          // 1. قسم الأدوات العلوية (يظهر فقط خارج وضع التحديد)
          if (!_isSelectionMode) ...[
            _buildTopControls(),
            const Divider(height: 1),
          ],

          // 2. قائمة المنتجات
          Expanded(
            child: Builder(
              builder: (context) {
                // ✅ QA Fix #05: استخدام الـ state المُخزَّن محلياً
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadProducts,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                if (_allProducts == null) {
                  return const Center(child: Text('لا توجد بيانات'));
                }
                final filteredList = _applyFilters(_allProducts!);

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 50, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isEmpty
                              ? 'لم تضف منتجات بعد'
                              : 'لا توجد نتائج مطابقة',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.only(bottom: 80), // مسافة للزر العائم
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final product = filteredList[index];
                    return _buildProductItem(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  // شريط البحث وفلاتر الأقسام
  Widget _buildTopControls() {
    // استخراج الأقسام الموجودة فعلياً في المنتجات لتكوين الفلتر
    Set<String> categories = {'الكل'};
    if (_allProducts != null) {
      categories.addAll(_allProducts!.map((p) => p.category).toSet());
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 5),
      child: Column(
        children: [
          // صف البحث وزر الإكسل
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المنتج...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            })
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'رفع ملف إكسل',
                icon: const Icon(Icons.file_upload, color: Colors.green),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ExcelUploadScreen(shopId: widget.currentShop.id))),
              ),
              // ✅ زر ترتيب المنتجات
              IconButton(
                tooltip: 'ترتيب أول 10 منتجات',
                icon: const Icon(Icons.format_list_numbered,
                    color: Colors.deepOrange),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductOrderScreen(shop: widget.currentShop),
                )),
              ),
              // ✅ زر إدارة الخدمات
              IconButton(
                tooltip: 'إدارة الخدمات',
                icon: const Icon(Icons.miscellaneous_services, color: Color(0xFF5E35B1)),
                onPressed: () => _showServicesManager(),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // شريط الأقسام (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(
                          () => _selectedCategory = selected ? cat : 'الكل');
                    },
                    selectedColor: Color(0xFFEDE7F6),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.green[900] : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                          color:
                              isSelected ? Colors.green : Colors.grey.shade300),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // كارت المنتج الواحد
  Widget _buildProductItem(Product product) {
    final isSelected = _selectedProductIds.contains(product.id);
    // نفترض أن الموديل يحتوي على isVisible، لو مش موجود هيعتبره true
    final bool isVisible = (product.toMap()['isVisible'] ?? true);

    return Card(
      color: isSelected
          ? Colors.green[50]
          : (isVisible ? Colors.white : Colors.grey[100]),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedProductIds.add(product.id);
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedProductIds.remove(product.id);
                if (_selectedProductIds.isEmpty) _isSelectionMode = false;
              } else {
                _selectedProductIds.add(product.id);
              }
            });
          }
        },
        // الصورة (باهتة لو مخفي)
        leading: Opacity(
          opacity: isVisible ? 1.0 : 0.5,
          child: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                        if (_selectedProductIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      }
                    });
                  })
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedImage(
                    imageUrl: product.imageUrls.isNotEmpty
                        ? product.imageUrls.first
                        : '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
        ),

        // تفاصيل المنتج
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isVisible ? null : TextDecoration.lineThrough,
            color: isVisible ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text('${product.price} ج.م • ${product.category}'),

        // أزرار التحكم (تظهر فقط خارج وضع التحديد)
        trailing: !_isSelectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. زر الإخفاء/الإظهار (Toggle)
                  IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: isVisible ? Colors.green : Colors.grey,
                    ),
                    tooltip: isVisible ? 'إخفاء المنتج مؤقتاً' : 'إظهار المنتج',
                    onPressed: () =>
                        _toggleProductVisibility(product, !isVisible),
                  ),

                  // 2. زر التعديل
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddProductScreen(
                                    shopId: widget.currentShop.id,
                                    shopCategory: widget.currentShop.category,
                                    productToEdit: product,
                                  )));
                      setState(() {}); // تحديث عند العودة
                    },
                  ),
                ],
              )
            : null,
      ),
    );
  }

  // --- Logic ---

  // دالة الفلترة
  List<Product> _applyFilters(List<Product> products) {
    return products.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'الكل' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // تبديل حالة الظهور
  Future<void> _toggleProductVisibility(Product product, bool newStatus) async {
    // تحديث الواجهة فوراً (Optimistic UI)
    setState(() {
      // تحديث مؤقت في القائمة المحلية لحد ما السيرفر يرد
      // ملاحظة: هذا يتطلب أن يكون Product model قابل للتعديل أو نعيد تحميل البيانات
      // هنا سنعتمد على إعادة البناء عند انتهاء الطلب
    });

    try {
      await ApiService.updateProduct(
          product.id, {'isVisible': newStatus}, null);

      // إظهار رسالة صغيرة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(newStatus ? 'تم إظهار المنتج ✅' : 'تم إخفاء المنتج 🙈'),
            duration: const Duration(seconds: 1),
          ),
        );
        setState(() {}); // تحديث كامل للبيانات
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ، يُرجى المحاولة مرة أخرى'), backgroundColor: Colors.red));
      }
    }
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.drive_file_move_outline),
        tooltip: 'نقل لقسم آخر',
        onPressed: _showBulkMoveDialog,
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        tooltip: 'حذف المحدد',
        onPressed: _showBulkDeleteDialog,
      ),
    ];
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedProductIds.clear();
    });
  }

  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف ${_selectedProductIds.length} منتج'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.bulkDeleteProducts(_selectedProductIds.toList());
              _exitSelectionMode();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحذف بنجاح')));
              }
            },
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
  }

  void _showBulkMoveDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('نقل ${_selectedProductIds.length} منتج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اكتب اسم القسم الجديد (مثال: مشروبات، ملابس شتوية):'),
            const SizedBox(height: 10),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                hintText: 'اسم القسم',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (categoryController.text.isEmpty) return;
              Navigator.pop(ctx);
              await ApiService.bulkUpdateProductCategory(
                  _selectedProductIds.toList(), categoryController.text);
              _exitSelectionMode();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النقل بنجاح')));
              }
            },
            child: const Text('نقل'),
          ),
        ],
      ),
    );
  }

  void _showServicesManager() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20, left: 16, right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('إدارة الخدمات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الخدمة *',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف (اختياري)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر (اختياري)',
                    suffixText: 'ج', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.add),
                label: const Text('إضافة الخدمة'),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await ApiService.addService({
                    'shopId': widget.currentShop.id,
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('✅ تمت إضافة الخدمة'),
                          backgroundColor: Colors.green));
                },
              ),
            ),
          ]),
        );
      }),
    );
  }
}
