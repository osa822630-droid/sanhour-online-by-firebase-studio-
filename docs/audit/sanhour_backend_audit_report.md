# 🛡️ التقرير الفني الشامل والدقيق لفحص الباك إند والبيانات والأمان (Backend & Data Layer Audit Report) — مشروع «سنهور أونلاين» (Sanhour Online)

**نطاق الفحص:** فحص شامل سطراً بسطر (Line-by-Line) لـ **50 ملفاً** تُمثّل كامل البنية التحتية للباك إند، قواعد الأمان، الفهارس، الدوال السحابية، خدمات البيانات، النماذج، ومزودات الحالة (`firebase.json`، `firestore.rules`، `firestore.indexes.json`، `storage.rules`، `functions/package.json`، `functions/index.js`، `lib/firebase_options.dart`، `pubspec.yaml`، `analysis_options.yaml`، `11` ملف نماذج في `lib/models/*.dart`، `22` ملف خدمات في `lib/services/*.dart`، `5` ملفات مزودات حالة في `lib/providers/*.dart`، و`3` ملفات أدوات مساعدة للبيانات في `lib/utils/date_helper.dart`، `date_parser.dart`، `logger.dart`).

---

## 📊 أولاً: الملخص التنفيذي ومصفوفة المخاطر الحرجة (Executive Risk Matrix)

| التصنيف | العدد المرصود | درجة الخطورة | أبرز الأمثلة الحرجة بالملف والسطر |
|---|---|---|---|
| **ثغرات أمنية قاتلة (Critical Security Vulnerabilities - P0)** | 7 ثغرات | 🔴 حرجة جداً (P0) | انتحال هوية السوبر أدمن (`super_admin`) عبر `auth_sessions` في `firestore.rules:13–17, 140–149` و`storage.rules:22, 29–33` و`functions/index.js:130–133`؛ تسريب مفتاح `Gemini API Key` لكل المستخدمين في `firestore.rules:468–471` و`auth_provider.dart:220–231`؛ صلاحية رد أي تاجر على تقييمات أي محل آخر في `firestore.rules:280`؛ والتلاعب بعدادات التقييمات والمشاهدات في `firestore.rules:168, 221, 242, 320`. |
| **أخطاء تمنع الترجمة (Compile-Time Errors)** | خطآن | 🔴 حرجة جداً (P0) | `lib/services/notification_service.dart` (الأسطر `78–80`): استدعاء `SharedPreferences.getInstance()` و`jsonDecode()` بدون عمل `import` لحزمتي `shared_preferences` و`dart:convert`. |
| **أعطال استعلامات وقواعد Firestore (Runtime Query & Rules Failures)** | 14 عطلاً | 🔴 حرجة (P0) | فشل كامل لنظام الإحالات (`ReferralService.applyReferralCode`) بسبب `permission-denied` في `firestore.rules:120, 492`؛ فشل استعلامات المنتجات والعروض والمتاجر وسجل التدقيق في الإنتاج بسبب نقص الفهارس المركبة (`Composite Indexes`) في `firestore.indexes.json`؛ ومحاولة حذف العروض المنتهية من حسابات الزوار في `product_service.dart:224`. |
| **عيوب النماذج وتلف البيانات (Data Model & Serialization Bugs)** | 16 عيباً | 🟠 عالية (P1) | إسقاط `userName` و`userImage` في `Review.toMap()` (`review_model.dart:68–80`)؛ تحويل `createdAt` إلى `String` في `Product.toMap()` و`Shop.toMap()` مما يكسر ترتيب Firestore؛ غياب `coverImageIndex` من `Product` وغياب `oldPrice`/`newPrice` من `Offer`؛ وعدم إخفاء إعلانات المحل عند تعطيله في `admin_service.dart:332`. |
| **نواقص معمارية ودوال سحابية مفقودة (Missing Backend Capabilities)** | 15 عنصراً | 🟡 متوسطة/تحسينية | غياب Cloud Function لمعالجة طابور الإشعارات (`notification_queue`)؛ غياب Cloud Function للتحقق من كود الإحالة وتحديث رصيد الداعي؛ غياب Cron Job لإيقاف المحلات المنتهي اشتراكها تلقائياً؛ وعدم تفعيل Firebase App Check. |

---

## 🚨 ثانياً: الفحص السطري لملفات القواعد والفهارس والدوال السحابية (`firestore.rules`, `storage.rules`, `firestore.indexes.json`, `functions/`)

