// lib/screens/options_screen.dart
// ✅ إضافة: دليل الاستخدام → يعود للـ OnboardingScreen
// ✅ إضافة: شكاواي → MyComplaintsScreen
// ✅ باقي الكود بدون تغيير
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import 'merchant_dashboard.dart';
import 'admin_dashboard.dart';
import 'report_problem_screen.dart';
import 'my_complaints_screen.dart';
import 'login_screen.dart';
import 'account_edit_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/gemini_chat_button.dart';
import '../services/gemini_service.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  bool _showStartupAds = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadAdsPreference();
  }

  Future<void> _loadAdsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showStartupAds = prefs.getBool('show_startup_ads') ?? true);
  }

  Future<void> _toggleAdsPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_startup_ads', value);
    if (!mounted) return;
    setState(() => _showStartupAds = value);
  }

  Future<void> _performSoftDelete(
      BuildContext dialogContext, app_auth.AuthProvider authProvider) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final deletionDate = DateTime.now().add(const Duration(days: 15));

      batch.update(firestore.collection('users').doc(user.uid), {
        'isDeleted': true,
        'scheduledForDeletionAt': Timestamp.fromDate(deletionDate),
        'isActive': false,
      });

      if (authProvider.userRole == app_auth.UserRole.merchant) {
        final shopsQ = await firestore
            .collection('shops')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        for (final doc in shopsQ.docs) {
          batch.update(doc.reference, {
            'isActive': false,
            'hiddenByDeletion': true,
          });
        }
      }

      await batch.commit();
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      await authProvider.logout();
      if (!mounted) return;
      if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدث خطأ، يُرجى المحاولة مرة أخرى'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والخيارات',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildUserStatusSection(context, authProvider),

          // ── لوحات التحكم ──────────────────────────────────────
          if (authProvider.userRole == app_auth.UserRole.admin ||
              authProvider.userRole == app_auth.UserRole.merchant) ...[
            _sectionTitle('لوحات التحكم'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                if (authProvider.userRole == app_auth.UserRole.admin)
                  Expanded(
                    child: _dashBtn(
                      icon: Icons.admin_panel_settings,
                      label: 'لوحة الإدارة',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AdminDashboard())),
                    ),
                  ),
                if (authProvider.userRole == app_auth.UserRole.admin)
                  const SizedBox(width: 12),
                if (authProvider.userRole == app_auth.UserRole.merchant)
                  Expanded(
                    child: _dashBtn(
                      icon: Icons.store,
                      label: 'لوحة التاجر',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const MerchantDashboard())),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          // ── المظهر ───────────────────────────────────────────
          _sectionTitle('المظهر والإعدادات'),
          _card([
            SwitchListTile(
              title: const Text('الوضع الليلي',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              secondary: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny,
                color: isDark ? Colors.yellow : Colors.orange,
              ),
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeColor: Colors.deepPurple,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('إعلانات عند فتح التطبيق',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('عرض أحدث العروض عند بدء التطبيق',
                  style: TextStyle(fontSize: 12)),
              secondary: const Icon(Icons.campaign, color: Colors.deepPurple),
              value: _showStartupAds,
              onChanged: _toggleAdsPreference,
              activeColor: Colors.deepPurple,
            ),
          ]),

          // ── الدعم والمساعدة ──────────────────────────────────
          _sectionTitle('الدعم والمساعدة'),
          _card([
            // ✅ دليل الاستخدام → OnboardingScreen
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined,
                  color: Colors.deepPurple),
              title: const Text('دليل الاستخدام',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('تعرّف على مميزات التطبيق وكيفية استخدامه',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(fromSettings: true),
                ),
              ),
            ),
            const Divider(height: 1),
            // Gemini
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF4527A0),
                    Color(0xFF7B1FA2)
                  ]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              title: const Text('مساعد سنهور الذكي',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('اسأل أي سؤال عن التطبيق',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
              onTap: () {
                final auth = context.read<app_auth.AuthProvider>();
                GeminiUserType userType;
                switch (auth.userRole) {
                  case app_auth.UserRole.admin:
                    userType = GeminiUserType.admin;
                    break;
                  case app_auth.UserRole.merchant:
                    userType = GeminiUserType.merchant;
                    break;
                  default:
                    userType = GeminiUserType.customer;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => GeminiChatSheet(userType: userType),
                );
              },
            ),
            const Divider(height: 1),
            // الإبلاغ عن مشكلة
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.orange),
              title: const Text('إرسال شكوى أو اقتراح'),
              subtitle: const Text('واجهت مشكلة؟ أخبرنا لنصلحها',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ReportProblemScreen())),
            ),
            // ✅ متابعة الشكاوى السابقة
            if (!authProvider.isGuest) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.inbox_outlined,
                    color: Colors.deepPurple),
                title: const Text('شكاواي واقتراحاتي'),
                subtitle: const Text('تتبع ردود الإدارة على رسائلك',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const MyComplaintsScreen())),
              ),
            ],
          ]),

          // ── معلومات التطبيق ──────────────────────────────────
          _sectionTitle('معلومات التطبيق'),
          _card([
            _infoTile('من نحن', Icons.people_outline, 'aboutUs'),
            const Divider(height: 1),
            _infoTile(
                'الشروط والأحكام', Icons.description_outlined, 'termsAndConditions'),
            const Divider(height: 1),
            _infoTile(
                'سياسة الخصوصية', Icons.privacy_tip_outlined, 'privacyPolicy'),
          ]),

          // ── الحساب ───────────────────────────────────────────
          _sectionTitle('الحساب'),
          _card([
            if (!authProvider.isGuest) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: Colors.deepPurple),
                title: const Text('تعديل الحساب'),
                subtitle: const Text('الاسم، الصورة، اسم المستخدم',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AccountEditScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: () => _showLogoutDialog(context, authProvider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever,
                    color: Colors.grey),
                title: const Text('حذف الحساب',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('يُحذف نهائياً بعد 15 يوماً',
                    style: TextStyle(fontSize: 10)),
                onTap: () =>
                    _showDeleteAccountDialog(context, authProvider),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login, color: Colors.deepPurple),
                title: const Text('تسجيل الدخول / إنشاء حساب'),
                onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false),
              ),
          ]),

          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, s) => Center(
              child: Text(
                'الإصدار ${s.data?.version ?? '1.0.0'}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '© ٢٠٢٦ سنهور أونلاين — جميع الحقوق محفوظة',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── مساعدات UI ────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey)),
      );

  Widget _card(List<Widget> children) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      );

  Widget _dashBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.deepPurple, size: 22),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.deepPurple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, IconData icon, String fieldKey) =>
      ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FirestoreTextScreen(
              title: label,
              fieldKey: fieldKey,
              icon: icon,
            ),
          ),
        ),
      );

  Widget _buildUserStatusSection(
      BuildContext context, app_auth.AuthProvider auth) {
    if (auth.isGuest) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.deepPurple.withValues(alpha: 0.08),
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person_off, color: Colors.white),
          ),
          title: const Text('أنت تتصفح كضيف',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('سجّل دخولك للاستفادة من كل المميزات'),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false),
            child: const Text('دخول'),
          ),
        ),
      );
    }

    String roleLabel;
    IconData roleIcon;
    switch (auth.userRole) {
      case app_auth.UserRole.admin:
        roleLabel = 'مدير النظام 🛡️';
        roleIcon = Icons.admin_panel_settings;
        break;
      case app_auth.UserRole.merchant:
        roleLabel = 'تاجر 🏪';
        roleIcon = Icons.store;
        break;
      default:
        roleLabel = 'عميل 👤';
        roleIcon = Icons.person;
    }

    final photoUrl = auth.user?.profileImageUrl;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const AccountEditScreen())),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.deepPurple,
              backgroundImage:
                  (photoUrl?.isNotEmpty == true)
                      ? NetworkImage(photoUrl!)
                      : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      auth.user?.name.isNotEmpty == true
                          ? auth.user!.name[0].toUpperCase()
                          : 'م',
                      style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.user?.name ?? 'مستخدم',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(auth.user?.phone ?? '',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(roleIcon, size: 12, color: Colors.deepPurple),
                    const SizedBox(width: 4),
                    Text(roleLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.deepPurple, size: 20),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const AccountEditScreen())),
          ),
        ]),
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context, app_auth.AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context, app_auth.AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب نهائياً',
            style: TextStyle(color: Colors.red)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيُعطَّل حسابك فوراً وستُحذف بياناتك بعد 15 يوماً.'),
            SizedBox(height: 8),
            Text(
              'يمكنك الاسترداد بتسجيل الدخول قبل انتهاء المهلة.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: _isDeleting
                ? null
                : () => _performSoftDelete(ctx, auth),
            child: _isDeleting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// شاشة النص من Firestore (من نحن / شروط / خصوصية)
// ════════════════════════════════════════════════════════════════════
class _FirestoreTextScreen extends StatelessWidget {
  final String title;
  final String fieldKey;
  final IconData icon;
  const _FirestoreTextScreen(
      {required this.title,
      required this.fieldKey,
      required this.icon});

  String _defaultContent() {
    switch (fieldKey) {
      case 'aboutUs':
        return 'سنهور أونلاين هو دليل شامل يجمع كل محلات وخدمات سنهور القبلية في مكان واحد.\n\n📍 الفيوم — سنهور القبلية، مصر';
      case 'termsAndConditions':
        return 'يُمنع نشر أي محتوى مسيء أو مضلل.\n\nيحق للإدارة إيقاف أي حساب يخالف السياسة.\n\nالتطبيق غير مسؤول عن المعاملات خارجه.';
      case 'privacyPolicy':
        return 'نحن نحترم خصوصيتك ولا نشارك بياناتك.\n\nنستخدم بياناتك لتحسين تجربتك فقط.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('settings')
            .doc('general')
            .get(),
        builder: (_, snap) {
          String content = '';
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>?;
            content = data?[fieldKey] as String? ?? '';
          }
          if (content.isEmpty) content = _defaultContent();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5E35B1), Color(0xFF3949AB)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)
                  ],
                ),
                child: Text(content,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: isDark
                            ? Colors.grey[300]
                            : Colors.grey[800])),
              ),
            ]),
          );
        },
      ),
    );
  }
}
