# 🔍 التقرير الفني الشامل والدقيق لفحص الفرونت إند (Frontend Audit Report) — مشروع «سنهور أونلاين» (Sanhour Online)

**نطاق الفحص:** فحص شامل سطراً بسطر (Line-by-Line) لـ **95 ملفاً** تُمثّل كامل واجهة المستخدم، الشاشات، الويدجيتس، الثيم، التوجيه (Routing)، إدارة الحالة المتصلة بالواجهة، وإعدادات المنصات (`lib/main.dart`، `lib/utils/app_theme.dart`، `lib/utils/constants.dart`، `lib/utils/image_helper.dart`، `26` ملف ويدجيت في `lib/widgets/*.dart`، `38` شاشة عامة في `lib/screens/*.dart`، `11` شاشة تاجر في `lib/screens/merchant/*.dart`، `9` تبويبات إدارة في `lib/screens/tabs/*.dart`، وملفات `android`، `ios`، `web`، `test`).

---

## 📊 أولاً: الملخص التنفيذي ومصفوفة الخطورة (Executive Summary)

| التصنيف | العدد المرصود | درجة الخطورة | أبرز الأمثلة الحرجة بالملف والسطر |
|---|---|---|---|
| **أخطاء تمنع الترجمة (Compile-Time Errors)** | 3 أخطاء | 🔴 حرجة جداً (P0) | `lib/screens/detail_screen.dart` (الأسطر `388`، `399`، `407`): التعامل مع `Review.userName` (`String?`) كـ `String` غير قابل لأن يكون `null`. |
| **أخطاء كراش وقت التشغيل (Runtime Crashes / Route Errors)** | 11 خطأ | 🔴 حرجة (P0) | `lib/screens/notifications_screen.dart` (الأسطر `542–602`): استدعاء `Navigator.pushNamed` لـ 6 مسارات غير مسجلة في `main.dart`؛ و`RangeError` عند عرض اسم مستخدم فارغ في `admin_users_tab.dart:243` و`my_service_history_screen.dart:495`. |
| **أخطاء منطق الواجهة وفقدان البيانات المرئية (UI Logic Bugs)** | 28 خطأ | 🟠 عالية (P1) | عدم ظهور صورة الغلاف المختارة للمنتج (`coverImageIndex`) في كل شاشات التطبيق؛ عدم ظهور صور العرض المتعددة أو السعر القديم/الجديد في `detail_screen.dart:78`؛ ضياع تعديلات التاجر في `merchant_products_tab.dart:363, 408` و`merchant_offers_tab.dart:417, 463` بسبب `setState(() {})` بدون إعادة جلب؛ ومسح حقول `workingDays` و`socialMedia` عند تعديل المحل. |
| **ثغرات تسريب موارد وذاكرة (Memory & Controller Leaks)** | 12 موضعاً | 🟡 متوسطة (P2) | عدم عمل `dispose()` لـ `TextEditingController` في `sanhour_dealer_screen.dart:455–458`، `merchant_products_tab.dart:470, 513–515`، `product_order_screen.dart:356`، `admin_complaints_tab.dart:358`، و`admin_locations_tab.dart:116`. |
| **عيوب الوضع الليلي وتناسق التصميم (Dark Mode & UI/UX Flaws)** | 34 موضعاً | 🟡 متوسطة (P2) | ألوان ثابتة (`Colors.white`، `Colors.black87`، `Colors.grey[100]`) تكسر قراءة النصوص في الوضع الليلي (Dark Mode) في `detail_screen.dart`، `shop_detail_screen.dart`، `review_screen.dart`، `merchant_products_tab.dart`، `merchant_offers_tab.dart`، و`admin_codes_tab.dart`. |
| **نواقص وخصائص غير مربوطة (Missing / Unwired Features)** | 19 عنصراً | 🔵 متوسطة/تحسينية | فلتر الترتيب غير المربوط في `service_requests_tab_screen.dart:160`؛ غياب ويدجيت مشغل الفيديو عن `ShopMediaGallery` و`DetailScreen`؛ عدم ربط `ShopDetailProvider` و`StartupAdDialog` و`CustomSearchBar`؛ وغياب شاشة إدارة الإحالات (`ReferralService`). |

---

## 🏗️ ثانياً: الفحص التفصيلي لنقطة الدخول والثيم والأدوات البصرية (`lib/main.dart` & `lib/utils/`)

### 1. ملف `lib/main.dart` (573 سطراً)
- **الدوال والويدجيتس المفحوصة:** `main()`، `_firebaseMessagingBackgroundHandler()`، `SanhourApp`، `_SanhourAppState`، `_handleNotificationNavigation()`، `_buildNotificationRoute()`، `ErrorApp`، `_GuardedRoute`.
- **العيوب (Flaws):**
  - **ازدواجية وتضارب أنظمة التوجيه (Routing Fragmentation):** التطبيق يستخدم 3 أنظمة توجيه مختلفة في نفس الوقت بدون توحيد:
    1. جدول `routes` الثابت في `main.dart:239–249` (`/login`, `/home`, `/admin`, `/merchant`, `/offers`, `/categories`, `/favorites`, `/ads_hub`, `/dealer`, `/seeder`).
    2. دالة `onGenerateRoute` في `main.dart:251–329` التي تتوقع مسارات مثل `/shop_detail` و`/product_detail` و`/offer_detail` و`/collection_detail` مع تمرير الكائنات داخل `settings.arguments` كـ `Map`.
    3. دالة `_buildNotificationRoute` في `main.dart:379–482` التي تجلب الوثائق من Firestore عبر `FutureBuilder` لمسارات الإشعارات (`shop_details`, `product_details`, `offer_details`).
    4. `DeepLinkService` و`NotificationsScreen` اللذان يستخدمان مسارات نصية مدمجة بالمعرف مثل `/shop/$id` و`/product/$id` غير المعرّفة أصلاً في `onGenerateRoute`!
  - **تضارب مفاتيح مسارات الإشعارات (Lines 380–455):** في `_buildNotificationRoute`، الكود يفحص `route == 'shop_details' || route == 'shop'`، بينما `AdminService.toggleShopSuspension` (`admin_service.dart:358`) يرسل `route: 'merchant'`، و`PostJobAdScreen` (`post_job_ad_screen.dart:109`) يرسل `route: 'job_ads'`، و`PostServiceRequestScreen` (`post_service_request_screen.dart:88`) يرسل `route: 'service_requests'`، و`ServiceRequestsTabScreen` (`service_requests_tab_screen.dart:573`) يرسل `route: 'service_request:$id'`، و`AdminComplaintsTab` (`admin_complaints_tab.dart:439`) يرسل `route: 'user_complaints'`. كل هذه المسارات تسقط في الفرع الافتراضي `default: return null;` في `main.dart:480` ولا تفتح أي شاشة عند الضغط على إشعار النظام (FCM Push Notification)!
- **الأخطاء (Bugs):**
  - **السطر 426 (`main.dart:426`):** عند استقبال إشعار لعرض (`offer_details` / `offer`)، يتم بناء `DetailScreen(item: Offer.fromMap(snap.data!.data()!, targetId))`، ولكن `Offer.fromMap` يحتاج `data['id']` أو تمرير `docId`، ومع ذلك إذا كانت الوثيقة محذوفة (`!snap.data!.exists`) يعرض `MainScreen()` داخل `Navigator.push` مما يكدّس شاشة رئيسية ثانية فوق الشاشة الحالية بدلاً من إظهار رسالة تنبيه بأن العرض لم يعد متاحاً.
  - **السطر 198 (`main.dart:198`):** يتم استدعاء `DeepLinkService.instance.init(navigatorKey)` داخل `initState` قبل اكتمال تهيئة `SplashScreen` ومصادقة المستخدم؛ فإذا فتح المستخدم التطبيق عبر رابط عميق (Deep Link) وهو في شاشة البداية، فإن `SplashScreen._replaceSelfNamed('/home')` قد تستبدل أو تغطي الشاشة التي فتحها الرابط العميق.
- **النواقص (Missing):**
  - غياب معالجة مسارات `/shop/:id`، `/product/:id`، `/offer/:id`، `/collection/:id`، `/job_ads`، `/service_requests`، و`/user_complaints` داخل `onGenerateRoute` و`_buildNotificationRoute`.
- **التحسينات المقترحة:**
  - توحيد جميع المسارات في موجه مركزي واحد (`AppRouter`) يدعم كلاً من تمرير الكائن الجاهز (`arguments`) أو جلب المعرف (`id`) من المسار مباشرة (`/shop/:id`) إذا لم يكن الكائن ممرراً.