### 1. ملف قواعد قاعدة البيانات `firestore.rules` (557 سطراً)
- **الدوال المفحوصة:** `isAuth()`, `appUid()`, `userExists()`, `userData()`, `userRole()`, `isSuperAdmin()`, `isAdmin()`, `isModerator()`, `isMerchant()`, `isActiveUser()`, `canManageShop()`, `canManageShopContent()`, وجميع قواعد الـ `24` مجموعة (Collections).
- **الأخطاء والثغرات الأمنية القاتلة (Critical Security Bugs):**
  1. **ثغرة السيطرة الكاملة على النظام وانتحال هوية السوبر أدمن (`Lines 13–17` و `Lines 140–149`):**
     ```javascript
     function appUid() {
       return exists(/databases/$(database)/documents/auth_sessions/$(request.auth.uid))
         ? get(/databases/$(database)/documents/auth_sessions/$(request.auth.uid)).data.appUserId
         : request.auth.uid;
     }
     ...
     match /auth_sessions/{sessionUid} {
       allow read: if isAuth() && request.auth.uid == sessionUid;
       allow create, update: if isAuth()
         && request.auth.uid == sessionUid
         && isAnonymousSession()
         && request.resource.data.keys().hasOnly(['appUserId', 'updatedAt'])
         && request.resource.data.appUserId is string
         && request.resource.data.appUserId.size() > 0
         && request.resource.data.appUserId.size() <= 128;
     }
     ```
     - **كيف تحدث الكارثة؟** أي شخص يملك مفتاح Firebase العام الموجود في APK التطبيق (`lib/firebase_options.dart`) يستطيع تسجيل دخول مجهول (`signInAnonymously()`) ثم كتابة وثيقة في `/auth_sessions/{his_anon_uid}` تحتوي على `{"appUserId": "<معرف_حساب_الأدمن_أو_أي_تاجر>"}`!
     - بمجرد كتابة هذه الوثيقة، فإن الدالة `appUid()` تعتبر هذا المهاجم هو السوبر أدمن نفسه (`isSuperAdmin() == true` و`isAdmin() == true`)، فيحصل فوراً على صلاحية قراءة وتعديل وحذف جميع المستخدمين، المحلات، الأكواد، الإعدادات، وحذف أي محل عبر Cloud Function `deleteShopCascade`!
     - **سبب الخطأ:** تم تصميم `auth_sessions` لدعم الحسابات التجريبية (`Mock Mode`) أثناء التطوير، لكن قواعد Firestore تعمل على السيرفر ولا تعرف شيئاً عن متغير `BuildFlags.mockModeEnabled` الموجود في كود العميل!
     - **الحل الإلزامي قبل الإطلاق:** تعطيل `auth_sessions` تماماً في الإنتاج (`allow create, update: if false;`) وجعل `appUid()` يرجع `request.auth.uid` فقط!
  2. **ثغرة تسريب مفتاح Gemini API Key لجميع المستخدمين والزوار (`Lines 468–471`):**
     ```javascript
     match /settings_private/{docId} {
       allow read: if hasSessionIdentity();
       allow write: if isAdmin();
     }
     ```
     - الدالة `hasSessionIdentity()` ترجع `true` لأي مستخدم مسجل دخول (أو أي جلسة مجهولة). وبذلك يستطيع أي مستخدم قراءة وثيقة `settings_private/gemini` وسحب مفتاح `apiKey` الخاص بحسابك المدفوع على Google AI واستخدامه خارج التطبيق بلا حدود!
     - **الحل الإلزامي:** جعل `match /settings_private/{docId}` مقروءاً ومكتوباً للأدمن فقط (`allow read, write: if isAdmin();`)، وحذف `AuthProvider._loadGeminiKey()` من التطبيق بحيث تمر جميع طلبات الذكاء الاصطناعي حصرياً عبر Cloud Function `askGemini` (`functions/index.js:171`).
  3. **ثغرة تعديل ردود التقييمات من أي تاجر على محلات المنافسين (`Lines 278–285`):**
     ```javascript
     allow update: if (
       (canManageShopContent(resource.data.targetId) || isMerchant())
       && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['reply', 'repliedAt'])
     ) || isModerator();
     ```
     - بسبب وجود `|| isMerchant()` بدون قيد ملكية، **يستطيع أي تاجر في التطبيق تعديل أو مسح أو كتابة رد باسم البائع على تقييمات أي محل آخر منافس له!**
     - كما أن التقييمات المكتوبة على منتج (`targetType == 'product'`) يكون فيها `resource.data.targetId` هو معرف المنتج (`productId`) وليس معرف المحل (`shopId`)، فتفشل دالة `canManageShopContent(resource.data.targetId)` لأنها تبحث في `/shops/$(targetId)`.
  4. **ثغرة التلاعب بعدادات التقييمات والمشاهدات والمفضلة والنقرات (`Lines 168–181, 221–227, 242–246, 320–321`):**
     - في `shops` (`L168`): يُسمح لأي مستخدم مسجل بتحديث `['views', 'favoriteCount', 'rating', 'reviewCount', 'phoneClicks', 'whatsappClicks', 'facebookClicks', 'instagramClicks', 'tiktokClicks', 'telegramClicks']` إلى أي قيمة يشاء دون التحقق من أن الزيادة بمقدار `+1` فقط أو أن التقييمات ضمن النطاق `0.0..5.0`! يستطيع أي مستخدم تصفير تقييم محل منافس (`rating: 1.0`) أو رفع مشاهدات محله إلى مليون مشاهدة!
  5. **تعطل نظام الإحالات بالكامل بسبب تعارض القواعد مع الكود (`Lines 120–130` و `Lines 487–495`):**
     - في `match /referrals/{refId}` (`L492`): القاعدة تشترط `request.resource.data.referredId == appUid()`. بينما `ReferralService.applyReferralCode` (`referral_service.dart:138`) يكتب الحقل باسم `'newUserId'` وليس `'referredId'`!
     - وفي نفس الـ Transaction (`referral_service.dart:128–131`)، يحاول المستخدم الجديد تحديث وثيقة المستخدم الداعي `users/{referrerId}` لزيادة `referralCount` و`referralBonusDaysEarned`، ولكن قاعدة `match /users/{userId}` (`L120`) تمنع أي مستخدم من تعديل وثيقة مستخدم آخر! النتيجة: فشل حتمي بـ `permission-denied` في كل مرة يُستخدم فيها كود إحالة!
  6. **ثغرة قراءة جميع بيانات المستخدمين وأرقام هواتفهم (`Lines 113–115`):**
     - `match /users/{userId}` يسمح بـ `allow read: if hasSessionIdentity();`، مما يتيح لأي مستخدم مسجل عمل استعلام `collection('users').get()` وسحب قاعدة بيانات جميع أهالي وتجار سنهور القبلية بأرقام هواتفهم وإيميلاتهم!

