// lib/screens/complete_profile_screen.dart
// ✅ Fix #164: كل النصوص مترجمة للعربية
// ✅ Fix #113: validators null-safe بدون force-unwrap
// ✅ Fix #122: messenger مُخزَّنة قبل await لمنع استخدام context غير نشط
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  String _userType = 'customer';

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final error = await auth.completeRegistration(
      _nameController.text.trim(),
      _usernameController.text.trim(),
      _userType,
    );

    if (!mounted) return;

    if (error == null) {
      // ✅ Fix #210: success dialog مع animation بدلاً من SnackBar فقط
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SuccessDialog(),
      );
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال بيانات الحساب'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_alt_1,
                    size: 80, color: Color(0xFF5E35B1)),
                const SizedBox(height: 20),
                const Text(
                  // ✅ Fix #164: نص عربي
                  'أكمل بياناتك للبدء في تجربة سنهور أونلاين!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  // ✅ Fix #113: null-safe validator
                  validator: (val) =>
                      (val == null || val.trim().isEmpty)
                          ? 'الاسم مطلوب'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newUsername],
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'مثال: ahmed_ali',
                    helperText: 'حروف إنجليزية وأرقام وشرطة سفلية فقط.',
                    border: OutlineInputBorder(),
                  ),
                  // ✅ Fix #113: null-safe validator
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'اسم المستخدم مطلوب';
                    if (val.length < 4) return 'اسم المستخدم: 4 أحرف على الأقل';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
                      return 'حروف إنجليزية، أرقام، وشرطة سفلية فقط';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // ✅ Fix #164: نص عربي
                const Text('نوع حسابي:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                RadioGroup<String>(
                  groupValue: _userType,
                  onChanged: (value) =>
                      setState(() => _userType = value!),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('مستخدم / مشتري'),
                        subtitle:
                            const Text('أتصفح المحلات والمنتجات.'),
                        value: 'customer',
                      ),
                      RadioListTile<String>(
                        title: const Text('تاجر / صاحب محل'),
                        subtitle:
                            const Text('أريد فتح محلي وعرض منتجاتي.'),
                        value: 'merchant',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitProfile,
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : const Text('حفظ ومتابعة',
                            style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ Fix #210: Success animation dialog
class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog();

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    // إغلاق تلقائي بعد 1.8 ثانية
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF5E35B1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'تم بنجاح! 🎉',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E35B1)),
              ),
              const SizedBox(height: 8),
              const Text(
                'مرحباً بك في سنهور أونلاين',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
