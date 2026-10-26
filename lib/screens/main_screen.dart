// lib/screens/main_screen.dart
// ✅ Tab الإعلانات → AdsHubScreen (مركز شامل: إعلانات + وظائف + خدمات)
import 'package:flutter/material.dart';
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
  // ✅ Fix #28: ترتيب التابات في الـ NavigationBar (نفس ترتيب _screens تحت)
  static const int homeTab = 0;
  static const int favoritesTab = 1;
  static const int offersTab = 2;

  /// التاب اللي الشاشة بتفتح عليه — الراوتس /favorites و/offers بتمرّره.
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = homeTab});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    // أي رقم خارج نطاق التابات بيرجع للرئيسية بدل ما يكسر IndexedStack
    final index = widget.initialIndex;
    _selectedIndex =
        (index >= 0 && index < _screens.length) ? index : MainScreen.homeTab;
  }

  // ✅ AdsHubScreen بدلاً من AllAdsScreen
  static const List<Widget> _screens = [
    HomeScreen(),
    FavoritesScreen(),
    OffersScreen(),
    CategoriesScreen(),
    SanhourDealerScreen(),
    AdsHubScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

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
          children: _screens,
        ),
        floatingActionButton: const GeminiChatButton(),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.startFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor:
              isDark ? const Color(0xFF1F1F1F) : Colors.white,
          indicatorColor:
              Colors.deepPurple.withValues(alpha: 0.15),
          surfaceTintColor: Colors.transparent,
          height: 62,
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon:
                  Icon(Icons.home, color: Colors.deepPurple),
              label: 'الرئيسية',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon:
                  Icon(Icons.favorite, color: Colors.deepPurple),
              label: 'المفضلة',
            ),
            const NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer,
                  color: Colors.deepPurple),
              label: 'العروض',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view,
                  color: Colors.deepPurple),
              label: 'الفئات',
            ),
            NavigationDestination(
              icon: DealerIcon(
                size: 22,
                color: _selectedIndex == 4
                    ? Colors.deepPurple
                    : isDark
                        ? Colors.grey[400]!
                        : Colors.grey[600]!,
              ),
              selectedIcon:
                  DealerIcon(size: 22, color: Colors.deepPurple),
              label: 'ديلر',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.campaign_outlined,
                color: _selectedIndex == 5
                    ? Colors.deepPurple
                    : isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
              ),
              selectedIcon: const Icon(Icons.campaign,
                  color: Colors.deepPurple),
              label: 'مركز',
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
      backgroundColor:
          isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── هيدر المستخدم ────────────────────────────────────
            Consumer<AuthProvider>(
              builder: (ctx, auth, _) => Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5E35B1), Color(0xFF3949AB)],
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
                              (auth.user?.profileImageUrl ?? '')
                                      .isNotEmpty
                                  ? NetworkImage(
                                      auth.user!.profileImageUrl!)
                                  : null,
                          child:
                              (auth.user?.profileImageUrl ?? '').isEmpty
                                  ? (auth.user?.name.isNotEmpty == true
                                      ? Text(
                                          // ✅ Fix #111: حماية من RangeError
                                          auth.user!.name[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight:
                                                  FontWeight.bold),
                                        )
                                      : const Icon(Icons.person,
                                          color: Colors.white,
                                          size: 30))
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
                                    size: 12,
                                    color: Color(0xFF5E35B1)),
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
                                builder: (_) =>
                                    const AccountEditScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'تعديل الحساب ✏️',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── عناصر القائمة ────────────────────────────────────

            // الإعدادات
            _drawerItem(
              context,
              icon: Icons.settings_outlined,
              label: 'الإعدادات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OptionsScreen()),
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
                  activeThumbColor: const Color(0xFF5E35B1),
                ),
              ),
            ),

            // ✅ الإشعارات → شاشتها المستقلة
            _drawerItem(
              context,
              icon: Icons.notifications_outlined,
              label: 'الإشعارات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
              },
            ),

            // ✅ عن التطبيق → شاشتها المستقلة
            _drawerItem(
              context,
              icon: Icons.info_outline,
              label: 'عن التطبيق',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AboutScreen()),
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
      leading: Icon(icon,
          color: iconColor ?? const Color(0xFF5E35B1), size: 22),
      title: Text(
        label,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: labelColor),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 8,
    );
  }
}
