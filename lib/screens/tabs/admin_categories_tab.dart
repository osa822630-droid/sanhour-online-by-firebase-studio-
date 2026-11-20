// lib/screens/tabs/admin_categories_tab.dart
// ✅ مزامنة الكاش في ShopsProvider بعد الإضافة أو التعديل أو الحذف
// ✅ تحديث اسم الفئة تلقائياً في المحلات والمنتجات المرتبطة عند تغيير اسم الفئة الرئيسية
// ✅ دعم الوضع الليلي (Dark Mode) بالكامل
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/shops_provider.dart';
import '../../services/api_service.dart';

class AdminCategoriesTab extends StatefulWidget {
  const AdminCategoriesTab({super.key});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final list = await ApiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
        // ✅ تحديث الكاش المشترك في ShopsProvider ليظهر التعديل فوراً في الرئيسية
        context.read<ShopsProvider>().fetchCategories(refresh: true);
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'تعذّر تحميل الفئات. اضغط لإعادة المحاولة.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121514) : Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: const Text('فئة جديدة'),
        icon: const Icon(Icons.add),
        backgroundColor: Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: GestureDetector(
                    onTap: _loadCategories,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMsg!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                )
              : _categories.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: ListView.builder(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 80),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          return _buildCategoryCard(cat, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat, bool isDark) {
    final color = Color(cat.colorValue);
    int totalSubSubs = 0;
    for (final list in cat.subSubCategories.values) {
      totalSubSubs += list.length;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF1B201E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CategoryModel.getIconData(cat.iconName),
              color: color,
              size: 24,
            ),
          ),
          title: Text(
            cat.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            '${cat.subCategories.length} قسم فرعي • $totalSubSubs تصنيف دقيق',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.blue, size: 20),
                tooltip: 'تعديل الفئة',
                onPressed: () => _showAddEditDialog(category: cat),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                tooltip: 'حذف الفئة',
                onPressed: () => _confirmDelete(cat),
              ),
            ],
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (cat.subCategories.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('لا توجد أقسام فرعية',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cat.subCategories.map((sub) {
                    final subSubs = cat.subSubCategories[sub] ?? [];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sub,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontSize: 12),
                          ),
                          if (subSubs.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subSubs.join('، '),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا توجد فئات مضافة بعد',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول فئة'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3D6B5E),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({CategoryModel? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryEditScreen(
          category: category,
          onSaved: _loadCategories,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _confirmDelete(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفئة؟'),
        content: Text(
            'سيتم حذف "${cat.name}" وجميع أقسامها الفرعية نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteCategory(cat.id);
              if (!mounted) return;
              _loadCategories();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditScreen extends StatefulWidget {
  final CategoryModel? category;
  final VoidCallback onSaved;

  const _CategoryEditScreen({this.category, required this.onSaved});

  @override
  State<_CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<_CategoryEditScreen> {
  final _nameCtrl = TextEditingController();
  final _subCatCtrl = TextEditingController();
  final Map<String, TextEditingController> _subSubCtrls = {};

  String _iconName = 'category';
  Color _selectedColor = Colors.blue;
  List<String> _subCategories = [];
  final Map<String, List<String>> _subSubCategories = {};
  bool _isSaving = false;

  final List<Color> _colors = [
    Colors.blue,
    const Color(0xFFE53935),
    Colors.green,
    Colors.deepOrange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.amber,
    const Color(0xFF3D6B5E),
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    if (cat != null) {
      _nameCtrl.text = cat.name;
      _iconName = cat.iconName;
      _selectedColor = Color(cat.colorValue);
      _subCategories = List.from(cat.subCategories);
      cat.subSubCategories.forEach((k, v) {
        _subSubCategories[k] = List.from(v);
      });
    }
    for (final sub in _subCategories) {
      _subSubCtrls[sub] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCatCtrl.dispose();
    for (final c in _subSubCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSubCat() {
    final name = _subCatCtrl.text.trim();
    if (name.isEmpty || _subCategories.contains(name)) return;
    setState(() {
      _subCategories.add(name);
      _subSubCategories[name] = [];
      _subSubCtrls[name] = TextEditingController();
      _subCatCtrl.clear();
    });
  }

  void _removeSubCat(String sub) {
    setState(() {
      _subCategories.remove(sub);
      _subSubCategories.remove(sub);
      _subSubCtrls[sub]?.dispose();
      _subSubCtrls.remove(sub);
    });
  }

  void _addSubSub(String parentSub) {
    final ctrl = _subSubCtrls[parentSub];
    if (ctrl == null || ctrl.text.trim().isEmpty) return;
    final name = ctrl.text.trim();
    if (_subSubCategories[parentSub]?.contains(name) == true) return;
    setState(() {
      _subSubCategories[parentSub] = [
        ...(_subSubCategories[parentSub] ?? []),
        name
      ];
      ctrl.clear();
    });
  }

  void _removeSubSub(String parent, String ss) {
    setState(() => _subSubCategories[parent]?.remove(ss));
  }

  Future<void> _cascadeCategoryRename(String oldName, String newName) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    final firestore = FirebaseFirestore.instance;
    for (final collectionName in const ['shops', 'products']) {
      final snap = await firestore
          .collection(collectionName)
          .where('category', isEqualTo: oldName)
          .get();
      if (snap.docs.isEmpty) continue;
      for (var i = 0; i < snap.docs.length; i += 400) {
        final chunk = snap.docs.skip(i).take(400);
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {'category': newName});
        }
        await batch.commit();
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم الفئة مطلوب')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final newName = _nameCtrl.text.trim();
      final newCat = CategoryModel(
        id: widget.category?.id ?? '',
        name: newName,
        iconName: _iconName,
        colorValue: _selectedColor.toARGB32(),
        subCategories: _subCategories,
        subSubCategories: _subSubCategories,
      );

      if (widget.category == null) {
        await ApiService.addCategory(newCat);
      } else {
        final oldName = widget.category!.name;
        await ApiService.updateCategory(newCat);
        if (oldName != newName) {
          await _cascadeCategoryRename(oldName, newName);
        }
      }

      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNew = widget.category == null;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121514) : const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: Text(
          isNew ? 'إضافة فئة جديدة' : 'تعديل "${widget.category!.name}"',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'اسم الفئة الرئيسية *',
              prefixIcon: Icon(Icons.label),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          const Text('الأيقونة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
                border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10)),
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: CategoryModel.iconList.length,
              itemBuilder: (_, i) {
                final item = CategoryModel.iconList[i];
                final selected = _iconName == item['name'];
                return GestureDetector(
                  onTap: () => setState(() => _iconName = item['name']!),
                  child: Tooltip(
                    message: item['label']!,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? _selectedColor
                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: _selectedColor, width: 2)
                            : null,
                      ),
                      child: Icon(
                        CategoryModel.getIconData(item['name']!),
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          const Text('اللون:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _colors.map((c) {
                final isSelected = _selectedColor.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 6)
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(CategoryModel.getIconData(_iconName),
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Text(
              _nameCtrl.text.isEmpty ? 'معاينة الفئة' : _nameCtrl.text,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ]),

          const SizedBox(height: 24),
          const Divider(),

          const Row(
            children: [
              Icon(Icons.account_tree_outlined, color: Color(0xFF3D6B5E)),
              SizedBox(width: 8),
              Text(
                'الأقسام الفرعية (Sub Categories)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _subCatCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSubCat(),
                decoration: const InputDecoration(
                  hintText: 'مثال: ملابس رجالي',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addSubCat,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Icon(Icons.add),
            ),
          ]),

          const SizedBox(height: 12),

          if (_subCategories.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text('لا يوجد أقسام فرعية بعد',
                    style: TextStyle(color: Colors.grey)),
              ]),
            )
          else
            Column(
              children: _subCategories.map((sub) {
                final ctrl = _subSubCtrls[sub] ??
                    (_subSubCtrls[sub] = TextEditingController());
                final subSubs = _subSubCategories[sub] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? const Color(0xFF1B201E) : Colors.white,
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: ValueKey(sub),
                      title: Text(sub,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${subSubs.length} فرعي دقيق',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        tooltip: 'حذف القسم',
                        onPressed: () => _removeSubCat(sub),
                      ),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addSubSub(sub),
                              decoration: InputDecoration(
                                hintText: 'فرعي دقيق (مثال: شيرت)',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'إضافة',
                            icon: const Icon(Icons.add_circle,
                                color: Colors.blue),
                            onPressed: () => _addSubSub(sub),
                          ),
                        ]),
                        if (subSubs.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: subSubs
                                  .map((ss) => InputChip(
                                        label: Text(ss,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                        deleteIcon: const Icon(Icons.close,
                                            size: 14),
                                        onDeleted: () =>
                                            _removeSubSub(sub, ss),
                                        backgroundColor: _selectedColor
                                            .withValues(alpha: 0.1),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