### 2. ملف قواعد التخزين `storage.rules` (176 سطراً)
- **الأخطاء والثغرات الأمنية:**
  1. **السطر `22` (`function allowMockSessions() { return true; }`):**
     مفعّل دائماً على `true` في السيرفر! ويسمح لأي جلسة مجهولة بانتحال صفة الأدمن أو التاجر عبر قراءة `firestore.get(/databases/(default)/documents/auth_sessions/$(request.auth.uid))` (`L29–33`) ورفع أو استبدال ملفات في مسارات الإدارة والمتاجر!
  2. **غياب صلاحية الحذف (`delete`) أو التقييد بالملكية:**
     قواعد `allow write` في المسارات `/shops/{allPaths=**}` و`/products/{allPaths=**}` و`/offers/{allPaths=**}` تسمح لأي تاجر (`isMerchant()`) بالكتابة أو الحذف في مجلدات الصور دون التحقق من ملكيته للمحل أو الملف لأن المسارات لا تتضمن `{shopId}` كجزء مفحوص في القاعدة!

### 3. ملف الفهارس المركبة `firestore.indexes.json` (237 سطراً)
- **الفهارس المفقودة أو الخاطئة التي تسبب انهيار الاستعلامات في الإنتاج (`failed-precondition: The query requires an index`):**
  1. **مجموعة `products` (`product_service.dart:44–50, 601–609`):**
     - الكود يستعلم بـ: `where('isVisible', isEqualTo: true)` + `where('isShopHidden', isEqualTo: false)` + `[where('shopId', isEqualTo: shopId)]` + `orderBy('createdAt', descending: true)`.
     - الفهرس الموجود في `firestore.indexes.json:23–30` يحتوي فقط على `shopId + isVisible + createdAt` **وينقصه حقل `isShopHidden`**! كما لا يوجد فهرس للاستعلام العام بدون `shopId` (`isVisible + isShopHidden + createdAt`)!
  2. **مجموعة `products` للأعلى مشاهدة (`product_service.dart:78–84`):**
     - الكود يستعلم بـ: `where('isVisible', isEqualTo: true)` + `[where('category', isEqualTo: category)]` + `orderBy('views', descending: true)`.
     - **لا يوجد أي فهرس مركب لهذا الاستعلام في `firestore.indexes.json`!**
  3. **مجموعة `offers` (`product_service.dart:206–213, 242–247`):**
     - الكود يستعلم بـ: `where('isActive', isEqualTo: true)` + `where('isShopHidden', isEqualTo: false)` + `where('shopId', isEqualTo: shopId)`.
     - وفي `getTopOffers` يستعلم بـ: `where('isActive', isEqualTo: true)` + `orderBy('views', descending: true)`.
     - **كلا الفهرسين مفقودان من `firestore.indexes.json`!**
  4. **مجموعة `shops` عند التصفية بالمنطقة أو الترتيب بالمشاهدات (`shop_service.dart:59–66, 566–577`):**
     - عند تصفية المحلات حسب المنطقة (`region != null`)، يضيف الكود `.where('location', isEqualTo: region)` مع `isSuspended` و`isFeatured` و`createdAt` — **لا يوجد فهرس مركب يشمل `location`!**
     - وفي `getRankedShops` (`L59–66`) يستعلم بـ `isSuspended == false` + `category == ...` + `orderBy('views', descending: true)` — **لا يوجد فهرس مركب له!**
  5. **مجموعة `admin_audit_log` (`audit_log_service.dart:65, 137, 156` مقابل `firestore.indexes.json:170–185`):**
     - الكود في `audit_log_service.dart` يحفظ ويرتب بالحقل `'timestamp'` (`orderBy('timestamp', descending: true)`).
     - بينما الفهارس في `firestore.indexes.json` مبنية على حقل باسم `'createdAt'` (`adminId + createdAt` و`action + createdAt`)!
  6. **مجموعة `referrals` (`referral_service.dart:184–189`):**
     - الكود يستعلم بـ `where('referrerId', isEqualTo: userId).orderBy('appliedAt', descending: true)` — **لا يوجد فهرس مركب له في `firestore.indexes.json`!**
  7. **مجموعة `service_bids` (`service_requests_tab_screen.dart:668–671`):**
     - الكود يستعلم بـ `where('requestId', isEqualTo: request.id).orderBy('createdAt', descending: false)` (تصاعدي `ASC`).
     - بينما الفهرس في `firestore.indexes.json:99–106` معرّف بترتيب تنازلي `DESCENDING` فقط!

