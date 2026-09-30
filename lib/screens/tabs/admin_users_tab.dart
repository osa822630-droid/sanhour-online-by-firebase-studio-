// lib/screens/tabs/admin_users_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // عشان التعامل مع Timestamps
import '../../services/api_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  // ✅ Fix #104/#106/#107: تخزين رسالة الخطأ
  String? _errorMsg;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';

  // التحكم في الفلاتر (التبويبات العلوية)
  late TabController _filterController;
  final List<String> _filters = ['الكل', 'التجار', 'العملاء', 'المحظورين'];

  @override
  void initState() {
    super.initState();
    _filterController = TabController(length: 4, vsync: this);
    _filterController
        .addListener(_applyFilters); // تحديث القائمة عند تغيير التبويب
    _loadUsers();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await ApiService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _applyFilters(); // تطبيق الفلتر الحالي على البيانات الجديدة
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة الفلترة الذكية (تدمج البحث + نوع التبويب)
  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allUsers;

    // 1. فلتر التبويب (Tabs)
    int index = _filterController.index;
    if (index == 1) {
      // التجار
      temp = temp.where((u) => u['userType'] == 'merchant').toList();
    } else if (index == 2) {
      // العملاء
      temp = temp
          .where((u) => u['userType'] == 'customer' || u['userType'] == null)
          .toList();
    } else if (index == 3) {
      // المحظورين
      temp = temp.where((u) => u['isSuspended'] == true).toList();
    }

    // 2. فلتر البحث (اسم، يوزرنيم، هاتف)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp.where((u) {
        final name = (u['name'] ?? '').toLowerCase();
        final username = (u['username'] ?? '').toLowerCase();
        final phone = (u['phone'] ?? '').toString();
        return name.contains(q) || username.contains(q) || phone.contains(q);
      }).toList();
    }

    setState(() {
      _filteredUsers = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث (اسم، اسم مستخدم، هاتف)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters(); // إعادة تعيين الفلتر
                          });
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
            ),
          ),

          // 2. تبويبات الفلترة (Tabs)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _filterController,
              labelColor: Colors.deepPurple[900],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple[900],
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
          ),

          // 3. شريط المعلومات (عدد النتائج + تحديث)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('العدد: ${_filteredUsers.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: _loadUsers,
                  tooltip: 'تحديث القائمة',
                ),
              ],
            ),
          ),

          // 4. القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_errorMsg!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 80),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (ctx, i) =>
                                _buildUserCard(_filteredUsers[i]),
                          ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildUserCard(Map<String, dynamic> user) {
    final bool isSuspended = user['isSuspended'] ?? false;
    final String role = user['userType'] ?? 'customer';
    final bool isMerchant = role == 'merchant';

    // تنسيق التاريخ
    String dateStr = '-';
    if (user['createdAt'] != null) {
      try {
        final date = user['createdAt'] is Timestamp
            ? (user['createdAt'] as Timestamp).toDate()
            : DateTime.tryParse(user['createdAt'].toString());
        if (date != null) {
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        }
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // لو محظور نخليه بإطار أحمر
        side: isSuspended
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      // لو محظور نغير لون الخلفية لحاجة باهتة
      color: isSuspended ? Colors.grey[100] : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        // 1. الأفاتار (مع إشارات مميزة)
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isSuspended
                  ? Colors.grey
                  : (isMerchant ? Colors.blue[100] : Colors.green[100]),
              child: Text(
                (user['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                style: TextStyle(
                    color: isMerchant ? Colors.deepPurple[900] : Colors.green[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
              ),
            ),
            // بادج التاجر
            if (isMerchant)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.deepPurple, shape: BoxShape.circle),
                  child: const Icon(Icons.store, size: 12, color: Colors.white),
                ),
              ),
            // بادج المحظور
            if (isSuspended)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.block, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),

        // 2. البيانات الأساسية
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['name'] ?? 'بدون اسم',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    // شطب الاسم لو محظور
                    decoration: isSuspended ? TextDecoration.lineThrough : null,
                    color: isSuspended ? Colors.grey : Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // 3. البيانات الفرعية (Username, Phone, Date)
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // اسم المستخدم
            Row(
              children: [
                const Icon(Icons.alternate_email, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('@${user['username'] ?? 'unknown'}',
                    style: const TextStyle(
                        color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            // الهاتف والتاريخ
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(user['phone'] ?? '-',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 15),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(dateStr, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),

        // 4. قائمة الإجراءات (بدون تغيير رتبة) ❌👮‍♂️
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'toggle_ban') {
              _toggleUserSuspension(user['id'], isSuspended, user['name']);
            }
            if (value == 'delete') {
              _confirmDeleteUser(user['id'], user['name']);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            // خيار الحظر/التفعيل
            PopupMenuItem<String>(
              value: 'toggle_ban',
              child: Row(
                children: [
                  Icon(isSuspended ? Icons.lock_open : Icons.block,
                      color: isSuspended ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Text(isSuspended
                      ? 'تفعيل الحساب (فك الحظر)'
                      : 'تعطيل الحساب (حظر)'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            // خيار الحذف النهائي
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('حذف نهائي', style: TextStyle(color: Colors.red)),
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
          Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text('لا يوجد مستخدمين مطابقين',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Actions Logic ---

  // 1. منطق الحظر / فك الحظر
  Future<void> _toggleUserSuspension(
      String userId, bool currentStatus, String name) async {
    // ديالوج التأكيد
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(currentStatus ? 'تفعيل الحساب' : 'تعطيل الحساب'),
            content: Text(currentStatus
                ? 'هل تريد إعادة تفعيل حساب "$name"؟ سيتمكن من الدخول للتطبيق مرة أخرى.'
                : 'هل تريد تعطيل حساب "$name"؟ سيتم طرده من التطبيق فوراً ولن يتمكن من الدخول.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: currentStatus ? Colors.green : Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(currentStatus ? 'تفعيل' : 'تعطيل'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.toggleUserSuspension(userId, currentStatus);
      if (mounted) {
        _loadUsers(); // تحديث القائمة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  currentStatus ? 'تم تفعيل الحساب ✅' : 'تم تعطيل الحساب ⛔')),
        );
      }
    }
  }

  // 2. منطق الحذف النهائي
  Future<void> _confirmDeleteUser(String userId, String name) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف المستخدم نهائياً'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تحذير: أنت على وشك حذف حساب "$name".'),
                const SizedBox(height: 10),
                const Text('• سيتم حذف بيانات الحساب تماماً من قاعدة البيانات.',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
                const Text('• هذا الإجراء لا يمكن التراجع عنه.',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف نهائي'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.deleteUser(userId);
      if (mounted) {
        _loadUsers(); // تحديث القائمة
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المستخدم بنجاح')));
      }
    }
  }
}