### 2. ملف `lib/utils/app_theme.dart` (102 سطر) و `lib/providers/theme_provider.dart` (104 أسطر)
- **الدوال والخصائص المفحوصة:** `AppTheme.lightTheme`، `AppTheme.darkTheme`، `ThemeProvider.isDarkMode`، `ThemeProvider.toggleTheme()`.
- **العيوب والأخطاء:**
  - **عدم تطابق ألوان الهوية البصرية بين `AppTheme` والشاشات (`app_theme.dart:12–20`):** يعرّف `AppTheme` اللون الأساسي `primaryColor = Color(0xFF6200EE)` و`secondaryColor = Color(0xFF03DAC6)`، بينما 90% من الشاشات تستخدم ألواناً مكتوبة يدوياً (Hardcoded) مثل `Color(0xFF5E35B1)` أو `Colors.deepPurple` أو `Colors.deepPurple[900]` والخلفية الداكنة `Color(0xFF0E0E1A)` بدلاً من `Color(0xFF121212)` المعرّف في `AppTheme.darkTheme` (`L58`).
  - **نقص تعريفات الثيم الحديث (Material 3):** `AppTheme` لا يعرّف `cardTheme`، `bottomSheetTheme`، `dialogTheme`، `chipTheme`، `tabBarTheme`، ولا `dividerTheme`، مما اضطر الشاشات لتكرار `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))` مئات المرات وتسبب في ظهور خلفيات بيضاء ساطعة في الوضع الليلي.
  - **خط Cairo عبر `google_fonts` (`app_theme.dart:24, 62`):** استخدام `GoogleFonts.cairoTextTheme()` يحاول جلب ملفات الخط عبر الإنترنت عند أول تشغيل إذا لم تكن مضمنة محلياً في `assets/fonts/` ومُسجلة في `pubspec.yaml`، وهو ما يسبب تأخراً بصرياً أو تغير شكل الخط في حالة ضعف الشبكة في سنهور.
- **التحسينات المقترحة:**
  - تضمين أوزان خط `Cairo` (`Regular`, `Medium`, `SemiBold`, `Bold`) محلياً داخل `assets/fonts/` في `pubspec.yaml` مع ضبط `GoogleFonts.config.allowRuntimeFetching = false`.
  - بناء نظام Design Tokens متكامل داخل `AppTheme` يشمل ألوان البطاقات (`surfaceContainer`)، الحدود، الشارات، وحالات النجاح/التحذير/الخطأ للوضعين الفاتح والداكن.

### 3. ملف `lib/utils/constants.dart` (349 سطراً)
- **الكلاسات المفحوصة:** `BuildFlags`، `AppConstants`، `AppColors`، `AppTextStyles`، `FirestoreCollections`، `StorageFolders`، `PrefKeys`، `RouteNames`.
- **العيوب والأخطاء:**
  - **ثوابت ميتة غير مستخدمة (Dead Constants):** الكلاسات `FirestoreCollections`، `StorageFolders`، `PrefKeys`، و`RouteNames` معرّفة في `constants.dart` لكن الغالبية العظمى من الشاشات والخدمات تكتب النصوص يدوياً (`'shops'`, `'onboarding_done'`, `'/shop_detail'`) بدلاً من استخدام هذه الثوابت، مما أدى لأخطاء إملائية قاتلة (مثل اختلاف مسارات الإشعارات ومفاتيح التخزين المحلي).
  - **السطر 18 (`BuildFlags.enableSeeder`):** يعتمد على `kDebugMode` فقط (`static const bool enableSeeder = kDebugMode;`)، وهو جيد، لكن يجب التأكد من عدم تفعيل `ALLOW_MOCK_MODE=true` أبداً في بناء الإنتاج.

### 4. ملف `lib/utils/image_helper.dart` (533 سطراً)
- **الدوال والويدجيتس المفحوصة:** `ImageRatio`، `ImageHelper.pickAndCrop()`، `ImageHelper.pickMultipleAndCrop()`، `ImageHelper.showSourcePicker()`، `_PreCropHintSheet`، `_WebCropDialog`.
- **العيوب والأخطاء:**
  - **السطر 118–135 (`pickMultipleAndCrop`):** عند اختيار عدة صور، يتم فتح أداة القص (`ImageCropper`) لكل صورة بالتتابع داخل حلقة `for`. إذا ألغى المستخدم قص صورة واحدة في المنتصف، يتم تجاهل تلك الصورة بصمت دون توضيح للمستخدم هل يريد تخطي هذه الصورة أم إلغاء العملية بالكامل.
  - **السطر 152 (`compressQuality: 80`):** الضغط يتم داخل `ImageCropper` فقط، بينما الشاشات التي تستخدم `ImagePicker().pickImage()` مباشرة دون المرور على `ImageHelper` (مثل `MerchantMarketingTab` في السطر `318` لرفع صور الإعلانات!) ترفع الصور بالحجم الكامل الخام بدون قص ولا ضغط!
- **التحسينات المقترحة:**
  - إجبار كافة عمليات اختيار الصور في التطبيق (بما فيها `MerchantMarketingTab` و`ReviewScreen` و`SanhourDealerScreen`) على المرور عبر `ImageHelper.pickAndCrop` لضمان توحيد الأبعاد وضغط الحجم.

---

## 🧩 ثالثاً: الفحص التفصيلي لكافة الويدجيتس (`lib/widgets/*.dart` — 26 ملفاً)

### 1. `lib/widgets/ad_carousel.dart` (260 سطراً)
- **الوظيفة:** عرض شريط الإعلانات الممولة المتحرك في الصفحة الرئيسية.
- **العيوب والأخطاء:**
  - **نقص دعم توجيه `'offer'` و`'shop_products'` و`'shop_offers'` في `_handleAdTap` (الأسطر `140–178`):** في `MerchantMarketingTab` (`L294–300`)، يُسمح للتاجر بإنشاء إعلان يوجه إلى `'shop_products'` أو `'shop_offers'` أو `'offer'`. لكن في `AdCarousel._handleAdTap`، الكود يعالج فقط `'shop'` و`'product'` و`'screen'` و`'url'`! أي إعلان يوجه إلى `'offer'` أو `'shop_products'` أو `'shop_offers'` لا يفعل شيئاً عند الضغط عليه!
  - **اعتماد `_handleAdTap` على العناصر المحملة فقط في `ShopsProvider` (`L145, L156`):** يبحث الكود عن المحل أو المنتج عبر `provider.shops.firstWhere` و`provider.products.firstWhere`. بما أن `ShopsProvider` يستخدم Pagination (يجلب 20 عنصراً فقط في البداية)، فإذا كان الإعلان يشير إلى محل أو منتج غير موجود في أول 20 عنصراً محملاً في الذاكرة، يفشل `firstWhere` ويدخل في `catch` ويعرض للمستخدم رسالة كاذبة: `"العرض غير متاح حالياً"` رغم أن المحل/المنتج موجود ونشط في Firestore!
  - **عدم دعم إعلانات الفيديو (`ad.isVideo`):** رغم أن `AdModel` و`AdService` يدعمان إعلانات الفيديو (`videoUrl`)، إلا أن `AdCarousel` يعرض فقط `CachedImage(imageUrl: ad.imageUrl)` ولا يشغل الفيديو أو يعرض أيقونة تشغيل للفيديو.

### 2. `lib/widgets/analytics_charts.dart` (335 سطراً)
- **الوظيفة:** رسوم بيانية مخصصة (`BarChartWidget`، `PieChartWidget`، `LineChartWidget`، `ChartData`).
- **العيوب والأخطاء:**
  - **ألوان ثابتة غير متوافقة مع الوضع الليلي (`L55, L112, L215`):** نصوص المحاور والخلفيات تستخدم `Colors.black87` و`Colors.grey[700]` مباشرة، مما يجعل الأرقام وأيام الأسبوع غير مقروءة في الوضع الليلي.
  - **في `LineChartWidget` (`L265`):** إذا كانت قائمة `data` تحتوي على عنصر واحد فقط (`data.length == 1`)، فإن القسمة على `data.length - 1` تسبب القسمة على صفر (`NaN` / `Infinity`) في حساب الإحداثي الأفقي `dx` وترسم خطاً معطوباً (`Canvas` crash).

### 3. `lib/widgets/app_footer.dart` (92 سطراً)
- **الوظيفة:** تذييل الصفحة (Footer) الذي يظهر أسفل القوائم.
- **العيوب والأخطاء:**
  - تصميم جيد وبسيط، لكنه يتكرر داخل `ListView` في بعض الشاشات بينما يغيب عن شاشات أخرى، ويفضل إخفاؤه عندما تكون القائمة قصيرة جداً (أقل من 3 عناصر) حتى لا يظهر في منتصف الشاشة.

### 4. `lib/widgets/cached_image.dart` (118 سطراً)
- **الوظيفة:** تغليف `CachedNetworkImage` مع معالجة الأخطاء ومؤشر التحميل.
- **العيوب والأخطاء:**
  - **السطر 48–62:** عندما يكون `imageUrl` فارغاً أو يفشل التحميل، يعرض أيقونة `Icons.storefront` دائماً كصورة بديلة حتى لو كانت الصورة لمنتج أو مستخدم أو إعلان!
  - **عدم تحديد `memCacheWidth` / `memCacheHeight`:** في قوائم الشبكة (`GridView` و`ListView`) يتم فك ضغط الصور الكاملة في الذاكرة العشوائية (RAM) بأبعادها الأصلية، مما يستهلك ذاكرة كبيرة على الهواتف الاقتصادية.
- **التحسينات المقترحة:**
  - إضافة باراميتر اختياري `fallbackIcon` (افتراضياً `Icons.image_outlined`)، وحساب `memCacheWidth` تلقائياً بناءً على `width * MediaQuery.devicePixelRatioOf(context)` عند تمرير `width` محدد.

### 5. `lib/widgets/category_list.dart` (109 أسطر)
- **الوظيفة:** شريط الفئات الأفقي في الشاشة الرئيسية.
- **العيوب والأخطاء:**
  - الويدجيت غير مستخدم فعلياً في `HomeScreen` (حيث تبني `HomeScreen` شريط الفئات داخلياً في `_buildCategoryChips`)، مما يجعله كوداً ميتاً (Dead Widget) أو مكرراً!

