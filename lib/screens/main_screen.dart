// lib/screens/main_screen.dart
// ✅ Tab الإعلانات → AdsHubScreen (مركز شامل: إعلانات + وظائف + خدمات)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'offers_screen.dart';
import 'favorites_screen.dart';
import 'categories_screen.dart';
import 'options_screen.dart';
import 'sanhour_dealer_screen.dart';
import 'ads_hub_screen.dart';
import 'notifications_screen.dart';
import 'about_screen.dart';
import 'account_edit_screen.dart';
import '../widgets/gemini_chat_button.dart';
import '../widgets/dealer_icon.dart';

class MainScreen extends StatefulWidget {
  static const int homeTab = 0;
  static const int favoritesTab = 1;
  static const int offersTab = 2;
  static const int categoriesTab = 3;
  static const int dealerTab = 4;
  static const int adsHubTab = 5;

  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = homeTab});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  static void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  static final ValueNotifier<int?> tabSwitchRequest = ValueNotifier<int?>(null);
  static void switchTab(int tabIndex, {int? adsSubTab, String? categoryName}) {
    if (adsSubTab != null) {
      AdsHubScreen.subTabRequest.value = adsSubTab;
    }
    if (categoryName != null) {
      CategoriesScreen.categoryRequest.value = categoryName;
    }
    tabSwitchRequest.value = tabIndex;
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late final Set<int> _activatedTabs;

  // ✅ تخزين Stream عداد الإشعارات غير المقروءة لمنع إعادة الاشتراك مع كل rebuild
  Stream<QuerySnapshot<Map<String, dynamic>>>? _unreadNotifStream;
  String? _unreadStreamUid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getUnreadStream(String uid) {
    if (_unreadNotifStream == null || _unreadStreamUid != uid) {
      _unreadStreamUid = uid;
      _unreadNotifStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .limit(99)
          .snapshots();
    }
    return _unreadNotifStream!;
  }

  void _onExternalTabRequest() {
    final target = MainScreen.tabSwitchRequest.value;
    if (target != null && target >= 0 && target < _screens.length && mounted) {
      setState(() {
        _selectedIndex = target;
        _activatedTabs.add(target);
      });
      MainScreen.tabSwitchRequest.value = null;
    }
  }

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex;
    _selectedIndex =
        (index >= 0 && index < _screens.length) ? index : MainScreen.homeTab;
    _activatedTabs = {_selectedIndex};
    MainScreen.tabSwitchRequest.addListener(_onExternalTabRequest);
  }

  @override
  void dispose() {
    MainScreen.tabSwitchRequest.removeListener(_onExternalTabRequest);
    super.dispose();
  }

  static const List<Widget> _screens = [
    HomeScreen(),
    FavoritesScreen(),
    OffersScreen(),
    CategoriesScreen(),
    SanhourDealerScreen(),
    AdsHubScreen(),
  ];

  void _onItemTapped(int index) => setState(() {
        _selectedIndex = index;
        _activatedTabs.add(index);
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        key: MainScreen.scaffoldKey,
        drawer: _buildOptionsDrawer(context, isDark),
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            _screens.length,
            (i) => _activatedTabs.contains(i)
                ? _screens[i]
                : const SizedBox.shrink(),
          ),
        ),
        floatingActionButton: const GeminiChatButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: isDark ? const Color(0xFF1B201E) : Colors.white,
          indicatorColor: (isDark ? const Color(0xFF73A899) : const Color(0xFF3D6B5E)).withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: isDark ? const Color(0xFF73A899) : const Color(0xFF3D6B5E)),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite, color: const Color(0xFF3D6B5E)),
              label: 'المفضلة',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer, color: const Color(0xFF3D6B5E)),
              label: 'العروض',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view, color: const Color(0xFF3D6B5E)),
              label: 'الفئات',
            ),
            NavigationDestination(
              icon: DealerIcon(
                size: 22,
                color: _selectedIndex == 4
                    ? const Color(0xFF3D6B5E)
                    : isDark
                        ? Colors.grey[400]!
                        : Colors.grey[600]!,
              ),
              selectedIcon: DealerIcon(size: 22, color: const Color(0xFF3D6B5E)),
              label: 'ديلز',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.campaign_outlined,
                color: _selectedIndex == 5
                    ? const Color(0xFF3D6B5E)
                    : isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
              ),
              selectedIcon:
                  const Icon(Icons.campaign, color: Color(0xFF3D6B5E)),
              label: 'الإعلانات',
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Drawer
  // ════════════════════════════════════════════════════════════════════
  Widget _buildOptionsDrawer(BuildContext context, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1B201E) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── هيدر المستخدم ────────────────────────────────────
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) => Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3D6B5E), Color(0xFF4B5E6F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white24,
                          backgroundImage:
                              (auth.user?.profileImageUrl ?? '').isNotEmpty
                                  ? NetworkImage(auth.user!.profileImageUrl!)
                                  : null,
                          child: (auth.user?.profileImageUrl ?? '').isEmpty
                              ? (auth.user?.name.isNotEmpty == true
                                  ? Text(
                                      auth.user!.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : const Icon(Icons.person,
                                      color: Colors.white, size: 30))
                              : null,
                        ),
                        if (!auth.isGuest)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AccountEditScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit,
                                    size: 12, color: Color(0xFF3D6B5E)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.isGuest
                          ? 'زائر'
                          : (auth.user?.name ?? 'سنهور أونلاين'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.isGuest
                          ? 'تصفح بدون حساب'
                          : (auth.user?.phone ?? ''),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    if (!auth.isGuest) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountEditScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'تعديل الحساب ✏️',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // لوحة تحكم الإدارة (للأدمن والمشرفين)
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) {
                if (!auth.isAdmin) return const SizedBox.shrink();
                return _drawerItem(
                  context,
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'لوحة تحكم الإدارة',
                  iconColor: const Color(0xFFC28542),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin');
                  },
                );
              },
            ),

            // لوحة تحكم التاجر (للتجار)
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) {
                if (auth.userRole != UserRole.merchant) {
                  return const SizedBox.shrink();
                }
                return _drawerItem(
                  context,
                  icon: Icons.storefront_outlined,
                  label: 'لوحة تحكم التاجر',
                  iconColor: const Color(0xFF00897B),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/merchant');
                  },
                );
              },
            ),

            // الإعدادات
            _drawerItem(
              context,
              icon: Icons.settings_outlined,
              label: 'الإعدادات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OptionsScreen()),
                );
              },
            ),

            // الوضع الليلي
            Consumer<ThemeProvider>(
              builder: (ctx, tp, _) => _drawerItem(
                context,
                icon: tp.isDarkMode
                    ? Icons.dark_mode
                    : Icons.light_mode_outlined,
                label: 'الوضع الليلي',
                trailing: Switch(
                  value: tp.isDarkMode,
                  onChanged: (_) => tp.toggleTheme(),
                  activeThumbColor: const Color(0xFF3D6B5E),
                ),
              ),
            ),

            // الإشعارات مع عداد محمي ضد إعادة الاشتراك المتكررة
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) {
                final uid = auth.user?.id;
                return _drawerItem(
                  context,
                  icon: Icons.notifications_outlined,
                  label: 'الإشعارات',
                  trailing: (uid == null || uid.isEmpty || auth.isGuest)
                      ? null
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _getUnreadStream(uid),
                          builder: (_, snap) {
                            final count = snap.data?.docs.length ?? 0;
                            if (count <= 0) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  },
                );
              },
            ),

            // عن التطبيق
            _drawerItem(
              context,
              icon: Icons.info_outline,
              label: 'عن التطبيق',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),

            const Spacer(),
            const Divider(height: 1),

            // تسجيل الخروج
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) => _drawerItem(
                context,
                icon: Icons.logout,
                label: 'تسجيل الخروج',
                iconColor: Colors.red,
                labelColor: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  await ctx.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? labelColor,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: iconColor ?? const Color(0xFF3D6B5E), size: 22),
      title: Text(
        label,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: labelColor),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 8,
    );
  }
}
