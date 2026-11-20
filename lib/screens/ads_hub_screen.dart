// lib/screens/ads_hub_screen.dart
// ✅ مركز الإعلانات — 3 تابات: إعلانات تجارية | وظائف | طلبات خدمات
import 'package:material_ui/material_ui.dart';
import 'all_ads_screen.dart';
import 'job_ads_tab_screen.dart';
import 'service_requests_tab_screen.dart';

class AdsHubScreen extends StatefulWidget {
  // initialTab: 0=ads, 1=jobs, 2=services
  final int initialTab;
  const AdsHubScreen({super.key, this.initialTab = 0});

  /// يسمح بالتبديل البرمجي إلى تبويب فرعي محدد (0: إعلانات، 1: وظائف، 2: خدمات)
  static final ValueNotifier<int?> subTabRequest = ValueNotifier<int?>(null);

  @override
  State<AdsHubScreen> createState() => _AdsHubScreenState();
}

class _AdsHubScreenState extends State<AdsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late final Set<int> _activatedTabs;

  @override
  void initState() {
    super.initState();
    final req = AdsHubScreen.subTabRequest.value;
    final initial = (req ?? widget.initialTab).clamp(0, 2);
    _activatedTabs = {initial};
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: initial,
    )..addListener(_onTabChanged);
    AdsHubScreen.subTabRequest.addListener(_onSubTabRequested);
  }

  void _onSubTabRequested() {
    final target = AdsHubScreen.subTabRequest.value;
    if (target != null && mounted) {
      final idx = target.clamp(0, 2);
      setState(() {
        _activatedTabs.add(idx);
      });
      _tabs.animateTo(idx);
      AdsHubScreen.subTabRequest.value = null;
    }
  }

  void _onTabChanged() {
    if (!_activatedTabs.contains(_tabs.index)) {
      setState(() {
        _activatedTabs.add(_tabs.index);
      });
    }
  }

  @override
  void dispose() {
    AdsHubScreen.subTabRequest.removeListener(_onSubTabRequested);
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
        backgroundColor: const Color(0xFF3D6B5E),
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
        children: [
          _activatedTabs.contains(0)
              ? const AllAdsScreen(showAppBar: false)
              : const SizedBox.shrink(),
          _activatedTabs.contains(1)
              ? const JobAdsTabScreen()
              : const SizedBox.shrink(),
          _activatedTabs.contains(2)
              ? const ServiceRequestsTabScreen()
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