### 4. الدوال السحابية `functions/index.js` (212 سطراً) و `functions/package.json` (13 سطراً)
- **الدوال المفحوصة:** `resolveCallerUid()`, `purgeAuthUser`, `deleteShopCascade`, `askGemini`.
- **الأخطاء والثغرات:**
  1. **ثغرة `resolveCallerUid` في `functions/index.js` (`Lines 15–29`):**
     تثق الدالة في وثيقة `auth_sessions/{authUid}` عندما يكون المستخدم مجهولاً (`isAnonymous`)، مما يسمح لأي مهاجم باستدعاء `deleteShopCascade` وحذف أي محل في قاعدة البيانات!
  2. **عدم حذف ملفات Firebase Storage في `deleteShopCascade` (`Lines 122–165`):**
     عند حذف المحل، تحذف الدالة وثائق Firestore المرتبطة بالمحل (`products`, `offers`, `reviews`, `services`, `ads`, `daily_stats`)، لكنها **لا تحذف صور وفيديوهات المحل والمنتجات والعروض من Firebase Storage**، مما يترك ملفات يتيمة تستهلك مساحة التخزين المدفوعة للأبد!
  3. **إعدادات `functions/package.json` (`L6`):**
     يحدد `"node": "20"`, ويستخدم `firebase-functions: ^5.0.0`. في `askGemini` (`L171`)، يعتمد على `process.env.GEMINI_API_KEY`، ولكن في `AdminSettingsTab` يحفظ الأدمن المفتاح في Firestore (`settings_private/gemini`) وليس في متغيرات بيئة Cloud Functions! لذلك إذا لم يضبط المطور `GEMINI_API_KEY` في Secret Manager يدوياً، تفشل دالة `askGemini` دائماً بـ `failed-precondition: خدمة المساعد الذكي غير مهيأة حالياً` (`L181`)! (الأفضل أن تقرأ `askGemini` المفتاح من `process.env.GEMINI_API_KEY` مع fallback لقراءته من وثيقة `settings_private/gemini` عبر Admin SDK!).

---

## 🧬 ثالثاً: الفحص التفصيلي لجميع النماذج (`lib/models/*.dart` — 11 ملفاً)

### 1. `lib/models/ad_model.dart` (139 سطراً)
- **العيوب والأخطاء:**
  - يحتوي على حقول مكررة للتاريخ: `startDate` و`endDate` بجانب `createdAt` و`expiresAt`.
  - في `toMap()` (`L106–126`)، يحول `startDate` و`endDate` إلى `Iso8601String` بينما يحول `createdAt` و`expiresAt` إلى `Timestamp`، مما يخلق عدم اتساق في نوع التواريخ داخل وثيقة الإعلان الواحدة.

### 2. `lib/models/category_model.dart` (206 أسطر)
- **العيوب:**
  - يحتوي على قائمة ثابتة `iconList` (`L95–204`) لربط أسماء الأيقونات بـ `IconData`. إذا أضاف الأدمن اسم أيقونة غير موجود في الـ `switch`، يرجع `Icons.category` افتراضياً.

### 3. `lib/models/job_ad_model.dart` (156 سطراً)
- **العيوب والأخطاء:**
  - في `toMap({bool isNew = false})` (`L68–84`): إذا استُدعيت `toMap()` بدون تمرير `isNew: true` (القيمة الافتراضية `false`)، فإنها تكتب `'createdAt': Timestamp.fromDate(createdAt)` بدلاً من `FieldValue.serverTimestamp()`.

### 4. `lib/models/offer.dart` (195 سطراً) — 🟠 يحتوي على نواقص تكسر ميزات العروض
- **الأخطاء والنواقص:**
  1. **غياب حقول `oldPrice` و`newPrice` و`coverImageIndex`:**
     في شاشة `AddOfferScreen` (`add_offer_screen.dart:155–156`)، عندما ينشئ التاجر عرضاً من نوع `"خصم سعر"` (`price_drop`)، يحفظ الكود `oldPrice` و`newPrice` في Firestore. لكن كلاس `Offer` (`lib/models/offer.dart`) **لا يحتوي أصلاً على حقلي `oldPrice` و`newPrice` ولا يقرأهما في `fromMap` ولا ينسخهما في `copyWith`**!
  2. **تجاهل `coverImageIndex` عند تحديد `imageUrl`:**
     في `Offer.fromMap` (`L65–82`)، إذا لم يكن `imageUrl` موجوداً، يأخذ `imgs.first` دون مراعاة `coverImageIndex`.

### 5. `lib/models/product.dart` (192 سطراً) — 🟠 يحتوي على أخطاء تكسر الفرز والغلاف
- **الأخطاء الحرجة:**
  1. **تحويل `createdAt` إلى نص `String` في `toMap()` (`Line 92`):**
     ```dart
     'createdAt': createdAt?.toIso8601String(),
     ```
     بينما `ProductService.addProduct` يكتب `FieldValue.serverTimestamp()` (`Timestamp`). إذا استُخدم `product.toMap()` في أي تحديث، يتحول `createdAt` في Firestore من `Timestamp` إلى `String`، مما يجعل المنتج يختفي أو يقفز خارج الترتيب في جميع استعلامات `orderBy('createdAt')`!
  2. **غياب حقول `coverImageIndex` و`isShopHidden` من كلاس `Product`:**
     يحفظ `ProductService.addProduct` (`product_service.dart:141–150`) الحقول `coverImageIndex` و`imageUrl` و`isShopHidden` في Firestore، لكن كلاس `Product` يتجاهلها تماماً في خصائصه وفي `fromMap()`! لذلك لا تعرف أي شاشة في التطبيق ما هي صورة الغلاف المختارة للمنتج (`coverImageIndex`) وتعرض دائماً `imageUrls.first`!

### 6. `lib/models/review_model.dart` (116 سطراً) — 🔴 خطأ يفقد اسم وصورة صاحب التقييم
- **الأخطاء الحرجة:**
  - **دالة `toMap()` تسقط 4 حقول أساسية (`Lines 68–80`):**
    ```dart
    Map<String, dynamic> toMap() {
      return {
        'targetId': targetId,
        'targetType': targetType,
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'reply': reply,
        'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
        'images': images,
      };
    }
    ```
    رغم أن الكلاس يمتلك الحقول `userName`، `userImage`، `targetName`، و`targetImage` ويقرأها في `fromFirestore()` (`L61–64`)، إلا أن `toMap()` **تنسى كتابتها بالكامل**! وعندما يستدعي `ReviewService.addReview` (`review_service.dart:61`) الدالة `review.toMap()`، تُحفظ التقييمات في Firestore **بدون اسم المستخدم (`userName: null`) وبدون صورته (`userImage: null`) وبدون اسم المنتج (`targetName: null`)**!

