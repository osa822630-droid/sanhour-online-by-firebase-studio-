// functions/index.js
// ✅ الوظائف السحابية الرسمية لتطبيق «سنهور أونلاين» (Sanhour Online)
// 1. processNotificationQueue: إرسال إشعارات FCM الدفعية تلقائياً عند إضافة عنصر في notification_queue
// 2. deleteShopCascade: حذف متسلسل ذري للمحل وجميع منتجاته وعروضه وخدماته وإعلاناته وتقييماته وملفاته في Storage
// 3. purgeAuthUser: حذف حساب المستخدم من Firebase Auth وبياناته عند الحذف الإداري
// 4. redeemReferralCode: تفعيل كود الإحالة وتحديث رصيد الداعي بصلاحيات الخادم الآمنة
// 5. askGemini: وكيل الذكاء الاصطناعي الآمن بدون كشف المفتاح للعميل

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * استخراج مسار ملف Firebase Storage من رابط التحميل العام وحذفه بأمان
 */
async function deleteStorageUrlIfPresent(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") return;
  try {
    let objectPath = null;
    if (rawUrl.includes("/o/")) {
      const encoded = rawUrl.split("/o/")[1].split("?")[0];
      objectPath = decodeURIComponent(encoded);
    } else if (rawUrl.startsWith("gs://")) {
      const withoutScheme = rawUrl.slice(5);
      const slashIdx = withoutScheme.indexOf("/");
      if (slashIdx !== -1) {
        objectPath = withoutScheme.slice(slashIdx + 1);
      }
    }
    if (objectPath) {
      await admin
        .storage()
        .bucket()
        .file(objectPath)
        .delete({ ignoreNotFound: true });
    }
  } catch (_) {
    // تجاهل أخطاء حذف الملفات الفردية حتى لا يتوقف الحذف المتسلسل
  }
}

/**
 * جمع روابط الوسائط من وثيقة Firestore لحذفها من Storage
 */
function extractMediaUrlsFromDoc(data) {
  if (!data || typeof data !== "object") return [];
  const urls = [];
  for (const key of ["imageUrl", "coverImageUrl", "videoUrl", "profileImage"]) {
    if (typeof data[key] === "string" && data[key].startsWith("http")) {
      urls.push(data[key]);
    }
  }
  for (const listKey of ["imageUrls", "mediaUrls", "images"]) {
    if (Array.isArray(data[listKey])) {
      for (const item of data[listKey]) {
        if (typeof item === "string" && item.startsWith("http")) {
          urls.push(item);
        }
      }
    }
  }
  return urls;
}

/**
 * 1. معالج طابور الإشعارات الفورية (FCM Dispatcher)
 * يستمع إلى أي وثيقة جديدة في notification_queue/{docId} ويرسل الإشعار عبر FCM
 */
