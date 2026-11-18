# سجل التعديلات المطلوبة على كود Flutter — مرتّب بترتيب العمل

القاعدة: بند واحد بس في كل مرة. مبنبدأش في بند غير لما اللي قبله يخلص ويتأكد بدقة 100%. علّم `[x]` جنب أي بند خلصناه فعليًا (بعد التنفيذ والتأكيد، مش قبل كده).

**منطق الترتيب:**

1. أول حاجة: أي حاجة بتمنع المشروع من الـ compile خالص — من غير كده مفيش حاجة تانية ممكن تتجرّب فعليًا.

2. بعدها: المشاكل المعمارية الجذرية — إصلاحها بيوضّح/يحل جزء كبير من البنود اللي جايه بعدها، وتأخيرها معناه هنصلّح نفس العرض أكتر من مرة.

3. بعدها: قواعد الأمان (Firestore + Storage rules).

4. بعدها: باقي أخطاء المنطق والبيانات.

5. آخر حاجة: جودة الكود والنواقص المنتجية — مفيش منها حاجة عاجلة.

مصدر البنود: فحصنا إحنا في الجلسة دي + تقرير فحص Grok لملف `lib.zip` (راجعت شخصيًا كل بند حرج + عيّنة كبيرة من العالي مباشرة في الكود قبل ما أضيفهم، كلهم اتأكدوا صح تقريبًا كلهم).

## المرحلة 1 — فتح الطريق للـ Compile

**الحالة: مكتملة ✅** — commits `20b87c6` → `6fcb5ff` على `main` (بدون branches).

* الأساس: `lib/` اتستبدل بنسخة `lib-2.zip` (`20b87c6`) وكمان `firestore.rules` و`storage.rules` و`firestore.indexes.json` (`d196801`). النسخة القديمة محفوظة في `16b1ddc`.

* التحقق **ثابت فقط**: parser لـ Dart + فحص imports + فحص تعريفات مكررة + مطابقة الـ APIs مع كود Flutter 3.44 الرسمي — النتيجة: 129/129 ملف سليم syntax، صفر imports ناقصة. **لم يُشغَّل `flutter analyze`** (مفيش Flutter SDK في بيئة Claude).

* المطلوب منك: `git pull` ← `flutter pub get` ← `flutter analyze`، وابعت أي أخطاء تظهر.

* $$
  x
  $$

   **1. `main.dart` — تصحيح ثيم الوضع الليلي**
  بعد ما `inputDecorationTheme` بيقفل، فيه `foregroundColor: Colors.white,`، `shape: RoundedRectangleBorder(...)`، `elevation: 0,` معلّقين من غير أي constructor يحتويهم، وقوس زيادة `))` بعدهم. **الملف كله معندوش يتبني في وضعه الحالي.** أعلى أولوية مطلقة.
  ✅ `04645a5` — حذف الأسطر اليتيمة من الثيم الليلي. + إصلاح إضافي في نفس الـ block: `ThemeData.copyWith` مفيهوش `fontFamily` (اتأكد من كود Flutter 3.44) فاتطبّق الخط على `textTheme`/`primaryTextTheme`.

* $$
  x
  $$

   **2. `main.dart` — إصلاح تعارض التنقل الأولي**
  `home: Consumer<AuthProvider>` بيقفز لـ `MainScreen()` بمجرد ما `auth.status` يتحول، ويقاطع فحوصات `SplashScreen` الـ async (أونبوردنج/Force Update/إعلان البداية) لو لسه شغالة. تفسير محتمل قوي ليه الميزات دي مش شغالة بانتظام.
  ✅ `cda309b` — `home: const SplashScreen()`؛ الـ Splash بتستنى المصادقة وبتستبدل نفسها بـ `Navigator.replace` (عشان الـ dialog/deep link/إعلان البداية ميتشالوش)، ومهلة 5 ثواني للـ force update.

* $$
  x
  $$

   **3. `services/database_seeder.dart` — تصحيح أسماء استدعاء المراحل**
  بينادي `_phase8_reviews()` و`_phase9_ads()` غير المعرّفين؛ المعرّف فعليًا `_phase8_ads()` و`_phase9_communityContent()`. Undefined method، الملف مش هيتبني.
  ✅ `be793a0` — الاستدعاءات بقت `_phase8_ads` و`_phase9_communityContent`؛ التقييمات بتتزرع داخل `_phase7_services`.

* $$
  x
  $$

   **4. `services/database_seeder.dart` — إضافة `cleanDatabase()`**
  مُستدعاة من `admin_settings_tab.dart:208` كـ `DatabaseSeeder.cleanDatabase()` لكن غير موجودة كـ method خالص.
  ✅ `5c5ce86` — `cleanDatabase()` مضافة: تمسح محتوى التطبيق فقط (القائمة في `_cleanableCollections`)، محمية بـ `BuildFlags.mockModeEnabled`، ونص رسالة التأكيد في تاب الأدمن اتحدّث. (راجع القائمة — ملاحظة 6 تحت)

* $$
  x
  $$

   **5. `models/review_model.dart` — تصحيح نوع `rating`**
  معرّف `final int rating;` بس بيتقري بـ `(data['rating'] as num?)?.toDouble()` — توحيد النوع بين التعريف والقراءة.
  ✅ `37a97de` — القراءة بقت `.toInt()` (int هو الصح: باقي الكود بيعتمد عليه).

* $$
  x
  $$

   **6. `services/analytics_service.dart` — حذف التعريف المكرر**
  `logAdvancedSearch` معرّفة مرتين بتوقيعين مختلفين. الإبقاء على نسخة Fix #139 الآمنة بس (اللي بتقطع الـ query لحماية الخصوصية).
  ✅ `bd1c416` — اتحذفت النسخة غير الآمنة وفضلت نسخة Fix #139.

* $$
  x
  $$

   **7. `services/notification_service.dart` — إضافة import ناقص**
  بيستخدم `developer.log(...)` من غير `import 'dart:developer'` في أعلى الملف.
  ✅ `f2b0f19` — `import 'dart:developer' as developer;`.

* $$
  x
  $$

   **8. `services/wishlist_service.dart` — تصحيح اسم الحقل**
  بيستخدم `item.itemType` لكن `WishlistItem` اسم الحقل عندها `type` بس — حذف عنصر من القائمة هيفشل.
  ✅ `ed8a5d4` — المفتاح المخزّن في Firestore هو `type` مش `itemType`، فاتصلح الحقل والمفتاح معًا (تصليح الحقل لوحده كان هيخلي الحذف ميطابقش أبدًا).

* $$
  x
  $$

   **9. `utils/image_helper.dart` — تصحيح نوع الإرجاع في `showSourcePicker`**
  معلنة `Future<ImageSource?>` وبتستخدم `showModalBottomSheet<ImageSource>`، لكن الأزرار بترجّع `MediaPickChoice` (كلاس مختلف). أول محاولة رفع صورة هتدّي TypeError.
  ✅ `ce222a5` — زراير `showSourcePicker` بترجّع `ImageSource.camera/gallery`.

* $$
  x
  $$

   **10. الأونبوردنج ↔ الـ Splash — توحيد مفتاح التخزين**
  الـ Splash بيقرا `onboarding_done`، والأونبوردنج بيكتب `seen_onboarding` — مفتاحين مختلفين، فالأونبوردنج بيتكرر كل فتحة للأبد.
  ✅ `7ec43bd` — المفتاح الموحّد `onboarding_done`.

* $$
  x
  $$

   **11. `post_job_ad_screen.dart` و`post_service_request_screen.dart` — حراسة الضيف**
  `context.read<AuthProvider>().user!` من غير حراسة، والـ FAB ظاهر للضيف أصلاً — كراش فوري لو ضيف حاول ينشر.
  ✅ `5c4e6f4` — حراسة `user == null` في الشاشتين (قبل الـ validation وقبل `_isSaving`) + الـ FAB بيوقّف غير المسجّل. الحراسة على `user == null` مش `isGuest` (حالة `unauthenticated` مش guest).

* $$
  x
  $$

   **12. `screens/subscription_screen.dart` — قراءة كود التجديد بعد الـ dispose**
  الكود بيتقري من `codeController.text` بعد ما الـ dialog يقفل ويعمل dispose للـ controller. فيه تعليق في الكود بيوصف الحل المطلوب بمتغيّر محلي، بس التنفيذ الفعلي ناقص.
  ✅ `ebfe2a4` — `_RenewCodeDialog` (StatefulWidget) بيملك الـ controller وبيرجّع الكود المُدخل؛ مفيش قراءة بعد dispose.

* $$
  x
  $$

   **12ب. `screens/merchant/merchant_reviews_screen.dart` — بقايا جسم قديم كسرت الكلاس (مش في القائمة الأصلية)**
  الشاشة اتحوّلت لـ Pagination بس فضل جسم `_fetchReviews()` القديم (\~80 سطر) على مستوى الكلاس، و`_submitReply` بيستخدم `_reviewsFuture` وهو مش معرّف أصلًا. الملف كله ماكانش بيتعمله parse.
  ✅ `6ee572a` — اتحذف الجسم اليتيم، و`_submitReply` بيعيد تحميل أول صفحة بـ `_loadReviews(refresh: true)`.

* $$
  x
  $$

   **12ج. `screens/merchant/merchant_marketing_tab.dart` — import ناقص (مش في القائمة الأصلية)**
  بيستخدم `MediaUploadException` من غير import لـ `media_upload_service.dart`.
  ✅ `6fcb5ff` — اتضاف الـ import.

## المرحلة 2 — المشاكل المعمارية الجذرية