### 7. `lib/models/service_bid_model.dart` (73 سطراً) و `lib/models/service_request_model.dart` (155 سطراً)
- **العيوب:**
  - في `ServiceBidModel.toMap()` (`service_bid_model.dart:38`): يكتب `'id': id` داخل الوثيقة، ولذلك اضطر `service_requests_tab_screen.dart:558` لعمل `{...bid.toMap(), 'id': bidRef.id}` حتى لا يفشل شرط `request.resource.data.id == bidId` في `firestore.rules:373`. يفضل ضبط `id` داخل `toMap` أو تمريره في المُنشئ.

### 8. `lib/models/shop.dart` (224 سطراً)
- **الأخطاء والعيوب:**
  - **في `Shop.toMap()` (`Line 142`):** يكتب `'createdAt': createdAt.toIso8601String()` (نص `String` بدلاً من `Timestamp`)، كما لا يكتب حقول `mediaUrls`، `mediaTypes`، `isActive`، `isSuspended`، `favoriteCount`، `phoneClicks`، `whatsappClicks`، و`pendingOwnerPhone` في `toMap()`!

### 9. `lib/models/user.dart` (108 أسطر) و `lib/models/wishlist_collection_model.dart` (110 أسطر)
- **العيوب:**
  - في `AppUser` (`user.dart`): لا يحتوي النموذج على حقول `referralCode`، `referredBy`، `referralCount`، `referralBonusDaysEarned`، ولا `businessType` رغم أن `AuthProvider` و`ReferralService` و`AddServiceProviderScreen` يكتبونها في وثيقة `users/{uid}`!

---

## ⚙️ رابعاً: الفحص التفصيلي لجميع الخدمات (`lib/services/*.dart` — 22 ملفاً)

### 1. `lib/services/notification_service.dart` (801 سطر) — 🔴 يحتوي على خطأ يمنع الترجمة (Compile Error)
- **الأخطاء الحرجة (Bugs):**
  1. **خطأ ترجمة (Compile Error) في الأسطر `78–80`:**
     ```dart
     FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
       final prefs = await SharedPreferences.getInstance();
       final rawUser = prefs.getString('user_data');
       if (rawUser != null) {
         final map = jsonDecode(rawUser) as Map<String, dynamic>;
     ```
     ملف `notification_service.dart` (الأسطر `1–12`) **لا يستورد** `package:shared_preferences/shared_preferences.dart` **ولا يستورد** `dart:convert`! وجود `SharedPreferences` و`jsonDecode` بدون استيراد يوقف بناء المشروع فوراً بخطأ `Undefined name 'SharedPreferences'` و`Undefined function 'jsonDecode'`!
  2. **خطأ منطقي في نفس المستمع (`Line 79`):**
     حتى بعد إضافة الـ imports، فإن `AuthProvider` يحفظ في `SharedPreferences` المفتاح `'user_id'` فقط (`auth_provider.dart:61, 211`) ولا يحفظ أبداً مفتاحاً باسم `'user_data'`! لذلك فإن `prefs.getString('user_data')` ترجع دائماً `null`، ولا يتم تحديث رمز الإشعارات (`fcmToken`) عند تجدده أبداً! يجب قراءة `prefs.getString('user_id')` مباشرة.
  3. **مشكلة معمارية في إشعارات الخلفية (`notification_queue`):**
     تعتمد ميزات التطبيق (الوظائف، طلبات الخدمة، الرد على الشكاوى، الإشعارات الإدارية الموجهة) على إضافة وثائق في مجموعة `notification_queue` في Firestore. ولكن `NotificationService` يعالج الطابور **محلياً داخل التطبيق** (`_listenToNotificationQueue` عند فتح التطبيق فقط)! لا توجد أي Cloud Function (`onDocumentCreated('notification_queue/{docId}')`) ترسل إشعارات FCM الحقيقية عبر `admin.messaging().send()` عندما يكون التطبيق مغلقاً!

### 2. `lib/services/product_service.dart` (749 سطراً)
- **الأخطاء الحرجة (Bugs):**
  1. **محاولة حذف العروض المنتهية من أجهزة العملاء والزوار (`Lines 220–226`):**
     ```dart
     for (final expiredOffer in expiredToDelete) {
       deleteOffer(expiredOffer.id).catchError((e) { ... });
     }
     ```
     داخل `getOffers()` (التي يستدعيها كل زائر ومشتري عند فتح الشاشة الرئيسية أو شاشة العروض!)، يقوم الكود باستدعاء `deleteOffer` لحذف العروض التي مضى على انتهائها 30 يوماً من Firestore! وبما أن المستخدم العادي أو الضيف لا يملك صلاحية حذف عروض المحلات في `firestore.rules:247` (`allow delete: if canManageShopContent(...)`)، فإن Firestore يرفض العملية بـ `permission-denied` في كل مرة يفتح فيها أي مستخدم التطبيق!
  2. **مشكلة `'الكل'` في `getTopProducts` (`Line 80`):**
     ```dart
     if (category != null && category.isNotEmpty) {
       query = query.where('category', isEqualTo: category);
     }
     ```
     لا يستثني `category != 'الكل'` (على عكس `ShopService.getRankedShops` التي تفحص `category != 'الكل'`). لذلك عندما تطلب لوحة الإدارة (`admin_overview_tab.dart:497`) أفضل المنتجات في فئة `'الكل'`، يرجع الاستعلام صفر نتائج!
  3. **تحديث بيانات المحل при حذف عرض (`deleteOffer` في `L330`):**
     يحاول تحديث `hasActiveOffers` في المحل، وإذا فشل يبتلع الخطأ.

