// lib/screens/tabs/admin_codes_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/audit_log_service.dart';

class AdminCodesTab extends StatefulWidget {
  const AdminCodesTab({super.key});

  @override
  State<AdminCodesTab> createState() => _AdminCodesTabState();
}

class _AdminCodesTabState extends State<AdminCodesTab> {
  bool _isLoading = true;
  int _selectedTypeIndex = 0; // 0 = Shops, 1 = Ads

  // القوائم
  List<Map<String, dynamic>> _shopCodes = [];
  List<Map<String, dynamic>> _adCodes = [];

  // الفلترة
  String _filterStatus = 'all'; // 'all', 'active', 'used'

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);
    try {
      // 1. جلب أكواد المحلات
      final shopSnapshot = await FirebaseFirestore.instance
          .collection('activation_codes')
          .orderBy('createdAt', descending: true)
          .get();

      // 2. جلب أكواد الإعلانات
      final adSnapshot = await FirebaseFirestore.instance
          .collection('ad_codes')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _shopCodes =
              shopSnapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
          _adCodes =
              adSnapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading codes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // القائمة الحالية المعروضة بناءً على التبويب والفلتر
  List<Map<String, dynamic>> get _currentList {
    List<Map<String, dynamic>> source =
        _selectedTypeIndex == 0 ? _shopCodes : _adCodes;

    if (_filterStatus == 'all') return source;
    if (_filterStatus == 'active') {
      return source.where((c) => c['isUsed'] == false).toList();
    }
    if (_filterStatus == 'used') {
      return source.where((c) => c['isUsed'] == true).toList();
    }
    return source;
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _currentList;
    final Color primaryColor =
        _selectedTypeIndex == 0 ? Colors.deepPurple[800]! : Colors.deepOrangeAccent[800]!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateCode,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label:
            Text(_selectedTypeIndex == 0 ? 'توليد كود محل' : 'توليد كود إعلان'),
      ),
      body: Column(
        children: [
          // 1. التبديل بين النوعين (Header)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Toggle Switch
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _buildToggleOption('🏪 تفعيل المحلات', 0, Colors.blue),
                      _buildToggleOption(
                          '📢 كوبونات الإعلانات', 1, Colors.deepOrangeAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // إحصائيات سريعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBadge(
                        'متاح',
                        currentList.where((c) => c['isUsed'] == false).length,
                        Colors.green),
                    _buildStatBadge(
                        'مستخدم',
                        currentList.where((c) => c['isUsed'] == true).length,
                        Colors.red),
                    _buildStatBadge(
                        'الإجمالي', currentList.length, Colors.grey),
                  ],
                )
              ],
            ),
          ),

          // 2. شريط الفلتر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سجل الأكواد:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButton<String>(
                  value: _filterStatus,
                  underline: const SizedBox(),
                  style: TextStyle(
                      color: primaryColor, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('عرض الكل')),
                    DropdownMenuItem(
                        value: 'active', child: Text('المتاح (Active)')),
                    DropdownMenuItem(
                        value: 'used', child: Text('المستخدم (Used)')),
                  ],
                  onChanged: (val) => setState(() => _filterStatus = val!),
                ),
              ],
            ),
          ),

          // 3. القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                            bottom: 80, left: 16, right: 16),
                        itemCount: currentList.length,
                        itemBuilder: (ctx, i) =>
                            _buildCodeTicket(currentList[i], primaryColor),
                      ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildToggleOption(String title, int index, Color color) {
    bool isSelected = _selectedTypeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTypeIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildCodeTicket(Map<String, dynamic> codeData, Color themeColor) {
    bool isUsed = codeData['isUsed'] ?? false;
    String code = codeData['code'] ?? '???';
    DateTime? date = codeData['createdAt'] != null
        ? (codeData['createdAt'] as Timestamp).toDate()
        : null;
    String dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : 'لا يوجد تاريخ';
    String valueStr = _selectedTypeIndex == 1 ? '• 50 ج.م' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // الشريط الجانبي الملون
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child:
                  Container(width: 6, color: isUsed ? Colors.grey : themeColor),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // الأيقونة والحالة
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUsed
                          ? Colors.grey[100]
                          : themeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUsed
                          ? Icons.check_circle
                          : (_selectedTypeIndex == 0
                              ? Icons.store
                              : Icons.campaign),
                      color: isUsed ? Colors.grey : themeColor,
                    ),
                  ),
                  const SizedBox(width: 15),

                  // تفاصيل الكود
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            decoration:
                                isUsed ? TextDecoration.lineThrough : null,
                            color: isUsed ? Colors.grey : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUsed
                              ? 'تم الاستخدام'
                              : 'نشط (جاهز للاستخدام) $valueStr',
                          style: TextStyle(
                              fontSize: 12,
                              color: isUsed ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'تاريخ الإنشاء: $dateStr',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // زر النسخ
                  if (!isUsed)
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ الكود ✅')));
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCode(
                          codeData['id'],
                          _selectedTypeIndex == 0
                              ? 'activation_codes'
                              : 'ad_codes'),
                    ),
                ],
              ),
            ),
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
          Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text('لا توجد أكواد $_filterStatus',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // --- Logic ---

  Future<void> _generateCode() async {
    setState(() => _isLoading = true);
    try {
      String newCode;

      if (_selectedTypeIndex == 0) {
        await ApiService.generateActivationCode('admin');
        final snapshot = await FirebaseFirestore.instance
            .collection('activation_codes')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        newCode = snapshot.docs.first['code'];
        // ✅ Fix #132: إضافة expiresAt للكود عند التوليد (30 يوماً)
        await snapshot.docs.first.reference.update({
          'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 30))),
        });
      } else {
        newCode = await ApiService.generateAdCode();
      }

      await _loadCodes();
      if (mounted) _showSuccessDialog(newCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم التوليد بنجاح 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                code,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color:
                        _selectedTypeIndex == 0 ? Colors.blue : Colors.deepOrangeAccent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _selectedTypeIndex == 0
                  ? 'كود لتفعيل حساب تاجر جديد'
                  : 'كوبون إعلاني بقيمة 50 ج.م',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('نسخ'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCode(String id, String collection) async {
    bool confirm = await showDialog(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text('حذف الكود'),
                    content: const Text('هل تريد حذف هذا الكود من السجل؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('حذف',
                              style: TextStyle(color: Colors.red))),
                    ])) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      // ✅ Fix #40: تسجيل حذف الكود في audit log
      await AuditLogService.log(
        action: AuditAction.activationCodeUsed, // closest available action
        targetId: id,
        targetType: collection,
      );
      if (mounted) {
        _loadCodes();
      }
    }
  }
}