### 6. `lib/widgets/context_search_bar.dart` (390 سطراً)
- **الوظيفة:** شريط البحث الموحد المزود بالبحث الصوتي (Speech-to-Text باللهجة المصرية `ar_EG`) وفلاتر Chips قابلة للطي.
- **العيوب والأخطاء:**
  - **مزامنة الحالة في `SearchFilter` (`L65–72`):** يتم نسخ `defaultOption` إلى خريطة `_selectedFilters` داخل `initState()` فقط (`L68`). إذا قامت الشاشة الأب بتغيير `defaultOption` برمجياً (مثل زر "مسح الفلاتر")، لا يتحدث `ContextSearchBar` لأنه يفتقر إلى `didUpdateWidget()`!
  - **مؤقت الـ Debounce (`_debounceTimer`) والبحث الصوتي (`L125–160`):** عند استخدام الميكروفون، يتم استدعاء `widget.onSearch(recognizedWords)` فوراً مع كل كلمة منطوقة دون تمريرها على `_debounceTimer`، مما قد يطلق عشرات الاستعلامات المتتالية في الشاشات التي تضرب Firestore مباشرة عند البحث.
  - **إغلاق الميكروفون عند الخروج من الشاشة (`dispose` في `L75–80`):** يستدعي `_speech.stop()`، ولكن إذا كان `_speech.isListening` نشطاً فقد تظل أيقونة الميكروفون معلقة على بعض أجهزة أندرويد ما لم يتم استدعاء `_speech.cancel()`.

### 7. `lib/widgets/custom_app_bar.dart` (32 سطراً)
- **الوظيفة:** شريط علوي مخصص.
- **العيوب:** يستخدم فقط في شاشة واحدة (`MerchantReviewsScreen`)، ولونه ثابت `Theme.of(context).primaryColor` (`0xFF6200EE`) بينما باقي شاشات التاجر تستخدم `0xFF5E35B1`.

### 8. `lib/widgets/dealer_icon.dart` (176 سطراً)
- **الوظيفة:** زر عائم/متحرك لفتح شاشة «سنهور ديلر».
- **العيوب والأخطاء:**
  - يستخدم `SingleTickerProviderStateMixin` مع `AnimationController(..repeat(reverse: true))` يعمل بلا توقف طوال فترة بقاء المستخدم في التطبيق، مما يسبب إعادة رسم مستمرة (60 إطاراً/ثانية) واستهلاكاً غير ضروري للبطارية. يُنصح باستخدام `RepaintBoundary` حوله أو إيقاف النبض بعد 3 مرات.

### 9. `lib/widgets/empty_state_widget.dart` (46 سطراً) و `lib/widgets/error_state_widget.dart` (52 سطراً)
- **الوظيفة:** عرض حالات الفراغ والأخطاء.
- **العيوب:** رغم وجود هذين الويدجيتين النظيفين، إلا أن أكثر من 20 شاشة في التطبيق تبني `_emptyState()` و`_errorState()` يدوياً داخلها بتصاميم وألوان مختلفة بدلاً من استخدام `EmptyStateWidget` و`ErrorStateWidget`.

### 10. `lib/widgets/favorites_button.dart` (210 أسطر)
- **الوظيفة:** زر القلب لإضافة/إزالة عنصر من المفضلة أو إضافته إلى قائمة مفضلة (`WishlistCollection`).
- **العيوب والأخطاء:**
  - **السطر 95–140 (`_showAddToCollectionSheet`):** عند الضغط المطول أو اختيار قائمة، يقوم الويدجيت بجلب قوائم المستخدم مباشرة من Firestore في كل مرة دون تخزين مؤقت، وإذا كان المستخدم ضيفاً (`isGuest`) يسمح له بالضغط على الزر قبل أن يفشل أو يظهر تنبيهاً متأخراً.

### 11. `lib/widgets/favorites_grid.dart` (142 سطراً)
- **الوظيفة:** شبكة عرض العناصر المفضلة.
- **العيوب:** يستخدم `GridView.builder` مع `childAspectRatio: 0.75` ثابت؛ على الشاشات الصغيرة أو عند تكبير خط النظام (`textScaler`) يحدث `RenderFlex overflowed` في أسفل البطاقة.

### 12. `lib/widgets/force_update_dialog.dart` (98 سطراً)
- **الوظيفة:** فحص وعرض نافذة التحديث الإجباري (`ForceUpdateChecker.check`).
- **العيوب والأخطاء:**
  - **رابط المتجر الثابت (`L75`):** عند الضغط على زر "تحديث الآن"، يفتح رابط Google Play لمعرف الحزمة `com.sanhour.online`، لكن لا يوجد fallback لنظام iOS (`App Store`) ولا رابط تحميل مباشر (`updateUrl` من إعدادات Firestore `settings/general`) في حال تم توزيع التطبيق كـ APK مباشر لأهل سنهور قبل رفعه على المتجر!

### 13. `lib/widgets/gemini_chat_button.dart` (369 سطراً)
- **الوظيفة:** زر ونافذة المحادثة مع «مساعد سنهور الذكي» (`GeminiChatButton` و`GeminiChatSheet`).
- **العيوب والأخطاء:**
  - **إعادة ضبط سجل المحادثة عند إغلاق الـ BottomSheet:** يتم استدعاء `GeminiService().resetChat()` عند إغلاق النافذة، مما يمسح المحادثة بالكامل لو أغلقت النافذة بالخطأ.
  - **عدم قابلية الروابط أو أسماء المحلات للضغط:** عندما يقترح المساعد الذكي محلاً أو منتجاً من سنهور، يظهر كنص عادي لا يمكن للمستخدم الضغط عليه للانتقال إلى صفحة المحل.

### 14. `lib/widgets/horizontal_list.dart` (226 سطراً)
- **الوظيفة:** قائمة أفقية لعرض المحلات أو المنتجات في الصفحة الرئيسية.
- **العيوب والأخطاء:**
  - **تجاهل `coverImageIndex` للمنتجات (`L132`):** يعرض دائماً `product.imageUrls.first` بدلاً من الصورة التي اختارها التاجر كغلاف للمنتج.
  - **استخدام `dynamic` للعناصر:** يقبل `List<dynamic> items` ويقوم بفحص `if (item is Shop)` و`else if (item is Product)` وقت التشغيل بدلاً من فصل الويدجيت أو استخدام Generics آمنة.

### 15. `lib/widgets/media_gallery_picker_widget.dart` (538 سطراً) و `lib/widgets/multi_image_picker_widget.dart` (534 سطراً)
- **الوظيفة:** اختيار وإدارة معرض وسائط المحل (صور + فيديو) وصور المنتجات/العروض المتعددة.
- **العيوب والأخطاء:**
  - **في `MultiImagePickerWidget` (`L88–104`):** في `didUpdateWidget`، يتم مزامنة `uploadProgress` و`isUploading` فقط، لكن إذا تغيرت `initialUrls` من الشاشة الأب بعد الحفظ لا يتم تحديث `_existingUrls`.
  - **في `MediaGalleryPickerWidget` (`L195`):** عند اختيار فيديو، يتم فحص الحجم فقط (`50MB`)، ولكن لا يتم التحقق من مدة الفيديو محلياً قبل محاولة رفعه، ولا يتم توليد صورة مصغرة (`Video Thumbnail`) للفيديو المختار بل يظهر مربع رمادي بأيقونة فيديو فقط.

### 16. `lib/widgets/media_preview_dialog.dart` (175 سطراً) و `lib/widgets/shop_media_gallery.dart` (311 سطراً)
- **الوظيفة:** استعراض صور وفيديوهات المحل بملء الشاشة.
- **الأخطاء والنواقص الحرجة:**
  - **عدم وجود مشغل فيديو فعلي (`shop_media_gallery.dart:210–255` و`media_preview_dialog.dart:95–130`):** عندما يضغط المستخدم على فيديو في معرض المحل (`mediaType == 'video'`)، لا يوجد `video_player` داخل التطبيق! بدلاً من تشغيل الفيديو داخل التطبيق، يعرض الكود أيقونة فيديو أو يحاول فتح الرابط خارجياً عبر `launchUrl` (مما يخرج المستخدم من التطبيق إلى المتصفح لتحميل ملف الفيديو الخام من Firebase Storage)!

### 17. `lib/widgets/pagination_widget.dart` (241 سطراً)
- **الوظيفة:** ويدجيت عام للقوائم المقسمة لصفحات (`PaginatedListView` / `PaginatedGridView`).
- **العيوب:** ويدجيت ممتاز ومكتوب بعناية، لكنه **غير مستخدم في أي شاشة من شاشات التطبيق**! (كل شاشة مثل `HomeScreen` و`MerchantReviewsScreen` و`AllAdsScreen` أعادت كتابة كود الـ `ScrollController` والـ pagination يدوياً).

### 18. `lib/widgets/search_bar.dart` (175 سطراً) و `lib/widgets/startup_ad_dialog.dart` (27 سطراً)
- **العيوب:**
  - **`search_bar.dart` (`CustomSearchBar`):** كود ميت (Dead Code) غير مستخدم في أي شاشة بعد استبداله بـ `ContextSearchBar`.
  - **`startup_ad_dialog.dart` (`StartupAdDialog`):** كود ميت ومبتور (27 سطراً فقط يعرض `AlertDialog` بدائي بدون تصميم)، لأن `SplashScreen` بنى `_showAdDialog` الخاص به في السطور `173–224` ولم يستخدم `StartupAdDialog`!