### 3. `lib/services/shop_service.dart` (649 سطراً)
- **الأخطاء والعيوب:**
  1. **في `createShop` (`Lines 155–265`):**
     يتم رفع صورة الشعار (`logoFile`) وصورة الغلاف (`coverFile`) إلى Firebase Storage أولاً، ثم بدء Transaction لحرق كود التفعيل وإنشاء المحل. إذا فشل الـ Transaction لأي سبب (مثلاً الكود استُخدم في نفس اللحظة)، تظل الصور المرفوعة في Storage يتيمة دون حذف.
  2. **في `updateShop` (`Lines 290–360`):**
     عندما يغير الأدمن مالك المحل عبر `targetOwnerIdentifier`، إذا أدخل الأدمن رقم هاتف يبدأ بـ `010...` بينما هو مخزن في `users` بصيغة `+2010...`، فإن البحث في `users` (`L312`) قد لا يعثر على المستخدم إذا لم يتم تطبيع الرقم للصيغتين (`010...` و`+2010...`)، فيحفظه كـ `pendingOwnerPhone` رغم أن المستخدم مسجل بالفعل!

### 4. `lib/services/admin_service.dart` (424 سطراً)
- **الأخطاء والعيوب:**
  1. **في `toggleShopSuspension` (`Lines 332–375`):**
     عند تعطيل محل، يخفي الكود منتجات المحل وعروضه (`isShopHidden: true`)، لكنه **لا يعطّل الإعلانات الممولة النشطة التابعة لهذا المحل في مجموعة `ads`**! فيظل إعلان المحل المعطل ظاهراً في الشاشة الرئيسية وعند الضغط عليه يفتح محلاً معطلاً!
  2. **في `toggleShopSuspension` (`Line 358`):**
     يرسل إشعاراً للتاجر بـ `'data': {'route': 'merchant', 'shopId': shopId}`، بينما `NotificationService` و`main.dart` لا يعرفان مساراً باسم `'merchant'` (اسم المسار في `main.dart` هو `'/merchant'`).
  3. **حد الـ 500 عملية في `WriteBatch` (`Lines 340–352`):**
     يضع تحديث المحل + جميع منتجاته + جميع عروضه في `WriteBatch` واحد! في Firestore، الحد الأقصى لـ `WriteBatch` هو 500 عملية؛ فإذا كان لدى التاجر 480 منتجاً و30 عرضاً (المجموع 511)، ينهار `batch.commit()` بالكامل ولا يتعطل المحل! (يجب تقسيم التحديثات عبر دالة تقطيع دفعات `chunked batches` بحجم 400 كما فعل في `ProductService`).

### 5. `lib/services/ad_service.dart` (475 سطراً)
- **الأخطاء والعيوب:**
  1. **في `redeemAdCode` (`Lines 340–395`):**
     يأخذ `userId` الممرر من الواجهة ويكتبه في `'usedBy': userId`. في `MerchantMarketingTab` (`L572`)، يتم تمرير `widget.currentShop.ownerId`. إذا كان المستخدم الحالي شريكاً (`partner`) في المحل وليس المالك، فإن `userId != appUid()`، وترفض `firestore.rules:429` (`request.resource.data.usedBy == appUid()`) حرق الكود بـ `permission-denied`! يجب استخدام معرف المستخدم الحالي الفعلي.
  2. **في `approveVideoAd` (`Lines 435–465`):**
     عندما يرفض الأدمن إعلان الفيديو (مثلاً لاحتوائه على موسيقى أو مخالفته الشروط)، يحدّث الحالة إلى `'rejected'`، لكنه **لا يحذف ملف الفيديو المرفوع من Firebase Storage** ولا يرسل إشعاراً للتاجر بسبب الرفض!

### 6. `lib/services/referral_service.dart` (227 سطراً) — 🔴 معطل بالكامل بسبب تعارض القواعد
- **الأخطاء الحرجة:**
  1. **تعارض اسم الحقل في `applyReferralCode` (`Line 138`):** يكتب `'newUserId': newUserId` بينما `firestore.rules:492` تشترط `request.resource.data.referredId == appUid()`.
  2. **تعارض صلاحيات تحديث المستخدم الداعي (`Lines 128–131`):** يحاول تحديث `users/{referrerId}` من جلسة المستخدم الجديد، وهو ممنوع في `firestore.rules:120`.
  3. **تعارض حقل الترتيب مع `database_seeder.dart` (`Line 188`):** يرتب بـ `orderBy('appliedAt', descending: true)` بينما `database_seeder.dart:1373` يزرع البيانات بحقل `'createdAt'`، فتختفي الإحالات المزروعة من الاستعلام.

### 7. `lib/services/review_service.dart` (162 سطراً)
- **الأخطاء والعيوب:**
  1. **فقدان اسم وصورة المقيّم (`Line 61`):** يعتمد على `review.toMap()` التي تسقط `userName` و`userImage` و`targetName` و`targetImage`.
  2. **عدم إرسال إشعار لصاحب المحل عند إضافة تقييم جديد:** عندما يضيف عميل تقييماً جديداً على محل أو منتج، لا يتم إرسال إشعار للتاجر في `notifications`.

