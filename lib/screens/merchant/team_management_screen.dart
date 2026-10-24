// lib/screens/merchant/team_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/shop.dart';
import '../../utils/logger.dart';

class TeamManagementScreen extends StatefulWidget {
  final Shop shop;
  const TeamManagementScreen({super.key, required this.shop});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
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
      final snap = await _firestore
          .collection('users')
          .where('linkedShopId', isEqualTo: widget.shop.id)
          .where('userType', isEqualTo: 'merchant')
          .get();

      if (mounted) {
        setState(() {
          _teamMembers = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
      // البحث عن المستخدم برقم الهاتف
      final snap = await _firestore.collection('users')
          .where('phone', isEqualTo: phone.startsWith('+2') ? phone : '+2$phone')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يُعثر على مستخدم بهذا الرقم'),
            backgroundColor: Colors.red));
        return;
      }

      final userId = snap.docs.first.id;
      await _firestore.collection('users').doc(userId).update({
        'linkedShopId': widget.shop.id,
        'shopRole': role, // 'partner' or 'worker'
        'userType': 'merchant',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تمت إضافة ${role == 'partner' ? 'الشريك' : 'العامل'}'),
          backgroundColor: Colors.green));
      await _loadTeam();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، حاول مجدداً'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _removeMember(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'linkedShopId': null,
      'shopRole': 'owner',
      'userType': 'customer',
    });
    await _loadTeam();
  }

  void _showAddDialog() {
    final phoneCtrl = TextEditingController();
    String selectedRole = 'worker';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('إضافة عضو للفريق'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixText: '+20 ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('الدور:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // ✅ groupValue/onChanged اتنقلوا من RadioListTile لـ RadioGroup (deprecated)
          RadioGroup<String>(
            groupValue: selectedRole,
            onChanged: (v) {
              if (v != null) setS(() => selectedRole = v);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // شريك
              RadioListTile<String>.adaptive(
                value: 'partner',
                title: const Text('شريك'),
                subtitle: const Text('صلاحيات كاملة كصاحب المحل',
                    style: TextStyle(fontSize: 12)),
                activeColor: const Color(0xFF5E35B1),
              ),
              // عامل
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
              Navigator.pop(ctx);
              if (phoneCtrl.text.trim().isNotEmpty) {
                _addMember(phoneCtrl.text.trim(), selectedRole);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      )),
    // ✅ Fix #70: dispose controller بعد إغلاق الـ dialog
    ).whenComplete(() => phoneCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فريق العمل'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'إضافة عضو',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeam,
              child: _teamMembers.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teamMembers.length,
                      itemBuilder: (_, i) => _buildMemberCard(_teamMembers[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة عضو'),
        onPressed: _showAddDialog,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('لا يوجد أعضاء في الفريق',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('أضف شريكاً أو عاملاً للمساعدة في إدارة المتجر',
            style: TextStyle(color: Colors.grey[500])),
      ]),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final role = member['shopRole'] as String? ?? 'worker';
    final isPartner = role == 'partner';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isPartner
              ? const Color(0xFF5E35B1).withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            isPartner ? Icons.supervisor_account : Icons.person,
            color: isPartner ? const Color(0xFF5E35B1) : Colors.orange,
          ),
        ),
        title: Text(member['name'] ?? 'مستخدم',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(member['phone'] ?? '', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPartner
                  ? const Color(0xFF5E35B1).withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isPartner ? '🤝 شريك — صلاحيات كاملة'
                        : '👷 عامل — منتجات وعروض فقط',
              style: TextStyle(
                color: isPartner ? const Color(0xFF5E35B1) : Colors.orange[800],
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
          onPressed: () => _confirmRemove(member),
        ),
      ),
    );
  }

  void _confirmRemove(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إزالة العضو'),
        content: Text('هل تريد إزالة ${member['name']} من الفريق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member['id']);
            },
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }
}
