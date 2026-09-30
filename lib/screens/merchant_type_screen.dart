// lib/screens/merchant_type_screen.dart
// ✅ شاشة اختيار نوع النشاط التجاري: صاحب محل أم مزوّد خدمة
// تظهر عند التسجيل كتاجر وتحدد businessType في Firestore
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'merchant/add_shop_screen.dart';
import 'merchant/add_service_provider_screen.dart';

class MerchantTypeScreen extends StatefulWidget {
  const MerchantTypeScreen({super.key});

  @override
  State<MerchantTypeScreen> createState() => _MerchantTypeScreenState();
}

class _MerchantTypeScreenState extends State<MerchantTypeScreen> {
  String? _selectedType; // 'shop' | 'service_provider'
  bool _isSaving = false;

  Future<void> _continue() async {
    if (_selectedType == null) return;
    if (_isSaving) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      // حفظ businessType مباشرة في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'businessType': _selectedType});
      if (!mounted) return;

      // الانتقال للشاشة المناسبة
      if (_selectedType == 'shop') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AddShopScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const AddServiceProviderScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('حدث خطأ، حاول مرة أخرى.'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('نوع نشاطك التجاري',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'أخبرنا عن نشاطك لنُهيِّئ لك التجربة المناسبة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // ── بطاقة صاحب المحل ─────────────────────────────────
            _TypeCard(
              icon: Icons.storefront_outlined,
              title: 'صاحب محل تجاري',
              description: 'لديك محل في سنهور، وتريد عرض منتجاتك وعروضك للزبائن.',
              examples: [
                'محل ملابس، بقالة، صيدلية',
                'كافيه، مطعم، مخبزة',
                'محل إلكترونيات، أثاث، مواد بناء',
              ],
              iconColor: Colors.deepPurple,
              isSelected: _selectedType == 'shop',
              onTap: () => setState(() => _selectedType = 'shop'),
            ),

            const SizedBox(height: 16),

            // ── بطاقة مزوّد الخدمة ───────────────────────────────
            _TypeCard(
              icon: Icons.handyman_outlined,
              title: 'مزوّد خدمة متنقّل',
              description:
                  'تقدم خدمة في منازل العملاء أو لا يوجد لديك محل ثابت.',
              examples: [
                'كهربائي، سباك، نجار، دهان',
                'مدرّس خصوصي، مصوّر، مبرمج',
                'غسيل سيارات، تصليح موبايل متنقل',
              ],
              iconColor: Colors.teal,
              isSelected: _selectedType == 'service_provider',
              onTap: () =>
                  setState(() => _selectedType = 'service_provider'),
            ),

            const SizedBox(height: 40),

            // زر المتابعة
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    _selectedType == null || _isSaving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('متابعة',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة نوع النشاط ─────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> examples;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.examples,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? iconColor
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? iconColor : null)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: examples.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(e,
                            style: TextStyle(
                                fontSize: 11, color: iconColor)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // مؤشر الاختيار
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? iconColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? iconColor : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