### 8. `lib/services/subscription_service.dart` (231 سطراً) و `lib/services/dealer_listing_service.dart` (120 سطراً)
- **الأخطاء والعيوب:**
  - **في `SubscriptionService.renew` (`Lines 110–185`):**
    1. يتحقق من أن الكود من نوع `shop_renewal` أو `shop_activation`، لكنه **لا يتحقق من فئة الباقة (`tier`) المخزنة في الكود**! بل يأخذ `planDays` و`planPrice` و`planKey` التي اختارها التاجر في واجهة الشاشة (`SubscriptionScreen`)!
    2. **خطورة هذا الخطأ (Business Logic Vulnerability):** يمكن للتاجر أن يشتري من الإدارة كود تجديد شهري رخيص (99 جنيهاً — 30 يوماً)، ثم في شاشة `SubscriptionScreen` يختار باقة **"سنوي (365 يوماً - 799 جنيهاً)"** ويدخل نفس الكود! فيقوم `SubscriptionService.renew` بتجديد اشتراكه لمدة **365 يوماً كاملة** وتسجيل قيمة الكود بـ 799 جنيهاً! يجب أن تُقرأ مدة التجديد (`days`) ونوع الباقة (`planKey`) والسعر (`price`) من وثيقة الكود في Firestore أو من بادئة الكود المعتمدة من الإدارة، وليس من اختيار العميل في الواجهة!

### 9. `lib/services/gemini_service.dart` (249 سطراً)
- **الأخطاء الأمنية والمعمارية:**
  - يحتوي على مسارين: استدعاء مباشر لـ `generativelanguage.googleapis.com` باستخدام مفتاح API محفوظ في ذاكرة العميل (`_apiKey`)، ومسار احتياطي عبر Cloud Function `askGemini`. وجود المسار المباشر في العميل استلزم فتح قراءة `settings_private/gemini` لكل المستخدمين، وهو ثغرة أمنية خطيرة. يجب قصر الاتصال على Cloud Function فقط.

### 10. `lib/services/database_seeder.dart` (1468 سطراً)
- **الأخطاء والتضاربات مع باقي النظام:**
  - **السطر `1272`:** يزرع إشعارات بهيكل `'data': {'route': 'shop_detail', 'targetId': 'shop_fashion'}` بينما `NotificationService` يتوقع `'route': 'shop_details:shop_fashion'`.
  - **السطر `1373`:** يزرع `referrals` بحقل `'createdAt'` و`'referredUserId'` بينما `ReferralService` يستخدم `'appliedAt'` و`'newUserId'`، و`firestore.rules` تتوقع `'referredId'`!

### 11. باقي الخدمات (`analytics_service.dart`, `api_service.dart`, `audit_log_service.dart`, `auth_service.dart`, `cache_service.dart`, `connectivity_service.dart`, `deep_link_service.dart`, `local_favorites_service.dart`, `media_upload_service.dart`, `stats_service.dart`, `wishlist_service.dart`)
- **`audit_log_service.dart` (`L65, L137`):** يكتب ويقرأ حقل `'timestamp'` بينما الفهارس في `firestore.indexes.json` تستخدم `'createdAt'`.
- **`auth_service.dart` (231 سطراً):** خدمة قديمة غير متزامنة مع `AuthProvider`؛ معظم منطق المصادقة الفعلي موجود داخل `AuthProvider` مباشرة (`727` سطراً)، مما يخلق ازدواجية بين `AuthService` و`AuthProvider`.
- **`api_service.dart` (438 سطراً):** يعمل كـ Facade يمرر الطلبات للخدمات الفرعية، لكن بعض الشاشات تستدعي `ApiService` وبعضها يستدعي `ShopService`/`AdService` مباشرة وبعضها يستدعي `FirebaseFirestore.instance` مباشرة.

---

## 🔄 خامساً: الفحص التفصيلي لمزودات الحالة (`lib/providers/*.dart` — 5 ملفات) والأدوات (`lib/utils/`)

### 1. `lib/providers/auth_provider.dart` (727 سطراً)
- **الأخطاء والعيوب:**
  1. **السطر `220–231` (`_loadGeminiKey`):** يسحب مفتاح Gemini السري من `settings_private/gemini` إلى جهاز كل مستخدم عند تسجيل الدخول.
  2. **السطر `515–560` (`claimPendingShopsForUser`):** عند تسجيل تاجر جديد برقم هاتف كان الأدمن قد أنشأ له محلاً مسبقاً (`pendingOwnerPhone`)، يبحث الكود عن المحلات التي تطابق `pendingOwnerPhone`. ولكن إذا كتب الأدمن الرقم بصيغة `010...` بينما سجل التاجر والنظام طبّع الرقم إلى `+2010...`، يجب التأكد من البحث بكلتا الصيغتين (`whereIn: [rawPhone, normalizedPhone]`) حتى لا يفشل الربط التلقائي للمحل!

### 2. `lib/providers/favorites_provider.dart` (483 سطراً)
- **العيوب والأخطاء:**
  - يدير المفضلة عبر مستندات في مجموعة `favorites` ومصفوفة `favoriteShopIds` في `users/{uid}`، وعند إضافة/إزالة مفضلة يحدّث عداد `favoriteCount` في وثيقة المحل/المنتج/العرض. إذا فشل تحديث العداد في الوثيقة الهدف بسبب الصلاحيات أو الشبكة، قد يختلف العداد الظاهر عن العدد الفعلي.

### 3. `lib/providers/shop_detail_provider.dart` (97 سطراً)
- **العيوب:**
  - **مزود حالة ميت بالكامل (Dead Provider):** مسجل أو موجود في `lib/providers/shop_detail_provider.dart`، لكن `ShopDetailScreen` (`lib/screens/shop_detail_screen.dart`) **لا يستخدمه إطلاقاً** بل يدير حالته محلياً داخل `_ShopDetailScreenState`!

