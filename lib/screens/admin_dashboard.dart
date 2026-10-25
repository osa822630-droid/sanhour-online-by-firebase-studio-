// lib/screens/admin_dashboard.dart
// ✅ إضافة تاب المناطق (AdminLocationsTab) كتاب تاسع
import 'package:flutter/material.dart';
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

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 9 تابات:
    // 1. نظرة عامة  2. المحتوى  3. الفئات  4. الإعلانات  5. الأكواد
    // 6. المستخدمين  7. الشكاوى  8. المناطق  9. الإعدادات
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        centerTitle: false,
        backgroundColor: Colors.deepPurple[900],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.deepPurpleAccent,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18),       text: 'نظرة عامة'),
            Tab(icon: Icon(Icons.layers, size: 18),           text: 'المحتوى'),
            Tab(icon: Icon(Icons.category, size: 18),         text: 'الفئات'),
            Tab(icon: Icon(Icons.campaign, size: 18),         text: 'الإعلانات'),
            Tab(icon: Icon(Icons.vpn_key, size: 18),          text: 'الأكواد'),
            Tab(icon: Icon(Icons.people, size: 18),           text: 'المستخدمين'),
            Tab(icon: Icon(Icons.support_agent, size: 18),    text: 'الشكاوى'),
            Tab(icon: Icon(Icons.location_on, size: 18),      text: 'المناطق'),
            Tab(icon: Icon(Icons.settings, size: 18),         text: 'الإعدادات'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'admin_add_shop',
            tooltip: 'إضافة محل جديد',
            backgroundColor: Colors.green,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddShopScreen(adminBypass: true),
              ),
            ),
            child: const Icon(Icons.add_business, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const GeminiChatButton(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminOverviewTab(),      // 1
          AdminContentTab(),       // 2
          AdminCategoriesTab(),    // 3
          AdminAdsTab(),           // 4
          AdminCodesTab(),         // 5
          AdminUsersTab(),         // 6
          AdminComplaintsTab(),    // 7
          AdminLocationsTab(),     // 8 ← جديد
          AdminSettingsTab(),      // 9
        ],
      ),
    );
  }
}