### 19. `lib/widgets/seasonal_overlay.dart` (140 سطراً)، `lib/widgets/shimmer_loader.dart` (126 سطراً)، `lib/widgets/stat_card.dart` (55 سطراً)، `lib/widgets/sub_category_list.dart` (468 سطراً)
- **العيوب والأخطاء:**
  - **`seasonal_overlay.dart`:** يرسم زينة المواسم (رمضان، العيدين) باستخدام `IgnorePointer`، لكن الأنيميشن يستمر في العمل حتى عندما يفتح المستخدم شاشات فرعية أو لوحة التاجر إذا كان الويدجيت مركباً في الشجرة الأعلى.
  - **`sub_category_list.dart` (`L1–468`):** ملف ضخم (468 سطراً) يخلط بين منطق عرض الأقسام الفرعية وبين قاموس ضخم من الأيقونات المضمنة يدوياً، ويكرر جزءاً كبيراً من منطق `CategoryModel.getIconData`.

---

## 📱 رابعاً: الفحص التفصيلي للشاشات العامة وشاشات المستخدم (`lib/screens/*.dart` — 38 شاشة)

### 1. `lib/screens/detail_screen.dart` (512 سطراً) — 🔴 تحتوي على أخطاء تمنع الترجمة (Compile Errors)
- **الأخطاء الحرجة (Bugs):**
  1. **خطأ ترجمة (Compile Error) في السطر `388`:**
     ```dart
     child: Text(r.userName.isNotEmpty ? r.userName[0] : 'م', ...)
     ```
     في `lib/models/review_model.dart:19`، الحقل معرّف كـ `final String? userName;` (قابل لأن يكون `null`). استدعاء `r.userName.isNotEmpty` و`r.userName[0]` بدون فحص `null` يفشل في مترجم Dart (`The property 'isNotEmpty' can't be unconditionally accessed because the receiver can be 'null'`).
  2. **خطأ ترجمة (Compile Error) في السطر `399`:**
     ```dart
     Text(r.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
     ```
     تمرير `String?` إلى `Text()` الذي يتطلب `String` غير فارغ يفشل في الترجمة (`The argument type 'String?' can't be assigned to the parameter type 'String'`).
  3. **خطأ في السطر `407`:** استدعاء `r.rating.round()` بينما `r.rating` هو `int` أصلاً في `Review` (`review_model.dart:16`).
  4. **اختفاء الصور المتعددة للعروض في السطر `76–78`:**
     ```dart
     final List<String> imageUrls = isProduct
         ? (widget.item as Product).imageUrls
         : [(widget.item as Offer).imageUrl];
     ```
     رغم أن `Offer` يمتلك `List<String> imageUrls` (`offer.dart:14`) ويسمح للتاجر برفع حتى 5 صور للعرض في `AddOfferScreen`، إلا أن `DetailScreen` يتجاهل `offer.imageUrls` تماماً ويعرض صورة واحدة فقط (`offer.imageUrl`)!
  5. **اختفاء تفاصيل العرض الإضافية (`oldPrice`, `newPrice`, `giftDescription`, `bundleDetails`):** عند فتح عرض من نوع `price_drop` أو `gift` أو `bundle` في `DetailScreen`، لا يتم عرض السعر قبل وبعد الخصم ولا تفاصيل الهدية أو الباقة، بل يكتفي بعرض نسبة الخصم `%` فقط!
  6. **الألوان الثابتة في الوضع الليلي (`L230, L285`):** استخدام `Colors.white` لخلفية الصفحة و`Colors.black87` للنصوص يكسر الوضع الليلي.

### 2. `lib/screens/notifications_screen.dart` (614 سطراً) — 🔴 تحتوي على كراش مسارات (Route Crash)
- **الأخطاء الحرجة (Bugs):**
  1. **كراش عند الضغط على أي إشعار في `_onNotificationTap` (الأسطر `542–602`):**
     - السطر `545` و`552`: يستدعي `Navigator.pushNamed(context, '/collection/$colId')`.
     - السطر `563`: يستدعي `Navigator.pushNamed(context, '/job_ads')`.
     - السطر `569`: يستدعي `Navigator.pushNamed(context, '/service_requests')`.
     - السطر `577`: يستدعي `Navigator.pushNamed(context, '/shop/$targetShopId')`.
     - السطر `586`: يستدعي `Navigator.pushNamed(context, '/offer/$targetOfferId')`.
     - السطر `596`: يستدعي `Navigator.pushNamed(context, '/product/$targetProdId')`.
     - **النتيجة:** ولا واحد من هذه المسارات الستة موجود في `main.dart`! الضغط على أي إشعار داخل `NotificationsScreen` يرمي استثناء `FlutterError: Could not find a generator for route RouteSettings("/shop/...", null)`!
  2. **عدم معالجة إشعارات رد الشكاوى وعروض الخدمات (`L535–605`):**
     - عندما يرد الأدمن على شكوى (`admin_complaints_tab.dart:439`)، يرسل إشعاراً بـ `type: 'complaint_reply'` و`data.route: 'user_complaints'`.
     - عندما يقدّم صنايعي عرض سعر (`service_requests_tab_screen.dart:569`)، يرسل إشعاراً بـ `type: 'new_bid'` و`data.route: 'service_request:${req.id}'`.
     - دالة `_onNotificationTap` في `notifications_screen.dart` لا تفحص `complaint_reply` ولا `new_bid` ولا `bid_accepted`، فلا يحدث أي انتقال عند الضغط عليها!

### 3. `lib/screens/login_screen.dart` (506 أسطر)
- **الأخطاء والعيوب:**
  1. **عطل كامل في ميزة «نسيت كلمة المرور» (`_showForgotPasswordDialog` في السطر `129`):**
     - يقوم الكود بتحويل رقم الهاتف إلى بريد إلكتروني بالصيغة:
       ```dart
       final email = '${digits}@sanhour.online';
       await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
       ```
     - **الخطأ الأول:** في `AuthProvider._phoneToAuthEmail` (`auth_provider.dart:266`)، البريد الذي يُسجَّل به المستخدم فعلياً في Firebase Auth هو `u201xxxxxxxxx@users.sanhour.online` وليس `01xxxxxxxxx@sanhour.online`! لذلك يرد Firebase Auth دائماً بأن المستخدم غير موجود (`user-not-found`).
     - **الخطأ الثاني (معماري):** حتى لو تطابق البريد، فإن `@users.sanhour.online` هو بريد وهمي داخلي (Synthetic Email) لا يملكه المستخدم ولا يستطيع فتح صندوق وارده لاستلام رابط إعادة تعيين كلمة المرور!
     - **الحل الصحيح المتوافق مع نموذج عمل سنهور أونلاين:** استبدال `sendPasswordResetEmail` بنافذة تواصل مباشر مع الدعم الفني عبر واتساب الإدارة لإصدار كود إعادة تعيين كلمة مرور، أو التحقق عبر البريد الحقيقي الاختياري إن وُجد.

### 4. `lib/screens/complete_profile_screen.dart` (262 سطراً) و `lib/screens/account_edit_screen.dart` (515 سطراً)
- **العيوب والأخطاء:**
  - **في `complete_profile_screen.dart` (`L95–130`):** عند تسجيل الدخول بحساب Google لأول مرة، يُطلب من المستخدم إدخال رقم الهاتف واسم المستخدم، ولكن لا يوجد حقل لإدخال **كود الإحالة (`referralCode`)** رغم أن التسجيل العادي يدعمه!
  - **في `account_edit_screen.dart` (`L180–230`):** عند تغيير اسم المستخدم (`username`)، يتم فحص التفرد وتحديث مستند `users/{uid}`، ولكن لا يتم تحديث وثيقة حجز اليوزرنيم في مجموعة `usernames/{oldUsername}` و`usernames/{newUsername}`، مما يترك الاسم القديم محجوزاً للأبد والاسم الجديد غير محجوز في `usernames`!
  - **غياب قسم كود الدعوة والإحالات:** لا يوجد في `AccountEditScreen` ولا في `OptionsScreen` أي مكان يعرض للمستخدم كود الإحالة الخاص به (`ReferralService.getOrCreateCode`) لمشاركته مع أصدقائه!

### 5. `lib/screens/home_screen.dart` (908 أسطر) و `lib/screens/main_screen.dart` (482 سطراً)
- **العيوب والأخطاء:**
  - **في `home_screen.dart` (`L115–145`):** عند السحب للتحديث (`RefreshIndicator`)، يتم استدعاء `fetchShops(refresh: true)` و`fetchProducts(refresh: true)` و`fetchOffers(refresh: true)`، ولكن لا يتم إعادة جلب إعدادات البانر العام (`settings/general`) ولا تحديث قائمة `forYouProducts` المبنية على اهتمامات المستخدم إلا عند إعادة بناء الشاشة.
  - **في `home_screen.dart` (`L310–365`):** قسم "اخترنا لك" يعتمد على قراءة `user_interests` من `SharedPreferences` في كل مرة، وإذا اختار المستخدم فئات لا تحتوي حالياً على منتجات في الصفحة الأولى من `provider.products`، يختفي القسم أو يعرض منتجات عشوائية دون جلب منتجات من تلك الفئات من Firestore.
  - **في `main_screen.dart` (`L85–120`):** عداد الإشعارات غير المقروءة (`Badge`) يعتمد على `StreamBuilder` مفتوح مباشرة على `notifications` بدون تحديد `limit`، مما يقرأ جميع الإشعارات غير المقروءة في كل تحديث.