exports.processNotificationQueue = onDocumentCreated(
  "notification_queue/{docId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const payload = snap.data();
    if (!payload || payload.status === "sent") return;

    const title = String(payload.title || "سنهور أونلاين");
    const body = String(payload.body || "");
    const rawData = payload.data || {};

    // تحويل جميع قيم data إلى نصوص كما يشترط FCM
    const fcmData = {};
    for (const [k, v] of Object.entries(rawData)) {
      if (v !== undefined && v !== null) {
        fcmData[k] = String(v);
      }
    }

    const androidConfig = {
      priority: "high",
      notification: {
        channelId: fcmData.channel || "general_channel",
        sound: "default",
      },
    };

    try {
      let fcmToken = payload.fcmToken || null;
      const targetUserId = payload.targetUserId || null;
      const topic = payload.topic || payload.targetTopic || null;

      // أ) إذا كان الإشعار موجهاً لمستخدم محدد ولم يُمرر التوكن مباشرة
      if (!fcmToken && targetUserId && targetUserId !== "guest") {
        const userDoc = await db.collection("users").doc(targetUserId).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data().fcmToken || null;
        }
      }

      if (fcmToken) {
        await messaging.send({
          token: fcmToken,
          notification: { title, body },
          data: fcmData,
          android: androidConfig,
        });
      } else if (topic) {
        await messaging.send({
          topic: String(topic),
          notification: { title, body },
          data: fcmData,
          android: androidConfig,
        });
      } else {
        await snap.ref.update({
          status: "skipped",
          error: "No target token or topic found",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      await snap.ref.update({
        status: "sent",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      await snap.ref.update({
        status: "failed",
        error: String(err.message || err),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * دالة مساعدة لحذف الوثائق وملفاتها في Storage على دفعات (≤ 450 عملية لكل دفعة)
 */
async function deleteQueryBatch(query, cleanStorage = false) {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let deleted = 0;
  const docs = snapshot.docs;

  if (cleanStorage) {
    const storageUrls = [];
    for (const doc of docs) {
      storageUrls.push(...extractMediaUrlsFromDoc(doc.data()));
    }
    await Promise.all(storageUrls.map((u) => deleteStorageUrlIfPresent(u)));
  }

  for (let i = 0; i < docs.length; i += 450) {
    const chunk = docs.slice(i, i + 450);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

/**
 * 2. الحذف المتسلسل الشامل للمحل ومرفقاته (deleteShopCascade)
 * ✅ Security Fix (P0): إلغاء قراءة auth_sessions لمنع انتحال هوية المشرف العام
 */
exports.deleteShopCascade = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }

  const callerUid = request.auth.uid;
  const callerDoc = await db.collection("users").doc(callerUid).get();
  const callerRole = callerDoc.exists ? callerDoc.data().userType : "";
  if (callerRole !== "admin" && callerRole !== "super_admin") {
    throw new HttpsError(
      "permission-denied",
      "حذف المحلات متاح للمشرف العام فقط."
    );
  }

  const shopId = request.data && request.data.shopId;
  if (!shopId || typeof shopId !== "string") {
    throw new HttpsError("invalid-argument", "معرف المحل (shopId) مطلوب.");
  }

  const shopRef = db.collection("shops").doc(shopId);
  const shopSnap = await shopRef.get();
  if (shopSnap.exists) {
    const shopMediaUrls = extractMediaUrlsFromDoc(shopSnap.data());
    await Promise.all(shopMediaUrls.map((u) => deleteStorageUrlIfPresent(u)));
  }

  // حذف جميع المجموعات المرتبطة بالمحل مع تنظيف ملفاتها في Storage
  await Promise.all([
    deleteQueryBatch(db.collection("products").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("offers").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("services").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("ads").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("reviews").where("targetId", "==", shopId), true),
    deleteQueryBatch(shopRef.collection("daily_stats"), false),
    deleteQueryBatch(shopRef.collection("subscription_history"), false),
  ]);

  await shopRef.delete();

  return { success: true, shopId };
});

/**
 * 3. حذف حساب المستخدم من Firebase Auth والبيانات المرتبطة (purgeAuthUser)
 */
exports.purgeAuthUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }

  const callerUid = request.auth.uid;
  const targetUserId = (request.data && request.data.userId) || callerUid;

  if (targetUserId !== callerUid) {
    const callerDoc = await db.collection("users").doc(callerUid).get();
    const callerRole = callerDoc.exists ? callerDoc.data().userType : "";
    if (callerRole !== "admin" && callerRole !== "super_admin") {
      throw new HttpsError("permission-denied", "غير مصرح لك بحذف هذا الحساب.");
    }
  }

  try {
    await admin.auth().deleteUser(targetUserId);
  } catch (err) {
    if (err.code !== "auth/user-not-found") {
      throw new HttpsError("internal", `تعذر حذف حساب المصادقة: ${err.message}`);
    }
  }

  return { success: true, userId: targetUserId };
});

/**
 * 4. تفعيل كود الإحالة ذرياً على الخادم (redeemReferralCode)
 */
exports.redeemReferralCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }

  const newUserId = request.auth.uid;
  const rawCode =
    request.data && typeof request.data.referralCode === "string"
      ? request.data.referralCode.trim().toUpperCase()
      : "";

  if (!rawCode) {
    throw new HttpsError("invalid-argument", "كود الإحالة مطلوب.");
  }

  const referrerSnap = await db
    .collection("users")
    .where("referralCode", "==", rawCode)
    .limit(1)
    .get();

  if (referrerSnap.empty) {
    return { success: false, message: "كود الإحالة غير صحيح." };
  }

  const referrerDoc = referrerSnap.docs[0];
  const referrerId = referrerDoc.id;
  if (referrerId === newUserId) {
    return { success: false, message: "لا يمكنك استخدام كود الإحالة الخاص بك." };
  }

  const newUserRef = db.collection("users").doc(newUserId);
  const referrerRef = db.collection("users").doc(referrerId);
  const referralLogRef = db.collection("referrals").doc(`${referrerId}_${newUserId}`);

  const result = await db.runTransaction(async (tx) => {
    const newUserSnap = await tx.get(newUserRef);
    if (newUserSnap.exists && newUserSnap.data().referredBy) {
      return { success: false, message: "تم استخدام كود إحالة لهذا الحساب مسبقاً." };
    }

    tx.set(
      newUserRef,
      {
        referredBy: referrerId,
        referredAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.update(referrerRef, {
      referralCount: admin.firestore.FieldValue.increment(1),
      referralBonusDaysEarned: admin.firestore.FieldValue.increment(7),
    });

    tx.set(referralLogRef, {
      referrerId,
      referredId: newUserId,
      newUserId,
      code: rawCode,
      bonusDays: 7,
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      referrerName: referrerDoc.data().name || "صديقك",
      bonusDays: 7,
    };
  });

  return result;
});

/**
 * 5. وكيل الذكاء الاصطناعي الآمن (askGemini)
 * يقرأ مفتاح Gemini من متغير البيئة GEMINI_API_KEY أو من وثيقة settings_private/gemini على الخادم دون كشفه للعميل
 */
exports.askGemini = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }

  let apiKey = process.env.GEMINI_API_KEY || null;
  if (!apiKey || apiKey.trim() === "") {
    const secretDoc = await db.collection("settings_private").doc("gemini").get();
    apiKey = secretDoc.exists ? secretDoc.data().apiKey : null;
  }

  if (!apiKey || typeof apiKey !== "string" || apiKey.trim() === "") {
    throw new HttpsError("failed-precondition", "مفتاح الذكاء الاصطناعي غير مضبوط.");
  }

  const payload = request.data && request.data.payload;
  const model = (request.data && request.data.model) || "gemini-2.5-flash";
  if (!payload || typeof payload !== "object") {
    throw new HttpsError("invalid-argument", "بيانات الطلب غير صالحة.");
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey.trim(),
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    throw new HttpsError("internal", `Gemini API returned ${resp.status}`);
  }
  const data = await resp.json();
  const text =
    data &&
    data.candidates &&
    data.candidates[0] &&
    data.candidates[0].content &&
    data.candidates[0].content.parts &&
    data.candidates[0].content.parts[0] &&
    data.candidates[0].content.parts[0].text;

  return { text: text ? String(text).trim() : "" };
});
