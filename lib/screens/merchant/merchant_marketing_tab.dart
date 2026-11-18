// lib/screens/merchant/merchant_marketing_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/ad_service.dart';
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
  Stream<QuerySnapshot>? _adsStream;
  String? _lastShopId;

  Stream<QuerySnapshot> _getAdsStream(String shopId) {
    if (_adsStream == null || _lastShopId != shopId) {
      _lastShopId = shopId;
      _adsStream = FirebaseFirestore.instance
          .collection('ads')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }
    return _adsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة الإعلانات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text('أنشئ إعلانات ممولة تظهر في الصفحة الرئيسية.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          StreamBuilder<QuerySnapshot>(
            stream: _getAdsStream(widget.currentShop.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAds = snapshot.data?.docs ?? [];

              List<DocumentSnapshot> activeAds = [];
              List<DocumentSnapshot> historyAds = [];

              final now = DateTime.now();

              for (var doc in allAds) {
                final data = doc.data() as Map<String, dynamic>;
                final isActive = data['isActive'] ?? false;
                final expiresAt = data['expiresAt'] is Timestamp
                    ? (data['expiresAt'] as Timestamp).toDate()
                    : null;

                if (isActive && expiresAt != null && expiresAt.isAfter(now)) {
                  activeAds.add(doc);
                } else {
                  historyAds.add(doc);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          _buildHistoryAdCard(historyAds[index], isDark),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E35B1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showAdDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء إعلان مصور'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5E35B1),
                      side: const BorderSide(color: Color(0xFF5E35B1)),
                    ),
                    onPressed: _showVideoAdDialog,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('إعلان فيديو ترويجي 🎬'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAdCard(DocumentSnapshot adDoc) {
    final adData = adDoc.data() as Map<String, dynamic>;
    final clicks = adData['clickCount'] ?? 0;
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
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
                            color: Color(0xFF5E35B1), size: 20),
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

  Widget _buildHistoryAdCard(DocumentSnapshot adDoc, bool isDark) {
    final adData = adDoc.data() as Map<String, dynamic>;
    final clicks = adData['clickCount'] ?? 0;
    final createdAt = adData['createdAt'] is Timestamp
        ? (adData['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(createdAt);

    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
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

  void _showAdDialog(DocumentSnapshot? adDoc) {
    final adMap = adDoc?.data() as Map<String, dynamic>?;
    final codeController = TextEditingController();
    final textController =
        TextEditingController(text: (adMap?['text'] ?? '').toString());
    final targetIdController = TextEditingController(
        text: adMap != null
            ? (adMap['targetId'] ?? widget.currentShop.id).toString()
            : widget.currentShop.id);
    String selectedType =
        (adMap?['targetType'] ?? 'shop').toString();
    File? selectedImage;
    bool isEditing = adDoc != null;

    final Map<String, String> targetTypes = {
      'shop': 'المتجر الرئيسي',
      'shop_products': 'قائمة المنتجات',
      'shop_offers': 'قائمة العروض',
      'product': 'منتج محدد',
      'offer': 'عرض محدد',
    };
    if (!targetTypes.containsKey(selectedType)) {
      selectedType = 'shop';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: Text(isEditing ? 'تعديل الإعلان' : 'إنشاء إعلان جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        color: isDark
                            ? const Color(0xFF252538)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400),
                      ),
                      child: selectedImage != null
                          ? Image.file(selectedImage!, fit: BoxFit.cover)
                          : (isEditing)
                              ? CachedImage(
                                  imageUrl: adMap?['imageUrl']?.toString() ?? '',
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

                  if (!isEditing)
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'كود التفعيل (من الإدارة)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                    ),

                  const SizedBox(height: 10),

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
                        if (selectedType.startsWith('shop')) {
                          targetIdController.text = widget.currentShop.id;
                        } else {
                          targetIdController.clear();
                        }
                      });
                    },
                  ),

                  if (selectedType == 'product' || selectedType == 'offer') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: targetIdController,
                      decoration: InputDecoration(
                        labelText: selectedType == 'product'
                            ? 'معرّف المنتج (Product ID)'
                            : 'معرّف العرض (Offer ID)',
                        border: const OutlineInputBorder(),
                        helperText: 'انسخ المعرّف من قائمة منتجاتك أو عروضك',
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
              TextButton.icon(
                icon: const Icon(Icons.preview_outlined, size: 18),
                label: const Text('معاينة'),
                onPressed: () {
                  final existingImageUrl = adMap?['imageUrl'] as String?;
                  showDialog(
                    context: context,
                    builder: (_) => _AdPreviewDialog(
                      imageFile: selectedImage,
                      imageUrl: existingImageUrl,
                      text: textController.text.trim(),
                      targetType: selectedType,
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!isEditing) {
                    if (codeController.text.trim().isEmpty) {
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

                  final effectiveTargetId = selectedType.startsWith('shop')
                      ? widget.currentShop.id
                      : targetIdController.text.trim();

                  Navigator.pop(ctx);
                  await _saveAd(
                    isEditing: isEditing,
                    adId: isEditing ? adDoc.id : null,
                    code: codeController.text.trim(),
                    image: selectedImage,
                    text: textController.text.trim(),
                    targetType: selectedType,
                    targetId: effectiveTargetId,
                  );
                },
                child: Text(isEditing ? 'حفظ' : 'نشر'),
              ),
            ],
          );
        },
      ),
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
          String newUrl = await ApiService.uploadImage(image, 'ad_images');
          updateData['imageUrl'] = newUrl;
          updateData['imageUrls'] = [newUrl];
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
        // ✅ التحقق من الكود وحرقه أولاً، أو رفع الصورة بعد التأكد من صحة الكود
        await _validateAndBurnCode(code!);
        String imageUrl = await ApiService.uploadImage(image!, 'ad_images');

        final docRef = FirebaseFirestore.instance.collection('ads').doc();
        await docRef.set({
          'id': docRef.id,
          'shopId': widget.currentShop.id,
          'imageUrl': imageUrl,
          'imageUrls': [imageUrl],
          'coverImageIndex': 0,
          'text': text,
          'targetType': targetType,
          'targetId': targetId,
          'isActive': true,
          'isMainActive': true,
          'displayLocations': const ['home', 'splash', 'ads_screen'],
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
      if (mounted) {
        final msg = e is MediaUploadException
            ? e.userMessage
            : e is AdCodeException
                ? e.userMessage
                : 'حدث خطأ، يُرجى المحاولة مرة أخرى';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _validateAndBurnCode(String code) async {
    await AdService.redeemAdCode(
      code: code,
      userId: widget.currentShop.ownerId,
      shopId: widget.currentShop.id,
    );
  }

  void _showVideoAdDialog() {
    final descController = TextEditingController();
    final durationController = TextEditingController(text: '60');
    File? selectedVideo;
    bool isUploading = false;
    double progress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final seconds = int.tryParse(durationController.text.trim()) ?? 60;
          final cost = AdService.calculateVideoCost(seconds.clamp(1, 180));
          final durationError = AdService.validateVideoDuration(seconds);

          return AlertDialog(
            title: const Text('إعلان فيديو ترويجي 🎬'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final picked = await ImagePicker().pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 3),
                            );
                            if (picked != null) {
                              setDialogState(
                                  () => selectedVideo = File(picked.path));
                            }
                          },
                    icon: Icon(selectedVideo != null
                        ? Icons.check_circle
                        : Icons.video_library),
                    label: Text(selectedVideo != null
                        ? 'تم اختيار الفيديو ✅'
                        : 'اختر ملف الفيديو (حتى 3 دقائق)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'مدة الفيديو (بالثواني - بحد أقصى 180 ثانية)',
                      errorText: durationError,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E35B1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'التكلفة التقديرية: ${cost.toStringAsFixed(0)} ج.م (${AdService.videoPricePerMinute.toStringAsFixed(0)} ج.م / دقيقة)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E35B1),
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'وصف الإعلان',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                        value: progress > 0 ? progress : null),
                    const SizedBox(height: 6),
                    Text('جاري رفع الفيديو... ${(progress * 100).round()}%',
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: (isUploading ||
                        selectedVideo == null ||
                        durationError != null)
                    ? null
                    : () async {
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(this.context);
                        setDialogState(() => isUploading = true);
                        final res = await AdService.uploadVideoAd(
                          videoFile: selectedVideo!,
                          shopId: widget.currentShop.id,
                          shopOwnerId: widget.currentShop.ownerId,
                          durationSeconds: seconds,
                          description: descController.text.trim(),
                          onProgress: (f) =>
                              setDialogState(() => progress = f),
                        );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text((res['message'] ??
                                    res['error'] ??
                                    'تمت العملية')
                                .toString()),
                            backgroundColor: res['success'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      },
                child: const Text('إرسال للمراجعة'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      descController.dispose();
      durationController.dispose();
    });
  }
}

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.cover)
                  : (imageUrl != null && imageUrl!.isNotEmpty)
                      ? CachedImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_outlined,
                                size: 56, color: Colors.grey),
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (text.isNotEmpty) ...[
                  Text(text, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 6),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