### 6. `lib/screens/categories_screen.dart` (474 سطراً) و `lib/screens/advanced_search_screen.dart` (851 سطراً)
- **العيوب والأخطاء:**
  - **في `categories_screen.dart` (`L210–265`):** الفلترة حسب القسم الفرعي (`subCategory`) والقسم الفرعي الدقيق (`subSubCategory`) تتم محلياً على قائمة `provider.shops` و`provider.products` المحملة في الذاكرة فقط؛ فإذا لم يكن المستخدم قد مرر لأسفل لتحميل كل الصفحات، لن تظهر له المحلات أو المنتجات الموجودة في الصفحات التالية ضمن هذا القسم!
  - **في `advanced_search_screen.dart` (`L180–245`):** البحث الذكي عبر Gemini (`GeminiService.smartSearch`) يُستدعى عند تفعيل خيار البحث الذكي، ولكن إذا فشل الاتصال أو لم يكن مفتاح Gemini متاحاً، يعود للبحث النصي العادي دون إشعار المستخدم بأن البحث الذكي غير مفعل حالياً.

### 7. `lib/screens/favorites_screen.dart` (421 سطراً) و `lib/screens/collection_detail_screen.dart` (591 سطراً)
- **العيوب والأخطاء:**
  - **في `collection_detail_screen.dart` (`L310–370`):** عند دعوة صديق لمشاركة قائمة مفضلة (`_inviteUser`)، يبحث الكود عن المستخدم عبر الهاتف أو اليوزرنيم، لكن إذا أدخل المستخدم رقم الهاتف بصيغة `010...` بينما هو مخزن في Firestore بصيغة `+2010...` (أو العكس)، قد يفشل البحث ما لم يتم تطبيع الرقم بنفس دالة `_normalizePhone` المستخدمة في `AuthProvider`!

### 8. `lib/screens/add_product_screen.dart` (435 سطراً) و `lib/screens/add_offer_screen.dart` (462 سطراً)
- **الأخطاء الحرجة (Bugs):**
  - **في `add_product_screen.dart` (`L77`):**
    ```dart
    // coverImageIndex دائماً 0 عند التعديل لأن Product لا يحفظه
    _coverImageIndex = 0;
    ```
    التعليق في الكود نفسه يعترف بالمشكلة! لأن `Product` model لا يحتوي على حقل `coverImageIndex`، فإن التاجر حين يختار الصورة رقم 2 كغلاف عند إضافة المنتج، ثم يفتح شاشة تعديل المنتج لاحقاً، يعود الغلاف تلقائياً إلى الصورة رقم 0!
  - **في `add_offer_screen.dart` (`L55–85`):** عند فتح عرض موجود للتعديل (`offerToEdit != null`)، لا يتم استرجاع `oldPrice` ولا `newPrice` إلى حقول النص `_oldPriceCtrl` و`_newPriceCtrl` لأن نموذج `Offer` (`lib/models/offer.dart`) لا يحتوي أصلاً على حقلي `oldPrice` و`newPrice` رغم أن `AddOfferScreen` يحفظهما في Firestore في السطور `155–156`!

### 9. `lib/screens/excel_upload_screen.dart` (370 سطراً)
- **العيوب والأخطاء:**
  - **السطر 95–155:** يقرأ ملف Excel (`.xlsx`) ويستخرج الصفوف، لكنه يرفع جميع المنتجات بدون صور (`imageUrls: []`) ولا يدعم قراءة عمود روابط الصور من ملف الإكسل إن وُجد، كما لا يضع حداً أقصى لعدد الصفوف في المرة الواحدة قبل تقسيمها.

### 10. `lib/screens/ads_hub_screen.dart` (92 سطراً)، `lib/screens/all_ads_screen.dart` (299 سطراً)، `lib/screens/job_ads_tab_screen.dart` (489 سطراً)، `lib/screens/post_job_ad_screen.dart` (409 أسطر)
- **العيوب والأخطاء:**
  - **في `all_ads_screen.dart` (`L165–210`):** يستخدم `AdminAdCard` (المستورد من `admin_ads_tab.dart`!) مع تمرير `showAdminControls: false`. ولكن عند الضغط على بطاقة الإعلان في `AllAdsScreen`، لا يوجد `onTap` في `AdminAdCard` (`admin_ads_tab.dart:339`)! أي أن المستخدم الذي يتصفح أرشيف الإعلانات في `AllAdsScreen` لا يستطيع الضغط على أي إعلان للانتقال إلى المحل أو المنتج المعلن عنه!
  - **في `job_ads_tab_screen.dart` (`L290–340`):** زر التواصل عبر واتساب على إعلان الوظيفة يركّب الرابط `'https://wa.me/2${job.posterPhone}'`. إذا كان `job.posterPhone` مخزناً بصيغة `+2010...` (كما يخزنه `AuthProvider` في `user.phone`!)، فإن إضافة `'2'` في البداية تجعل الرقم `'https://wa.me/2+2010...'` وهو رابط واتساب معطوب يفشل في فتح المحادثة! (نفس المشكلة تتكرر عند وجود `+20`).

### 11. `lib/screens/service_requests_tab_screen.dart` (930 سطراً)، `lib/screens/post_service_request_screen.dart` (326 سطراً)، `lib/screens/provider_registration_screen.dart` (324 سطراً)، `lib/screens/my_service_history_screen.dart` (533 سطراً)
- **الأخطاء الحرجة (Bugs):**
  1. **فلتر الترتيب الفارغ غير المربوط في `service_requests_tab_screen.dart` (السطر `160`):**
     ```dart
     filters: [
       SearchFilter(
         id: 'sort',
         label: 'الترتيب',
         options: ['الأحدث', 'العاجل أولاً', 'الأقل عروضاً'],
       ),
     ],
     onFilterChanged: (_, __) {},
     ```
     الدالة `onFilterChanged: (_, __) {}` فارغة تماماً! عندما يختار المستخدم "الأقل عروضاً" أو "الأحدث" من شريط الفلاتر، لا يحدث أي شيء على الإطلاق!
  2. **خطأ `RangeError` محتمل في `my_service_history_screen.dart` (السطر `495`):**
     عند عرض الحرف الأول من اسم مقدم الخدمة، إذا كان الاسم فارغاً يرمي `substring(0, 1)` خطأ `RangeError`.
  3. **عدم الاشتراك الفعلي في FCM Topics في `provider_registration_screen.dart` (الأسطر `107–116`):**
     يكتب الكود المجالات المختارة في وثيقة Firestore `provider_topic_subscriptions/{uid}`، لكنه **لا يستدعي** `FirebaseMessaging.instance.subscribeToTopic('providers_$c')` على الجهاز، ولا توجد Cloud Function تقرأ `provider_topic_subscriptions` لتسجيل الـ token في الـ topic! بالتالي لن تصل إشعارات طلبات الخدمة الجديدة للصنايعي عبر FCM Topic!
  4. **تضارب أسماء حقول `service_providers` بين شاشات التسجيل وشاشة الأدمن:**
     - في `provider_registration_screen.dart:87` و`add_service_provider_screen.dart:70`: يُحفظ المجال في مصفوفة `'categories'` والحالة في `'isActive'`.
     - في `admin_content_tab.dart:225–227`: يقرأ الأدمن الحقل `'serviceCategory'` (كنص مفرد!) والحقل `'isAvailable'`! لذلك تظهر كل حسابات الصنايعية في لوحة الإدارة تحت قسم `"خدمات عامة"` بدلاً من تخصصاتهم الفعلية!

### 12. `lib/screens/sanhour_dealer_screen.dart` (649 سطراً)
- **الأخطاء والعيوب:**
  1. **تسريب ذاكرة (Memory Leak) لـ 4 `TextEditingController` في `_showAddAdSheet` (`L455–458`):** يتم إنشاء `titleCtrl`، `descCtrl`، `priceCtrl`، و`phoneCtrl` عند فتح الـ BottomSheet دون عمل `dispose()` لها في `.whenComplete()`.
  2. **نقص زر التواصل عبر واتساب وتعديل الإعلان (`L264–286` و`L403–420`):** في تفاصيل إعلان الديلر يوجد زر اتصال هاتفي فقط بدون زر واتساب، وفي تبويب "إعلاني" يوجد زر `Switch` لتفعيل/إيقاف الإعلان فقط دون إمكانية حذف الإعلان أو تعديل سعره أو إضافة أكثر من صورة واحدة.
  3. **تحديد `limit(5)` ثابت في تبويب "إعلاني" (`L331`):** إذا نشر المستخدم أكثر من 5 إعلانات على مدار الشهور، لا تظهر إعلاناته السابقة ولا يمكنه إدارتها.

### 13. `lib/screens/shop_detail_screen.dart` (1000 سطر)
- **الأخطاء والعيوب:**
  1. **فقدان ردود التاجر وصور التقييمات وتاريخ التقييم في تبويب التقييمات (`L75–80` و`L948–980`):**
     في `_loadShopData()` (السطر `75–80`)، يقوم الكود بتحويل كائنات `Review` القادمة من `ApiService.getReviews` إلى `Map` مختزل يحتوي على 4 حقول فقط (`comment`, `rating`, `userName`, `userImage`) ويهمل `reply` (رد التاجر!) و`repliedAt` و`images` و`createdAt`! لذلك لا يظهر رد التاجر ولا صور التقييم في تبويب التقييمات داخل `ShopDetailScreen`!
  2. **ألوان ثابتة تكسر الوضع الليلي (`L462, L499, L675`):** وصف المحل في السطر `499` يستخدم `color: Colors.black87`، وبطاقة العرض في السطر `462` تستخدم `color: Colors.red[50]`، ونص `ChoiceChip` غير المحدد في السطر `675` يستخدم `Colors.black`، مما يجعلها غير مقروءة في الوضع الليلي.
  3. **السطر `706` (`p.sortOrder != null && p.sortOrder! < 999`):** في `Product` model (`product.dart:28`)، القيمة الافتراضية لـ `sortOrder` للمنتجات العادية غير المثبتة هي `0`! بينما `ProductOrderScreen` (`product_order_screen.dart:55`) يعطي المنتجات المثبتة أرقاماً من `1` إلى `10` والمنتجات غير المثبتة `0`. الشرط `p.sortOrder! < 999` في `shop_detail_screen.dart:706` يتحقق دائماً حتى عندما يكون `sortOrder == 0`! مما يجعل شارة **`"📌 مثبت"` تظهر على جميع منتجات المحل بلا استثناء** بدلاً من المنتجات التي شرطها `p.sortOrder > 0 && p.sortOrder <= 10`!

