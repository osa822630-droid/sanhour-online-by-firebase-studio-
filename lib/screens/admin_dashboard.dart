// lib/screens/admin_dashboard.dart
// ✅ P1-5 Fix: منع منح صلاحيات كاملة عند user == null أو عند غياب مفتاح الصلاحية (استخدام ?? false)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_content_tab.dart';
import 'tabs/admin_categories_tab.dart';
import 'tabs/admin_ads_tab.dart';
import 'tabs/admin_codes_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_complaints_tab.dart';
import 'tabs/admin_settings_tab.dart';
import 'tabs/admin_locations_tab.dart';
import '../widgets/gemini_chat_button.dart';
import 'merchant/add_shop_screen.dart';

class _AdminTabSpec {
  final String label;
  final IconData icon;
  final Widget child;
  const _AdminTabSpec({
    required this.label,
    required this.icon,
    required this.child,
  });
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_AdminTabSpec> _tabs;
  late bool _isFullAdmin;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    _isFullAdmin = user != null && user.isAdmin;
    final perms = user?.moderatorPermissions;

    _tabs = [
      const _AdminTabSpec(
        label: 'نظرة عامة',
        icon: Icons.dashboard,
        child: AdminOverviewTab(),
      ),
      if (_isFullAdmin ||
          (perms?.manageShops ?? false) ||
          (perms?.manageProducts ?? false) ||
          (perms?.manageOffers ?? false))
        const _AdminTabSpec(
          label: 'المحتوى',
          icon: Icons.layers,
          child: AdminContentTab(),
        ),
      if (_isFullAdmin || (perms?.manageCategories ?? false))
        const _AdminTabSpec(
          label: 'الفئات',
          icon: Icons.category,
          child: AdminCategoriesTab(),
        ),
      if (_isFullAdmin || (perms?.manageAds ?? false))
        const _AdminTabSpec(
          label: 'الإعلانات',
          icon: Icons.campaign,
          child: AdminAdsTab(),
        ),
      if (_isFullAdmin || (perms?.manageActivationCodes ?? false))
        const _AdminTabSpec(
          label: 'الأكواد',
          icon: Icons.vpn_key,
          child: AdminCodesTab(),
        ),
      if (_isFullAdmin || (perms?.manageUsers ?? false))
        const _AdminTabSpec(
          label: 'المستخدمين',
          icon: Icons.people,
          child: AdminUsersTab(),
        ),
      if (_isFullAdmin || (perms?.viewReports ?? false))
        const _AdminTabSpec(
          label: 'الشكاوى',
          icon: Icons.support_agent,
          child: AdminComplaintsTab(),
        ),
      if (_isFullAdmin || (perms?.manageSettings ?? false)) ...[
        const _AdminTabSpec(
          label: 'المناطق',
          icon: Icons.location_on,
          child: AdminLocationsTab(),
        ),
        const _AdminTabSpec(
          label: 'الإعدادات',
          icon: Icons.settings,
          child: AdminSettingsTab(),
        ),
      ],
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final perms = auth.user?.moderatorPermissions;
    final canCreateShopBypass =
        _isFullAdmin || (auth.user?.isModerator == true && (perms?.manageShops ?? false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        centerTitle: false,
        backgroundColor: const Color(0xFF1F3B33),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFE0A865),
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label))
              .toList(),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canCreateShopBypass) ...[
            FloatingActionButton.small(
              heroTag: 'admin_add_shop',
              tooltip: 'إضافة محل جديد',
              backgroundColor: Color(0xFF3D6B5E),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddShopScreen(adminBypass: true),
                ),
              ),
              child: const Icon(Icons.add_business_rounded, color: Color(0xFFE0A865)),
            ),
            const SizedBox(height: 12),
          ],
          const GeminiChatButton(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => t.child).toList(),
      ),
    );
  }
}
