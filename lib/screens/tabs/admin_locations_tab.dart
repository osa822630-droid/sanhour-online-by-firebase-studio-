// lib/screens/tabs/admin_locations_tab.dart
// ✅ إدارة المناطق الجغرافية — إضافة وتعديل وحذف أسماء المناطق
// وتحديد ما إذا كان زر الموقع يظهر في الرئيسية
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLocationsTab extends StatefulWidget {
  const AdminLocationsTab({super.key});

  @override
  State<AdminLocationsTab> createState() => _AdminLocationsTabState();
}

class _AdminLocationsTabState extends State<AdminLocationsTab> {
  final _db = FirebaseFirestore.instance;
  final _addCtrl = TextEditingController();
  List<String> _regions = [];
  bool _showLocationFilter = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await _db.collection('settings').doc('general').get();
      final data = doc.data() ?? {};
      setState(() {
        _regions = List<String>.from(data['regions'] as List? ?? []);
        _showLocationFilter = data['showLocationFilter'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _db.collection('settings').doc('general').update({
        'regions': _regions,
        'showLocationFilter': _showLocationFilter,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addRegion() {
    final name = _addCtrl.text.trim();
    if (name.isEmpty || _regions.contains(name)) return;
    setState(() => _regions.add(name));
    _addCtrl.clear();
  }

  void _removeRegion(String r) {
    setState(() => _regions.remove(r));
  }

  Future<void> _editRegion(String old) async {
    final ctrl = TextEditingController(text: old);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم المنطقة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != old) {
      setState(() {
        final idx = _regions.indexOf(old);
        if (idx != -1) _regions[idx] = result;
      });
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── إعداد ظهور أيقونة الموقع ───────────────────────────
          _SectionHeader(
            icon: Icons.location_on,
            title: 'أيقونة الموقع في الرئيسية',
            subtitle:
                'تحكّم في ظهور زر تصفية المنطقة للمستخدمين',
          ),
          _cardWrap(isDark, [
            SwitchListTile(
              title: const Text('إظهار أيقونة الموقع 📍',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _showLocationFilter
                    ? 'الأيقونة ظاهرة في الرئيسية'
                    : 'الأيقونة مخفية حالياً',
                style: TextStyle(
                  color: _showLocationFilter ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
              value: _showLocationFilter,
              onChanged: (v) =>
                  setState(() => _showLocationFilter = v),
              activeColor: const Color(0xFF5E35B1),
            ),
          ]),

          const SizedBox(height: 24),

          // ── إدارة المناطق ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.map_outlined,
            title: 'المناطق والأحياء',
            subtitle:
                'هذه القائمة تظهر للتجار عند إضافة محل أو خدمة، وللمستخدمين عند التصفية',
          ),
          _cardWrap(isDark, [
            // حقل الإضافة
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addRegion(),
                  decoration: const InputDecoration(
                    hintText: 'مثال: ميدان المحطة',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add_location_alt_outlined,
                        color: Color(0xFF5E35B1)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _addRegion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('إضافة'),
              ),
            ]),

            const SizedBox(height: 14),

            if (_regions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 18),
                  SizedBox(width: 8),
                  Text('لم تُضَف مناطق بعد',
                      style: TextStyle(color: Colors.grey)),
                ]),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIdx, newIdx) {
                  setState(() {
                    if (newIdx > oldIdx) newIdx--;
                    final item = _regions.removeAt(oldIdx);
                    _regions.insert(newIdx, item);
                  });
                },
                children: _regions.map((r) {
                  return ListTile(
                    key: ValueKey(r),
                    leading: const Icon(Icons.drag_handle,
                        color: Colors.grey),
                    title: Text(r,
                        style: const TextStyle(fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blue, size: 20),
                          onPressed: () => _editRegion(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _removeRegion(r),
                        ),
                      ],
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),
            Text(
              '${_regions.length} منطقة — اسحب للترتيب',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ]),

          const SizedBox(height: 28),

          // زر الحفظ
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── ملاحظة للمطوّر ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المناطق المضافة هنا ستظهر للتاجر كقائمة اختيار عند إضافة محل أو خدمة، '
                    'وللمستخدم كقائمة تصفية عند ظهور أيقونة الموقع في الرئيسية.',
                    style: TextStyle(
                        color: Colors.blue, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardWrap(bool isDark, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );
}

// ─── Header المقطع ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(icon, color: const Color(0xFF5E35B1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E35B1))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
