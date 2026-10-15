// lib/screens/merchant/merchant_marketing_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/media_upload_service.dart';
import '../../models/shop.dart';
import '../../widgets/cached_image.dart';

class MerchantMarketingTab extends StatefulWidget {
  final Shop currentShop;

  const MerchantMarketingTab({super.key, required this.currentShop});

  @override
  State<MerchantMarketingTab> createState() => _MerchantMarketingTabState();
}

class _MerchantMarketingTabState extends State<MerchantMarketingTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان بسيط
          const Text(
            'إدارة الإعلانات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text('أنشئ إعلانات ممولة تظهر في الصفحة الرئيسية.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // جلب الإعلانات وفصلها (نشط / أرشيف)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ads')
                .where('shopId', isEqualTo: widget.currentShop.id)
                .orderBy('createdAt', descending: true)
                // ✅ QA Fix #23: حد أقصى لمنع جلب كل تاريخ الإعلانات في كل تغيير
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAds = snapshot.data?.docs ?? [];

              // فصل الإعلانات
              List<DocumentSnapshot> activeAds = [];
              List<DocumentSnapshot> historyAds = [];

              final now = DateTime.now();

              for (var doc in allAds) {
                final data = doc.data() as Map<String, dynamic>;
                final isActive = data['isActive'] ?? false;
                final expiresAt = data['expiresAt'] != null
                    ? (data['expiresAt'] as Timestamp).toDate()
                    : null;

                // الإعلان نشط لو: مفعل + تاريخه لسه مجاش
                if (isActive && expiresAt != null && expiresAt.isAfter(now)) {
                  activeAds.add(doc);
                } else {
                  historyAds.add(doc);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. قسم الإعلان النشط
                  const Text('الإعلان النشط حالياً',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 10),
                  if (activeAds.isEmpty)
                    _buildCreateAdCard()
                  else
                    _buildActiveAdCard(activeAds.first),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 2. قسم سجل الإعلانات (History)
                  const Text('سجل الإعلانات السابقة',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  if (historyAds.isEmpty)
                    const Text('لا يوجد سجل إعلانات سابق.',
                        style: TextStyle(
                            color: Colors.grey, fontStyle: FontStyle.italic))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: historyAds.length,
                      itemBuilder: (context, index) =>
                          _buildHistoryAdCard(historyAds[index]),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  // كارت إنشاء إعلان (لو مفيش إعلان نشط)
  Widget _buildCreateAdCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.add_photo_alternate,
                  size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              const Text('لا يوجد إعلان نشط',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showAdDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('إنشاء إعلان جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // كارت الإعلان النشط
  Widget _buildActiveAdCard(DocumentSnapshot adDoc) {
    final adData = adDoc.data() as Map<String, dynamic>;
    final clicks = adData['clickCount'] ?? 0;
    // ✅ Fix #117: safe Timestamp cast — تجنب InvalidCastException
    final expiresAtRaw = adData['expiresAt'];
    final expiresAt = expiresAtRaw is Timestamp
        ? expiresAtRaw.toDate()
        : DateTime.now().add(const Duration(days: 7));
    final dateStr = DateFormat('yyyy-MM-dd').format(expiresAt);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedImage(
              imageUrl: adData['imageUrl'],
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (adData['text'] != null &&
                    adData['text'].toString().isNotEmpty)
                  Text(adData['text'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app,
                            color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 5),
                        Text('$clicks نقرات',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('ينتهي في: $dateStr',
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('تعديل'),
                    onPressed: () => _showAdDialog(adDoc),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // كارت الإعلان في السجل (الأرشيف)
  Widget _buildHistoryAdCard(DocumentSnapshot adDoc) {
    final adData = adDoc.data() as Map<String, dynamic>;
    final clicks = adData['clickCount'] ?? 0;
    final createdAt = adData['createdAt'] != null
        ? (adData['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(createdAt);

    return Card(
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedImage(
            imageUrl: adData['imageUrl'],
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(adData['text'] ?? 'بدون نص',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('تاريخ النشر: $dateStr'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app, size: 16, color: Colors.grey),
            Text('$clicks',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- ديالوج الإنشاء/التعديل (بدون زيادات) ---
  void _showAdDialog(DocumentSnapshot? adDoc) {
    final codeController = TextEditingController();
    final textController =
        TextEditingController(text: adDoc != null ? (adDoc['text'] ?? '') : '');
    final targetIdController =
        TextEditingController(text: adDoc != null ? adDoc['targetId'] : '');
    String selectedType = adDoc != null ? adDoc['targetType'] : 'shop';
    File? selectedImage;
    bool isEditing = adDoc != null;

    // ✅ تم حذف 'url' نهائياً
    final Map<String, String> targetTypes = {
      'shop': 'المتجر الرئيسي',
      'shop_products': 'قائمة المنتجات',
      'shop_offers': 'قائمة العروض',
      'product': 'منتج محدد',
      'offer': 'عرض محدد',
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'تعديل الإعلان' : 'إنشاء إعلان جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. اختيار الصورة (بسيط)
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() => selectedImage = File(pickedFile.path));
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: selectedImage != null
                          ? Image.file(selectedImage!, fit: BoxFit.cover)
                          : (isEditing)
                              ? CachedImage(
                                  imageUrl: adDoc['imageUrl'],
                                  fit: BoxFit.cover)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, color: Colors.grey),
                                    Text('اضغط لاختيار صورة')
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 2. كود التفعيل (فقط عند الإنشاء)
                  if (!isEditing)
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'كود التفعيل (من الإدارة)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // 3. النص
                  TextField(
                    controller: textController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'نص الإعلان',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.text_fields),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. نوع التوجيه (بدون روابط خارجية)
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                        labelText: 'عند الضغط يفتح:',
                        border: OutlineInputBorder()),
                    items: targetTypes.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedType = val!;
                        // تعبئة تلقائية للـ ID
                        if (selectedType.startsWith('shop')) {
                          targetIdController.text = widget.currentShop.id;
                        } else {
                          targetIdController.clear();
                        }
                      });
                    },
                  ),

                  // 5. حقل الـ ID (يظهر لو منتج أو عرض)
                  if (selectedType == 'product' || selectedType == 'offer') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: targetIdController,
                      decoration: InputDecoration(
                        labelText: selectedType == 'product'
                            ? 'Product ID'
                            : 'Offer ID',
                        border: const OutlineInputBorder(),
                        helperText: 'انسخ الرقم من قائمة منتجاتك',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              // ✅ Fix #209: زر معاينة قبل النشر
              TextButton.icon(
                icon: const Icon(Icons.preview_outlined, size: 18),
                label: const Text('معاينة'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => _AdPreviewDialog(
                      imageFile: selectedImage,
                      imageUrl: isEditing ? (adDoc.data() as Map<String, dynamic>?)?['imageUrl'] as String? : null,
                      text: textController.text.trim(),
                      targetType: selectedType,
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!isEditing) {
                    if (codeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل كود التفعيل')));
                      return;
                    }
                    if (selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('اختر صورة')));
                      return;
                    }
                  }

                  Navigator.pop(ctx);
                  await _saveAd(
                    isEditing: isEditing,
                    adId: isEditing ? adDoc.id : null,
                    code: codeController.text,
                    image: selectedImage,
                    text: textController.text,
                    targetType: selectedType,
                    targetId: targetIdController.text,
                  );
                },
                child: Text(isEditing ? 'حفظ' : 'نشر'),
              ),
            ],
          );
        },
      ),
    // ✅ Fix #63: dispose controllers بعد إغلاق الـ dialog
    ).whenComplete(() {
      codeController.dispose();
      textController.dispose();
      targetIdController.dispose();
    });
  }

  Future<void> _saveAd({
    required bool isEditing,
    String? adId,
    String? code,
    File? image,
    required String text,
    required String targetType,
    required String targetId,
  }) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      if (isEditing) {
        Map<String, dynamic> updateData = {
          'targetType': targetType,
          'targetId': targetId,
          'text': text,
        };
        if (image != null) {
          // ✅ إصلاح: توحيد اسم المجلد مع باقي التطبيق (ad_images وليس
          // ads_images) — كان الاختلاف يمنع الرفع تماماً لعدم وجود قاعدة
          // مطابقة في storage.rules
          String newUrl = await ApiService.uploadImage(image, 'ad_images');
          updateData['imageUrl'] = newUrl;
        }
        await FirebaseFirestore.instance
            .collection('ads')
            .doc(adId)
            .update(updateData);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تم التعديل بنجاح')));
        }
      } else {
        await _validateAndBurnCode(code!);
        // ✅ إصلاح: توحيد اسم المجلد مع باقي التطبيق (ad_images وليس ads_images)
        String imageUrl = await ApiService.uploadImage(image!, 'ad_images');

        await FirebaseFirestore.instance.collection('ads').add({
          'shopId': widget.currentShop.id,
          'imageUrl': imageUrl,
          'text': text,
          'targetType': targetType,
          'targetId': targetId,
          'isActive': true,
          'clickCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        });

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تم النشر بنجاح')));
        }
      }
    } catch (e) {
      // ✅ تحسين: رسالة خطأ مُحدَّدة من MediaUploadException بدلاً من رسالة
      // عامة دائماً — يعرف المستخدم السبب الحقيقي (حجم الصورة، الاتصال، ...)
      if (mounted) {
        final msg = e is MediaUploadException
            ? e.userMessage
            : 'حدث خطأ، يُرجى المحاولة مرة أخرى';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      // ✅ ملاحظة: هذا الإغلاق يخص Dialog التحميل المؤقت الذي فُتح في بداية
      // هذه الدالة (وليس شاشة التسويق نفسها التي لا تُغلَق أبداً هنا) —
      // يجب أن يُغلَق دائماً (نجاح أو فشل) وإلا سيبقى المستخدم عالقاً أمام
      // مؤشر تحميل لا يمكن التخلص منه (barrierDismissible: false)
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _validateAndBurnCode(String code) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ad_codes')
        .where('code', isEqualTo: code)
        .where('isUsed', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('الكود غير صحيح أو مستخدم');
    }
    await snapshot.docs.first.reference.update({'isUsed': true});
  }
}

// ✅ Fix #209: معاينة الإعلان قبل النشر
class _AdPreviewDialog extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String text;
  final String targetType;

  const _AdPreviewDialog({
    this.imageFile,
    this.imageUrl,
    required this.text,
    required this.targetType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.cover)
                  : (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          ))
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 56, color: Colors.grey),
                          ),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('معاينة الإعلان',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (text.isNotEmpty) ...[
                  Text(text, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'النوع: $targetType',
                    style: const TextStyle(
                        color: Color(0xFF5E35B1), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E35B1),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('إغلاق المعاينة'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