### 14. `lib/screens/splash_screen.dart` (274 سطراً)، `lib/screens/onboarding_screen.dart` (272 سطراً)، `lib/screens/interests_screen.dart` (211 سطراً)
- **العيوب والأخطاء:**
  - **في `splash_screen.dart` (`L226–245` - `_handleAdClick`):**
    1. عند الضغط على إعلان البداية (`Startup Ad`)، يبحث الكود عن المحل أو المنتج في `provider.shops` أو `provider.products`؛ ولكن في لحظة شاشة الـ Splash لم يتم تحميل `ShopsProvider` بعد (`provider.shops` قد تكون فارغة أو قيد التحميل)، فيرمي `firstWhere` استثناء `StateError` ويعرض `"العرض غير متاح حالياً"`!
    2. حتى لو نجح وفتح `ShopDetailScreen` عبر `Navigator.push` في السطر `232`، فبمجرد إغلاق الـ Dialog في السطر `203` (`Navigator.pop(context); _handleAdClick(ad);`)، يكمل `_startStartupSequence` تنفيذه في السطر `96` ويستدعي `_replaceSelfNamed('/home')` أو `'/login'`، مما قد يربك مكدس التنقل (`Navigator` stack).

### 15. `lib/screens/options_screen.dart` (753 سطراً)، `lib/screens/about_screen.dart` (279 سطراً)، `lib/screens/report_problem_screen.dart` (265 سطراً)، `lib/screens/my_complaints_screen.dart` (413 سطراً)، `lib/screens/review_screen.dart` (565 سطراً)، `lib/screens/subscription_screen.dart` (484 سطراً)، `lib/screens/seeder_screen.dart` (385 سطراً)، `lib/screens/merchant_type_screen.dart` (284 سطراً)
- **العيوب والأخطاء:**
  - **`about_screen.dart`:** شاشة ميتة (Dead Screen) من 279 سطراً لم تعد مستخدمة لأن `OptionsScreen` بنى بداخلها `_FirestoreTextScreen` (`options_screen.dart:650–753`) لعرض "من نحن" و"الشروط والأحكام" و"سياسة الخصوصية".
  - **في `options_screen.dart` (`L74–85` - `_performSoftDelete`):** عند طلب حذف الحساب للتاجر، يخفي المحل فقط (`isActive: false, hiddenByDeletion: true`)، لكنه **لا يخفي منتجات وعروض المحل** (`isShopHidden: true` في مجموعتي `products` و`offers`)، فتظل منتجات التاجر المحذوف حسابه ظاهرة في الصفحة الرئيسية والبحث!
  - **في `review_screen.dart` (`L246, L555`):** استخدام `color: Colors.grey[50]` لصندوق الترويسة و`color: Colors.black87` لنص رد البائع يكسر الوضع الليلي.

---

## 🏪 خامساً: الفحص التفصيلي لشاشات التاجر (`lib/screens/merchant/*.dart` — 11 ملفاً + `merchant_dashboard.dart`)

### 1. `lib/screens/merchant_dashboard.dart` (402 سطراً)
- **العيوب والأخطاء:**
  - **السطر 110–145:** يجلب بيانات المحل عند فتح اللوحة، ولكن إذا قام التاجر بتعديل بيانات المحل في `EditShopScreen` أو تجديد الاشتراك في `SubscriptionScreen` ثم عاد إلى `MerchantDashboard`، لا يتم تحديث كائن `_currentShop` في بعض المسارات إلا عند إعادة فتح اللوحة.

### 2. `lib/screens/merchant/add_service_provider_screen.dart` (296 سطراً)
- **الأخطاء:**
  - **السطر 78–80:** يحدّث `'businessType': 'service_provider'` في `users/{uid}`، لكنه لا يحدّث كائن المستخدم داخل `AuthProvider` في الذاكرة قبل الانتقال إلى `'/home'`، ولا يشترك فعلياً في FCM Topics على الجهاز.

### 3. `lib/screens/merchant/add_shop_screen.dart` (615 سطراً) و `lib/screens/merchant/edit_shop_screen.dart` (528 سطراً)
- **الأخطاء والعيوب:**
  - **في `add_shop_screen.dart` (`L138–149`):** يستدعي `ApiService.validateActivationCode(_activationCode)` للتحقق من الكود قبل رفع الصور، ثم داخل `ApiService.createShop` يتم التحقق من الكود وحرقه مرة أخرى. لكن إذا كانت `categories` في `ShopsProvider` لم تُحمّل بعد عند فتح `AddShopScreen` مباشرة بعد التسجيل، تكون القائمة المنسدلة للتصنيف فارغة (`categoryNames` فارغة في `L234`) فلا يستطيع التاجر اختيار تصنيف المحل!
  - **في `edit_shop_screen.dart` (`L158–175`):** لا يتيح للتاجر تعديل أيام العمل (`workingDays`) رغم وجودها في `Shop` model.

### 4. `lib/screens/merchant/merchant_marketing_tab.dart` (785 سطراً)
- **الأخطاء والعيوب:**
  1. **السطر 572 (`_validateAndBurnCode`):** يمرر `userId: widget.currentShop.ownerId`. إذا كان الذي ينشئ الإعلان هو **شريك (`partner`)** في المحل وليس المالك الأصلي، أو إذا كان `ownerId` فارغاً قبل المطالبة بالمحل، فإن `AdService.redeemAdCode` يسجل `usedBy: widget.currentShop.ownerId`، مما يفشل في قواعد Firestore إذا كانت القاعدة تتحقق من `request.resource.data.usedBy == appUid()`! (في `firestore.rules:429`، القاعدة تشترط `request.resource.data.usedBy == appUid()`؛ فإذا استخدم الشريك الكود، تكون `widget.currentShop.ownerId != appUid()` ويرفض Firestore العملية بـ `permission-denied`!).
  2. **السطر 318:** اختيار صورة الإعلان يستخدم `ImagePicker().pickImage(source: ImageSource.gallery)` مباشرة بدون تمريرها على `ImageHelper.pickAndCrop`، فلا يتم قص الصورة ولا ضغطها.

### 5. `lib/screens/merchant/merchant_offers_tab.dart` (475 سطراً)
- **الأخطاء الحرجة (Bugs):**
  1. **عدم تحديث القائمة بعد تجميد/تفعيل العرض (`_toggleVisibility` في السطر `417`) أو حذفه (`_confirmDelete` في السطر `463`):**
     يستدعي الكود `setState(() {})` فقط بدلاً من `_refreshOffers()`! وبما أن `FutureBuilder` يعتمد على `_offersFuture` المحفوظ في الـ state (`L28`)، والبيانات تُقرأ من `_allOffers` المحفوظة، فإن `setState(() {})` يعيد رسم نفس البيانات القديمة بدون أي تغيير! يظل العرض المحذوف ظاهراً أمام التاجر، ويظل العرض المجمّد بحالته القديمة حتى يغلق التاجر الشاشة ويعيد فتحها!
  2. **رسالة Snackbar معكوسة عند التجميد/التفعيل (`L421`):**
     ```dart
     await FirebaseFirestore.instance.collection('offers').doc(offer.id).update({'isVisible': !offer.isVisible});
     ...
     Text(offer.isVisible ? 'تم تفعيل العرض ✅' : 'تم تجميد العرض ⏸️')
     ```
     بما أن `offer.isVisible` هي القيمة **القديمة** قبل العكس (`!offer.isVisible`)، فإذا كان العرض ظاهراً (`offer.isVisible == true`) وضغط التاجر "تجميد مؤقت"، يُرسل الكود `isVisible: false` للسيرفر لكنه يعرض للتاجر رسالة: **`"تم تفعيل العرض ✅"`**! والعكس بالعكس!
  3. **دالة ميتة مكررة `duplicateOffer` (`L434–445`):** دالة غير مستخدمة تمرر `id: null` (بينما `_handleAction` في السطر `383` تعالج `'duplicate'` بالفعل).