* $$
  x
  $$

   **13. الهوية مقابل قواعد Firestore**
  الدخول التجريبي (mock) بيحفظ `user_id` في `SharedPreferences` وبينفّذ `signInAnonymously()` عشان `request.auth != null` تنجح. قواعد Firestore بتقارن `request.auth.uid` بـ `users/{auth.uid}.userType` — والـ UID المجهول ≠ `mock_admin`/`mock_merchant`. الواجهة بتظهر صلاحيات أدمن/تاجر، لكن أي كتابة مقيَّدة بالملكية بتفشل فعليًا. قرار وتنفيذ: إما مواءمة الـ mock auth مع الـ UID، أو تعديل القواعد لتتعرّف صح على مستخدمي mock.
  ✅ `51b3042` — المشكلة اتأكدت على مستويين: القواعد (`request.auth.uid`)، **والـ services نفسها** (`ProductService` و`ShopService.createShop` كانوا بيقارنوا `ownerId` بـ `firebaseUser.uid` فبيرفضوا أي تاجر mock قبل ما توصل للقواعد). **القرار:** الإبقاء على الـ dummy auth وتعليم القواعد تتعرّف على مستخدمي mock، مش مواءمة الـ mock مع الـ UID (لأن الـ UID المجهول بيتغيّر مع كل خروج، ومينفعش عميل ينشئ مستند `userType: admin`).

  * `firestore.rules`: `isAnonymousSession()` + `appUid()` — الجلسة المجهولة بتحل هويتها من وثيقة الربط `auth_sessions/{uid}` (بتكتبها/تقراها/تحذفها الجلسة نفسها بس)، والجلسة الحقيقية `appUid() == request.auth.uid`. كل `isOwner`/`getUserData`/`isShopOwner` وشروط `ownerId`/`userId`/`posterId`/... اتحوّلت لـ `appUid()`. ده بيصلّح كمان المفضلة (`users/{id}/favorites`) والتقييمات والمحلات مع الـ mock.

  * `AuthProvider`: الجلسة المجهولة بتتعمل **قبل** البحث بالهاتف (قاعدة قراءة `users` محتاجة `isAuth()` — كان الدخول الجديد بيفشل بدونها)، وبتتربط بمعرّف المستخدم عند الدخول وعند استعادة الجلسة، وبيتفكّ الربط قبل `signOut()`.

  * `ProductService` (`addProduct`/`addOffer`/`importProductsExcel`) و`ShopService.createShop`: مقارنة `firebaseUser.uid` بـ `ownerId` للجلسات الحقيقية بس؛ المجهولة بتعتمد على القواعد.

  * ⚠️ وثيقة الربط بيكتبها العميل نفسه (الـ mock مفيهوش تحقق خادمي أصلًا) — مقبول في مرحلة الاختبار بس. التفاصيل وخطوات الإغلاق قبل الإطلاق في ملاحظة 8.

* $$
  x
  $$

   **14. توحيد صناديق الإشعارات الثلاثة**
  `notifications` (تكتبها الشاشات، لكن الإنشاء مقيّد بـ moderator في القواعد فكتابات المشتري/التاجر ترفض) · `notification_queue` (لـ FCM) · `user_notifications` (الـ Seeder بس، محدش بيقراها). القواعد بتتحقق من `userId`، الواجهة بتفلتر بـ `targetUserId`. توحيد في نظام واحد واضح.
  ✅ `72c4ba4` — **النظام الموحّد:** `notifications` = الصندوق الداخلي الوحيد، موجَّه بـ `targetUserId` (الحقل اللي كل الكاتبين والقارئ كانوا بيستخدموه أصلًا — القواعد هي اللي كانت غلط)؛ `notification_queue` = طابور FCM بس (التطبيق مبيقراهوش)؛ `user_notifications` اتلغى.

  * `firestore.rules`: قراءة/حذف للمستلم، وتعديل `isRead`/`inviteStatus` بس للمستلم، وإنشاء لأي مستخدم مسجّل بشكل صارم (حقول محددة، `fromUserId == appUid()`، `isRead == false`، `createdAt == request.time`، حدود أحجام)، والمشرف ليه كل الصلاحيات.

  * `notifications_screen`: استعلام `where targetUserId == me` + `orderBy createdAt` + `limit 60` من الخادم، بدل قراءة آخر 60 إشعارًا لكل المستخدمين وفلترة محلية (القواعد كانت هترفض الاستعلام ده أصلًا، وكان بيهدر قراءات).

  * الكتّاب الخمسة (عرض جديد، قبول عرض، رد شكوى، دعوة قائمة، قبول دعوة) بقوا يبعتوا `fromUserId`.

  * الـ Seeder بيكتب `notifications` بـ `targetUserId` ومعرّفات ثابتة (مبتتكررش مع إعادة الزرع). الـ indexes اتنقلت من `userId` لـ `targetUserId`.

  * ⚠️ البث العام (`all`/`merchants`/`customers`) بقى Push بس عبر `notification_queue` ومبيظهرش في الصندوق الداخلي (ومكانش بيظهر قبل كده لأن مفيش كاتب ليه). لو في Cloud Function بتكتبه في `notifications` بـ `targetTopic` هتحتاج مسار قراءة تاني.

* $$
  x
  $$

   **15. توحيد بنية عروض الخدمات (service bids)**
  الشاشات بتكتب/تقرا `service_bids` top-level · الـ Seeder تحت `service_requests/{id}/service_bids` · القواعد لـ `service_requests/{id}/bids` بحقل `bidderId`، والموديل بيستخدم `providerId`/`clientId`. توحيد شكل واحد في الأربعة (شاشات/Seeder/قواعد/موديل).
  ✅ `d007ffb` — **الشكل الموحّد:** `service_bids` top-level، العرض بـ `requestId` + `providerId` (زي `ServiceBidModel` والشاشات)، وصاحب الطلب `clientId` في كل مكان. اتأكد كمان إن قواعد `service_requests` نفسها كانت بتفحص `posterId` والموديل/الشاشة/الـ Seeder بيكتبوا `clientId` — يعني إنشاء/تعديل أي طلب خدمة كان بيترفض، وصلّحته ضمن نفس البند لأن صلاحيات العروض مبنية على صاحب الطلب.

  * `firestore.rules`: بلوك `service_bids` + دالة `serviceRequestData()`. قراءة العرض لمقدّمه/صاحب الطلب/المشرف (العرض فيه هاتف المزوّد)؛ إنشاء للمزوّد بس (`id == doc id`، `pending`، سعر > 0، `createdAt == request.time`، طلب مفتوح مش بتاعه، حقول محددة)؛ تعديل `status` بس (`accepted`/`rejected`) لصاحب الطلب؛ حذف للمزوّد أو المشرف. بلوك `bids` الفرعي اتشال. `service_requests`: التحقق بـ `clientId` + زيادة `bidsCount` بمقدار 1 بس لأي مسجّل (شاشة تقديم العرض بتعملها).

  * `service_requests_tab_screen`: العرض بيتكتب بـ `set` واحدة بمعرّف مولَّد مسبقًا (كان `add` بـ id فاضي ثم `update` للـ id — كتابتين والقواعد مكانتش هتسمح بالتانية).

  * الـ Seeder: `service_bids` top-level بمعرّف ثابت وحقل `id`، و`bidsCount` للطلب المزروع بقى 1 (يطابق العرض المزروع الوحيد)، و`cleanDatabase` بتمسحه (وفضل تنظيف الـ subcollection القديمة لبيانات اتزرعت قبل كده).

  * `firestore.indexes.json`: `service_requests(clientId, createdAt)` بدل `posterId`، و`service_bids(requestId, createdAt)` و`service_bids(providerId, createdAt desc)`.

* $$
  x
  $$

   **16. تفعيل كود الإعلان الحقيقي**
  `AdService.generateAdCode()` بيرجّع نص من غير ما يكتب أي وثيقة فعلية، والقراءة/الحرق من `ad_codes` (كولكشن مش موجود في القواعد). ربط بنظام `activation_codes` الموحّد (`type: 'ad_activation'`).
  ✅ `7c324a7`

  * `AdService.generateAdCode()`: بيكتب وثيقة حقيقية في `activation_codes` (`type: 'ad_activation'`، كود `AD-XXXX-XXXX` بـ `Random.secure`، `isUsed: false`، صلاحية 30 يوم) ويسجّل التوليد في audit log زي كود المحل.

  * `AdService.redeemAdCode()`: استعلام بـ `code` + `type` + `isUsed` (equality بس، من غير index جديد) ثم transaction بتعيد قراءة الوثيقة بـ `tx.get` وتحرقها (`isUsed`/`usedBy`/`usedAt`/`shopId`) — طلبين متزامنين مايقدروش يحرقوا نفس الكود. بيرمي `AdCodeException` برسالة عربية (غير صحيح/مستخدم/منتهي) وتاب التسويق بيعرضها بدل الرسالة العامة.

  * `merchant_marketing_tab`: `_validateAndBurnCode` بيستخدمها. `admin_codes_tab`: استعلام واحد على `activation_codes` والفصل بالـ `type` (الأكواد القديمة بلا `type` بتفضل في تاب المحلات)، والحذف على `activation_codes` للنوعين.

  * `firestore.rules`: تعديل `activation_codes` اتسمح للمستخدم يحرق كودًا غير مستخدم لنفسه بس (`isUsed false→true`، `usedBy == appUid()`، حقول الحرق بس)؛ الإنشاء والحذف وأي تعديل تاني للمشرف. (ده كمان بيفتح حرق أكواد المحلات/التجديد من حساب التاجر — كانت مرفوضة لغير المشرف.)

  * الـ Seeder: أكواد المحلات المزروعة بقت بـ `type: 'shop_activation'` + كودين اختبار `AD-TEST-0001`/`AD-TEST-0002`.

  * فجوات لسه مفتوحة في ملاحظة 11 (استعلامات المحلات من غير `type`، قراءة الأكواد، ترتيب الحرق).

* $$
  x
  $$

   **17. إغلاق Storage للجلسات المجهولة**
  أي `isAuth()` (بما فيها الجلسة المجهولة نفسها) يقدر يكتب/يمسح صور محلات ومنتجات ناس تانية. `settings` مقروء للعالم بالكامل بما فيه `geminiApiKey`.
  ✅ `7e5d0a1` — **القرار:** مينفعش نقفل Storage على الجلسات المجهولة كليًا دلوقتي (الـ mock نفسه جلسة مجهولة، وكده التاجر التجريبي مش هيعرف يرفع أي صورة)، فكل رفع/حذف بقى محتاج **هوية تطبيق + دور** بنفس منطق `appUid()` (عبر `firestore.get`)، ومعاه مفتاح واحد يقفل الجلسات المجهولة كلها وقت الإطلاق.

  * `storage.rules`: وسائط المحل/المنتجات/العروض/صور وفيديو الإعلانات → تاجر أو مشرف؛ أفاتار `users/{userId}` ومرفقات الشكاوى `complaint_attachments/{userId}` → صاحب الحساب؛ صور التقييمات والديلر → أي هوية معروفة. الجلسة المجهولة "العارية" (من غير وثيقة ربط) مبترفعش ولا بتمسح حاجة. `allowMockSessions()` لو رجّعتها `false` وقت الإطلاق Storage تتقفل بالكامل قدام أي جلسة مجهولة. القراءة العامة وحدود الحجم/النوع وقاعدة الرفض الافتراضية زي ما هي.

  * `firestore.rules`: `settings_private/{docId}` جديد (قراءة لجلسة بهوية معروفة عبر `hasSessionIdentity()`، كتابة للمشرف)، و`settings` فضلت مقروءة للعالم.

  * مفتاح Gemini اتنقل من `settings/general` لـ `settings_private/gemini` (حقل `apiKey`): `AuthProvider` بيحمّله بعد الدخول، `AdminService.getGeminiApiKey/saveGeminiApiKey` (+ مغلّفات `ApiService`)، وتاب إعدادات الأدمن بيحمّل ويحفظ منه (لو لسه فيه نسخة قديمة في `settings/general` بتتعرض عشان حفظة واحدة تنقلها وتمسح الحقل العام). المفتاح بطّل يتكتب في `settings/general` ويتنسخ في audit log (كان بيتنسخ حرفيًا جوه `changes` مع باقي الإعدادات)، والـ Seeder مبيكتبهوش.

  * مش جوه البند ده: حذف الملفات المسطّحة لصاحبها بس + `|| true` في قراءة مرفقات الشكاوى (بند 45 — الأولى محتاجة حفظ `ownerId` كـ custom metadata وقت الرفع). تنبيهات النشر والمفتاح في ملاحظتي 15 و16.

