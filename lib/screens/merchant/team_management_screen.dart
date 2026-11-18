// lib/screens/merchant/team_management_screen.dart
// ✅ P0-5 Fix: إدارة وعرض أعضاء الفريق عبر Cloud Function (manageShopTeam) دون فهرسة مجموعة users من العميل
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/shop.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

class TeamManagementScreen extends StatefulWidget {
  final Shop shop;
  const TeamManagementScreen({super.key, required this.shop});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _functions = FirebaseFunctions.instance;
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    try {
      final callable = _functions.httpsCallable('manageShopTeam');
      final res = await callable.call({
        'shopId': widget.shop.id,
        'action': 'list',
      });
      final data = res.data;
      final rawMembers =
          (data is Map && data['members'] is List) ? data['members'] as List : [];

      if (mounted) {
        setState(() {
          _teamMembers = rawMembers
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('loadTeam error', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMember(String phone, String role) async {
    try {
      final candidates = AppConstants.phoneLookupCandidates(phone);
      if (candidates.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('أدخل رقم هاتف مصري صحيح'),
            backgroundColor: Colors.red));
        return;
      }

      final callable = _functions.httpsCallable('manageShopTeam');
      await callable.call({
        'shopId': widget.shop.id,
        'action': 'add',
        'phone': phone.trim(),
        'role': role,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('✅ تمت إضافة ${role == 'partner' ? 'الشريك' : 'العامل'}'),
          backgroundColor: Colors.green));
      await _loadTeam();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message ?? 'تعذّرت إضافة العضو'),
          backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، حاول مجدداً'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      final callable = _functions.httpsCallable('manageShopTeam');
      await callable.call({
        'shopId': widget.shop.id,
        'action': 'remove',
        'userId': userId,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّرت إزالة العضو، حاول مجدداً'),
          backgroundColor: Colors.red));
      return;
    }
    if (!mounted) return;
    await _loadTeam();
  }

  void _showAddDialog() {
    final phoneCtrl = TextEditingController();
    String selectedRole = 'worker';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                title: const Text('إضافة عضو للفريق'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '01xxxxxxxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('الدور:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: selectedRole,
                    onChanged: (v) {
                      if (v != null) setS(() => selectedRole = v);
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      RadioListTile<String>.adaptive(
                        value: 'partner',
                        title: const Text('شريك'),
                        subtitle: const Text('صلاحيات كاملة كصاحب المحل',
                            style: TextStyle(fontSize: 12)),
                        activeColor: const Color(0xFF5E35B1),
                      ),
                      RadioListTile<String>.adaptive(
                        value: 'worker',
                        title: const Text('عامل'),
                        subtitle: const Text(
                            'إضافة وتعديل المنتجات والعروض فقط\n(بدون إحصائيات أو اشتراكات)',
                            style: TextStyle(fontSize: 12)),
                        activeColor: const Color(0xFF5E35B1),
                      ),
                    ]),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E35B1),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final phone = phoneCtrl.text.trim();
                      if (phone.isEmpty) return;
                      Navigator.pop(ctx);
                      _addMember(phone, selectedRole);
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('فريق عمل ${widget.shop.name}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة عضو'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E35B1)))
          : _teamMembers.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('لا يوجد أعضاء في الفريق حالياً',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('أضف شريكاً أو عاملاً لمساعدتك في إدارة المحل',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                      ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teamMembers.length,
                  itemBuilder: (_, i) {
                    final m = _teamMembers[i];
                    final isPartner = m['shopRole'] == 'partner';
                    return Card(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPartner
                              ? Colors.deepPurple.withValues(alpha: 0.12)
                              : Colors.teal.withValues(alpha: 0.12),
                          child: Icon(
                            isPartner ? Icons.handshake : Icons.badge,
                            color: isPartner ? Colors.deepPurple : Colors.teal,
                          ),
                        ),
                        title: Text(m['name'] ?? 'عضو',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${isPartner ? 'شريك' : 'عامل'} — ${m['phone'] ?? ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          tooltip: 'إزالة من الفريق',
                          onPressed: () => _removeMember(m['id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