### 6. `lib/screens/merchant/merchant_products_tab.dart` (579 سطراً)
- **الأخطاء الحرجة (Bugs):**
  1. **عدم تحديث قائمة المنتجات بعد التعديل أو الإخفاء أو الحذف الجماعي أو النقل الجماعي (`L363, L408, L456, L499`):**
     بعد أنreplaced الكود `FutureBuilder` بتحميل يدوي في `_allProducts` داخل `initState()` (`L28–54`)، نسي المطور استبدال `setState(() {})` باستدعاء `_loadProducts()` في 4 مواضع:
     - بعد العودة من تعديل المنتج (`L363`: `setState(() {});`).
     - بعد إخفاء/إظهار المنتج (`L408`: `setState(() {});`).
     - بعد الحذف الجماعي للمنتجات (`L456`: `setState(() {});`).
     - بعد النقل الجماعي لقسم آخر (`L499`: `setState(() {});`).
     **النتيجة:** كل هذه العمليات الأربع تنفذ في Firestore ولكن **لا تتحدث الشاشة أمام التاجر أبداً** لأن `_allProducts` في الذاكرة لم يتغير ولم يُستدعَ `_loadProducts()`!
  2. **عدم تحديث القائمة بعد العودة من `ExcelUploadScreen` (`L199`) و`ProductOrderScreen` (`L210`):** لا يوجد `.then((_) => _loadProducts())`.
  3. **تسريب ذاكرة (Memory Leak) للـ Controllers:** في `_showBulkMoveDialog` (`L470`) وفي `_showServicesManager` (`L513–515`) يتم إنشاء `TextEditingController` بدون `dispose()`.

### 7. `lib/screens/merchant/merchant_reviews_screen.dart` (361 سطراً)
- **الأخطاء الحرجة (Bugs):**
  - **استعلام التقييمات لا يجلب تقييمات منتجات المحل (`L65–69`):**
    يحتوي `_filteredReviews` (`L108–109`) و`_buildReviewCard` (`L240, L253`) على منطق لعرض تقييمات المنتجات (`targetType == 'product'`). لكن الاستعلام في `_loadReviews` (`L65–69`) يطلب فقط `.where('targetId', isEqualTo: widget.shopId)`! وبما أن تقييم المنتج يحمل `targetId == productId` وليس `shopId`، فإن تقييمات منتجات التاجر **لا تظهر أبداً في شاشة تقييمات التاجر** ولا يستطيع التاجر الرد عليها!

### 8. `lib/screens/merchant/merchant_services_tab.dart` (231 سطراً)
- **العيوب والأخطاء:**
  - يعمل بشكل جيد، ولكن زر إضافة خدمة مكرر أيضاً داخل `MerchantProductsTab._showServicesManager` (`merchant_products_tab.dart:512`) حيث يضيف الخدمة هناك **بدون حقل `'ownerId'`** (`L560–565`) بينما `MerchantServicesTab` يضيف `'ownerId': widget.currentShop.ownerId` (`L104`)!

### 9. `lib/screens/merchant/merchant_stats_tab.dart` (458 سطراً)
- **العيوب والأخطاء:**
  - **السطر 222:** يعرض `'أنت تتنافس مع ${_overviewData!['totalCompetitors'] - 1} متاجر أخرى'`. إذا كان `totalCompetitors` يساوي `0`، يظهر النص: **`"أنت تتنافس مع -1 متاجر أخرى"`**! يجب استخدام `math.max(0, totalCompetitors - 1)`.
  - **السطر 314:** زر `"عرض المزيد (Load More)"` يظهر دائماً في أسفل القائمة حتى لو كان عدد منتجات التاجر الكلي 3 منتجات فقط ولا يوجد المزيد لتحميله!

### 10. `lib/screens/merchant/product_order_screen.dart` (406 أسطر)
- **الأخطاء والعيوب:**
  1. **القوائم الجديدة لا تُحفظ إذا كانت فارغة (`_showNewListDialog` في السطر `373`):** عندما ينشئ التاجر قائمة داخلية جديدة، تُضاف إلى `_productLists` في الذاكرة فقط. إذا خرج التاجر من الشاشة دون نقل منتج إليها، تضيع القائمة لأن القوائم تُستنتج فقط من حقل `listName` داخل المنتجات (`L60–65`).
  2. **تسريب ذاكرة (`L356`):** `ctrl` في `_showNewListDialog` لا يتم عمل `dispose()` له.

### 11. `lib/screens/merchant/team_management_screen.dart` (308 أسطر)
- **الأخطاء والعيوب:**
  - **تنسيق رقم الهاتف عند البحث لإضافة عضو (`L51`):**
    ```dart
    .where('phone', isEqualTo: phone.startsWith('+2') ? phone : '+2$phone')
    ```
    في حقل الإدخال (`L128`)، وضع المطور `prefixText: '+20 '`. لذلك يظن التاجر أن `+20` مكتوبة مسبقاً فيدخل الرقم بدون صفر البداية (`1008908728`)! عندها يقوم السطر `51` بتركيب `'+21008908728'` (بدون الصفر بعد `+2`) فلا يعثر على المستخدم أبداً! يجب استخدام دالة تطبيع موحدة تحول `010...` و`10...` و`+2010...` إلى `+2010...`.

---

## 🛡️ سادساً: الفحص التفصيلي لتبويبات لوحة الإدارة (`lib/screens/tabs/*.dart` — 9 ملفات + `admin_dashboard.dart`)

### 1. `lib/screens/admin_dashboard.dart` (109 أسطر)
- **العيوب:** تحتوي على 8 تبويبات في `TabBar` ولكنها **لا تعرض تبويب `AdminLocationsTab`**!
  - لنفحص `admin_dashboard.dart`! في `admin_dashboard.dart`، التبويبات هي: الإحصائيات، الأكواد، الإعلانات، المحتوى، الأقسام، المستخدمين، الشكاوى، الإعدادات (8 تبويبات). بينما ملف `lib/screens/tabs/admin_locations_tab.dart` (410 أسطر) موجود في المشروع لإدارة المناطق الجغرافية وإظهار/إخفاء فلتر الموقع، ولكنه **غير مضاف أصلاً في `AdminDashboard` ولا يمكن للأدمن الوصول إليه من أي مكان في التطبيق!** (نقص حرج جداً).

### 2. `lib/screens/tabs/admin_ads_tab.dart` (749 سطراً)
- **الأخطاء والعيوب:**
  - **السطر 708–722 (`_AdFormScreen`):** عندما يختار الأدمن `_targetType = 'screen'`، تظهر القائمة المنسدلة `DropdownButtonFormField` بالقيمة الابتدائية `'offers'`، لكن `_targetIdCtrl.text` يظل فارغاً (`''`) ما لم يقم الأدمن بتغيير القيمة يدوياً في القائمة المنسدلة (`onChanged`)! فإذا تركها الأدمن على الخيار الأول ("صفحة العروض") وضغط حفظ، يُحفظ الإعلان بـ `targetId: null` ولا يفتح صفحة العروض!
  - **عدم وجود خيار تعديل الإعلان للأدمن:** `AdminAdCard` يعرض للأدمن زر تفعيل/تعطيل وزر حذف فقط، ولا يتيح للأدمن تعديل نص أو صور أو مدة الإعلان بعد نشره.

### 3. `lib/screens/tabs/admin_categories_tab.dart` (699 سطراً)
- **العيوب والأخطاء:**
  - عند تعديل اسم فئة رئيسية (مثلاً من `"مطاعم"` إلى `"مطاعم وكافيهات"`)، يتم تحديث وثيقة الفئة في `categories`، لكن جميع المحلات والمنتجات المسجلة بالاسم القديم `"مطاعم"` تظل تحمل الاسم القديم في حقل `category` وتختفي عند التصفية بالاسم الجديد!

### 4. `lib/screens/tabs/admin_codes_tab.dart` (506 أسطر)
- **الأخطاء والعيوب:**
  - **في `_buildCodeTicket` (`L257–261`):** عند عرض تبويب رقم `3` (`🔄 التجديد`)، السويتش يفرغ `valueStr = ''` ولا يعرض قيمة كود التجديد، وفي السطر `307` يعرض أيقونة `Icons.sell` بدلاً من `Icons.autorenew`، وفي `_showSuccessDialog` (`L442`) يعطي لون `Colors.teal` بدلاً من `Colors.indigo`.
  - **في `_deleteCode` (`L497`):** يسجل في سجل التدقيق `AuditAction.activationCodeUsed` عند **حذف** الكود بدلاً من إجراء خاص بحذف الكود.

### 5. `lib/screens/tabs/admin_complaints_tab.dart` (504 أسطر)
- **الأخطاء والعيوب:**
  - **تسريب ذاكرة (`L358`):** `replyCtrl` في `_showReplyDialog` لا يتم عمل `dispose()` له عند إغلاق الـ Dialog.
  - **في `_submitReply` (`L429`):** إذا أرسل زائر (`userId == 'guest'`) شكوى، وردّ عليها الأدمن، فإن الشرط `if (userId.isNotEmpty)` يتحقق لأن `'guest'.isNotEmpty == true`! فيقوم الكود بإرسال إشعار في `notifications` وإشعار في `notification_queue` للمعرف الوهمي `'guest'`! يجب أن يكون الشرط `if (userId.isNotEmpty && userId != 'guest')`.

### 6. `lib/screens/tabs/admin_content_tab.dart` (555 سطراً)
- **الأخطاء الحرجة (Bugs):**
  1. **فتح `StreamBuilder` غير محدود بدون Pagination على 4 مجموعات كاملة (`L345–350`):**
     يفتح `_buildStreamList` استماعاً حياً (`snapshots()`) على كامل مجموعة `shops`، وكامل `products`، وكامل `offers`، وكامل `service_providers` بدون `.limit()`! إذا كان في التطبيق 2000 منتج، فإن فتح تبويب المحتوى يحمّل 2000 وثيقة دفعة واحدة!
  2. **تضارب حقول `service_providers` (`L224–227`):**
     يقرأ `data['serviceCategory']` و`data['isAvailable']`، بينما شاشات تسجيل الصنايعي تكتب `data['categories']` (List) و`data['isActive']` (bool)!