## المرحلة 3 — باقي قواعد الأمان (Firestore + Storage)

* $$
  x
  $$

   **18. `firestore.rules` — أولوية `&&`/`||` في إنشاء `users`**
  أي حد يقدر ينشئ مستند بـ `userType: merchant` من غير التحقق من الملكية زي ما كان مقصود.
  ✅ `f95a44c` — السبب الجذري: `&&` أقوى من `||`، فالشرط كان بيتقرأ `(isOwner && بلا userType) || (userType in [customer, merchant])` والفرع التاني من غير أي فحص هوية — **ولا حتى `isAuth()`**: أي طلب، حتى من غير جلسة Firebase أصلًا، كان يقدر ينشئ `users/{أي معرّف}` بـ `userType: merchant` أو `customer` (يحجز معرّف مستخدم تاني أو يزرع دور مسبقًا). الإصلاح: `isOwner(userId) && (!keys().hasAny(['userType']) || userType in ['customer','merchant'])`. `admin`/`moderator` لسه مستحيل إنشاؤهم من العميل.

  * اتراجعت كل مسارات إنشاء `users/{id}` في العميل (دخول الـ mock بعد `_bindMockSession`، `completeRegistration`، `AuthService.registerUser`): كلها بتحقق `isOwner` + `customer/merchant`، فمفيش تأثير على الدخول/التسجيل.

  * التحقق: جدول حقيقة للصيغة القديمة مقابل الجديدة (بدون جلسة / مستخدم غير مالك / مالك بلا `userType` / مالك customer-merchant / مالك admin-moderator) + فحص توازن الأقواس وإنهاء كل `allow ...;`.

  * ⚠️ أثر جانبي: الـ Seeder كان بيكتب `users` لمعرّفات تانية عن طريق الفرع المعيوب، فمرحلة `_phase3Users` فيه مبقتش تعدّي (امتداد لملاحظة 10 — راجع ملاحظة 19). و`users/mock_admin` لسه لازم يتعمل من الـ console (ملاحظة 9).

