// lib/screens/login_screen.dart
// ✅ Phase 2 Fix #25: إضافة Form + GlobalKey + AutovalidateMode + Validators.
// قبل الإصلاح: كانت TextFields مجردة بلا Form — الكود يتحقق يدوياً من isEmpty()
// فقط، مما يتيح إرسال مدخلات غير صحيحة (رقم 4 أرقام، كلمة مرور حرف واحد).
// بعد الإصلاح: validators صريحة تمنع الإرسال قبل أن يصل الطلب للـ AuthProvider.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sanhour_online/providers/auth_provider.dart';
import '../services/analytics_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ✅ Fix #25: GlobalKey للـ Form
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  // ✅ تفعيل validation بعد أول محاولة submit فقط — لا تُزعج المستخدم قبلها
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // ✅ Fix #25: تفعيل validation أولاً
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final error = await auth.loginWithPhoneAndPassword(phone, password);

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

  // ── Validators ────────────────────────────────────────────

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    // ✅ Fix #230: قبول أرقام عربية وصيغ دولية (+20 / 0020)
    String trimmed = value.trim().replaceAllMapped(
        RegExp(r'[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - '٠'.codeUnitAt(0)).toString());
    trimmed = trimmed.replaceAll(RegExp(r'[\s\-]'), '');
    // قبول: 01xxxxxxxxx أو +201xxxxxxxxx أو 00201xxxxxxxxx
    if (!RegExp(r'^(\+?20|0020)?01[0-9]{9}$').hasMatch(trimmed)) {
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
            colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── هيدر ──────────────────────────────────────
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront,
                            size: 56, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'سنهور أونلاين',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'أهلاً بك — سجّل دخولك للمتابعة',
                        style:
                            TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              // ── بطاقة الفورم ──────────────────────────────
              Expanded(
                flex: 3,
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
                        padding:
                            const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autovalidateMode,
                          // ✅ AutofillGroup يُمكِّن مديري كلمات المرور من ملء الحقول
                          child: AutofillGroup(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── حقل رقم الهاتف ────────────
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: _validatePhone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  hintText: '01xxxxxxxxx',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone_android),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── حقل كلمة المرور ───────────
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                autofillHints: const [AutofillHints.password],
                                validator: _validatePassword,
                                onFieldSubmitted: (_) =>
                                    isLoading ? null : _login(),
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
                              const SizedBox(height: 24),

                              // ── زر تسجيل الدخول ───────────
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
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
                                      : const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

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
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(
                                        color: Colors.deepPurple),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ), // end AutofillGroup
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
