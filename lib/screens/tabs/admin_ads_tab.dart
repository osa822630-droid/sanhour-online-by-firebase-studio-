// lib/screens/tabs/admin_ads_tab.dart
// ✅ استخدام MultiImagePickerWidget في _AdFormScreen
// ✅ عرض كل الإعلانات (نشطة + منتهية) للأدمن عبر AdService.getAllAds()
// ✅ إضافة import لـ ApiService
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/ad_model.dart';
import '../../services/ad_service.dart';
import '../../widgets/cached_image.dart';
import '../../utils/image_helper.dart';
import '../../widgets/multi_image_picker_widget.dart';
import '../../services/media_upload_service.dart';

class AdminAdsTab extends StatefulWidget {
  const AdminAdsTab({super.key});

  @override
  State<AdminAdsTab> createState() => _AdminAdsTabState();
}

class _AdminAdsTabState extends State<AdminAdsTab> {
  bool _isLoading = true;
  String? _errorMsg;
  List<AdModel> _ads = [];
  int _totalClicks = 0;
  int _activeCount = 0;
  // ✅ Fix #163: فلتر نشط / منتهي
  final String _filterStatus = 'all'; // 'all' | 'active' | 'inactive'

  // ignore: unused_element
  List<AdModel> get _filteredAds {
    switch (_filterStatus) {
      case 'active':
        return _ads.where((a) => a.isActive).toList();
      case 'inactive':
        return _ads.where((a) => !a.isActive).toList();
      default:
        return _ads;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  // ✅ نستخدم getAllAds() للأدمن (نشطة + منتهية)
  Future<void> _loadAds() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final ads = await AdService.getAllAds();
      int clicks = 0;
      for (final ad in ads) {
        clicks += ad.clickCount;
      }
      if (mounted) {
        setState(() {
          _ads = ads;
          _activeCount = ads.where((a) => a.isActive).length;
          _totalClicks = clicks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminAdsTab error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAdStatus(AdModel ad) async {
    try {
      await FirebaseFirestore.instance
          .collection('ads')
          .doc(ad.id)
          .update({'isActive': !ad.isActive});
      _loadAds();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteAd(String adId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: const Text('سيُحذف الإعلان نهائياً ولا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('ads')
          .doc(adId)
          .delete();
      _loadAds();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E1A) : Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AdFormScreen(onSaved: _loadAds),
            fullscreenDialog: true,
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMsg!, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAds,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAds,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      _statCard('إجمالي الإعلانات', '${_ads.length}',
                          Icons.campaign, Colors.blue, isDark),
                      const SizedBox(width: 12),
                      _statCard('نشط', '$_activeCount', Icons.check_circle,
                          Colors.green, isDark),
                      const SizedBox(width: 12),
                      _statCard('نقرات', '$_totalClicks', Icons.touch_app,
                          Colors.orange, isDark),
                    ]),
                    const SizedBox(height: 20),
                    if (_ads.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          Icon(Icons.campaign_outlined,
                              size: 70, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text('لا توجد إعلانات حالياً',
                              style: TextStyle(color: Colors.grey)),
                        ]),
                      )
                    else
                      ...(_ads.map((ad) => _buildAdCard(ad, isDark))),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ✅ Fix #141: تفويض العرض لـ AdminAdCard المستقل
  Widget _buildAdCard(AdModel ad, bool isDark) {
    return AdminAdCard(
      ad: ad,
      isDark: isDark,
      onToggle: () => _toggleAdStatus(ad),
      onDelete: () => _deleteAd(ad.id),
    );
  }
}

// ✅ Fix #141: AdminAdCard — widget مستقل قابل لإعادة الاستخدام
class AdminAdCard extends StatelessWidget {
  final AdModel ad;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const AdminAdCard({
    super.key,
    required this.ad,
    required this.isDark,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired =
        ad.expiresAt != null && ad.expiresAt!.isBefore(DateTime.now());
    final isActive = ad.isActive && !isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ad.imageUrl.isNotEmpty)
            Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedImage(imageUrl: ad.imageUrl, fit: BoxFit.cover),
                ),
              ),
              if (ad.imageUrls.length > 1)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text('${ad.imageUrls.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ]),
                  ),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isActive ? '● نشط' : '● منتهي',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (ad.expiresAt != null)
                  Text('ينتهي: ${DateFormat('dd/MM/yyyy').format(ad.expiresAt!)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ]),
              if (ad.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ad.text, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.touch_app_outlined, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${ad.clickCount} نقرة',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                Switch(
                  value: ad.isActive,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// شاشة إضافة/تعديل الإعلان (fullscreen) — ✅ MultiImagePickerWidget
// ══════════════════════════════════════════════════════════════════════════════
class _AdFormScreen extends StatefulWidget {
  final VoidCallback onSaved;
  final AdModel? ad;

  // ignore: unused_element_parameter
  const _AdFormScreen({required this.onSaved, this.ad});

  @override
  State<_AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<_AdFormScreen> {
  final _textCtrl = TextEditingController();
  final _targetIdCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '7');

  String _targetType = 'none';
  bool _isSaving = false;
  final List<String> _selectedLocations = ['home'];

  // ✅ حالة الصور المتعددة
  List<String> _existingUrls = [];
  List<File> _newImageFiles = [];
  int _coverImageIndex = 0;

  // ✅ نظام تقدم الرفع — المفتاح index ضمن _newImageFiles
  final Map<int, double> _imageProgress = {};

  /// المتوسط الإجمالي لتقدم رفع كل الصور الجديدة (0.0–1.0)
  double get _overallImageProgress {
    if (_newImageFiles.isEmpty) return 0;
    double sum = 0;
    for (int i = 0; i < _newImageFiles.length; i++) {
      sum += _imageProgress[i] ?? 0;
    }
    return sum / _newImageFiles.length;
  }

  static const Map<String, String> _locationLabels = {
    'home': 'الرئيسية',
    'splash': 'شاشة البدء',
    'ads_screen': 'شاشة الإعلانات',
  };

  static const Map<String, String> _screenOptions = {
    'offers': 'صفحة العروض',
    'categories': 'صفحة الفئات',
    'favorites': 'المفضلة',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.ad;
    if (a != null) {
      _textCtrl.text = a.text;
      _targetType = a.targetType ?? 'none';
      _targetIdCtrl.text = a.targetId ?? '';
      _existingUrls = List.from(a.imageUrls);
      _coverImageIndex = a.coverImageIndex;
      if (a.displayLocations.isNotEmpty) {
        _selectedLocations
          ..clear()
          ..addAll(a.displayLocations);
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _targetIdCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final totalImages = _existingUrls.length + _newImageFiles.length;
    if (totalImages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب إضافة صورة واحدة على الأقل للإعلان'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_selectedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر مكان ظهور واحد على الأقل'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _isSaving = true;
      _imageProgress.clear();
    });
    try {
      final durationDays = int.tryParse(_durationCtrl.text.trim()) ?? 7;

      await AdService.createAd(
        imageFiles: _newImageFiles,
        targetType: _targetType,
        text: _textCtrl.text.trim(),
        targetId: _targetIdCtrl.text.trim().isEmpty
            ? null
            : _targetIdCtrl.text.trim(),
        durationDays: durationDays,
        coverIndex: _coverImageIndex,
        displayLocations: _selectedLocations,
        // ✅ نظام تقدم الرفع — يُحدِّث الواجهة مباشرةً مع كل دفعة بايتات
        onImageProgress: (fileIndex, fraction) {
          if (!mounted) return;
          setState(() => _imageProgress[fileIndex] = fraction);
        },
      );

      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      // ✅ MediaUploadException يحمل رسالة عربية جاهزة — وإلا نُزيل
      // الـ "Exception: " البادئة من رسائل الاستثناءات العادية
      final msg = e is MediaUploadException
          ? e.userMessage
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل الحفظ: $msg'),
        backgroundColor: Colors.red,
      ));
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
        title: Text(
          widget.ad == null ? 'إضافة إعلان جديد' : 'تعديل الإعلان',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'جاري...' : 'حفظ',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── ✅ صور متعددة مع اختيار الغلاف ──────────────────
          MultiImagePickerWidget(
            initialUrls: _existingUrls,
            initialFiles: _newImageFiles,
            initialCoverIndex: _coverImageIndex,
            ratio: ImageRatio.tallAd,
            maxImages: 5,
            label: 'صور الإعلان *',
            // ✅ تقدم رفع كل صورة + قفل التفاعل أثناء الحفظ
            uploadProgress: _isSaving ? _imageProgress : null,
            isUploading: _isSaving,
            onChanged: (state) {
              _existingUrls = List.from(state.existingUrls);
              _newImageFiles = List.from(state.newFiles);
              _coverImageIndex = state.coverIndex;
            },
          ),
          Text(
            'الأبعاد المثالية: 9:16 للبدء والإعلانات — 16:9 للرئيسية',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),

          // ✅ شريط تقدم رفع الصور — يظهر فقط عند وجود صور جديدة قيد الرفع
          if (_isSaving && _newImageFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _overallImageProgress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF5E35B1),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'جارٍ رفع الصور... ${(_overallImageProgress * 100).round()}%',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5E35B1),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── نص الإعلان ────────────────────────────────────────
          _sectionLabel('نص الإعلان (اختياري)'),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'مثال: خصم 50% على جميع المنتجات...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.text_fields),
            ),
          ),
          const SizedBox(height: 20),

          // ── أماكن الظهور ──────────────────────────────────────
          _sectionLabel('أماكن الظهور *'),
          const SizedBox(height: 8),
          ..._locationLabels.entries.map((e) {
            final selected = _selectedLocations.contains(e.key);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              value: selected,
              activeColor: const Color(0xFF5E35B1),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedLocations.add(e.key);
                  } else {
                    _selectedLocations.remove(e.key);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 20),

          // ── مدة الإعلان ──────────────────────────────────────
          _sectionLabel('مدة الإعلان (بالأيام)'),
          const SizedBox(height: 8),
          TextField(
            controller: _durationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.timer_outlined),
              border: OutlineInputBorder(),
              hintText: '7',
            ),
          ),
          const SizedBox(height: 20),

          // ── نوع الإجراء عند الضغط ────────────────────────────
          _sectionLabel('عند الضغط (Action)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _targetType,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: 'none', child: Text('لا شيء (صورة فقط)')),
              DropdownMenuItem(value: 'shop', child: Text('فتح محل')),
              DropdownMenuItem(
                  value: 'product', child: Text('فتح منتج')),
              DropdownMenuItem(
                  value: 'screen', child: Text('فتح شاشة داخلية')),
              DropdownMenuItem(
                  value: 'url', child: Text('رابط خارجي')),
            ],
            onChanged: (val) {
              setState(() {
                _targetType = val!;
                _targetIdCtrl.clear();
              });
            },
          ),

          if (_targetType != 'none') ...[
            const SizedBox(height: 12),
            if (_targetType == 'screen')
              DropdownButtonFormField<String>(
                initialValue: _screenOptions.keys.first,
                decoration: const InputDecoration(
                  labelText: 'الشاشة المستهدفة',
                  border: OutlineInputBorder(),
                ),
                items: _screenOptions.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _targetIdCtrl.text = val;
                },
              )
            else
              TextField(
                controller: _targetIdCtrl,
                decoration: InputDecoration(
                  labelText:
                      _targetType == 'url' ? 'الرابط الخارجي' : 'ID المستهدف',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF5E35B1),
        ),
      );
}