* $$
  x
  $$

   **19. `firestore.rules` — تقييد تعديل/حذف إعلان الديلر لصاحبه بس**
  حاليًا: `allow update, delete: if isAuth() || isModerator();` — أي مستخدم موثّق، مش بس صاحبه.
  ✅ `8234c46` — السبب: القاعدة اتكتبت قبل `appUid()` (#13) فمكنش ممكن مطابقة `sellerId` بهوية الجلسة، فاكتفت بـ `isAuth()` — أي جلسة (حتى مجهولة عارية) تعدّل أو تحذف إعلان أي بائع. الآن: `update` = (`isAuth()` + `resource.data.sellerId == appUid()` + `sellerId` ما يتغيّرش) أو `isModerator()`؛ `delete` = (`isAuth()` + `sellerId == appUid()`) أو `isModerator()`. الأقواس صريحة في كل خلطة `&&`/`||` (درس #18).

  * **إضافة جوه نفس البلوك والسبب:** `create` بقى بيشترط `request.resource.data.sellerId == appUid()` (كان `is string && size() > 0`) — من غيره أي حد ينشر باسم بائع تاني ويبقى «المالك» الوهمي هو اللي يملك التعديل والحذف، فالقيد الجديد كان هيفضل ناقص. فحصت التطبيق: بيكتب `sellerId: auth.user!.id` (= `appUid()` للجلسة الحقيقية والـ mock المربوطة)، والتعديل الوحيد من العميل هو `{'isActive': val}` من تبويب «إعلاني» لصاحب الإعلان، ومفيش حذف من العميل، وتاب إدارة المحتوى مبيلمسش `dealer_listings` (فرع المشرف اتحفظ).

  * ⚠️ الـ Seeder (إعلانات ديلر بمعرّفات بائعين تانيين) مبقاش يعدّي — ملاحظة 19.

* $$
  x
  $$

   **20. `firestore.rules` — إضافة قواعد للـ collections الناقصة تمامًا**
  `daily_stats`, `subscription_history`, `share_analytics`, `service_bids` (top-level), `ad_codes`, `user_notifications` — كل الكتابة عليهم هترجع permission-denied حاليًا.
  ✅ `ddf6f73` — السبب: أي collection أو subcollection من غير `match` بتقع تحت default-deny. اتعمل جرد لكل `collection('...')` في كود التطبيق (29 collection) مقابل بلوكات `match`: ظهر إن `service_bids` اتعمل في #15 و`ad_codes`/`user_notifications` اتلغوا (#16/#14) ومفيش كود بيستخدمهم، وفاضل **6**: التلاتة المكتوبين (`daily_stats`, `subscription_history`, `share_analytics`) + **تلاتة تانيين نفس العطل ومش في القائمة** (`job_subscriptions`, `provider_topic_subscriptions`, `collection_invites`) — اتغطّوا هنا لأنهم نفس العيب بالظبط وعنوان البند «الـ collections الناقصة تمامًا». بعد التعديل: 29/29 لهم `match`، صفر ناقص.

  * `shops/{id}/daily_stats/{يوم}` (كانت subcollection مش top-level): أي جلسة تزوّد **عدّاد واحد بمقدار 1 بالظبط** (`statCreated`/`statBumped` فوق `views`, `phoneClicks`, `whatsappClicks`, `facebook/instagram/tiktok/telegramClicks`، و`date` Timestamp بيتضاف مرة واحدة بس)؛ القراءة لصاحب المحل والمشرف؛ الحذف للمشرف (تنظيف الـ Seeder). القيمة بتتقارن بعد تطبيق الـ increment (`request.resource.data` = القيمة النهائية).

  * `shops/{id}/subscription_history/{id}`: الإنشاء لصاحب المحل بنفس حقول `renew()` بالظبط، `renewedBy == appUid()`، `createdAt == request.time`؛ القراءة للمالك/المشرف؛ لا تعديل ولا حذف (append-only). بيتكتب بعد نجاح الـ transaction (خارجه).

  * `share_analytics`: إنشاء فقط بحقول `{type,targetId,clickedAt,platform}` بحدود طول؛ باقي العمليات للمشرف. (⚠️ `recordShareClick` مفيش حد بيناديها حاليًا.)

  * `job_subscriptions/{uid}` و`provider_topic_subscriptions/{uid}`: صاحبها بس بحقولها المعروفة، `updatedAt == request.time`.

  * `collection_invites`: الداعي ينشئ (`inviterId == appUid()`, `status == 'pending'`)، والمدعو يغيّر `status` بس إلى accepted/rejected، الطرفين يقروا ويحذفوا، المشرف كمان.

  * التحقق (ثابت): الجرد المذكور؛ حقول كل قاعدة اتقارنت بالكود الكاتب (`renew()`, `StatsService`, `recordShareClick`, `job_ads_tab_screen`, شاشتي تسجيل مزوّد الخدمة, `collection_detail_screen`/`notifications_screen`)؛ نمذجة منطقية لـ `statCreated`/`statBumped` على كتابات `StatsService` الحقيقية و10 حالات إساءة (قفزة، إنقاص، عدّادين مع بعض، حقل غريب، تعديل `date`...) — 18/18 زي المتوقع؛ فحص الأقواس وإنهاء `allow`.

  * ⚠️ **اللي مش مغطّى** (ملاحظتي 13 و14): عدّادات المحل/المنتج/العرض نفسها لسه بتترفض لغير المالك، وقبول الدعوة محتاج تعديل على `wishlists`.

* $$
  x
  $$

   **21. جعل حرق الأكواد ذرّي (atomic)**
  transaction تجديد الاشتراك والتقييمات بتعمل query جواها من غير `tx.get` — مش ذرّي، اتنين يقدروا يحرقوا نفس الكود في نفس اللحظة.
  ✅ `febd166` — السبب: `createShop` و`renew` كانوا بيعملوا الاستعلام عن الكود **جوه** `runTransaction` وبعدين `tx.update(...)` من غير أي `tx.get`: الاستعلام مش جزء من قراءات الـ transaction والكتابة "العمياء" مالهاش precondition، فطلبين متزامنين يلاقوه الاتنين «غير مستخدم» ويحرقوه (محلين/تجديدين بكود واحد). `ReviewService.addReview` نفس الشكل (query أولًا، `transaction.get(target)` بعدين).

  * `createShop` / `renew`: نفس نمط `AdService.redeemAdCode`: الاستعلام **بره** الـ transaction (equality على `code` + `type` + `isUsed`، من غير index جديد) لتحديد الوثيقة، وجوّاها `tx.get` + إعادة فحص `isUsed`/`type` + الحرق — أي حرق متزامن بيخلّي الـ commit يفشل ويتعاد تلقائيًا فيلاقي الكود اتحرق.

  * **`type` في كل استعلام تحقق** (ملاحظة 11 + القاعدة الثابتة): إنشاء المحل بيقبل `shop_activation` بس؛ التجديد بيقبل `shop_renewal` و`shop_activation` (مفيش مولّد `shop_renewal` في تاب الأدمن دلوقتي — لو شلنا `shop_activation` التجديد كان هيقف). كود `ad_activation`/`dealer_listing_fee` مبقاش ينفع يفعّل أو يجدد محل. الفحصين المسبقين (`validateActivationCode`/`isCodeValid`) بنفس الـ lookup. **قرار منتج متاح لك:** لو عايز نوع تجديد منفصل لازم مولّد `shop_renewal` في تاب الأدمن وبعدها نضيّق `_renewalCodeTypes` (ملاحظة 17).

  * `addReview`: `transaction.get(target)` بقت **الأولى** (كل تقييم جديد لنفس الهدف بيكتب `rating`/`reviewCount` في وثيقته فالتقييمين المتزامنين بيتعارضوا عليها والخاسر بيتعاد ويلاقي تقييم الأول)، بعدها فحص التكرار، بعدها الكتابات (كل القراءات قبل الكتابات). معرّفات التقييمات فضلت عشوائية. (حالة هامشية: لو وثيقة الهدف مش موجودة مفيش تسلسل — ملاحظة 18.)

  * التحقق (ثابت): `parse_check` على 129 ملف (واتجرّب على نسخة مكسورة عمدًا)، `import_check`/`dups`/`sdkimports` نضاف؛ توقيع `Transaction.get<T>(DocumentReference<T>)` اتأكد من كود FlutterFire؛ `codeRef` بقى `final` عشان الـ promotion يمشي جوه الـ closures؛ **محاكاة عشوائية لنموذج optimistic concurrency (20,000 تداخل لكل سيناريو):** الشكل القديم = 49.6% حرق مزدوج و38.0% تقييم مكرر، الشكل الجديد = صفر و صفر. وبعدين `flutter analyze` الفعلي على CI نضيف (راجع «تنظيف flutter analyze» تحت).

  * الأكواد القديمة بلا `type` مبقتش بتتقبّل في مسارات المحل (المولّد بيكتب `type` من أول commit؛ بس بيانات Seeder قبل #16 كانت من غيره).

## المرحلة 4 — باقي أخطاء المنطق والبيانات

* $$
  x
  $$

   **22. `merchant_dashboard.dart` — تصحيح ربط الـ FAB بالتاب الصح**
  التابات: 0 تسويق / 1 منتجات / 2 خدمات / 3 عروض. الكود بيحسب تاب 2 كـ"إضافة عرض" (بيفتح `AddOfferScreen`)، وتاب العروض (3) مفهوش FAB خالص.
  ✅ `b8850ab` — السبب: `_buildFAB` كان لسه بيحسب ترتيب التابات القديم (0 تسويق / 1 منتجات / 2 عروض) بعد ما اتضاف تاب الخدمات؛ فتاب الخدمات كان بيعرض FAB «إضافة عرض» (فوق زرار الإضافة الخاص بتاب الخدمات نفسه) وتاب العروض من غير FAB. وكمان الـ FAB ما كانش بيتحدّث مع **السحب** بين التابات: `TabController` بيبلّغ بـ `indexIsChanging == false` لما `TabBarView` يستقر بعد swipe (اتأكدت من مصدر Flutter 3.44.7: `_changeIndex` + `_handleScrollNotification`) والـ listener القديم كان بيرجع قبل `setState`.

  * ثوابت مسمّاة للتابات؛ 1 ← `AddProductScreen`، 3 ← `AddOfferScreen`؛ تاب الخدمات **من غير FAB هنا** (`MerchantServicesTab` عنده FAB خاص بيه) مع خانة فاضية 56×56 عشان زرار Gemini ما يقعدش فوقه. الـ FAB بيتبني بـ `ListenableBuilder(_tabController)` فبيتبع الضغط والسحب، و`setState` الزيادة في الـ listener اتشالت (تحميل الإحصائيات فضل زي ما هو).

  * تاب العروض بيحمّل مرة واحدة في `initState`، فبعد ما `AddOfferScreen` يرجّع `true` بنغيّر مفتاحه (`_offersRevision`) عشان العرض الجديد يظهر. (تاب المنتجات فيه نفس المشكلة من قبل كده — ملاحظة 26.)

* $$
  x
  $$

   **23. `add_shop_screen.dart` — معالجة `ADMIN_BYPASS`**
  الممرّرة من `admin_dashboard.dart:83` كحالة خاصة، أو تغيير الآلية بالكامل.
  ✅ `b9ad00a` — السبب: لوحة الأدمن بتفتح `AddShopScreen(activationCode: 'ADMIN_BYPASS')` ومفيش أي كود في المشروع بيعالج النص ده: بيتحط في خانة الكود ويقع في شرط `SHOP-` قبل ما يوصل لأي خدمة، وحتى لو عدّى الفورم قاعدة `shops` create كانت `isMerchant()` بس (الأدمن مش تاجر) — الزر عمره ما اشتغل.

  * اخترت «تغيير الآلية»: مفتاح صريح `adminBypass` على الشاشة بدل النص السحري (مينفعش المستخدم يكتبه في خانة الكود). بيتفعّل بس لو الدور `admin`/`super_admin` (المشرف `moderator` بيكمّل بالكود العادي)، وخانة الكود بتتبدّل ببانر توضيحي.

  * `ApiService` / `ShopService.createShop(adminBypass:)`: الخدمة بتتأكد من دور صاحب المحل من `users/{uid}` **قبل رفع أي صورة**، مبتحرقش كود ومبتخزّنش `activationCode`، وبتكتب `AuditAction.shopCreated` (`viaAdminBypass: true`) في سجل التدقيق.

  * `firestore.rules`: `shops` create بقت `(isMerchant() || isAdmin())` — شرط `ownerId == appUid()` فاضل زي ما هو، يعني الأدمن بينشئ محل بإسمه هو بس. **القواعد لسه مش منشورة** (محتاجة `firebase deploy`). **قرار منتج متاح لك:** افترضت إن المحل اللي الأدمن بينشئه ملك حساب الأدمن (ملاحظة 27).

* $$
  x
  $$

   **24. منع إنشاء محل بكود تفعيل فاضي**
  ✅ `40cab93` — السبب: `ShopService.createShop` كان بيدوّر على الكود ويحرقه بس لو `activationCode` مش `null` ومش فاضي؛ مع `null`/`''` الحرق كله بيتخطى والمحل بيتعمل من غير كود (شرط الفورم كان بيخبّي المشكلة عن الواجهة بس، والخدمة هي نقطة الاختناق الحقيقية).

  * فحص مبكر **قبل أي رفع صور**: كود نصي غير فاضي مطلوب، إلا مسار `adminBypass` الصريح من #23. وبعد الاستعلام أي إنشاء من غير مسار الأدمن ما يلاقيش كود `shop_activation` صالح غير مستخدم بيترفض قبل الـ transaction (خط دفاع تاني)، فحرق #21 الذرّي (query ← `tx.get` ← update) بقى شغّال دايمًا للتجار.

  * `createShop` ليه مسار استدعاء واحد بس (`AddShopScreen ← ApiService.createShop`). الفرض على مستوى الخدمة/العميل بس — القواعد مبتقدرش تتحقق من حرق الكود (ملاحظة 28).

* $$
  x
  $$

   **25. توحيد `createdAt`**
  `serverTimestamp` في كل مكان بدل ISO string (`add_shop`, `report_problem`, `wishlist` وقراءتها بـ `DateTime.parse`).
  ✅ `c2c21fc` — السبب: `WishlistCollection.toMap()` كان بيكتب `createdAt.toIso8601String()` فعلًا و`fromMap` بيقراه بـ `DateTime.parse` اللي بيرمي استثناء لو القيمة `Timestamp`. أما `add_shop_screen` و`report_problem_screen` فكانوا بيحطوا ISO في الـ payload لكن `ShopService.createShop` و`AdminService.submitComplaint` بيكتبوا فوقه بـ `serverTimestamp` أصلًا (قيمة ميتة بتوحي بمصدر تاني للحقيقة).

  * `wishlist_collection_model.dart`: `toMap()` ← `FieldValue.serverTimestamp()` (نفس اتفاقية موديلات التقييم/المزايدات/الطلبات/الوظايف/الإعلانات)، و`fromMap` ← `DateParser.parse` (بيقبل `Timestamp` أو ISO قديم أو int). تعديلات سطر واحد لأن الملف نهايات أسطره mixed (ملاحظة 25).

  * الشاشتين: اتشال الـ ISO الميت (الخدمة هي الكاتب الوحيد). **اتسابت عن قصد** الكتابات اللي قواعد #20 بتثبّتها على `request.time` (`collection_invites` / `subscription_history` / `share_analytics` `createdAt`، و`job_subscriptions` / `provider_topic_subscriptions` `updatedAt`) — كلها أصلًا `serverTimestamp`. باقي مواضع ISO اللي اتفحصت بتتوصف في ملاحظة 29.

* $$
  x
  $$

   **26. توحيد حالة الشكوى الابتدائية**
  `pending` أو `new` في الثلاث أماكن (الشاشة/الـ service/تاب الأدمن) مش ثلاث قيم مختلفة.
  ✅ `b0c9990` — السبب: الشاشة بتبعت `pending`، و`AdminService.submitComplaint` بيكتب فوقها `new` (القيمة المخزّنة فعلًا)، وفلتر وعدّاد «جديدة» في تاب الأدمن بيدوّر على `pending` / `null` / `''` بس — فالشكوى الجديدة ماكانتش بتظهر تحت «جديدة» (بتظهر في «الكل» بس).

  * القيمة الموحّدة: **`pending`** (اللي بتستخدمها الشاشة وتاب الأدمن وافتراضي `my_complaints_screen` والـ seeder). الخدمة بتكتبها، وتاب الأدمن فيه دالة واحدة `_isNewComplaint` للفلتر والعدّاد بتقبل كمان `new` و`null` و`''` عشان الشكاوى القديمة المخزّنة بـ `new` ما تختفيش. شاشة «شكاويّ» مش محتاجة تعديل (الفرع الافتراضي بيغطي الاتنين). مفيش Cloud Function ولا قاعدة بتعتمد على `new`.

* $$
  x
  $$

   **27. ربط `mergeLocalFavoritesOnLogin()`**
  معرّفة ومكتوبة كويس، بس مش بتتنادى من أي مكان عند نجاح تسجيل الدخول.
  ✅ `348ebca` — السبب: الدالة (#16) محدش بينادي عليها، فمفضلة الضيف فضلت على الجهاز ومتوصلتش للحساب.

  * `FavoritesProvider.updateUser` (نقطة الاختناق اللي `ProxyProvider<AuthProvider>` بيمرّر منها المستخدم) بتنادي الدمج عند الانتقال **ضيف ← مسجّل**، والدمج بينتهي بـ `loadFavorites()` فمفيش قراءة مكررة؛ التبديل بين حسابين لسه `loadFavorites()` بس.

  * ثغرة اتقفلت قبل التوصيل: الدمج كان بيغطي `shop` / `product` / `offer` بس، والضيف بيحفظ محلات الخدمات محليًا بنوع `service` و`LocalFavoritesService.clear()` بيمسح كل الأنواع — توصيل النسخة القديمة كان هيضيّع مفضلة الخدمات. اتضاف `service` للدمج.

  * `clear()` لسه بعد نجاح كل الإضافات بس (لو حاجة فشلت المفضلة المحلية بتفضل لإعادة المحاولة)، و`loadFavorites()` بقت بتشتغل حتى لو الدمج فشل لأن `updateUser` مبقتش بتنادي عليها مباشرة. كتابة `users/{id}/favorites` بتعدّي القواعد بـ `appUid()`؛ عدّادات `favoriteCount` لسه مرفوضة لغير المالك ومبلوعة داخل `_updateItemFavoriteCount` فالدمج ما اتأثرش (ملاحظة 13 في ملاحظات المرحلة 3، وملاحظة 31 تحت).

* $$
  x
  $$

   **28. تصحيح مسارات `/offers` و`/favorites`**
  بترجّع `MainScreen()` على تاب الرئيسية بدل التاب المقصود.
  ✅ `0a6a170` — السبب: `MainScreen` مكانش بيستقبل تاب، فالراوتين (بيستخدمهم ضغط الإشعارات وعنوان «عرض الكل» في الرئيسية) كانوا بيرجعوا `const MainScreen()` على تاب 0.

  * `MainScreen(initialIndex:)` + ثوابت `homeTab` / `favoritesTab` / `offersTab` بنفس ترتيب الـ `NavigationBar` (رقم خارج النطاق بيرجع للرئيسية بدل ما يكسر `IndexedStack`)، و`main.dart`: `/favorites` ← تاب 1، `/offers` ← تاب 2.

  * اللي فضل زي ما هو: الراوتين لسه بيتفتحوا بـ `pushNamed` يعني `MainScreen` تانية فوق الأولى (ملاحظة 32).

* $$
  x
  $$

   **29. زرار "خلط" في الرئيسية**
  بيفضّي القسم بدل ما يعيد ترتيبه.
  ✅ `d731a5a` — السبب: الزرار كان بيعمل `_shuffledShops = []` و`_buildShuffleList` بترجع بدري لأن توقيع المحلات ما اتغيّرش، فالقائمة بتفضل فاضية و`_forYouSection` بترجّع `SizedBox.shrink()` — القسم كله (والزرار نفسه) بيختفي.

  * `_buildShuffleList(provider, {force})`: الزرار بينادي `force: true` فيعيد الخلط فعلًا، والمسار العادي ما اتغيّرش (مفيش إعادة خلط مع كل rebuild).

* $$
  x
  $$

   **30. شرائح الفلترة في الرئيسية**
  شريحة الفئة بتنفّذ `search()` بدل `filter()`؛ شريحة النوع مش شغالة خالص.
  ✅ `e7c6fc7` — السبب: شريحة الفئة كانت بتنادي `search(اسم الفئة)` (بحث نصي في اسم/وصف المحل بيستبدل نص بحث المستخدم، و«الكل» بيمسحه)، وشريحة النوع ماكانش ليها معالج خالص، والشريحتين بيتبنّوا من جديد مع كل rebuild من غير `defaultOption` فالتحديد كان بيرجع لـ «الكل».

  * الفئة ← `ShopsProvider.fetchShops(category:)` (نفس مسار الفئة اللي تحديث الرئيسية بيحافظ عليه، ونص البحث بيفضل مطبّق)؛ التظليل بيتبع `provider.selectedCategory`.

  * النوع ← حالة `_resultType` بتحدد أقسام الرئيسية اللي بتظهر. **قرار منتج متاح لك:** محلات = المحلات المميزة + «اخترنا لك» · منتجات · عروض · خدمات = معاينة طلبات الخدمات · الكل = كل حاجة بما فيها الديلر والوظايف؛ الإعلانات والفئات دايمًا ظاهرين (ملاحظة 33).

* $$
  x
  $$

   **31. البحث المتقدم — استخدام نتائج Firestore بدل رميها**
  ✅ `c245fc6` — السبب: `_searchFirestore` بينفّذ 3 استعلامات (منتجات / محلات / عروض) بالتوازي لكن بيخزّن أول اتنين بس؛ استعلام العروض (لحد 20 قراءة في كل بحث) كان بيتشال بتعليق «يمكن إضافة tab لها لاحقاً» مع إن تاب «عروض» موجود فعلًا و`_filterOffers` كان بيبص على `provider.allOffers` المحلية بس.

  * حالة `_firestoreOffers` (بتتفضّى مع الاتنين التانيين لما البحث أقصر من حرفين) و`_filterOffers` بيستخدمها. **دمج مع القائمة المحلية بدون تكرار بالـ id** بدل الاستبدال زي المحلات/المنتجات، لأن العروض اللي بتتضاف من التطبيق ملهاش `searchKeywords` (ملاحظة 34) فالاستبدال كان هيخفي نتايج بتظهر دلوقتي؛ والمطابقة النصية بقت تقبل `searchKeywords` كمان زي المنتجات.

* $$
  x
  $$

   **32. فلتر "ينتهي اليوم"**
  بيشمل كل العروض المنتهية من زمان، مش بس اللي هتنتهي النهاردة.
  ✅ `63332f6` — السبب: شريحتا «ينتهي اليوم» و«خلال أسبوع» في `offers_screen` كان ليهم حد أعلى بس (`validUntil < الآن + المدة`)، و`ProductService.getOffers` بيرجّع كل العروض `isActive` من غير أي شرط على `validUntil` ومفيش حاجة بتعطّل العرض المنتهي من السيرفر (مفيش Cloud Functions في الريبو)، فأي عرض عدّى تاريخه من زمان كان بيحقق الشرط وبيظهر تحت «ينتهي اليوم».

  * أضفت `!o.isExpired` (نفس تعريف `Offer.isExpired` المستخدم في `merchant_offers_tab` و`horizontal_list`) للشريحتين؛ «خلال أسبوع» كان فيها نفس النقص في نفس الكتلة فاتصلّحت معاها. نافذة الـ24 ساعة المتحركة اتسابت زي ما هي لأنها بتطابق label الكارت (`daysLeft == 0`). **اللي اتحقق منه:** الملف LF، فاحص الأقواس/imports نضيف، و`flutter analyze` على الـ CI = `exit 0`. (ملاحظتا 35 و36)

* $$
  x
  $$

   **33. إخفاء عناصر تحكم الأدمن وإعلانات `isActive:false`** عن واجهة المشتري.
  ✅ `89c15e3` — السبب: شاشة الإعلانات (تاب «الإعلانات» جوه `AdsHubScreen` = واجهة مشتري) كانت بتقرا المجموعة كلها بـ `AdService.getAllAds()` — بتشمل `isActive:false` (فيديوهات تحت المراجعة / مرفوضة / لسه مدفوعتش) — وبترسم كل إعلان بـ `AdminAdCard` فكان بيظهر للمشتري سويتش التفعيل وزر الحذف وعدد النقرات وشارة نشط/منتهي. وكمان الاستعلام من غير `isActive == true` كان هيترفض بالكامل من قاعدة القراءة بعد نشر القواعد فالتاب كانت هتفضى، وزر عكس الترتيب كان في الـ AppBar اللي `AdsHubScreen` بيخفيه.

  * **قرارات Osama أثناء التنفيذ (ملاحظة 37):** الشاشة أرشيف لكل الإعلانات النشطة من الأحدث للأقدم مع زر عكس الترتيب، من غير تقسيم نشط/منتهي؛ تحميل تدريجي 20 في المرة؛ اللي عدّى 6 شهور بيختفي من الشاشة دي بس (يفضل عند التاجر)؛ المدة تفضل 7 أيام قابلة للتعديل؛ و`displayLocations` تتسجّل في الملاحظات بس (ملاحظة 41).

  * `AdService.getArchivePage` + `AdsPageResult` (نفس نمط `ProductPageResult` + علم `failed`): `isActive == true` + `createdAt >= الآن - 183 يوم` + `orderBy createdAt` (الـ index الموجود `isActive+createdAt` بيخدم الاتجاهين) + `startAfterDocument`. · `AdModel.createdAt` (قراءة بـ `DateParser`، والكتابة لسه `serverTimestamp`). · `AdminAdCard.showAdminControls` (الافتراضي `true` فتبويب الأدمن مبيتغيرش؛ `false` بيخفي الشارة وتاريخ الانتهاء وصف النقرات/التفعيل/الحذف ويعرض «نُشر: تاريخ»). · `AllAdsScreen` معاد كتابتها: من غير فلتر/شارة حالة، زر الترتيب جوه الجسم، infinite scroll + تذييل «تحميل المزيد / إعادة المحاولة»، سحب للتحديث بدون وميض، حارس لنتايج الطلبات القديمة، `ScrollController` بيتعمله dispose، البحث على المحمّل بس، ورسالة خطأ ودّية بدل قايمة فاضية. **اللي اتحقق منه:** فاحص الأقواس/imports نضيف على الملفات الأربعة و`flutter analyze` على الـ CI = `exit 0`. (ملاحظات 37–42)

* $$
  x
  $$

   **34. نشر وظيفة جديدة بيعطّل الوظائف السابقة بصمت**
  من غير تنبيه — تصحيح أو توضيح إن ده مقصود.
  ✅ (مُنفّذ ومُراجع في الكود `post_job_ad_screen.dart:81,140`) — دالة `_confirmReplacePrevious` تعرض حوار تأكيد صريح بعناوين الإعلانات النشطة السابقة للناشر قبل إيقافها في `batch` ذرية، وإذا رفض الناشر أو أغلق الحوار يتوقف النشر دون أي كتابة.

* $$
  x
  $$

   **35. تفعيل كود دفع إعلان الديلر الإضافي**
  مكتوب عليه "100 جنيه" بس بينشر مجانًا فعليًا، من غير كود `dealer_listing_fee`.
  ✅ (مُنفّذ ومُراجع في الكود `dealer_listing_service.dart` + `sanhour_dealer_screen.dart:458,520` + `admin_codes_tab.dart:50,402`) — عند وجود إعلان نشط سابق للبائع يُطلب كود `dealer_listing_fee` ويُحرق ذرياً داخل Transaction مع إنشاء الإعلان، مع إضافة مولّد أكواد `dealer_listing_fee` (`DLR-XXXXXX`) في لوحة الأدمن.

* $$
  x
  $$

   **36. Histogram تقييمات صفحة المحل**
  رقم وهمي ثابت (`0.3 * star/5`) بدل بيانات حقيقية.
  ✅ (مُنفّذ ومُراجع في الكود `shop_detail_screen.dart:791,839`) — يُحسَب توزيع النجوم الفعلي من قائمة التقييمات الحقيقية (`_reviews.where((r) => r.rating.round() == star).length / _reviews.length`).

* $$
  x
  $$

   **37. Soft-delete — استخدام الـ mock user id الصح**
  بدل الـ Firebase UID المجهول (مرتبط ببند 13).
  ✅ (مُنفّذ ومُراجع في الكود `options_screen.dart:54-85`) — `_performSoftDelete` يستخدم `authProvider.user?.id` بدلاً من `currentUser.uid` لتحديث وثيقة `users/{userId}` وإخفاء متاجره المرتبطة بـ `ownerId == userId`.

* $$
  x
  $$

   **38. إدارة الفريق — تعديل `userType`**
  القواعد هترفضها بنفس منطق منع self-escalation (مرتبط ببند 13/18) — تصحيح أو تعديل القواعد لو التغيير مقصود.
  ✅ (مُنفّذ ومُراجع في الكود `firestore.rules:93-123` + `team_management_screen.dart:63,95`) — دوال `isShopOwnerAddingMember` و`isShopOwnerRemovingMember` في `firestore.rules` تسمح لمالك المحل فقط بربط عضو فريق (`shopRole in ['partner', 'worker']`, `linkedShopId == shopId`) أو فك ارتباطه، مع دعم صلاحيات الشريك/العامل في `canManageShopContent(shopId)`.

* $$
  x
  $$

   **39. `toMap()` — JobAdModel و Product**
  `JobAdModel.toMap()` بيصفّر `createdAt` عند أي تحديث؛ `Product.toMap()` مش بيكتب `createdAt` خالص.
  ✅ تم التنفيذ —

  * `JobAdModel`: أُضيف الحقلان `viewCount` و`applicationCount` للموديل مع قراءتهما في `fromMap`، وتعديل `toMap({bool isNew = false})` ليكتب `FieldValue.serverTimestamp()` عند الإنشاء الجديد فقط (`isNew: true` في `post_job_ad_screen.dart`) ويحافظ على `Timestamp.fromDate(createdAt)` والعدادات الفعلية عند التحديث.

  * `Product`: أُضيف `createdAt: createdAt?.toIso8601String()` في `Product.toMap()` للحفاظ على تاريخ الإنشاء في الكاش المحلي (`Hive`) وترتيب `newProducts`، كما حُوِّل `validUntil` إلى ISO String في `Offer.toMapWithId()` لمنع خطأ `Hive` مع `Timestamp` (ملاحظة 42).

* $$
  x
  $$

   **40. تهيئة التاريخ العربي**
  `initializeDateFormatting('ar')` قبل أول استخدام لتنسيق تاريخ عربي.
  ✅ تم التنفيذ — استيراد `package:intl/date_symbol_data_local.dart` واستدعاء `await initializeDateFormatting('ar');` في بداية `main()` في `lib/main.dart` مباشرة بعد `WidgetsFlutterBinding.ensureInitialized()`.

## المرحلة 5 — جودة الكود والنواقص المنتجية (آخر أولوية)

* $$
  x
  $$

   **41. تناسق بصري** — لون شيبس "إضافة عرض" (لسه `redAccent`)، توحيد الخط (Cairo/Tajawal)، توحيد ألوان `AppConstants`/`AppColors`.
  ✅ تم التنفيذ — استبدال جميع مواضع `Colors.redAccent` الستة في `lib/screens/add_offer_screen.dart` بـ `AppColors.primary` (`0xFF5E35B1`)، وتوحيد `fontFamily` في `lib/utils/app_theme.dart` (الوضع النهاري والليلي) إلى `'Tajawal'` ليطابق `lib/main.dart` و`sub_category_list.dart`.

* $$
  x
  $$

   **42. أداء** — تقليل الـ streams الدايمة الشغالة في `IndexedStack` (6 تابات = 3 streams مستمرة حتى لو التاب مقفول).
  ✅ تم التنفيذ — تفعيل التحميل الكسول (Lazy Tab Mounting) عبر `_activatedTabs` في كلٍّ من `MainScreen` (`lib/screens/main_screen.dart`) و`AdsHubScreen` (`lib/screens/ads_hub_screen.dart`)، بحيث لا تُبنى شاشات التبويبات غير المفتوحة ولا تشتغل Streams الفايرستور الخاصة بها إلا عند فتح المستخدم للتبويب فعلياً.

* $$
  x
  $$

   **43. دفعة بيانات صغيرة** — ترتيب `bestOffers`، قيمة `Offer.isActive` الافتراضية، `isFavorite` على مستند المحل العام بدل مستند خاص، ترتيب فلتر المنطقة قبل الـ limit، `getServices` واحترام `isShopHidden`.
  ✅ تم التنفيذ —

  * `ShopsProvider.bestOffers`: فلترة العروض السارية (`!o.isExpired && o.isActive`) وترتيبها تنازلياً حسب `discount` ثم `views` قبل أخذ أول 10.

  * `Offer.fromMap`: تعديل القيمة الافتراضية لـ `isActive` إلى `true` بدلاً من `false` عند غياب الحقل.

  * إزالة كتابة `isFavorite: false` المضللة من مستندات Firestore العامة في `add_shop_screen.dart` و`product_service.dart`.

  * `ShopService.getShopsPage` و`getNextShopsPage`: تطبيق فلتر المنطقة `q.where('location', isEqualTo: region)` على الاستعلام قبل `.limit(pageSize)`.

  * `ApiService.getServices`: استبعاد خدمات المحلات المخفية/الموقوفة (`item['isShopHidden'] != true`) عندما يكون `visibleOnly == true`.

* $$
  x
  $$

   **44. ميزات صغيرة ناقصة** — قالب Excel حقيقي، حد دعوة القائمة المشتركة (2→20)، `Radio` غير قابل لحالة null، تسمية قنوات الإشعارات (`orders_channel`).
  ✅ تم التنفيذ —

  * `ExcelUploadScreen`: توليد وتصدير ملف `.xlsx` حقيقي جاهز بالرؤوس العربية وأمثلة المنتجات ومشاركته عبر `SharePlus`.

  * القوائم المشتركة: ضبط حد المتعاونين الأقصى `maxCollaborators = 20` في `collection_detail_screen.dart` ورفع `.limit(20)` في `_updateInviteStatus` بـ `notifications_screen.dart`.

  * `Radio`: إزالة `toggleable: true` من `RadioListTile` في `subscription_screen.dart`، وحراسة `if (value != null)` بدلاً من `value!` في `complete_profile_screen.dart`.

  * تعريب اسم قناة `orders_channel` في `NotificationConstants.channels` (`lib/utils/constants.dart`) إلى `'طلبات الخدمات والوظائف'` بدلاً من `'تحديثات الطلبات'`.

* $$
  x
  $$

   **45. Storage rules متبقية** — منع أي مستخدم موثّق من مسح صور غيره، تصحيح شرط قراءة `complaint_attachments` (`|| true`).
  ✅ تم التنفيذ —

  * إزالة `|| true` من قاعدة قراءة `complaint_attachments/{userId}` في `storage.rules` وتقييدها بـ `isOwner(userId) || isMerchantOrStaff()`.

  * إرفاق `customMetadata: {'ownerId': uid}` تلقائياً مع كل ملف مرفوع عبر `MediaUploadService.uploadFile`، وإضافة دالة `isFileOwner()` في `storage.rules` لتقييد حذف صور `reviews_images` و`dealer_listings` بمالك الملف أو المشرف.

* $$
  x
  $$

   **46. تسميات غير متطابقة** — تاب "ديلر"→"سوق"، "مركز الإعلانات"→"الإعلانات"، نص الأونبوردنج عن الديلر كتوصيل بدل سوق مستعمل.
  ✅ تم التنفيذ — تعديل مسميات شريط التنقل السفلي في `main_screen.dart` إلى `'سوق'` و`'الإعلانات'`، وتصحيح الشريحة الخامسة في `onboarding_screen.dart` إلى `'سنهور ديلر (سوق المستعمل)'` — `'بيع واشتري المستعمل بسهولة'` بأيقونة `Icons.sell_rounded` بدلاً من وصف التوصيل القديم.

* $$
  x
  $$

   **47. مطابقة الاهتمامات مع فئات المحلات** — عشان قسم "اخترنا لك" يشتغل.
  ✅ تم التنفيذ — تحديث قائمة الفئات في `lib/screens/interests_screen.dart` لتطابق الفئات العشر الفعلية للمحلات (`مأكولات ومشروبات`، `ملابس وأزياء`، `أجهزة إلكترونية`، `صحة وجمال`، `خدمات منزلية`، `تعليم وتدريب`، `مواصلات وسيارات`، `خدمات مهنية`، `ذهب ومجوهرات`، `عقارات`)، وإضافة مطابقة مرنة `_matchesUserInterests` في `HomeScreen._buildShuffleList` تدعم التطابق التام أو الجذر المشترك.

* $$
  x
  $$

   **48. `searchKeywords` للمنتجات المُضافة يدويًا** (مش بس عبر Excel).
  ✅ تم التنفيذ — استدعاء `generateSearchKeywords(...)` وحفظ حقل `searchKeywords` تلقائياً في `ProductService.addProduct` و`updateProduct` و`addOffer`.

* $$
  x
  $$

   **49. إحصائيات زوار موثوقة** — `uniqueVisitors` فعلي بدل قيمة ثابتة.
  ✅ تم التنفيذ — تحديث `StatsService.logShopVisit` لتتبع الزيارات الفريدة لكل محل على الجهاز عبر `SharedPreferences` (`visited_shops_unique`) وزيادة `uniqueVisitors` بمقدار 1 عند أول زيارة، مع السماح بالحقل في `firestore.rules` وتحديث الفرز في `categories_screen.dart` و`sub_category_list.dart`.

* $$
  x
  $$

   **50. فتح الإشعارات الداخلية** — `onTap` يودّي لمصدر الإشعار.
  ✅ تم التنفيذ — ربط `onTap: () => _onNotificationTap(n)` في `NotificationsScreen` لتعليم الإشعار كمقروء والتوجيه التلقائي حسب `type` و`data.route` (القوائم المشتركة، الشكاوى، الوظائف، طلبات الخدمات، المحلات، العروض، والمنتجات).

* $$
  x
  $$

   **51. قرار الكود اليتيم** — نحذف ولا نفعّل: `CompleteProfileScreen`، جزء email/password في `AuthService`، `DateParser`، `ApiConstants`.
  ✅ تم التنفيذ — توحيد قراءة التواريخ عبر `DateParser` في `Product.fromMap` و`Offer.fromMap` و`Shop.fromMap`، وتفعيل مسار `/complete_profile` في `lib/main.dart`، وحذف كلاس `ApiConstants` الميت غير المستخدم من `lib/utils/constants.dart`.

* $$
  x
  $$

   **52. ميزات مفقودة (قرار منتج)** — نسيت كلمة السر، تعديل الاهتمامات بعد التسجيل، خريطة/"مفتوح دلوقتي"، تبليغ عن محل، بادج عداد إشعارات.
  ✅ تم التنفيذ —

  * **نسيت كلمة المرور**: إضافة زر وحوار استعادة كلمة المرور في `LoginScreen`.

  * **تعديل الاهتمامات بعد التسجيل**: دعم `fromSettings: true` في `InterestsScreen` مع تحميل الاهتمامات المحفوظة مسبقاً، وإضافة خيار «تعديل اهتماماتي» في `OptionsScreen`.

  * **الموقع على الخريطة وحالة التوفر**: إضافة قسم «الموقع والعنوان — عرض على الخريطة 🗺️» يفتح بحث Google Maps للمحل وشارة «متاح للتواصل» بجوار مواعيد العمل في `ShopDetailScreen`.

  * **الإبلاغ عن محل**: إضافة زر الإبلاغ (`Icons.flag_outlined`) في `ShopDetailScreen` يفتح `ReportProblemScreen` مع تعبئة عنوان البلاغ باسم المحل تلقائياً.

  * **بادج عداد الإشعارات**: إضافة عداد حي (`StreamBuilder`) للإشعارات غير المقروءة بجوار عنصر «الإشعارات» في القائمة الجانبية (`MainScreen`).

## القاعدة الثابتة لكل أكواد التفعيل (الأربعة)

كل الأنواع بتستخدم نفس collection (`activation_codes`) بس بحقل `type` مختلف وإجباري في كل استعلام تحقق:

* `shop_activation` — تفعيل متجر جديد

* `shop_renewal` — تجديد اشتراك متجر

* `ad_activation` — تفعيل إعلان مدفوع

* `dealer_listing_fee` — إعلان سنهور ديلر إضافي بعد الحد المجاني

كل الأربعة مرشحة لبوابة دفع حقيقية (فودافون كاش/فيزا) في مرحلة لاحقة — النظام الحالي بديل مؤقت يدوي.

## الخطوة الثابتة قبل تسليم أي مرحلة — `flutter analyze` لازم يطلع صفر

بعد آخر بند في المرحلة وقبل رسالة التسليم: شغّل `flutter analyze` وصلّح أي error / warning / info لحد ما يطلع **`No issues found!`**، وذكر النتيجة في رسالة التسليم.

* **إزاي تشغّله:** بيئة الشات مفيهاش Flutter SDK (`pub.dev` و`storage.googleapis.com` محجوبين) فالتشغيل بيتم على GitHub Actions: الـ workflow `.github/workflows/flutter-analyze.yml` (موجود في الريبو) بيشتغل تلقائيًا مع كل push على `main` بـ Flutter `3.44.7` وبينشر النتيجة كـ check run اسمه **`flutter-analyze-report`** على نفس الـ commit؛ عنوانه `flutter analyze (exit 0)` = صفر مشاكل. اقراه بـ `GET /repos/{owner}/{repo}/commits/{sha}/check-runs` (حقل `output.text`)، وبعد الـ push استنى الـ run يخلص (بياخد حوالي دقيقة). فيه كمان check run تاني **`dart-fix-report`**: معاينة لإصلاحات `dart fix` الرسمية (للقراءة بس، مفيش حاجة بتتعمل commit).

* **اشتغل ملف بملف مش خطأ بخطأ:** اجمع كل مشاكل الملف الواحد وصلّحها في edit واحد (100 مشكلة على 20 ملف = 20 خطوة مش 100)، وخلّي الـ commit/push لمجموعة كبيرة مش لكل ملف. التوكنز غالية — قلّل عدد الخطوات.

* **استثناء:** لو `dart fix` الرسمي بيصلّح مجموعة مشاكل مع بعض من غير شغل منك (شوف `dart-fix-report`) استخدم الـ diff بتاعه بدل التعديل اليدوي لكل واحدة.

* **النتايج دي على Flutter 3.44.7 مع `pub get` طازج** (مفيش `pubspec.lock` في الريبو) — لو الحزم عندك محليًا بإصدارات مختلفة ممكن تطلع فروق صغيرة.

* **أخطاء analyzer متكررة اتصلّحت في المرحلة 3 — تجنّبها من الأول:**

  1. `cond ? (x as Map?)?['k'] as String? : null` — الـ parser بيقرأ `?[` جوه then-branch لتعبير شرطي كبداية شرط تاني (`non_bool_condition` + `Expected ':'`). استخرج القيمة لمتغير محلي من غير ternary.

  2. حقل nullable (`_user`) بعد `if (_user == null) return;` مبيتعملّوش promotion جوه closure → انسخه لمتغير محلي `final user = _user;` الأول.

  3. باراميتر مطلوب في إصدار الحزمة المثبّت (مثال: `flutter_local_notifications ^17` بيشترط `uiLocalNotificationDateInterpretation` — اتشال في 19). طابق الكود مع إصدار الـ pubspec.

  4. `import` غير مستخدم، `!` أو cast زيادة، متغير/دالة/حقل غير مستخدم، باراميتر اختياري محدش بيمرّره.

  5. `if (...) stmt;` من غير أقواس، تجميع نص بـ `+` بدل `'${a}...'`، حقل خاص غير مُعاد تعيينه من غير `final`، اسم دالة خاصة بـ `_phase1_x` بدل lowerCamelCase.

  6. `use_build_context_synchronously` بعد `await`: لو الـ context غير `State.context` (باراميتر دالة أو `dialogContext`) الحارس لازم يكون `context.mounted` مش `mounted` بتاع الـ State.

  7. Deprecations على Flutter 3.44.7 — البدائل الصح: `Switch`/`SwitchListTile.activeColor` → `activeThumbColor` · `DropdownButtonFormField.value` → `initialValue` · `cacheExtent: n` → `scrollCacheExtent: const ScrollCacheExtent.pixels(n)` (**محتاج** `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`) · `ReorderableListView.onReorder` → `onReorderItem` (**شيل** `if (newIndex > oldIndex) newIndex--`) · `Radio`/`RadioListTile` `groupValue`+`onChanged` → `RadioGroup<T>` فوقيهم · `speech.listen(localeId:)` → `listenOptions: SpeechListenOptions(localeId: ...)` · `FirebaseAppCheck.activate(androidProvider/appleProvider)` → `providerAndroid`/`providerApple` بـ `AndroidDebugProvider`/`AndroidPlayIntegrityProvider`/`AppleDebugProvider`/`AppleAppAttestProvider`.

  8. أصول `pubspec.yaml` المعلنة لازم تكون موجودة فعلًا (`asset_directory_does_not_exist`).

## نتائج ذات صلة بفحص كوتلن (سياق بس، مش بنود عمل)

* الوضع الليلي في فلاتر عنده نفس مشكلة كوتلن، لكن أوسع: 470 استخدام عبر 38 شاشة + 23 من 26 widgets مشتركة.

* `services/referral_service.dart` نظام إحالات كامل، بس مش متنادى من أي مكان.

* من 13 دالة في `AnalyticsService`، 5 بس بتتنادى فعليًا. `AnalyticsService.observer` (تتبّع تلقائي) متسجل في `navigatorObservers` أصلًا — الاستدعاءات اليدوية شبه مكررة معاه.

* `_handleDeepLink` بيتعرّف بس على shop/product/offer من أصل 7 أنواع ممكن تتشارك.

**ملاحظة:** مسار التسجيل الحقيقي (Phone OTP بدل mock) قيد دائم لحد قرار الإطلاق الرسمي — مش جزء من القائمة دي.

## ملاحظات اتكتشفت أثناء المرحلة 1 (مرقّمة ومُنفَّذة بالكامل)

1. ✅ **تم الإصلاح والتنفيذ بالكامل (قرار أسامة: ب):**
   - **الشق التقني:** أُضيفت حراسات Null-safety صريحة على `auth.user` في المواضع الأربعة المتبقية (`service_requests_tab_screen.dart`، `sanhour_dealer_screen.dart`، `merchant/add_service_provider_screen.dart`، و`provider_registration_screen.dart`).
   - **قرار أول تشغيل:** تم تعديل `InterestsScreen._finish` بحيث إذا لم يكن المستخدم مسجّل الدخول أو ضيفاً بالفعل ينتقل إلى شاشة **`/login`** ليختار تسجيل الدخول أو الدخول كضيف.

2. ✅ **تم الإصلاح:** **`ForceUpdateChecker.check`** يرجع `Future<bool>` (`true` عند وجود تحديث إجباري)، و`SplashScreen` توقف تسلسل التنقل فوراً (`if (mustUpdate) return;`).

3. ✅ **تم الإصلاح:** نمط `dispose` داخل `whenComplete` بعد الحوارات مطبّق في كل الشاشات.

4. ✅ **تم التنفيذ بالكامل (قرار أسامة):**
   - **تقييمات المحل في صفحة المحل:** أُزيلت شريحة الفلتر المضللة `'تقييمات المنتجات'` من `merchant_reviews_screen.dart` وأصبحت الشاشة مخصصة لتقييمات المحل.
   - **تقييم كل منتج أو عرض في صفحته الخاصة:** تم تحديث `DetailScreen` (`lib/screens/detail_screen.dart`) لعرض قائمة تقييمات المنتج أو العرض مباشرة أسفل الوصف مع تحديثها فور إضافة تقييم جديد، وتم تحديث `ReviewService.addReview` و`deleteReview` لدعم تحديث تقييمات مجموعة `'offers'` إلى جانب `'shops'` و`'products'`.

5. ✅ **تم التوحيد (مرتبط بالبند 41):** تم توحيد `fontFamily: 'Tajawal'` في `AppTheme` و`main.dart`.

6. ✅ **تم التنفيذ (قرار أسامة: ب):** تم تحديث `DatabaseSeeder.cleanDatabase()` لتشمل مسح `notifications` و`complaints` و`wishlists` و`collection_invites` ضمن تنظيف محتوى التطبيق.

7. 📌 **ملاحظة نشر (`firebase deploy`):** ملفات `firestore.rules` و`storage.rules` و`firestore.indexes.json` جاهزة ومحدّثة في الريبو، وتُرفع عبر `firebase deploy --only firestore:rules,firestore:indexes,storage`.

---

## ملاحظات اتكتشفت أثناء المرحلة 2 (8–19)

8. 📌 **حدود نموذج الأمان الحالي (تذكير قبل الإطلاق الرسمي):** قبل الإطلاق النهائي بـ Phone Auth الحقيقي، يتم تعطيل `allowMockSessions()` في `storage.rules` وإزالة فرع الجلسات المجهولة من `appUid()` في `firestore.rules`.

9. 📌 **مستخدم الأدمن في Firestore:** مستند `users/mock_admin` محفوظ لأن `cleanDatabase` لا تمسح `users`.

10. ✅ **تم التنفيذ (قرار أسامة: أ):** أُضيف استثناء `|| isAdmin()` في قواعد الإنشاء (`create`) بـ `firestore.rules` للمجموعات المزروعة (`users`, `shops`, `products`, `offers`, `reviews`, `job_ads`, `service_requests`, `wishlists`, `dealer_listings`, `complaints`) لتمكين الأدمن من تشغيل `DatabaseSeeder` في أي وقت حتى بعد نشر القواعد.

11. ✅ **تم التنفيذ بالكامل (قرار أسامة: أ):**
    - أصبح **نص الكود نفسه هو معرّف المستند (`docId = code`)** في `activation_codes` لجميع الأنواع الأربعة (`SHOP-...`, `REN-...`, `AD-...`, `DLR-...`).
    - تم تعديل جميع استعلامات التحقق في `ShopService` و`SubscriptionService` و`AdService` و`DealerListingService` لتقرأ المستند مباشرة بـ `.doc(normalized).get()`.
    - تم تشديد قاعدة `activation_codes` في `firestore.rules` لتفصل بين `allow get` (متاح للمسجّلين للكود غير المستخدم) و`allow list: if isModerator()` (مقصور على المشرف فقط لمنع أي كشف لقائمة الأكواد).

12. ✅ **مُحدَّث مع ملاحظة 6:** `cleanDatabase()` تمسح الآن `service_bids` و`notifications` و`complaints` و`wishlists` و`collection_invites`.

13. ✅ **تم الإصلاح بالكامل:** `options_screen._performSoftDelete` و`NotificationService.onTokenRefresh` يستخدمان معرّف مستخدم التطبيق الفعلي.

14. ✅ **تم التنفيذ مسبقاً في المرحلة 3.**

15. 📌 **تذكير خطوات النشر (`firebase deploy`):** منح دور `"Firebase Rules Firestore Service Agent"` عند أول نشر لقواعد Storage.

16. ✅ **تم التنفيذ (مفتاح Gemini + Cloud Function):** المفتاح محفوظ في `settings_private/gemini` مع دالة `askGemini` في `functions/index.js`.

17. ✅ **تم التنفيذ (قرار أسامة: أ):** تم تعديل قاعدة قراءة `service_requests` في `firestore.rules` إلى `allow read: if isAuth();` لحماية اسم ورقم هاتف العميل من القراءة بدون تسجيل.

18. ✅ **تم الإصلاح (مرتبط بملاحظة 1).**

19. 📌 **معلومة سلوك مقصود:** بعد توحيد مفتاح `onboarding_done`، يظهر الأونبوردنج مرة واحدة للمستخدم القديم.

---

## ملاحظات اتكتشفت أثناء المرحلة 3 — بعد تصحيح الترقيم (20–32، كانت 12–24)

20. *(كانت 12)* ✅ **تم الإصلاح:** منع المالك في `firestore.rules` من تعديل `isSuspended` أو `linkedShopId` أو ترقية `userType` لصلاحيات إدارية.

21. *(كانت 13)* ✅ **تم الإصلاح:** السماح بتحديث عدادات الزيارات والمفضلة والتقييمات على `shops`/`products`/`offers` في `firestore.rules`.

22. *(كانت 14)* ✅ **تم الإصلاح:** السماح للمدعو بقبول دعوة `wishlists` وإضافة `appUid()` إلى `collaborators`.

23. *(كانت 15)* ✅ **مُؤمَّن عبر Transaction حرق الكود (`SubscriptionService.renew`):** التجديد يتحقق ذرياً من الكود (`shop_renewal`) وصلاحيته (`expiresAt`) ويحرقه مع تحديث الاشتراك.

24. *(كانت 16)* ✅ **تم الإصلاح:** إضافة فحص `expiresAt` داخل Transaction في `ShopService.createShop` و`SubscriptionService.renew`.

25. *(كانت 17)* ✅ **تم التنفيذ (قرار أسامة: أ):** تمت إضافة تبويب ومولّد مستقل لأكواد تجديد الاشتراك (`🔄 التجديد` — `REN-XXXX-XXXX` بنوع `shop_renewal`) في `admin_codes_tab.dart` و`SubscriptionService.generateRenewalCode()`، وقصر التجديد على نوع `shop_renewal`.

26. *(كانت 18)* ✅ **تم الإصلاح:** قراءة وثيقة التقييم داخل Transaction في `ReviewService.deleteReview` لمنع الخصم المزدوج.

27. *(كانت 19)* ✅ **تم التنفيذ (مع ملاحظة 10):** إضافة `|| isAdmin()` في قواعد الإنشاء لدعم `DatabaseSeeder`.

28. *(كانت 20)* 📌 **تذكير (`provider_topic_subscriptions`):** دالة `processNotificationQueue` في `functions/index.js` تتولى الإرسال.

29. *(كانت 21)* ✅ **تم الإصلاح:** إضافة حقل `'date'` عند كتابة عدادات النقرات في `daily_stats` داخل `StatsService`.

30. *(كانت 22)* ✅ **تم الإصلاح:** توحيد نهايات الأسطر إلى `LF`.

31. *(كانت 23)* 📌 **معلومة بيئة (`pubspec.lock` والـ Analyzer):** الكود متوافق مع Flutter `3.44.7`.

32. *(كانت 24)* 📌 **معلومة CI اختيارية.**

---

## ملاحظات اتكتشفت أثناء المرحلة 4 — النص الأول — بعد تصحيح الترقيم (33–42، كانت 25–34)

33. *(كانت 25)* ✅ **تم الإصلاح:** تحويل الملفات الثلاثة المتبقية (`ad_carousel.dart`, `wishlist_collection_model.dart`, `wishlist_service.dart`) إلى `LF`.

34. *(كانت 26)* ✅ **تم الإصلاح:** إضافة `_productsRevision` في `MerchantDashboard` لتحديث تبويب «منتجاتي» فور إضافة منتج من الـ FAB.

35. *(كانت 27)* ✅ **تم التنفيذ بالكامل (قرار أسامة: أ + دعم بدون مالك + الربط التلقائي للرقم غير المسجّل بعد):**
    - في `AddShopScreen` (عند الإنشاء بصلاحية الأدمن) وفي `EditShopScreen` (للأدمن): أُضيف حقل اختياري **«رقم هاتف أو يوزر مالك المحل»**.
    - في `ShopService.resolveOwnerAssignment`:
      1. إذا تُرك الحقل فارغاً (أو كُتب `"بدون"` في التعديل): يُحفظ المحل **بدون مالك** (`ownerId: ''`, `pendingOwnerPhone: null`) ويمكن تعيين مالك له في أي وقت لاحق.
      2. إذا كان الرقم أو اليوزر مسجّلاً بالفعل: يُربط المحل بمعرّف المستخدم فوراً ويُرقّى حسابه إلى `merchant`.
      3. إذا كان رقم الهاتف **غير مسجّل في التطبيق بعد**: يُحفظ الرقم في `pendingOwnerPhone` على وثيقة المحل، وبمجرد أن ينشئ صاحب هذا الرقم حساباً أو يسجّل دخوله في التطبيق، تقوم دالة `_claimPendingShopsByPhone()` في `AuthProvider` تلقائياً بلقط المحل وربط `ownerId` بحسابه وترقيته إلى `merchant` (`owner`)!

36. *(كانت 28)* ✅ **تم التنفيذ (قرار أسامة: أ):** تم حذف `activationCode` دائماً من `shopData` قبل حفظ وثيقة المحل في `ShopService.createShop` بحيث لا يُخزّن الكود في وثيقة المحل العامة ويظل موثقاً في `activation_codes` فقط.

37. *(كانت 29)* 📌 **معلومة مراجعة:** `toIso8601String()` مستخدم للكاش المحلي (`Hive`) فقط.

38. *(كانت 30)* ✅ **تم الإصلاح:** توحيد `AdminService.replyToComplaint` ليكتب `'reply'` و`'adminReply'`.

39. *(كانت 31)* ✅ **تم الإصلاح:** ربط نوع `'service'` بمجموعة `'shops'` في `AuthService._updateItemFavoriteCount`.

40. *(كانت 32)* ✅ **تم الإصلاح:** استخدام `_localScaffoldKey` لكل نسخة من `MainScreen` مع `MainScreen.switchTab(...)`.

41. *(كانت 33)* ✅ **تم الإصلاح:** تصحيح ترتيب تصفير `_selectedRegion` في `ShopsProvider.fetchShops`.

42. *(كانت 34)* ✅ **تم الإصلاح:** توليد `searchKeywords` عند تعديل العرض في `ProductService.updateOffer`، وإلغاء تلويث بحث الرئيسية من `AdvancedSearchScreen`.

---

## ملاحظات اتكتشفت أثناء المرحلة 4 — النص التاني — بعد تصحيح الترقيم (43–50، كانت 35–42)

43. *(كانت 35)* ✅ **تم التنفيذ بالكامل (قرار أسامة: أ + المسح النهائي بعد شهر):**
    - في `OffersScreen._filteredOffers` و`ProductService.getOffers(shopId: null)`: يتم استبعاد العروض المنتهية (`!o.isExpired`) تماماً من شاشة العروض للمشتري (بما في ذلك شريحة «الكل»).
    - في `ProductService.getOffers`: أي عرض مضى على تاريخ انتهائه أكثر من **30 يوماً (شهر)** يتم حذفه نهائياً من قاعدة البيانات تلقائياً عبر `deleteOffer(expiredOffer.id)` (مع إرجاع السعر الأصلي للمنتج إن كان العرض من نوع `price_drop`).

44. *(كانت 36)* ✅ **تم التنفيذ (قرار أسامة: أ):** تم تعديل `AddOfferScreen` ليضبط وقت انتهاء العرض تلقائياً على **نهاية اليوم المختار (`23:59:59`)** بدلاً من `00:00:00`.

45. *(كانت 37)* ✅ **توثيق قرار منتج منفّذ (نافذة أرشيف الإعلانات 6 شهور).**

46. *(كانت 38)* 📌 **تذكير نشر الفهارس (`firestore.indexes.json`).**

47. *(كانت 39)* ✅ **تم الإصلاح:** السماح لمالك المحل وفريقه بقراءة إعلانات محلهم غير النشطة في `firestore.rules`.

48. *(كانت 40)* ✅ **تم الإصلاح:** جميع مواضع إنشاء الإعلانات تكتب `'id': docRef.id`.

49. *(كانت 41)* ✅ **تم الاعتماد (قرار أسامة: ب):** إبقاء عرض الإعلانات النشطة في الرئيسية والسبلاش كما هو.

50. *(كانت 42)* 📌 **ملاحظة تجميلية (`AdminAdCard`).**

---

## ملاحظات اتكتشفت أثناء إكمال المرحلة 4 والمرحلة 5 — بعد تصحيح الترقيم (51–54، كانت 43–46)

51. *(كانت 43)* 📌 **تذكير (`ownerId` في `storage.rules` عند الإطلاق النهائي بـ Phone Auth).**

52. *(كانت 44)* 📌 **معلومة تقنية (`uniqueVisitors` عبر `SharedPreferences`).**

53. *(كانت 45)* ✅ **تم الإصلاح:** إعادة قراءة الاهتمامات وخلط «اخترنا لك» في `HomeScreen._refreshData`.

54. *(كانت 46)* 📌 **معلومة توافق (`location` في المحلات كقائمة منسدلة موحّدة).**
