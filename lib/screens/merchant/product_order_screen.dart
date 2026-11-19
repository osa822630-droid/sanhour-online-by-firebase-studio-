// lib/screens/merchant/product_order_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../utils/logger.dart';

class ProductOrderScreen extends StatefulWidget {
  final Shop shop;
  const ProductOrderScreen({super.key, required this.shop});

  @override
  State<ProductOrderScreen> createState() => _ProductOrderScreenState();
}

class _ProductOrderScreenState extends State<ProductOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Product> _allProducts = [];
  List<Product> _pinnedProducts = [];
  List<Product> _restProducts = [];
  List<String> _productLists = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('shopId', isEqualTo: widget.shop.id)
          .where('isVisible', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      final products = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return Product.fromMap(data, d.id);
      }).toList();

      // ✅ توحيد معيار المنتجات المثبتة (< 999) والمنتجات غير المثبتة (>= 999 أو <= 0)
      final pinned = products
          .where((p) => p.sortOrder > 0 && p.sortOrder < 999)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final rest = products
          .where((p) => p.sortOrder <= 0 || p.sortOrder >= 999)
          .toList();

      final existingLists = products
          .map((p) => p.listName.trim())
          .where((l) => l.isNotEmpty)
          .toSet();
      existingLists.addAll(_productLists);
      final sortedLists = existingLists.toList()..sort();

      if (mounted) {
        setState(() {
          _allProducts = products;
          _pinnedProducts = pinned;
          _restProducts = rest;
          _productLists = sortedLists;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('loadProducts error', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _isSaving = true);
    try {
      final allOps = <MapEntry<DocumentReference, int>>[];
      for (int i = 0; i < _pinnedProducts.length; i++) {
        allOps.add(MapEntry(
          FirebaseFirestore.instance
              .collection('products')
              .doc(_pinnedProducts[i].id),
          i + 1,
        ));
      }
      for (final p in _restProducts) {
        allOps.add(MapEntry(
          FirebaseFirestore.instance.collection('products').doc(p.id),
          999,
        ));
      }

      for (int i = 0; i < allOps.length; i += 450) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = allOps.sublist(i, (i + 450).clamp(0, allOps.length));
        for (final entry in chunk) {
          batch.update(entry.key, {'sortOrder': entry.value});
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم حفظ ترتيب المنتجات'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، حاول مجدداً'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveListName(Product p, String listName) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(p.id)
        .update({'listName': listName.trim()});
    await _loadProducts();
  }

  void _pin(Product p) {
    if (_pinnedProducts.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الحد الأقصى 10 منتجات مميزة')));
      return;
    }
    setState(() {
      _restProducts.remove(p);
      _pinnedProducts.add(p);
    });
  }

  void _unpin(Product p) {
    setState(() {
      _pinnedProducts.remove(p);
      _restProducts.insert(0, p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ترتيب المنتجات'),
        backgroundColor: const Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _saveOrder,
              icon: const Icon(Icons.save, color: Colors.white),
              label:
                  const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'ترتيب أول 10'),
            Tab(text: 'تقسيم لقوائم'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildOrderTab(), _buildListsTab()],
            ),
    );
  }

  Widget _buildOrderTab() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF3D6B5E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF3D6B5E).withValues(alpha: 0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFF3D6B5E), size: 18),
          SizedBox(width: 8),
          Expanded(
              child: Text(
            'اسحب المنتجات لترتيبها. أول 10 تظهر مثبتة في مقدمة صفحتك.',
            style: TextStyle(fontSize: 13, color: Color(0xFF3D6B5E)),
          )),
        ]),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          const Icon(Icons.push_pin, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Text('المنتجات المميزة (${_pinnedProducts.length}/10)',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
      if (_pinnedProducts.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('اضغط + بجانب أي منتج لإضافته',
              style: TextStyle(color: Colors.grey[500])),
        )
      else
        SizedBox(
          height: 260,
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _pinnedProducts.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _pinnedProducts.removeAt(oldIndex);
                _pinnedProducts.insert(newIndex, item);
              });
            },
            itemBuilder: (_, i) {
              final p = _pinnedProducts[i];
              return ListTile(
                key: ValueKey(p.id),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF3D6B5E),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(p.name, style: const TextStyle(fontSize: 14)),
                subtitle:
                    Text('${p.price} ج', style: const TextStyle(fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _unpin(p),
                  ),
                ]),
              );
            },
          ),
        ),

      const Divider(),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          const Icon(Icons.list_alt, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text('بقية المنتجات (${_restProducts.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _restProducts.length,
          itemBuilder: (_, i) {
            final p = _restProducts[i];
            return ListTile(
              leading:
                  const Icon(Icons.inventory_2_outlined, color: Colors.grey),
              title: Text(p.name, style: const TextStyle(fontSize: 14)),
              subtitle:
                  Text('${p.price} ج', style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF3D6B5E)),
                onPressed: () => _pin(p),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildListsTab() {
    final groups = <String, List<Product>>{};
    for (final p in _allProducts) {
      final lName = p.listName.trim();
      final key = lName.isEmpty ? 'بدون قائمة' : lName;
      groups.putIfAbsent(key, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading:
                const Icon(Icons.add_box_outlined, color: Color(0xFF3D6B5E)),
            title: const Text('إنشاء قائمة جديدة'),
            onTap: _showNewListDialog,
          ),
        ),
        const SizedBox(height: 8),
        ...groups.entries
            .map((entry) => _buildGroupCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildGroupCard(String listName, List<Product> products) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3D6B5E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(listName,
                style: const TextStyle(
                    color: Color(0xFF3D6B5E), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text('${products.length} منتج',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ]),
        children: products
            .map((p) => ListTile(
                  dense: true,
                  title: Text(p.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('${p.price} ج',
                      style: const TextStyle(fontSize: 11)),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) => _showMoveToListDialog(p, val),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'move', child: Text('نقل لقائمة أخرى')),
                      const PopupMenuItem(
                          value: 'remove', child: Text('إزالة من القائمة')),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showNewListDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم القائمة الجديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'مثال: وجبات رئيسية', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D6B5E)),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (!_productLists.contains(name)) {
                    _productLists.add(name);
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم إنشاء قائمة "$name"')));
              }
            },
            child:
                const Text('إنشاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  void _showMoveToListDialog(Product p, String action) {
    if (action == 'remove') {
      _saveListName(p, '');
      return;
    }
    final lists = ['بدون قائمة', ..._productLists];
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('نقل "${p.name}" إلى'),
        children: lists
            .map((l) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveListName(p, l == 'بدون قائمة' ? '' : l);
                  },
                  child: Text(l),
                ))
            .toList(),
      ),
    );
  }
}