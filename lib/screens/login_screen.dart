// lib/screens/login_screen.dart
// ✅ Phase 2 Fix #25: إضافة Form + GlobalKey + AutovalidateMode + Validators.
// ✅ Pre-Launch Fix: دعم التبديل السلس بين تسجيل الدخول وإنشاء حساب جديد (زبون / تاجر) + كود الدعوة + استعادة كلمة المرور الفعالة
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sanhour_online/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _isRegisterMode = false;
  String _selectedUserType = 'customer';
  bool _isPasswordVisible = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    String? error;
    if (_isRegisterMode) {
      error = await auth.registerWithPhoneAndPassword(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        phone: phone,
        password: password,
        userType: _selectedUserType,
        referralCode: _referralCodeController.text.trim().isNotEmpty
            ? _referralCodeController.text.trim()
            : null,
      );
    } else {
      error = await auth.loginWithPhoneAndPassword(phone, password);
    }

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final userType = auth.user?.userType ?? 'unknown';
      AnalyticsService().logUserLogin(userType);
      AnalyticsService()
          .setUserProperties(userType: userType, userId: auth.user?.id);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _loginAsGuest(AuthProvider auth) async {
    await auth.loginAsGuest();
    if (!mounted) return;
    AnalyticsService().logUserLogin('guest');
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ✅ استعادة كلمة المرور: عبر البريد الحقيقي أو التواصل الفوري عبر واتساب الإدارة لحسابات الهاتف
  Future<void> _showForgotPasswordDialog() async {
    final phoneOrEmailCtrl =
        TextEditingController(text: _phoneController.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل رقم الهاتف المسجّل للتواصل المباشر مع دعم سنهور أونلاين لإعادة تعيين كلمة المرور، أو أدخل بريدك الإلكتروني إن كان حسابك مسجلاً ببريد إلكتروني:',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneOrEmailCtrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف أو البريد الإلكتروني',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D6B5E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('متابعة'),
            onPressed: () async {
              final input = phoneOrEmailCtrl.text.trim();
              if (input.isEmpty) {
                return;
              }
              if (input.contains('@') &&
                  !input.endsWith('@users.sanhour.online') &&
                  !input.endsWith('@sanhour.online')) {
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: input);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (_) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'تعذّر إرسال البريد الإلكتروني. تحقق من صحة البريد أو تواصل مع الإدارة.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              // حساب رقم هاتف: جلب رقم واتساب الدعم من الإعدادات وفتح محادثة جاهزة
              final normalizedPhone = AppConstants.normalizePhone(input);
              String supportWhatsapp = '';
              try {
                final settingsDoc = await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('general')
                    .get();
                final data = settingsDoc.data() ?? {};
                supportWhatsapp = (data['whatsapp'] ??
                        data['supportWhatsapp'] ??
                        data['supportPhone'] ??
                        data['phone'] ??
                        '')
                    .toString()
                    .trim();
              } catch (_) {}

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (supportWhatsapp.isNotEmpty) {
                final waPhone =
                    AppConstants.normalizeWhatsAppPhone(supportWhatsapp);
                final msg = Uri.encodeComponent(
                    'مرحباً إدارة سنهور أونلاين، أرغب في إعادة تعيين كلمة المرور لحسابي المسجل برقم الهاتف: $normalizedPhone');
                final uri = Uri.parse('https://wa.me/$waPhone?text=$msg');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return;
                }
              }

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'لإعادة تعيين كلمة سر حساب الهاتف، يرجى التواصل مع إدارة سنهور أونلاين وتزويدهم برقم هاتفك المسجل.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
    ).whenComplete(() => phoneOrEmailCtrl.dispose());
  }

  // ── Validators ────────────────────────────────────────────

  String? _validateName(String? value) {
    if (!_isRegisterMode) return null;
    if (value == null || value.trim().length < 3) {
      return 'أدخل الاسم الكامل (3 أحرف على الأقل)';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (!_isRegisterMode) return null;
    if (value == null || value.trim().isEmpty) {
      return 'اسم المستخدم مطلوب';
    }
    final clean = value.trim();
    if (clean.length < 4) {
      return 'اسم المستخدم يجب أن يكون 4 أحرف على الأقل';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      return 'حروف إنجليزية وأرقام وشرطة سفلية (_) فقط';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    final normalized = AppConstants.normalizePhoneToLocal(value);
    if (!RegExp(r'^01[0-9]{9}$').hasMatch(normalized)) {
      return 'أدخل رقم هاتف مصري صحيح (11 رقم يبدأ بـ 01)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'كلمة المرور مطلوبة';
    }
    if (value.trim().length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0xFF26483F), Color(0xFF3D6B5E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── هيدر ──────────────────────────────────────
              Expanded(
                flex: _isRegisterMode ? 1 : 2,
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withValues(alpha: 0.15),
                                child: const Icon(Icons.storefront,
                                    size: 48, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'سنهور أونلاين',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegisterMode
                              ? 'أنشئ حسابك الجديد في ثوانٍ'
                              : 'أهلاً بك — سجّل دخولك للمتابعة',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── بطاقة الفورم ──────────────────────────────
              Expanded(
                flex: _isRegisterMode ? 4 : 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final isLoading =
                          auth.status == AuthStatus.authenticating;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autovalidateMode,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isRegisterMode) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.name],
                                    validator: _validateName,
                                    decoration: const InputDecoration(
                                      labelText: 'الاسم الكامل',
                                      hintText: 'مثال: أحمد محمد',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _usernameController,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    autofillHints: const [
                                      AutofillHints.newUsername
                                    ],
                                    validator: _validateUsername,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم المستخدم (بالإنجليزي)',
                                      hintText: 'مثال: ahmed_sanhour',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.alternate_email),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // ── حقل رقم الهاتف ────────────
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9٠-٩\+\-\s]')),
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  validator: _validatePhone,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الهاتف',
                                    hintText: '01xxxxxxxxx',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.phone_android),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // ── حقل كلمة المرور ───────────
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  autofillHints: const [AutofillHints.password],
                                  validator: _validatePassword,
                                  onFieldSubmitted: (_) =>
                                      isLoading ? null : _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(_isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible =
                                              !_isPasswordVisible),
                                    ),
                                  ),
                                ),
                                if (!_isRegisterMode)
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: TextButton(
                                      onPressed: isLoading
                                          ? null
                                          : _showForgotPasswordDialog,
                                      child: const Text(
                                        'نسيت كلمة المرور؟',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),

                                if (_isRegisterMode) ...[
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _referralCodeController,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.done,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      labelText: 'كود الدعوة (اختياري)',
                                      hintText: 'مثال: SAN-AB12CD',
                                      border: OutlineInputBorder(),
                                      prefixIcon:
                                          Icon(Icons.card_giftcard_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ChoiceChip(
                                          label: const Text('مشتري / زبون'),
                                          selected:
                                              _selectedUserType == 'customer',
                                          onSelected: (v) {
                                            if (v) {
                                              setState(() => _selectedUserType =
                                                  'customer');
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ChoiceChip(
                                          label: const Text('تاجر / صاحب محل'),
                                          selected:
                                              _selectedUserType == 'merchant',
                                          onSelected: (v) {
                                            if (v) {
                                              setState(() => _selectedUserType =
                                                  'merchant');
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 20),

                                // ── زر تسجيل الدخول / إنشاء الحساب ───────────
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3D6B5E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : Text(
                                            _isRegisterMode
                                                ? 'إنشاء الحساب'
                                                : 'تسجيل الدخول',
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // ── التبديل بين الدخول والتسجيل ───────────
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isRegisterMode = !_isRegisterMode;
                                            _autovalidateMode =
                                                AutovalidateMode.disabled;
                                          });
                                        },
                                  child: Text(
                                    _isRegisterMode
                                        ? 'لديك حساب بالفعل؟ سجّل دخولك'
                                        : 'ليس لديك حساب؟ إنشاء حساب جديد',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // ── زر الدخول كزائر ───────────
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : () => _loginAsGuest(auth),
                                    icon: const Icon(Icons.person_outline),
                                    label: const Text('تصفح كزائر'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF73A899)
                                          : const Color(0xFF3D6B5E),
                                      side: BorderSide(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF73A899)
                                              : const Color(0xFF3D6B5E),
                                          width: 1.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
