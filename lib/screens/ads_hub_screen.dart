// lib/screens/ads_hub_screen.dart
// ✅ مركز الإعلانات — 3 تابات: إعلانات تجارية | وظائف | طلبات خدمات
import 'package:flutter/material.dart';
import 'all_ads_screen.dart';
import 'job_ads_tab_screen.dart';
import 'service_requests_tab_screen.dart';

class AdsHubScreen extends StatefulWidget {
  // initialTab: 0=ads, 1=jobs, 2=services
  final int initialTab;
  const AdsHubScreen({super.key, this.initialTab = 0});

  @override
  State<AdsHubScreen> createState() => _AdsHubScreenState();
}

class _AdsHubScreenState extends State<AdsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مركز الإعلانات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: false,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'إعلانات',  icon: Icon(Icons.campaign, size: 18)),
            Tab(text: 'وظائف',    icon: Icon(Icons.work_outline, size: 18)),
            Tab(text: 'خدمات',    icon: Icon(Icons.handyman_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          AllAdsScreen(showAppBar: false),
          JobAdsTabScreen(),
          ServiceRequestsTabScreen(),
        ],
      ),
    );
  }
}
