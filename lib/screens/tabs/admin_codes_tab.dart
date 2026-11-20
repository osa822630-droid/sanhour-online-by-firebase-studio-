// lib/screens/tabs/admin_codes_tab.dart
// ✅ إصلاح كراش Colors.deepOrangeAccent[800]!
// ✅ السماح بحذف الأكواد غير المستخدمة أيضاً عند الخطأ في التوليد
// ✅ تسجيل AuditAction.activationCodeDeleted عند الحذف بدلاً من activationCodeUsed
// ✅ عرض قيمة الكود لجميع أنواع الأكواد الأربعة (تفعيل متجر، إعلان، ديلر، تجديد متجر)
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/dealer_listing_service.dart';
import '../../services/subscription_service.dart';

class AdminCodesTab extends StatefulWidget {
  const AdminCodesTab({super.key});

  @override
  State<AdminCodesTab> createState() => _AdminCodesTabState();
}

class _AdminCodesTabState extends State<AdminCodesTab> {
  int _selectedTypeIndex = 0; // 0: متجر, 1: إعلان, 2: ديلر, 3: تجديد متجر
  String _filterStatus = 'all'; // 'all', 'active', 'used'
  bool _isLoading = false;

  List<Map<String, dynamic>> _codes = [];

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);
    try {
      if (_selectedTypeIndex == 0) {
        final all = await ApiService.getAllCodes();
        _codes = all
            .where((c) =>
                c['type'] == 'shop_activation' ||
                (c['code'] ?? '').toString().startsWith('SHP-') ||
                (c['code'] ?? '').toString().startsWith('SHOP-') ||
                (c['type'] == null &&
                    !(c['code'] ?? '').toString().startsWith('AD-') &&
                    !(c['code'] ?? '').toString().startsWith('DLR-') &&
                    !(c['code'] ?? '').toString().startsWith('RNW-')))
            .toList();
      } else if (_selectedTypeIndex == 1) {
        final all = await ApiService.getAllCodes();
        _codes = all
            .where((c) =>
                c['type'] == 'ad_activation' ||
                (c['code'] ?? '').toString().startsWith('AD-'))
            .toList();
      } else if (_selectedTypeIndex == 2) {
        final all = await ApiService.getAllCodes();
        _codes = all
            .where((c) =>
                c['type'] == 'dealer_listing_fee' ||
                (c['code'] ?? '').toString().startsWith('DLR-'))
            .toList();
      } else {
        final all = await ApiService.getAllCodes();
        _codes = all
            .where((c) =>
                c['type'] == 'shop_renewal' ||
                (c['code'] ?? '').toString().startsWith('RNW-'))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading codes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCodes {
    return _codes.where((code) {
      final isUsed = code['isUsed'] ?? false;
      if (_filterStatus == 'active') return !isUsed;
      if (_filterStatus == 'used') return isUsed;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ إصلاح: Colors.deepOrangeAccent[800] كانت ترمي Null check error لأن MaterialAccentColor لا يحتوي على المفتاح 800
    final Color themeColor = switch (_selectedTypeIndex) {
      0 => Colors.blue.shade800,
      1 => Colors.deepOrange.shade800,
      2 => Colors.teal.shade800,
      _ => Colors.indigo.shade800,
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121514) : Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateCode,
        backgroundColor: themeColor,
        icon: const Icon(Icons.qr_code, color: Colors.white),
        label: Text(
          switch (_selectedTypeIndex) {
            0 => 'توليد كود متجر (SHOP)',
            1 => 'توليد كود إعلان (50 ج)',
            2 => 'توليد كود ديلر (${DealerListingService.extraListingFee} ج)',
            _ => 'توليد كود تجديد (RNW)',
          },
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Color(0xFF1B201E) : Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232927) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTypeButton('🏪 المتاجر', 0, Colors.blue.shade800, isDark),
                      _buildTypeButton(
                          '📢 الإعلانات', 1, Colors.deepOrange.shade800, isDark),
                      _buildTypeButton('🏷️ الديلر', 2, Colors.teal.shade800, isDark),
                      _buildTypeButton('🔄 التجديد', 3, Colors.indigo.shade800, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFilterChip('الكل', 'all', themeColor),
                    const SizedBox(width: 8),
                    _buildFilterChip('متاح (جديد)', 'active', Colors.green),
                    const SizedBox(width: 8),
                    _buildFilterChip('مستخدم', 'used', Colors.grey),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: themeColor.withValues(alpha: 0.12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('الإجمالي', _codes.length, themeColor),
                _buildStatItem('المتاح',
                    _codes.where((c) => !c['isUsed']).length, Colors.green),
                _buildStatItem('المستخدم',
                    _codes.where((c) => c['isUsed']).length, Colors.grey),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCodes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _filteredCodes.length,
                        itemBuilder: (ctx, i) {
                          final codeData = _filteredCodes[i];
                          return _buildCodeTicket(codeData, themeColor, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String title, int index, Color color, bool isDark) {
    bool isSelected = _selectedTypeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTypeIndex = index;
            _loadCodes();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1B201E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status, Color color) {
    bool isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _filterStatus = status),
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: isSelected
          ? BorderSide(color: color)
          : BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildCodeTicket(
      Map<String, dynamic> codeData, Color themeColor, bool isDark) {
    bool isUsed = codeData['isUsed'] ?? false;
    String code = codeData['code'] ?? '???';
    DateTime? date = codeData['createdAt'] is Timestamp
        ? (codeData['createdAt'] as Timestamp).toDate()
        : null;
    String dateStr =
        date != null ? DateFormat('yyyy-MM-dd').format(date) : 'لا يوجد تاريخ';
    final num? explicitPrice = codeData['price'] is num ? codeData['price'] as num : null;
    final String valueStr = explicitPrice != null && explicitPrice > 0
        ? '• ${explicitPrice.toInt()} ج.م'
        : switch (_selectedTypeIndex) {
            0 => '• 200 ج.م',
            1 => '• 50 ج.م',
            2 => '• ${DealerListingService.extraListingFee} ج.م',
            _ => '• 200 ج.م',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B201E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                  width: 6, color: isUsed ? Colors.grey : themeColor),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUsed
                          ? (isDark ? Colors.white10 : Colors.grey[100])
                          : themeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUsed
                          ? Icons.check_circle
                          : switch (_selectedTypeIndex) {
                              0 => Icons.store,
                              1 => Icons.campaign,
                              2 => Icons.sell,
                              _ => Icons.autorenew,
                            },
                      color: isUsed ? Colors.grey : themeColor,
                    ),
                  ),
                  const SizedBox(width: 15),
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
                            color: isUsed
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUsed
                              ? 'تم الاستخدام $valueStr'
                              : 'نشط (جاهز للاستخدام) $valueStr',
                          style: TextStyle(
                              fontSize: 12,
                              color: isUsed ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'تاريخ الإنشاء: $dateStr',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (!isUsed)
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ الكود ✅')));
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'حذف الكود',
                    onPressed: () =>
                        _deleteCode(codeData['id'], 'activation_codes'),
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
    final filterLabel = switch (_filterStatus) {
      'active' => 'متاحة',
      'used' => 'مستخدمة',
      _ => '',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text('لا توجد أكواد $filterLabel حالياً',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _generateCode() async {
    setState(() => _isLoading = true);
    try {
      String newCode;

      if (_selectedTypeIndex == 0) {
        newCode = await ApiService.generateActivationCode('admin');
      } else if (_selectedTypeIndex == 1) {
        newCode = await ApiService.generateAdCode();
      } else if (_selectedTypeIndex == 2) {
        newCode = await DealerListingService.generateFeeCode();
      } else {
        newCode = await SubscriptionService.generateRenewalCode();
      }

      await _loadCodes();
      if (mounted) _showSuccessDialog(newCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String code) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark ? const Color(0xFF232927) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                code,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: switch (_selectedTypeIndex) {
                      0 => Colors.blue,
                      1 => Colors.deepOrange,
                      2 => Colors.teal,
                      _ => Colors.indigo,
                    }),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              switch (_selectedTypeIndex) {
                0 => 'كود لتفعيل حساب تاجر جديد',
                1 => 'كوبون إعلاني بقيمة 50 ج.م',
                2 =>
                  'كود دفع إعلان ديلر إضافي بقيمة ${DealerListingService.extraListingFee} ج.م',
                _ => 'كود لتجديد اشتراك متجر حالي',
              },
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق')),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('نسخ'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الكود')));
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
      await AuditLogService.log(
        action: AuditAction.activationCodeDeleted,
        targetId: id,
        targetType: collection,
      );
      if (mounted) {
        _loadCodes();
      }
    }
  }
}
