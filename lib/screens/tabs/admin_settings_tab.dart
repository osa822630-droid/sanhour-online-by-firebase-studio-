// lib/screens/tabs/admin_settings_tab.dart
// ✅ إعادة كتابة كاملة — إزالة comment الـ placeholder وإصلاح كل الوظائف
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_seeder.dart';
import '../../services/api_service.dart';
import '../seeder_screen.dart';
import '../../utils/constants.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _bannerController = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  final _aboutUsCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _privacyCtrl = TextEditingController();

  bool _isKeyVisible = false;
  bool _isLoading = false;
  bool _isSeeding = false;
  bool _isCleaning = false;
  bool _isSendingNotif = false;

  // إشعارات مستهدفة
  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  String _notifTarget = 'all';

  // التحديث الإجباري
  final _updateVersionCtrl = TextEditingController();
  final _updateMessageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _bannerController.dispose();
    _geminiKeyCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    _updateVersionCtrl.dispose();
    _updateMessageCtrl.dispose();
    _aboutUsCtrl.dispose();
    _termsCtrl.dispose();
    _privacyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await ApiService.getAppSettings();
      // ✅ Fix #17: المفتاح من settings_private. ولو بقيت نسخة قديمة في
      // settings/general (لم تُنقل بعد) تُعرَض هنا ليحفظها الأدمن فتُنقل
      // وتُمسح من الوثيقة العامة.
      var geminiKey = '';
      try {
        geminiKey = await ApiService.getGeminiApiKey();
      } catch (e) {
        debugPrint('loadGeminiKey error: $e');
      }
      if (geminiKey.isEmpty) geminiKey = data['geminiApiKey'] ?? '';
      if (mounted) {
        setState(() {
          _phoneController.text = data['supportPhone'] ?? '';
          _whatsappController.text = data['whatsapp'] ?? '';
          _bannerController.text = data['globalBanner'] ?? '';
          _geminiKeyCtrl.text = geminiKey;
          _aboutUsCtrl.text = data['aboutUs'] ?? '';
          _termsCtrl.text = data['termsAndConditions'] ?? '';
          _privacyCtrl.text = data['privacyPolicy'] ?? '';
          // ✅ تحميل إعدادات التحديث الإجباري الموجودة
          _updateVersionCtrl.text = data['minRequiredVersion'] ?? '';
          _updateMessageCtrl.text = data['updateMessage'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('loadSettings error: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.updateAppSettings({
        'supportPhone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'globalBanner': _bannerController.text.trim(),
        'aboutUs': _aboutUsCtrl.text.trim(),
        'termsAndConditions': _termsCtrl.text.trim(),
        'privacyPolicy': _privacyCtrl.text.trim(),
      });
      // ✅ Fix #17: مفتاح Gemini في settings_private/gemini — لا يُكتب في
      // settings/general المقروءة للعالم ولا يُنسخ في audit log مع الإعدادات
      await ApiService.saveGeminiApiKey(_geminiKeyCtrl.text.trim());
      if (!mounted) return;
      _showSnackBar('تم حفظ الإعدادات بنجاح ✅', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('حدث خطأ أثناء الحفظ', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── إرسال إشعار مستهدف — يُخزَّن في Firestore ─────────────────────────────
  Future<void> _sendTargetedNotification() async {
    if (_notifTitleCtrl.text.trim().isEmpty ||
        _notifBodyCtrl.text.trim().isEmpty) {
      _showSnackBar('العنوان والنص مطلوبان', Colors.red);
      return;
    }
    setState(() => _isSendingNotif = true);
    try {
      // ✅ Fix #7: إضافة expiresAt و data channel للـ notification_queue
      await FirebaseFirestore.instance.collection('notification_queue').add({
        'topic': _notifTarget,
        'title': _notifTitleCtrl.text.trim(),
        'body': _notifBodyCtrl.text.trim(),
        'data': {
          'channel': 'admin_broadcast',
          'route': 'notifications',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24))),
      });

      if (!mounted) return;
      _notifTitleCtrl.clear();
      _notifBodyCtrl.clear();
      _showSnackBar('✅ تم إرسال الإشعار بنجاح إلى: $_notifTarget',
          Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('حدث خطأ أثناء الإرسال', Colors.red);
    } finally {
      if (mounted) setState(() => _isSendingNotif = false);
    }
  }

  Future<void> _updateSeason(String season) async {
    try {
      await ApiService.updateAppSettings({'season': season});
      if (!mounted) return;
      _showSnackBar('تم تفعيل ثيم "$season" بنجاح', Colors.deepPurple);
    } catch (_) {}
  }

  Future<void> _sendForceUpdate() async {
    if (_updateVersionCtrl.text.trim().isEmpty) {
      _showSnackBar('أدخل رقم الإصدار المطلوب', Colors.red);
      return;
    }
    try {
      await ApiService.updateAppSettings({
        'forceUpdate': true,
        'minRequiredVersion': _updateVersionCtrl.text.trim(),
        'updateMessage': _updateMessageCtrl.text.trim().isNotEmpty
            ? _updateMessageCtrl.text.trim()
            : 'يرجى تحديث التطبيق للاستمرار.',
      });
      if (!mounted) return;
      _showSnackBar('✅ تم تفعيل التحديث الإجباري',
          Colors.deepOrangeAccent);
    } catch (_) {}
  }

  Future<void> _disableForceUpdate() async {
    try {
      await ApiService.updateAppSettings({
        'forceUpdate': false,
        'minRequiredVersion': '',
      });
      if (!mounted) return;
      _showSnackBar('✅ تم إلغاء التحديث الإجباري', Colors.green);
    } catch (_) {}
  }

  // ✅ يفتح SeederScreen الجديدة بدلاً من استدعاء DatabaseSeeder.seedDatabase() مباشرة
  // — تُعرض التقدم لكل مرحلة مع نسبة مئوية وسجل تفاصيل
  Future<void> _seedDatabase() async {
    // ✅ إصلاح مشكلة #5
    if (!BuildFlags.mockModeEnabled) {
      _showSnackBar('غير متاح في بيئة الإنتاج', Colors.orange);
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeederScreen()),
    );
  }

  Future<void> _cleanDatabase() async {
    final ok = await _confirm(
      title: '⚠️ تحذير خطير',
      content:
          'سيُحذف كل المحتوى (محلات، منتجات، فئات، عروض، إعلانات، تقييمات، خدمات، وظائف، قوائم الديلر، طلبات الخدمة) نهائياً. لن تُحذف حسابات المستخدمين ولا الإعدادات ولا أكواد التفعيل. هل أنت متأكد؟',
      confirmText: 'نعم، احذف كل شيء',
      isDanger: true,
    );
    if (ok != true) return;
    setState(() => _isCleaning = true);
    try {
      await DatabaseSeeder.cleanDatabase();
      if (!mounted) return;
      _showSnackBar('🗑️ تم تنظيف قاعدة البيانات بنجاح!',
          Colors.deepOrangeAccent);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ فشل التنظيف: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String content,
    required String confirmText,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                color: isDanger ? Colors.red : null)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? Colors.red : Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E1A) : Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── معلومات التواصل ───────────────────────────────────────
            _sectionTitle('معلومات التواصل العامة',
                'هذه الأرقام تظهر للمستخدمين في صفحة "تواصل معنا"',
                Icons.contact_phone),
            _cardWrap(isDark, [
              _buildTextField(
                  'رقم الدعم الفني (اتصال)',
                  Icons.phone,
                  _phoneController),
              const SizedBox(height: 14),
              _buildTextField(
                  'رقم الواتساب',
                  Icons.message,
                  _whatsappController),
            ]),

            const SizedBox(height: 24),

            // ── إعدادات Gemini ──────────────────────────────────────
            _sectionTitle(
                'إعدادات الذكاء الاصطناعي',
                'مفتاح Gemini API لتشغيل ميزات الذكاء الاصطناعي',
                Icons.auto_awesome),
            _cardWrap(isDark, [
              StatefulBuilder(
                builder: (ctx, setLS) => TextField(
                  controller: _geminiKeyCtrl,
                  obscureText: !_isKeyVisible,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'AIza...',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isKeyVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _isKeyVisible = !_isKeyVisible),
                    ),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // ── بانر عام ───────────────────────────────────────────
            _sectionTitle(
                'إعلان شريط البانر',
                'رسالة تظهر في أعلى الصفحة الرئيسية (فارغة = مخفي)',
                Icons.campaign),
            _cardWrap(isDark, [
              TextField(
                controller: _bannerController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة',
                  hintText:
                      'مثال: سيتوقف التطبيق عن العمل يوم الجمعة للصيانة...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.announcement_outlined),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // ── ثيم المناسبات ───────────────────────────────────────
            _sectionTitle('ثيم التطبيق والمناسبات 🎨',
                'اختر مظهراً يظهر لجميع المستخدمين',
                Icons.palette_outlined),
            _cardWrap(isDark, [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settings')
                    .doc('general')
                    .snapshots(),
                builder: (ctx, snap) {
                  String current = 'none';
                  if (snap.hasData && snap.data!.exists) {
                    current =
                        (snap.data!.data() as Map?)
                            ?['season'] as String? ??
                        'none';
                  }
                  return DropdownButtonFormField<String>(
                    // ✅ إصلاح API قديم: value مُهملة لصالح initialValue (Flutter 3.32+)
                    initialValue: current,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.celebration_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'none',
                          child: Text('الافتراضي (بدون زينة)')),
                      DropdownMenuItem(
                          value: 'ramadan',
                          child: Text('شهر رمضان 🌙 (فوانيس)')),
                      DropdownMenuItem(
                          value: 'eid_fitr',
                          child: Text('عيد الفطر 🎈 (بلالين)')),
                      DropdownMenuItem(
                          value: 'eid_adha',
                          child: Text('عيد الأضحى 🐑 (خروف)')),
                    ],
                    onChanged: (val) {
                      if (val != null) _updateSeason(val);
                    },
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ── نصوص التطبيق (من نحن / شروط / خصوصية) ───────────────
            const SizedBox(height: 24),
            _sectionTitle(
                'نصوص التطبيق',
                'هذه النصوص تظهر للمستخدمين في الإعدادات',
                Icons.article_outlined),
            _cardWrap(isDark, [
              _buildTextArea(
                label: 'من نحن',
                icon: Icons.people_outline,
                controller: _aboutUsCtrl,
                hint: 'اكتب وصفاً للتطبيق...',
              ),
              const SizedBox(height: 14),
              _buildTextArea(
                label: 'الشروط والأحكام',
                icon: Icons.description_outlined,
                controller: _termsCtrl,
                hint: 'اكتب شروط الاستخدام...',
              ),
              const SizedBox(height: 14),
              _buildTextArea(
                label: 'سياسة الخصوصية',
                icon: Icons.privacy_tip_outlined,
                controller: _privacyCtrl,
                hint: 'اكتب سياسة الخصوصية...',
              ),
            ]),

            const SizedBox(height: 24),
            // ── زر الحفظ ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
            _divider(),
            const SizedBox(height: 24),

            // ── إشعارات مستهدفة ─────────────────────────────────────
            _sectionTitle('إشعار مستهدف',
                'أرسل إشعاراً فورياً لفئة محددة من المستخدمين',
                Icons.notifications_active,
                color: Colors.deepPurple),
            _cardWrap(isDark, [
              TextField(
                controller: _notifTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notifBodyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نص الإشعار *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text('المستهدف:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'all',
                        label: Text('الجميع'),
                        icon: Icon(Icons.group)),
                    ButtonSegment(
                        value: 'merchants',
                        label: Text('التجار'),
                        icon: Icon(Icons.store)),
                    ButtonSegment(
                        value: 'customers',
                        label: Text('العملاء'),
                        icon: Icon(Icons.person)),
                  ],
                  selected: {_notifTarget},
                  onSelectionChanged: (s) =>
                      setState(() => _notifTarget = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Colors.deepPurple,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSendingNotif ? null : _sendTargetedNotification,
                  icon: _isSendingNotif
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(
                      _isSendingNotif ? 'جاري الإرسال...' : 'إرسال الإشعار'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white),
                ),
              ),
            ]),

            const SizedBox(height: 32),
            _divider(),
            const SizedBox(height: 24),

            // ── التحديث الإجباري ─────────────────────────────────────
            _sectionTitle('التحديث الإجباري',
                'ألزم المستخدمين بتحديث التطبيق لإصدار محدد',
                Icons.system_update_alt,
                color: Colors.deepOrangeAccent),
            _cardWrap(isDark, [
              TextField(
                controller: _updateVersionCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الإصدار المطلوب (مثال: 1.2.0)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.new_releases_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _updateMessageCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'رسالة التحديث (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendForceUpdate,
                    icon: const Icon(Icons.lock_clock),
                    label: const Text('تفعيل'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                        foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disableForceUpdate,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('إلغاء'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey),
                  ),
                ),
              ]),
            ]),

            const SizedBox(height: 32),
            _divider(),
            const SizedBox(height: 24),

            // ── أدوات المطور ─────────────────────────────────────────
            _sectionTitle(
                'Developer Tools',
                'أدوات خطرة — للمطورين فقط',
                Icons.developer_mode,
                color: Colors.red[700]!),
            _cardWrap(isDark, [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSeeding || _isCleaning ? null : _seedDatabase,
                  icon: _isSeeding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.data_usage),
                  label: Text(_isSeeding
                      ? 'جارٍ إضافة البيانات...'
                      : 'إضافة بيانات وهمية (Seed)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSeeding || _isCleaning
                        ? Colors.grey
                        : Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSeeding || _isCleaning ? null : _cleanDatabase,
                  icon: _isCleaning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_forever),
                  label: Text(_isCleaning
                      ? 'جارٍ تنظيف البيانات...'
                      : 'تنظيف قاعدة البيانات (Clean)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSeeding || _isCleaning
                        ? Colors.grey
                        : Colors.deepOrangeAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── مساعدات UI ────────────────────────────────────────────────────────────

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon, {
    Color? color,
  }) {
    final c = color ?? const Color(0xFF5E35B1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardWrap(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _divider() => Container(
        height: 1,
        color: Colors.grey.withValues(alpha: 0.2),
      );

  Widget _buildTextField(
      String label, IconData icon, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTextArea({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(icon),
        ),
      ),
    );
  }
}