### 4. `lib/providers/shops_provider.dart` (533 سطراً)
- **العيوب والأخطاء:**
  - **في `getStartupAd` (`L445–475`):** يجلب إعلانات البداية ولكن إذا تم استدعاؤه من `SplashScreen` قبل اكتمال `fetchAds()`، قد يعيد الجلب مرتين.
  - **عدم وجود استماع أو تحديث تلقائي عند تعليق محل:** إذا قام الأدمن بتعطيل محل، يظل المحل موجوداً في `CacheService` المحلية لمدة صلاحية الكاش (TTL) لدى المستخدمين الذين فتحوا التطبيق مسبقاً.

---

## 💡 سادساً: الاقتراحات والتحسينات والإضافات المقترحة للباك إند (Suggestions, Improvements & Proposed Additions)

### 1. اقتراحات عامة (General Suggestions)
1. **إغلاق ثغرات القواعد فوراً قبل نشر أي نسخة (Security First):**
   - إلغاء `auth_sessions` للمستخدمين المجهولين في `firestore.rules` و`storage.rules` و`functions/index.js`.
   - قفل قراءة `settings_private` على الأدمن فقط (`allow read, write: if isAdmin();`).
   - تقييد تحديث ردود التقييمات (`reviews`) بمالك المحل الفعلي فقط عبر تمرير وحفظ `shopId` داخل وثيقة `Review`.
   - تقييد تحديث عدادات `views` و`favoriteCount` و`clicks` بشرط الزيادة بمقدار `1` فقط (`request.resource.data.views == resource.data.views + 1`).
2. **توحيد الفهارس المركبة (`firestore.indexes.json`):** إضافة الفهارس السبعة المفقودة (`products` مع `isShopHidden` و`views`، `offers` مع `isShopHidden` و`views`، `shops` مع `location` و`views`، `admin_audit_log` مع `timestamp`، `referrals` مع `appliedAt`، و`service_bids` بترتيب تصاعدي).

### 2. تحسينات تقنية ومعمارية مقترحة (Proposed Technical Refactoring)
1. **نقل العمليات الحساسة إلى Cloud Functions (`functions/index.js`):**
   - **دالة `redeemReferralCode`:** تنفيذ التحقق من كود الإحالة وتحديث رصيد الداعي وإنشاء سجل `referrals` عبر Cloud Function بصلاحيات Admin SDK بدلاً من كتابتها من جهاز المستخدم الجديد.
   - **دالة `processNotificationQueue`:** Trigger يعمل عند إنشاء وثيقة في `notification_queue/{docId}` لإرسال إشعارات FCM الحقيقية للأجهزة والمواضيع (`Topics`) حتى لو كان تطبيق المرسل أو المستقبل مغلقاً.
   - **ربط `tier` و`days` بوثيقة كود التفعيل/التجديد:** عند توليد كود تجديد أو تفعيل من لوحة الأدمن، يحدد الأدمن الباقة (شهري/ربع سنوي/سنوي) وتُخزن `days` و`price` داخل وثيقة الكود في `activation_codes`، ويقرأها `SubscriptionService.renew` من الكود نفسه لمنع التلاعب بالمدة.
2. **تفعيل Firebase App Check (Play Integrity لـ Android و App Attest لـ iOS):** لحماية Firestore وStorage وCloud Functions من أي سكربتات خارجية تستخدم مفتاح API العام.
3. **إصلاح `Review.toMap()` و`Product` و`Offer`:**
   - تضمين `userName`، `userImage`، `targetName`، `targetImage`، و`shopId` في `Review.toMap()`.
   - إضافة `coverImageIndex` إلى `Product` و`oldPrice`/`newPrice` إلى `Offer`، واستبدال `.toIso8601String()` بـ `Timestamp.fromDate(...)` في جميع دوال `toMap()`.

### 3. إضافات مقترحة للباك إند (Proposed Backend Additions — متوافقة مع نموذج عمل سنهور أونلاين)
1. **مهمة مجدولة يومية (`Scheduled Cloud Function - Cron Job`) لإدارة الاشتراكات والعروض المنتهية:**
   - تعمل كل ليلة تلقائياً على السيرفر:
     1. ترسل إشعار تذكير للتجار الذين تنتهي اشتراكاتهم خلال 3 أيام.
     2. تحوّل حالة المحلات التي انتهى اشتراكها إلى `subscriptionStatus: 'expired'` وتخفي منتجاتها وعروضها تلقائياً حتى يجدد التاجر بكود جديد.
     3. تحذف العروض المنتهية منذ أكثر من 30 يوماً وتنظف صورها من Firebase Storage (بدلاً من محاولة حذفها من هواتف العملاء!).
     4. تنفذ الحذف النهائي للحسابات التي مضى على طلب حذفها (`scheduledForDeletionAt`) أكثر من 15 يوماً.
2. **تنظيف تلقائي للملفات اليتيمة في Firebase Storage عند الحذف:**
   - تحديث `deleteShopCascade` وإضافة Trigger عند حذف منتج أو عرض أو إعلان لحذف صوره وفيديوهاته من Storage تلقائياً لتوفير تكلفة التخزين.
3. **نظام النسخ الاحتياطي التلقائي لبيانات سنهور أونلاين (Automated Firestore Export):**
   - دالة مجدولة أسبوعية تصدّر نسخة احتياطية من مجموعات (`shops`, `products`, `categories`, `users`, `activation_codes`) إلى Cloud Storage Bucket آمن لحماية بيانات التجار من أي خطأ بشري.
