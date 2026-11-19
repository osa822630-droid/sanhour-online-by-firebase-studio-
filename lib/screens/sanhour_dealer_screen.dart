// lib/screens/sanhour_dealer_screen.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/dealer_listing_service.dart';
import '../services/media_upload_service.dart';
import '../utils/constants.dart';
import '../widgets/cached_image.dart';
import '../widgets/error_state_widget.dart';
import 'login_screen.dart';

class SanhourDealerScreen extends StatefulWidget {
  const SanhourDealerScreen({super.key});
  @override
  State<SanhourDealerScreen> createState() => _SanhourDealerScreenState();
}

class _SanhourDealerScreenState extends State<SanhourDealerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCat = 'الكل';
  final List<String> _cats = [
    'الكل',
    'ملابس',
    'إلكترونيات',
    'أثاث',
    'أدوات منزلية',
    'كتب',
    'عربيات',
    'دراجات',
    'أخرى'
  ];

  // ✅ تخزين Streams لمنع إعادة الاشتراك مع كل rebuild
  Stream<QuerySnapshot>? _browseStream;
  String? _lastBrowseCat;
  Stream<QuerySnapshot>? _myAdsStream;
  String? _lastMyAdsUserId;

  final Set<String> _nonEmptyDealerCats = {'الكل'};

  Stream<QuerySnapshot> _getBrowseStream() {
    if (_browseStream == null || _lastBrowseCat != _selectedCat) {
      _lastBrowseCat = _selectedCat;
      _browseStream = _selectedCat == 'الكل'
          ? FirebaseFirestore.instance
              .collection('dealer_listings')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('dealer_listings')
              .where('isActive', isEqualTo: true)
              .where('category', isEqualTo: _selectedCat)
              .orderBy('createdAt', descending: true)
              .snapshots();
    }
    return _browseStream!;
  }

  Future<void> _refreshDealerData() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('dealer_listings')
          .where('isActive', isEqualTo: true)
          .limit(200)
          .get();
      final activeCats = <String>{'الكل'};
      for (final d in snap.docs) {
        final c = (d.data()['category'] ?? '').toString().trim();
        if (c.isNotEmpty) activeCats.add(c);
      }
      if (mounted) {
        setState(() {
          _nonEmptyDealerCats
            ..clear()
            ..addAll(activeCats);
          if (!_nonEmptyDealerCats.contains(_selectedCat)) {
            _selectedCat = 'الكل';
          }
          _browseStream = null;
        });
      }
    } catch (_) {}
  }

  Stream<QuerySnapshot> _getMyAdsStream(String userId) {
    if (_myAdsStream == null || _lastMyAdsUserId != userId) {
      _lastMyAdsUserId = userId;
      _myAdsStream = FirebaseFirestore.instance
          .collection('dealer_listings')
          .where('sellerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    }
    return _myAdsStream!;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshDealerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.handshake_rounded,
                color: const Color(0xFFFFC72C), size: 22),
          ),
          const SizedBox(width: 10),
          const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ديلز',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('بيع وشراء المستعمل',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
        ]),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'تصفح الإعلانات', icon: Icon(Icons.search, size: 18)),
            Tab(text: 'إعلاني', icon: Icon(Icons.sell, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBrowseTab(),
          auth.isGuest ? _buildGuestTab() : _buildMyAdTab(auth),
        ],
      ),
    );
  }

  // ─── تبويب 1: تصفح الإعلانات ────────────────────────────────────────────────
  Widget _buildBrowseTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.orange.withValues(alpha: 0.12),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
              child: Text(
            'ديلز وسيط فقط — التطبيق لا يضمن جودة المنتجات.',
            style: TextStyle(fontSize: 11, color: Colors.orange),
          )),
        ]),
      ),
      SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: _cats.length,
          itemBuilder: (_, i) {
            final cat = _cats[i];
            final sel = _selectedCat == cat;
            return ChoiceChip(
              label: Text(cat, style: const TextStyle(fontSize: 12)),
              selected: sel,
              selectedColor: const Color(0xFF5E35B1),
              labelStyle: TextStyle(color: sel ? Colors.white : null),
              onSelected: (_) => setState(() => _selectedCat = cat),
            );
          },
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getBrowseStream(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              developer.log(
                  'dealer_listings browse query error: ${snap.error}',
                  name: 'SanhourDealerScreen');
              return ErrorStateWidget(
                message:
                    'تعذّر تحميل الإعلانات. تحقق من اتصالك وحاول مجدداً.',
                onRetry: () => setState(() => _browseStream = null),
              );
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.sell_outlined,
                        size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    const Text('لا توجد إعلانات حالياً',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('كن أول من يضيف إعلاناً!',
                        style:
                            TextStyle(color: Color(0xFF5E35B1), fontSize: 13)),
                  ]));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
              itemCount: docs.length,
              itemBuilder: (_, i) => _buildAdCard(
                  docs[i].data() as Map<String, dynamic>, docs[i].id),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildAdCard(Map<String, dynamic> data, String docId) {
    return GestureDetector(
      onTap: () => _showAdDetail(data, docId),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(fit: StackFit.expand, children: [
              (data['imageUrls'] as List?)?.isNotEmpty == true
                  ? CachedImage(
                      imageUrl: (data['imageUrls'] as List).first as String,
                      fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey)),
              Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFC72C),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('مستعمل',
                        style: TextStyle(color: Colors.white, fontSize: 9)),
                  )),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.all(8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 3),
              Text('${data['price'] ?? 0} جنيه',
                  style: const TextStyle(
                      color: Color(0xFF5E35B1),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              Text(data['category'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showAdDetail(Map<String, dynamic> data, String docId) {
    final phone = (data['phone'] ?? '').toString().trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((data['imageUrls'] as List?)?.isNotEmpty == true)
              SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: CachedImage(
                      imageUrl: (data['imageUrls'] as List).first as String,
                      fit: BoxFit.cover)),
            Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${data['price'] ?? 0} جنيه',
                          style: const TextStyle(
                              fontSize: 22,
                              color: Color(0xFF5E35B1),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (data['description'] != null &&
                          data['description'].toString().trim().isNotEmpty) ...[
                        const Text('الوصف:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(data['description'].toString(),
                            style: const TextStyle(height: 1.6)),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.warning_amber,
                                    color: Colors.orange, size: 16),
                                SizedBox(width: 6),
                                Text('تنبيه هام',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                              ]),
                              SizedBox(height: 6),
                              Text(
                                'ديلز وسيط فقط بين البائع والمشتري. التطبيق لا يضمن جودة المنتج ولا يتحمل أي مسؤولية عن الصفقات. تأكد من المعاينة الشخصية قبل الشراء.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    height: 1.5),
                              ),
                            ]),
                      ),
                      const SizedBox(height: 16),
                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final clean =
                                      AppConstants.normalizePhone(phone);
                                  final uri = Uri.parse('tel:$clean');
                                  try {
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  } catch (e) {
                                    developer.log(
                                        'dealer call launch error: $e',
                                        name: 'SanhourDealerScreen');
                                  }
                                },
                                icon: const Icon(Icons.call),
                                label: Text('اتصال: $phone'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5E35B1),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final wa =
                                    AppConstants.normalizeWhatsAppPhone(phone);
                                final uri = Uri.parse('https://wa.me/$wa');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.message),
                              label: const Text('واتساب'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                              ),
                            ),
                          ],
                        ),
                    ])),
          ]),
        ),
      ),
    );
  }

  // ─── تبويب 2: إعلاني ─────────────────────────────────────────────────────────
  Widget _buildGuestTab() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.sell_outlined, size: 60, color: Color(0xFF5E35B1)),
        const SizedBox(height: 16),
        const Text('سجّل دخولك لإضافة إعلان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('يمكنك نشر إعلان واحد مجاني شهرياً.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('تسجيل الدخول'),
        ),
      ]),
    ));
  }

  Widget _buildMyAdTab(AuthProvider auth) {
    final currentUserId = auth.user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض إعلاناتك'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _getMyAdsStream(currentUserId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          developer.log('dealer_listings myAds query error: ${snap.error}',
              name: 'SanhourDealerScreen');
          return ErrorStateWidget(
            message: 'تعذّر تحميل إعلاناتك. تحقق من اتصالك وحاول مجدداً.',
            onRetry: () => setState(() => _myAdsStream = null),
          );
        }
        final docs = snap.data?.docs ?? [];
        // ✅ فحص ما إذا كان المستخدم قد نشر إعلاناً هذا الشهر (بغض النظر عن حالته لتجنب التحايل بالإيقاف المؤقت)
        final now = DateTime.now();
        final adsThisMonth = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (data['createdAt'] == null) return false;
          final dt = (data['createdAt'] as Timestamp).toDate();
          return dt.year == now.year && dt.month == now.month;
        }).toList();
        final hasUsedMonthlyFreeAd = adsThisMonth.isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF5E35B1), size: 18),
                      SizedBox(width: 8),
                      Text('قواعد ديلز',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5E35B1))),
                    ]),
                    const SizedBox(height: 8),
                    _ruleRow('إعلان واحد مجاني في الشهر'),
                    _ruleRow('إضافة إعلان ثانٍ قبل انتهاء الشهر = 100 جنيه'),
                    _ruleRow('التطبيق وسيط فقط — لا نضمن جودة المنتجات'),
                  ]),
            ),
            const SizedBox(height: 20),

            const Text('إعلاناتي',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('لم تنشر أي إعلانات بعد',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                          width: 50,
                          height: 50,
                          child: (data['imageUrls'] as List?)?.isNotEmpty ==
                                  true
                              ? CachedImage(
                                  imageUrl:
                                      (data['imageUrls'] as List).first
                                          as String)
                              : const Icon(Icons.image)),
                    ),
                    title: Text(data['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('${data['price']} جنيه · ${data['category']}'),
                    trailing: Switch(
                      value: data['isActive'] ?? false,
                      activeThumbColor: const Color(0xFF5E35B1),
                      onChanged: (val) {
                        FirebaseFirestore.instance
                            .collection('dealer_listings')
                            .doc(d.id)
                            .update({'isActive': val});
                      },
                    ),
                  ),
                );
              }),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showAddAdSheet(context, auth, hasUsedMonthlyFreeAd),
                icon: const Icon(Icons.add),
                label: Text(hasUsedMonthlyFreeAd
                    ? 'إضافة إعلان آخر (100 جنيه)'
                    : 'إضافة إعلان مجاني'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasUsedMonthlyFreeAd
                      ? Colors.orange
                      : const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _ruleRow(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: Color(0xFF5E35B1)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );

  void _showAddAdSheet(BuildContext context, AuthProvider auth, bool isPaid) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: auth.user?.phone ?? '');
    String selectedCat = 'أخرى';
    File? imageFile;
    bool submitting = false;
    String feeCode = '';
    String? feeCodeError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isPaid ? 'إعلان مدفوع (100 ج)' : 'إعلان مجاني',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx)),
                      ]),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                          'لقد استخدمت إعلانك المجاني لهذا الشهر. إضافة إعلان آخر تتطلب كود دفع (100 جنيه) تحصل عليه من الإدارة بعد السداد.',
                          style: TextStyle(fontSize: 12, color: Colors.orange)),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final p = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 70);
                      if (p != null) {
                        setSheetState(() => imageFile = File(p.path));
                      }
                    },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252538)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        image: imageFile != null
                            ? DecorationImage(
                                image: FileImage(imageFile!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: imageFile == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 40, color: Colors.grey),
                                  Text('أضف صورة المنتج',
                                      style: TextStyle(color: Colors.grey)),
                                ])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'عنوان الإعلان *',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'وصف المنتج',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'السعر (جنيه) *',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'رقم التواصل *',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    decoration: const InputDecoration(
                        labelText: 'الفئة', border: OutlineInputBorder()),
                    items: _cats
                        .where((c) => c != 'الكل')
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedCat = v!),
                  ),
                  if (isPaid) ...[
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) {
                        feeCode = v;
                        if (feeCodeError != null) {
                          setSheetState(() => feeCodeError = null);
                        }
                      },
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'كود دفع الإعلان *',
                        hintText: 'DLR-XXXX-XXXX',
                        helperText:
                            'تحصل عليه من الإدارة بعد سداد ${DealerListingService.extraListingFee} جنيه',
                        errorText: feeCodeError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty ||
                                  priceCtrl.text.trim().isEmpty ||
                                  phoneCtrl.text.trim().isEmpty) {
                                return;
                              }
                              if (isPaid && feeCode.trim().isEmpty) {
                                setSheetState(() => feeCodeError =
                                    'أدخل كود دفع الإعلان الذي استلمته من الإدارة.');
                                return;
                              }
                              setSheetState(() => submitting = true);
                              try {
                                DocumentReference<Map<String, dynamic>>?
                                    feeCodeRef;
                                if (isPaid) {
                                  feeCodeRef =
                                      await DealerListingService.findFeeCode(
                                          feeCode);
                                }
                                String imageUrl = '';
                                if (imageFile != null) {
                                  imageUrl =
                                      await MediaUploadService.uploadFile(
                                    file: imageFile!,
                                    folder: 'dealer_listings',
                                    kind: MediaKind.image,
                                  );
                                }
                                final sellerId = auth.user?.id ?? '';
                                if (sellerId.isEmpty) {
                                  return;
                                }
                                final listing = <String, dynamic>{
                                  'sellerId': sellerId,
                                  'title': titleCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'price':
                                      double.tryParse(priceCtrl.text.trim()) ??
                                          0,
                                  'phone': phoneCtrl.text.trim(),
                                  'category': selectedCat,
                                  'imageUrls':
                                      imageUrl.isNotEmpty ? [imageUrl] : [],
                                  'condition': 'used_good',
                                  'isActive': true,
                                };
                                if (feeCodeRef != null) {
                                  await DealerListingService
                                      .publishPaidListing(
                                    codeRef: feeCodeRef,
                                    userId: sellerId,
                                    listing: listing,
                                  );
                                } else {
                                  await FirebaseFirestore.instance
                                      .collection('dealer_listings')
                                      .add({
                                    ...listing,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } on DealerFeeCodeException catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() {
                                    submitting = false;
                                    feeCodeError = e.userMessage;
                                  });
                                }
                              } on MediaUploadException catch (e) {
                                setSheetState(() => submitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(e.userMessage),
                                          backgroundColor: Colors.red));
                                }
                              } catch (e) {
                                developer.log(
                                    'dealer listing publish error: $e',
                                    name: 'SanhourDealerScreen');
                                setSheetState(() => submitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'تعذّر نشر الإعلان. تحقق من اتصالك وحاول مجدداً.'),
                                          backgroundColor: Colors.red));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E35B1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: submitting
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text('نشر الإعلان',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
          ),
        );
      }),
    ).whenComplete(() {
      titleCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      phoneCtrl.dispose();
    });
  }
}