### 7. `lib/screens/tabs/admin_locations_tab.dart` (410 أسطر)
- **الأخطاء:**
  - **التبويب معزول وغير مربوط في `AdminDashboard` (`admin_dashboard.dart`)!** لا يمكن للأدمن الوصول لهذه الشاشة نهائياً من الواجهة.
  - **تسريب ذاكرة (`L116`):** `ctrl` في `_editRegion` لا يتم عمل `dispose()` له.

### 8. `lib/screens/tabs/admin_overview_tab.dart` (694 سطراً)
- **الأخطاء والعيوب:**
  - **في `DetailedReportScreen._loadData` (`L495, L497`):** عندما يكون `_selectedCategory == 'الكل'`، يمرر الكود `category: 'الكل'` إلى `ApiService.getRankedShops(category: _selectedCategory)` و`ApiService.getTopProducts(category: _selectedCategory)`.
    - في `ShopService.getRankedShops` (`shop_service.dart:61`)، يفحص `if (category != null && category != 'الكل')` (يعمل).
    - لكن في `ProductService.getTopProducts` (`product_service.dart:80`)، يفحص فقط `if (category != null && category.isNotEmpty)` **ولا يستثني `'الكل'`**! فيبحث في Firestore عن منتجات قسمها اسمه حرفياً `'الكل'` ويرجع قائمة فارغة دائماً (`0` منتجات)!

### 9. `lib/screens/tabs/admin_settings_tab.dart` (763 سطراً)
- **العيوب والأخطاء:**
  - **السطر 28 (`final bool _isSeeding = false;`):** متغير `final` ثابت لا يتغير أبداً، لأن الزر أصبح يفتح `SeederScreen`.
  - **في `_sendForceUpdate` (`L164–180`) و`_disableForceUpdate` (`L182–192`):** في حالة حدوث استثناء داخل `try`، يتم ابتلاع الخطأ في `catch (_) {}` بصمت دون إظهار أي رسالة للأدمن بأن التفعيل فشل!

### 10. `lib/screens/tabs/admin_users_tab.dart` (469 سطراً)
- **الأخطاء الحرجة (Bugs):**
  - **كراش `RangeError` في السطر `243`:**
    ```dart
    (user['name'] ?? '?').toString().substring(0, 1).toUpperCase()
    ```
    إذا كان حقل `user['name']` موجوداً في Firestore ولكنه نص فارغ `""` (وليس `null`)، فإن `user['name'] ?? '?'` يرجع `""`، واستدعاء `"".substring(0, 1)` يرمي `RangeError (end): Invalid value: Only valid value is 0: 1` ويكسر شاشة المستخدمين بالكامل!

---

## ⚙️ سابعاً: فحص إعدادات المنصات والاختبارات (`android/`, `ios/`, `web/`, `test/`)

1. **`android/app/build.gradle.kts` (68 سطراً):**
   - **تعارض `namespace` و`applicationId` (`L18` مقابل `L33`):** `namespace = "com.example.sanhour_online"` بينما `applicationId = "com.sanhour.online"`. يُفضل توحيد `namespace` ليكون `"com.sanhour.online"`.
   - **التوقيع في وضع Release (`L53–57`):** إذا لم يكن ملف `key.properties` موجوداً، يوقّع نسخة الـ Release بمفتاح `debug` دون تنبيه أو إيقاف البناء.
2. **`android/app/src/main/AndroidManifest.xml` (91 سطراً):**
   - **السطر 9 (`SCHEDULE_EXACT_ALARM`):** إذن حساس في Android 13/14+ قد يسبب رفض التطبيق في مراجعة Google Play إذا لم يكن التطبيق تطبيق منبه أو تقويم؛ الإشعارات المحلية العادية لا تحتاج `SCHEDULE_EXACT_ALARM` هنا.
3. **`web/manifest.json` (35 سطراً) و `web/index.html` (102 سطراً):**
   - **في `web/manifest.json` (`L2–8`):** لا يزال يحمل القيم الافتراضية لمشروع Flutter جديد: `"name": "myapp"`, `"short_name": "myapp"`, `"description": "A new Flutter project."`, `"theme_color": "#0175C2"` بدلاً من `"سنهور أونلاين"` واللون البنفسجي `#5E35B1`!
   - **في `web/index.html` (`L25`):** `window.flutterWebRenderer = "html";` مهمل (Deprecated) في إصدارات Flutter الحديثة (Flutter 3.29+ / 3.32+).
4. **`test/widget_test.dart` (200 سطر):**
   - **خطأ ترجمة في الاختبار (`test/widget_test.dart:119`):**
     ```dart
     ServiceRequestModel.categoryLabel(ServiceCategory.plumbing)
     ```
     اسم الـ Enum في `lib/models/service_request_model.dart:6` هو `ServiceRequestCategory` وليس `ServiceCategory`! لذلك يفشل تشغيل `flutter test` بخطأ ترجمة `Undefined name 'ServiceCategory'`!

---

## 💡 ثامناً: الاقتراحات والتحسينات والإضافات المقترحة للفرونت إند (Suggestions, Improvements & Proposed Additions)

### 1. اقتراحات عامة (General Suggestions)
1. **توحيد نظام التوجيه المركزي (`AppRouter`):** إلغاء التشتت بين `routes` و`onGenerateRoute` و`_buildNotificationRoute` وبناء موجه مركزي واحد يدعم الروابط العميقة ومسارات الإشعارات بكفاءة.
2. **توحيد إدارة الحالة وفصل منطق Firestore عن الشاشات:** نقل جميع استدعاءات `FirebaseFirestore.instance` المباشرة الموجودة داخل 18 شاشة (مثل `PostJobAdScreen`، `PostServiceRequestScreen`، `SanhourDealerScreen`، `TeamManagementScreen`، `ProductOrderScreen`، `AdminLocationsTab`) إلى طبقة الخدمات (`Services`) ومزودات الحالة (`Providers`).
3. **حذف الملفات والكود الميت (Dead Code Cleanup):** إزالة أو دمج `lib/screens/about_screen.dart`، `lib/widgets/search_bar.dart`، `lib/widgets/startup_ad_dialog.dart`، و`lib/widgets/category_list.dart`، واستخدام `PaginatedListView` الموجود في `lib/widgets/pagination_widget.dart`.

### 2. تحسينات تقنية وبصرية مقترحة (Proposed Technical & UX Improvements)
1. **إصلاح شامل للوضع الليلي (Dark Mode Polish):** استبدال جميع الألوان الثابتة (`Colors.white`, `Colors.black87`, `Colors.grey[100]`) بمتغيرات `Theme.of(context).colorScheme` لضمان تباين مثالي (WCAG AA) في الوضعين الفاتح والداكن.
2. **إضافة مشغل فيديو مدمج خفيف لمعرض المحل والإعلانات:** استخدام حزمة `video_player` مع واجهة تحكم عربية بسيطة داخل `MediaPreviewDialog` و`AdCarousel` بدلاً من إخراج المستخدم للمتصفح.
3. **ربط تبويب `AdminLocationsTab` في `AdminDashboard`:** إضافته كتبويب تاسع في لوحة الإدارة أو دمجه داخل `AdminSettingsTab` ليتمكن الأدمن من إدارة مناطق سنهور القبلية وتفعيل فلتر الموقع.
4. **إصلاح عرض الغلاف المختار للمنتج والعرض (`coverImageIndex`):** إضافة دالة `String get displayCoverUrl` في كل من `Product` و`Offer` ترجع `imageUrls[coverImageIndex]` بأمان، واستخدامها في جميع بطاقات العرض.

### 3. إضافات مقترحة للفرونت إند (Proposed Additions — متوافقة 100% مع هوية سنهور أونلاين كدليل محلي بدون سلة مشتريات أو دفع إلكتروني أو توصيل)
1. **بطاقة «مفتوح الآن / مغلق الآن» الذكية للمحلات:** تحويل مواعيد عمل المحل إلى مؤشر حي أخضر/أحمر ("مفتوح الآن • يغلق 11:00 م") يظهر على بطاقة المحل وفي صفحته.
2. **مشاركة بطاقة المحل أو العرض كصورة مصممة على واتساب ورموز QR للمحلات:** توليد بطاقة بصرية أنيقة للمحل أو العرض مع كود QR خاص بالمحل يطبعه التاجر ويعلقه في محله بسنهور ليمسحه الأهالي ويفتحوا صفحة المحل مباشرة.
3. **شاشة «دعوة الأصدقاء ومكافآتي» للتجار والمستخدمين:** واجهة لعرض ونسخ كود الإحالة (`ReferralService`) ومتابعة عدد الأيام المجانية المكتسبة للتاجر عند دعوة تجار أو مستخدمين جدد.
4. **مقارنة عروض الأسعار للصنايعية جنباً إلى جنب:** في شاشة عروض طلب الخدمة (`_BidsListScreen`)، عرض تقييم الصنايعي وسابقة أعماله وشارة التوثيق (`✅ صنايعي موثق`) بجانب السعر المقدم لتسهيل الاختيار قبل الاتصال به.
5. **دليل «أرقام الطوارئ والخدمات العامة في سنهور القبلية»:** قسم سريع في الشاشة الرئيسية أو الخيارات يضم أرقام الطوارئ والمرافق الحيوية في سنهور (الإسعاف، المطافئ، الوحدة الصحية، أعطال الكهرباء والمياه، الصيدليات المناوبة ليلاً).
