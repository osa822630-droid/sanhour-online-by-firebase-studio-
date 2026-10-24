// lib/screens/subscription_screen.dart
// ✅ Refactored: كل منطق Firestore مُفوَّض لـ SubscriptionService
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_service.dart';
import '../utils/logger.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? shopId;
  const SubscriptionScreen({super.key, this.shopId});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _subscriptionData;
  bool _isLoading = true;
  bool _isRenewing = false;
  String _selectedPlan = 'monthly';

  // خطط الاشتراك
  static const Map<String, Map<String, dynamic>> _plans = {
    'monthly': {
      'label': 'شهري',
      'price': 99,
      'days': 30,
      'icon': Icons.calendar_month,
      'color': Color(0xFF5E35B1),
    },
    'quarterly': {
      'label': 'ربع سنوي',
      'price': 249,
      'days': 90,
      'icon': Icons.event_repeat,
      'color': Color(0xFF00897B),
      'badge': 'وفر 16%',
    },
    'yearly': {
      'label': 'سنوي',
      'price': 799,
      'days': 365,
      'icon': Icons.workspace_premium,
      'color': Color(0xFFE65100),
      'badge': 'الأوفر',
    },
  };

  @override
  void initState() {
    super.initState();
    // ✅ Phase 2 Fix #26: Permission Guard — هذه الشاشة للتجار فقط
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
    _loadSubscription();
  }

  void _checkPermission() {
    final auth = context.read<AuthProvider>();
    final role = auth.user?.userType ?? '';
    final allowed = ['merchant', 'admin', 'super_admin'].contains(role);
    if (!auth.isLoggedIn || !allowed) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الصفحة مخصصة للتجار المُفعَّلين فقط.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadSubscription() async {
    if (widget.shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await SubscriptionService.getSubscription(widget.shopId!);
      if (mounted) setState(() { _subscriptionData = data; _isLoading = false; });
    } catch (e) {
      AppLogger.error('loadSubscription error', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renewSubscription() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || widget.shopId == null) return;

    // ✅ Item #12: الـ dialog نفسه (_RenewCodeDialog) بيرجّع الكود المُدخل كنتيجة،
    // فمفيش قراءة من controller بعد dispose. والـ controller بقى مملوك للـ State
    // بتاع الـ dialog ويتعمله dispose لما الـ dialog يتشال فعلًا (بعد أنيميشن
    // الإغلاق) — الـ whenComplete القديم كان بيعمله dispose والـ TextField لسه
    // مرسوم، وده بيطلّع "TextEditingController was used after being disposed".
    final enteredCodeRaw = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RenewCodeDialog(
        planLabel: _plans[_selectedPlan]!['label'] as String,
      ),
    );

    // null = المستخدم ضغط "إلغاء"
    if (enteredCodeRaw == null || !mounted) return;
    final enteredCode = enteredCodeRaw.trim();

    if (enteredCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال كود التفعيل'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isRenewing = true);

    // ✅ تفويض كامل منطق الـ transaction لـ SubscriptionService
    final plan = _plans[_selectedPlan]!;
    final result = await SubscriptionService.renew(
      shopId: widget.shopId!,
      userId: user.id,
      activationCode: enteredCode,
      planKey: _selectedPlan,
      planDays: plan['days'] as int,
      planPrice: plan['price'] as int,
      planLabel: plan['label'] as String,
      currentShopData: _subscriptionData,
    );

    if (!mounted) return;
    setState(() => _isRenewing = false);

    if (result.success && result.newEndDate != null) {
      final d = result.newEndDate!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ تم تجديد الاشتراك حتى ${d.day}/${d.month}/${d.year}'),
        backgroundColor: Colors.green,
      ));
      await _loadSubscription();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'حدث خطأ'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ✅ QA Fix #32: شاشة فارغة عند فتح الاشتراك بدون shopId
  Widget _buildNoShopState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'لا يوجد محل محدد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'يرجى الوصول لهذه الصفحة من لوحة تحكم التاجر',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('الاشتراك'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      // ✅ QA Fix #32: empty state واضح عند shopId == null
      body: widget.shopId == null
          ? _buildNoShopState()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentStatus(isDark),
                  const SizedBox(height: 24),
                  const Text(
                    'اختر خطة التجديد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._plans.entries.map((e) => _buildPlanCard(e.key, e.value, isDark)),
                  const SizedBox(height: 28),
                  _buildRenewButton(),
                  const SizedBox(height: 16),
                  _buildFeaturesList(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatus(bool isDark) {
    final endDate = _subscriptionData?['subscriptionEndDate'] != null
        ? (_subscriptionData!['subscriptionEndDate'] as Timestamp).toDate()
        : null;
    final status = _subscriptionData?['subscriptionStatus'] ?? 'غير محدد';
    final plan = _subscriptionData?['subscriptionPlan'] ?? 'غير محدد';

    final isActive = status == 'active' && endDate != null && endDate.isAfter(DateTime.now());
    final isExpiringSoon = isActive && endDate.difference(DateTime.now()).inDays <= 7;

    Color statusColor = isActive
        ? (isExpiringSoon ? Colors.orange : Colors.green)
        : Colors.red;
    IconData statusIcon = isActive
        ? (isExpiringSoon ? Icons.warning_amber_rounded : Icons.check_circle)
        : Icons.cancel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(statusIcon, color: statusColor, size: 22),
            const SizedBox(width: 8),
            Text(
              isActive
                  ? (isExpiringSoon ? 'ينتهي قريباً!' : 'الاشتراك نشط')
                  : 'الاشتراك منتهي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: statusColor,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _statusRow(Icons.workspace_premium_outlined, 'الخطة الحالية',
              _planLabel(plan)),
          if (endDate != null)
            _statusRow(Icons.event_outlined, 'تاريخ الانتهاء',
                '${endDate.day}/${endDate.month}/${endDate.year}'),
          if (isActive)
            _statusRow(Icons.timelapse, 'الأيام المتبقية',
                '${endDate.difference(DateTime.now()).inDays} يوم'),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Widget _buildPlanCard(String key, Map<String, dynamic> plan, bool isDark) {
    final isSelected = _selectedPlan == key;
    final color = plan['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8)]
              : [],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(plan['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan['label'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (plan.containsKey('badge')) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(plan['badge'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${plan['days']} يوم',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          Text(
            '${plan['price']} ج',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 8),
          // ✅ groupValue/onChanged اتنقلوا من RadioListTile لـ RadioGroup (deprecated).
          // toggleable بيبعت null عند إلغاء التحديد: نتجاهله (كان v! بيكسر هنا).
          RadioGroup<String>(
            groupValue: _selectedPlan,
            onChanged: (v) {
              if (v != null) setState(() => _selectedPlan = v);
            },
            child: RadioListTile<String>.adaptive(
              value: key,
              activeColor: color,
              contentPadding: EdgeInsets.zero,
              toggleable: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRenewButton() {
    final plan = _plans[_selectedPlan]!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: plan['color'] as Color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        onPressed: _isRenewing ? null : _renewSubscription,
        icon: _isRenewing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh_rounded),
        label: Text(
          _isRenewing
              ? 'جارٍ التجديد...'
              : 'تجديد الاشتراك — ${plan['price']} جنيه',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFeaturesList(bool isDark) {
    const features = [
      'ظهور المحل في نتائج البحث',
      'إضافة منتجات وعروض بلا حدود',
      'إحصائيات تفصيلية يومية وأسبوعية',
      'إشعارات للمتابعين بالعروض الجديدة',
      'دعم فني على مدار الأسبوع',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مميزات الاشتراك',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 10),
              Text(f, style: const TextStyle(fontSize: 14)),
            ]),
          )),
        ],
      ),
    );
  }

  String _planLabel(String plan) {
    return _plans[plan]?['label'] as String? ?? plan;
  }
}

/// ✅ Item #12: dialog إدخال كود التجديد.
///
/// بيرجّع الكود المُدخل (String) عند "تجديد الاشتراك"، أو null عند "إلغاء".
/// الـ [TextEditingController] مملوك للـ State هنا، فبيتعمله dispose في الوقت
/// الصح (لما الـ dialog يتشال بعد أنيميشن الإغلاق) بدل dispose يدوي من بره.
class _RenewCodeDialog extends StatefulWidget {
  final String planLabel;
  const _RenewCodeDialog({required this.planLabel});

  @override
  State<_RenewCodeDialog> createState() => _RenewCodeDialogState();
}

class _RenewCodeDialogState extends State<_RenewCodeDialog> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تجديد الاشتراك', textAlign: TextAlign.right),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('خطة: ${widget.planLabel}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'كود التفعيل',
              hintText: 'أدخل الكود الذي حصلت عليه من الإدارة',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, _codeController.text),
            child: const Text('تجديد الاشتراك')),
      ],
    );
  }
}