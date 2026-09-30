// lib/screens/tabs/admin_categories_tab.dart
// ✅ إصلاح التجميد: نقل TextEditingController خارج map() ومنع overflow
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/category_model.dart';

class AdminCategoriesTab extends StatefulWidget {
  const AdminCategoriesTab({super.key});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab> {
  bool _isLoading = true;
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cats = await ApiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E1A) : Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEditDialog,
        label: const Text('فئة جديدة'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.deepPurple[900],
        foregroundColor: Colors.white,
      ),
      body: _categories.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _categories.length,
                itemBuilder: (_, i) => _buildCategoryCard(_categories[i]),
              ),
            ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(cat.colorValue).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(CategoryModel.getIconData(cat.iconName),
              color: Color(cat.colorValue)),
        ),
        title: Text(cat.name,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
            '${cat.subCategories.length} قسم فرعي — ${cat.subSubCategories.values.fold<int>(0, (s, l) => s + l.length)} فرعي دقيق'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              tooltip: 'تعديل',
              onPressed: () => _showAddEditDialog(category: cat),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف',
              onPressed: () => _confirmDelete(cat),
            ),
          ],
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (cat.subCategories.isEmpty)
            const Text('لا يوجد أقسام فرعية',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cat.subCategories.map((sub) {
                final subSubs = cat.subSubCategories[sub] ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 16,
                            color: Color(cat.colorValue)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(sub,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ]),
                      if (subSubs.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: subSubs
                              .map((ss) => Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors
                                              .grey.shade300),
                                      borderRadius:
                                          BorderRadius.circular(
                                              6),
                                    ),
                                    child: Text(ss,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
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
          const Text('لا توجد فئات حالياً',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddEditDialog,
            icon: const Icon(Icons.add),
            label: const Text('أضف فئة'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[900],
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── ديالوج الإضافة/التعديل ─────────────────────────────────────────────────
  // ✅ الإصلاح الجوهري: استخدام Navigator.push لشاشة مستقلة بدلاً من AlertDialog
  // يمنع overflow ومشكلة TextEditingController داخل map()
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
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

// ══════════════════════════════════════════════════════════════════════════════
// شاشة تعديل/إضافة الفئة (fullscreen) — لا overflow، لا تجميد
// ══════════════════════════════════════════════════════════════════════════════
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
  // ✅ الإصلاح: مفتاح ثابت لكل subSub controller بدلاً من إنشائه داخل build()
  final Map<String, TextEditingController> _subSubCtrls = {};

  String _iconName = 'category';
  Color _selectedColor = Colors.blue;
  List<String> _subCategories = [];
  final Map<String, List<String>> _subSubCategories = {};
  bool _isSaving = false;

  final List<Color> _colors = [
    Colors.blue, const Color(0xFFE53935), Colors.green,
    Colors.deepOrange, Colors.purple, Colors.teal,
    Colors.brown, Colors.pink, Colors.indigo,
    Colors.cyan, Colors.amber, const Color(0xFF5E35B1),
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
    // ✅ إنشاء controller واحد لكل sub فرعي عند التهيئة
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
      _subSubCtrls[name] = TextEditingController(); // ✅ مرة واحدة فقط
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم الفئة مطلوب')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final newCat = CategoryModel(
        id: widget.category?.id ?? '',
        name: _nameCtrl.text.trim(),
        iconName: _iconName,
        colorValue: _selectedColor.toARGB32(),
        subCategories: _subCategories,
        subSubCategories: _subSubCategories,
      );

      if (widget.category == null) {
        await ApiService.addCategory(newCat);
      } else {
        await ApiService.updateCategory(newCat);
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
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(
          isNew ? 'إضافة فئة جديدة' : 'تعديل "${widget.category!.name}"',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.deepPurple[900],
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
          // ── اسم الفئة ──────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم الفئة الرئيسية *',
              prefixIcon: Icon(Icons.label),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          // ── اختيار الأيقونة ──────────────────────────────────────
          const Text('الأيقونة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
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
                            ? Border.all(
                                color: _selectedColor, width: 2)
                            : null,
                      ),
                      child: Icon(
                        CategoryModel.getIconData(item['name']!),
                        color: selected ? Colors.white : Colors.grey[600],
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── اختيار اللون ─────────────────────────────────────────
          const Text('اللون:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _colors.map((c) {
                final isSelected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
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

          // معاينة النتيجة
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ]),

          const SizedBox(height: 24),
          const Divider(),

          // ── الأقسام الفرعية ──────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  color: Color(0xFF5E35B1)),
              const SizedBox(width: 8),
              const Text(
                'الأقسام الفرعية (Sub Categories)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
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
                // ✅ كل controller مُنشأ مسبقاً في initState / _addSubCat
                final ctrl = _subSubCtrls[sub] ??
                    (_subSubCtrls[sub] = TextEditingController());
                final subSubs = _subSubCategories[sub] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: ValueKey(sub),
                      title: Text(sub,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
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
                        // إضافة فرعي دقيق
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addSubSub(sub),
                              decoration: InputDecoration(
                                hintText: 'فرعي دقيق (مثال: شيرت)',
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.blue),
                            onPressed: () => _addSubSub(sub),
                          ),
                        ]),
                        if (subSubs.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: subSubs
                                  .map((ss) => InputChip(
                                        label: Text(ss,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        visualDensity:
                                            VisualDensity.compact,
                                        deleteIcon: const Icon(
                                            Icons.close,
                                            size: 14),
                                        onDeleted: () =>
                                            _removeSubSub(sub, ss),
                                        backgroundColor:
                                            _selectedColor.withValues(
                                                alpha: 0.1),
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
