// functions/index.js
// ✅ الوظائف السحابية الرسمية المؤمّنة بالكامل لتطبيق «سنهور أونلاين» (Sanhour Online)
// تغلق كافة ثغرات P0-1 إلى P0-9 و P1 و P2

const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

setGlobalOptions({ maxInstances: 10 });

// ── Helpers ──────────────────────────────────────────────────────────────────

function assertAuthenticatedUser(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }
  const provider =
    request.auth.token &&
    request.auth.token.firebase &&
    request.auth.token.firebase.sign_in_provider;
  if (provider === "anonymous") {
    throw new HttpsError(
      "permission-denied",
      "الجلسات المجهولة غير مصرح لها بهذه العملية."
    );
  }
  return request.auth.uid;
}

async function getCallerProfile(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() || {} : {};
}

function isAdminRole(role) {
  return role === "admin" || role === "super_admin";
}

function isStaffRole(role) {
  return role === "admin" || role === "super_admin" || role === "moderator";
}

function hasModeratorPermission(userData, permKey) {
  const role = userData && userData.userType;
  if (isAdminRole(role)) return true;
  if (role === "moderator") {
    const perms = userData.moderatorPermissions;
    return Boolean(perms && typeof perms === "object" && perms[permKey] === true);
  }
  return false;
}

async function syncUserCustomClaims(uid, userType, shopRole, linkedShopId) {
  try {
    await admin.auth().setCustomUserClaims(uid, {
      userType: userType || "customer",
      role: userType || "customer",
      shopRole: shopRole || "owner",
      linkedShopId: linkedShopId || null,
    });
  } catch (_) {
    // تجاهل إذا كان حساب المستخدم في بيئة محاكاة
  }
}

function normalizePhoneToE164(raw) {
  if (!raw || typeof raw !== "string") return "";
  const eastern = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
  let cleaned = raw.trim();
  for (let i = 0; i < eastern.length; i++) {
    cleaned = cleaned.split(eastern[i]).join(String(i));
  }
  const digits = cleaned.replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("0020") && digits.length >= 14) {
    return `+${digits.slice(2)}`;
  }
  if (digits.startsWith("20") && digits.length === 12) {
    return `+${digits}`;
  }
  if (digits.startsWith("01") && digits.length === 11) {
    return `+2${digits}`;
  }
  if (digits.startsWith("1") && digits.length === 10) {
    return `+20${digits}`;
  }
  return cleaned.startsWith("+") ? `+${digits}` : `+2${digits}`;
}

function phoneLookupCandidates(raw) {
  const normalized = normalizePhoneToE164(raw);
  if (!normalized) return [];
  const local = normalized.startsWith("+20")
    ? `0${normalized.slice(3)}`
    : normalized;
  return Array.from(new Set([normalized, local, String(raw).trim()])).filter(
    Boolean
  );
}

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
  } catch (_) {}
}

async function deleteStoragePrefix(prefix) {
  if (!prefix || typeof prefix !== "string") return;
  try {
    await admin.storage().bucket().deleteFiles({ prefix, force: true });
  } catch (_) {}
}

function extractMediaUrlsFromDoc(data) {
  if (!data || typeof data !== "object") return [];
  const urls = [];
  for (const key of [
    "imageUrl",
    "coverUrl",
    "coverImageUrl",
    "videoUrl",
    "profileImage",
    "profileImageUrl",
    "photoUrl",
  ]) {
    if (typeof data[key] === "string" && data[key].startsWith("http")) {
      urls.push(data[key]);
    }
  }
  for (const listKey of ["imageUrls", "mediaUrls", "images", "videoUrls"]) {
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

async function deleteQueryBatch(query, cleanStorage = false) {
  const snapshot = await query.get();
  if (snapshot.empty) return [];

  const docs = snapshot.docs;
  const deletedIds = docs.map((d) => d.id);

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
  }
  return deletedIds;
}

const SUBSCRIPTION_TIERS = {
  monthly: { label: "شهري", price: 99, days: 30 },
  quarterly: { label: "ربع سنوي", price: 249, days: 90 },
  yearly: { label: "سنوي", price: 799, days: 365 },
};

// ════════════════════════════════════════════════════════════════════════════
// 1. معالج طابور الإشعارات الفورية (P0-4 Fixed: لا يقبل fcmToken خام من الوثيقة)
// ════════════════════════════════════════════════════════════════════════════

exports.processNotificationQueue = onDocumentCreated(
  "notification_queue/{docId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const payload = snap.data();
    if (!payload || payload.status === "sent") return;

    const title = String(payload.title || "سنهور أونلاين").slice(0, 150);
    const body = String(payload.body || "").slice(0, 500);
    const rawData = payload.data || {};

    const fcmData = {};
    for (const [k, v] of Object.entries(rawData)) {
      if (v !== undefined && v !== null) {
        fcmData[String(k).slice(0, 64)] = String(v).slice(0, 256);
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
      let fcmToken = null;
      const targetUserId =
        typeof payload.targetUserId === "string" ? payload.targetUserId.trim() : null;
      const topic =
        typeof (payload.topic || payload.targetTopic) === "string"
          ? String(payload.topic || payload.targetTopic).trim()
          : null;

      // ✅ P0-4 Fix: استخراج التوكن حصرياً من وثيقة المستخدم على الخادم وتجاهل أي fcmToken ممرر
      if (targetUserId && targetUserId !== "guest") {
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
      } else if (topic && /^[a-zA-Z0-9-_.~%]{1,120}$/.test(topic)) {
        await messaging.send({
          topic,
          notification: { title, body },
          data: fcmData,
          android: androidConfig,
        });
      } else {
        await snap.ref.update({
          status: "skipped",
          error: "No valid target user token or topic found",
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

// ════════════════════════════════════════════════════════════════════════════
// 2. إضافة إشعار آمن للطابور بعد التحقق من الصلاحيات (enqueueNotification — P0-4 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.enqueueNotification = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const data = request.data || {};

  const title = String(data.title || "").trim().slice(0, 150);
  const body = String(data.body || "").trim().slice(0, 500);
  const targetUserId =
    typeof data.targetUserId === "string" && data.targetUserId.trim()
      ? data.targetUserId.trim()
      : null;
  const topic =
    typeof data.topic === "string" && data.topic.trim()
      ? data.topic.trim()
      : null;
  const extraData =
    data.data && typeof data.data === "object" ? data.data : {};

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "عنوان ونص الإشعار مطلوبان.");
  }

  // التحقق من صلاحية الإرسال إلى المواضيع العامة (Topics)
  if (topic) {
    const broadcastTopics = ["all", "merchants", "customers", "admins"];
    if (broadcastTopics.includes(topic)) {
      if (!isStaffRole(callerData.userType)) {
        throw new HttpsError(
          "permission-denied",
          "الإشعارات العامة متاحة لإدارة التطبيق فقط."
        );
      }
    } else if (topic.startsWith("shop_favorites_")) {
      const shopId = topic.slice("shop_favorites_".length);
      const shopDoc = await db.collection("shops").doc(shopId).get();
      const isShopMember =
        (shopDoc.exists && shopDoc.data().ownerId === callerUid) ||
        callerData.linkedShopId === shopId ||
        isStaffRole(callerData.userType);
      if (!isShopMember) {
        throw new HttpsError(
          "permission-denied",
          "غير مصرح لك بإرسال إشعارات متابعي هذا المتجر."
        );
      }
    } else if (
      !topic.startsWith("item_favorites_") &&
      !topic.startsWith("jobs_") &&
      !topic.startsWith("providers_")
    ) {
      if (!isStaffRole(callerData.userType)) {
        throw new HttpsError("permission-denied", "موضوع الإشعار غير مصرح به.");
      }
    }
  } else if (!targetUserId) {
    throw new HttpsError("invalid-argument", "يجب تحديد مستلم الإشعار.");
  }

  const docRef = await db.collection("notification_queue").add({
    title,
    body,
    topic: targetUserId ? null : topic,
    targetUserId,
    senderId: callerUid,
    data: extraData,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 24 * 60 * 60 * 1000)
    ),
  });

  return { success: true, id: docRef.id };
});

// ════════════════════════════════════════════════════════════════════════════
// 3. حساب متوسط التقييمات تلقائياً على الخادم (onReviewWritten — P0-9 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.onReviewWritten = onDocumentWritten(
  "reviews/{reviewId}",
  async (event) => {
    const beforeData = event.data && event.data.before ? event.data.before.data() : null;
    const afterData = event.data && event.data.after ? event.data.after.data() : null;
    const refData = afterData || beforeData;
    if (!refData || !refData.targetId) return;

    const targetId = String(refData.targetId);
    const targetType = String(refData.targetType || "shop");
    const collectionName =
      targetType === "shop"
        ? "shops"
        : targetType === "offer"
        ? "offers"
        : "products";

    const reviewsSnap = await db
      .collection("reviews")
      .where("targetId", "==", targetId)
      .get();

    let sum = 0;
    let count = 0;
    for (const doc of reviewsSnap.docs) {
      const r = Number(doc.data().rating);
      if (Number.isFinite(r) && r >= 1 && r <= 5) {
        sum += r;
        count += 1;
      }
    }

    const avgRating = count > 0 ? Number((sum / count).toFixed(1)) : 0.0;
    const targetRef = db.collection(collectionName).doc(targetId);
    const targetSnap = await targetRef.get();
    if (targetSnap.exists) {
      await targetRef.update({
        rating: avgRating,
        reviewCount: count,
      });
    }
  }
);

// ════════════════════════════════════════════════════════════════════════════
// 4. التحقق من صلاحية كود التفعيل دون كشف المجموعة (checkActivationCode — P1-7 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.checkActivationCode = onCall(async (request) => {
  assertAuthenticatedUser(request);
  const rawCode =
    request.data && typeof request.data.code === "string"
      ? request.data.code.trim().toUpperCase()
      : "";
  const expectedType =
    request.data && typeof request.data.expectedType === "string"
      ? request.data.expectedType.trim()
      : "";

  if (!rawCode) {
    return { valid: false, message: "يرجى إدخال كود التفعيل." };
  }

  const codeSnap = await db.collection("activation_codes").doc(rawCode).get();
  if (!codeSnap.exists) {
    return { valid: false, message: "كود التفعيل غير صحيح." };
  }

  const data = codeSnap.data() || {};
  if (data.isUsed === true) {
    return { valid: false, message: "هذا الكود مستخدم مسبقاً." };
  }
  if (expectedType && data.type !== expectedType) {
    return { valid: false, message: "نوع كود التفعيل غير مطابق لهذه العملية." };
  }
  if (
    data.expiresAt &&
    typeof data.expiresAt.toDate === "function" &&
    data.expiresAt.toDate() < new Date()
  ) {
    return { valid: false, message: "انتهت صلاحية كود التفعيل." };
  }

  return {
    valid: true,
    type: data.type || "",
    tier: data.tier || "monthly",
    days: Number(data.days || 30),
    price: Number(data.price || 0),
  };
});

// ════════════════════════════════════════════════════════════════════════════
// 5. إنشاء محل بكود تفعيل ذرياً على الخادم (createShopWithCode — P0-1 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.createShopWithCode = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const payload = request.data || {};
  const shopData = payload.shopData && typeof payload.shopData === "object" ? payload.shopData : {};
  const adminBypass = Boolean(payload.adminBypass);
  const rawCode =
    typeof payload.activationCode === "string"
      ? payload.activationCode.trim().toUpperCase()
      : "";

  const callerCanBypass =
    adminBypass && hasModeratorPermission(callerData, "manageShops");

  if (adminBypass && !callerCanBypass) {
    throw new HttpsError(
      "permission-denied",
      "إنشاء محل بدون كود تفعيل متاح للإدارة فقط."
    );
  }

  if (!callerCanBypass && !rawCode) {
    throw new HttpsError("invalid-argument", "كود التفعيل مطلوب لإنشاء المحل.");
  }

  // تحديد المالك في حال أنشأ الأدمن المحل لمالك آخر أو رقم هاتف معلق
  let targetOwnerId = callerUid;
  let pendingOwnerPhone = null;

  if (callerCanBypass && typeof payload.targetOwnerIdentifier === "string") {
    const rawTarget = payload.targetOwnerIdentifier.trim().replace(/^@/, "");
    if (!rawTarget || rawTarget === "بدون") {
      targetOwnerId = "";
      pendingOwnerPhone = null;
    } else {
      const candidates = phoneLookupCandidates(rawTarget);
      let userSnap = null;
      if (candidates.length > 0 && /^(\+?20|0020)?0?1[0-9]{9}$/.test(rawTarget.replace(/[\s-]/g, ""))) {
        userSnap = await db
          .collection("users")
          .where("phone", "in", candidates.slice(0, 10))
          .limit(1)
          .get();
      } else {
        userSnap = await db
          .collection("users")
          .where("username", "==", rawTarget.toLowerCase())
          .limit(1)
          .get();
      }

      if (userSnap && !userSnap.empty) {
        targetOwnerId = userSnap.docs[0].id;
        pendingOwnerPhone = null;
      } else if (candidates.length > 0) {
        targetOwnerId = "";
        pendingOwnerPhone = normalizePhoneToE164(rawTarget);
      } else {
        targetOwnerId = "";
        pendingOwnerPhone = null;
      }
    }
  }

  const shopRef = db.collection("shops").doc();
  const codeRef = !callerCanBypass
    ? db.collection("activation_codes").doc(rawCode)
    : null;

  const now = new Date();

  await db.runTransaction(async (tx) => {
    let durationDays = 30;
    let planTier = "monthly";

    if (codeRef) {
      const codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) {
        throw new HttpsError("not-found", "كود التفعيل غير صحيح.");
      }
      const cData = codeSnap.data() || {};
      if (cData.isUsed === true || cData.type !== "shop_activation") {
        throw new HttpsError(
          "failed-precondition",
          "كود التفعيل غير صالح أو مستخدم مسبقاً."
        );
      }
      if (
        cData.expiresAt &&
        typeof cData.expiresAt.toDate === "function" &&
        cData.expiresAt.toDate() < now
      ) {
        throw new HttpsError("failed-precondition", "انتهت صلاحية كود التفعيل.");
      }

      durationDays = Number(cData.days || cData.durationDays || 30);
      planTier = String(cData.tier || "monthly");

      tx.update(codeRef, {
        isUsed: true,
        usedBy: callerUid,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        shopId: shopRef.id,
      });
    }

    const endDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // بناء وثيقة المحل بحقول آمنة ومُطهّرة
    const safeShopDoc = {
      id: shopRef.id,
      name: String(shopData.name || "").trim().slice(0, 150),
      description: String(shopData.description || "").trim().slice(0, 2000),
      category: String(shopData.category || "أخرى").trim(),
      subCategory: shopData.subCategory || null,
      phone: String(shopData.phone || "").trim(),
      whatsapp: String(shopData.whatsapp || shopData.phone || "").trim(),
      location: String(shopData.location || "").trim(),
      addressDetails: String(shopData.addressDetails || "").trim(),
      imageUrl: String(shopData.imageUrl || ""),
      coverUrl: String(shopData.coverUrl || ""),
      mediaUrls: Array.isArray(shopData.mediaUrls) ? shopData.mediaUrls.slice(0, 20) : [],
      workingHours: shopData.workingHours || {},
      socialLinks: shopData.socialLinks || {},
      isServiceProvider: Boolean(shopData.isServiceProvider),
      searchKeywords: Array.isArray(shopData.searchKeywords)
        ? shopData.searchKeywords.slice(0, 80)
        : [],
      ownerId: targetOwnerId,
      pendingOwnerPhone: pendingOwnerPhone,
      // ✅ فرض القيم المحمية على السيرفر لمنع التزوير
      isFeatured: callerCanBypass ? Boolean(shopData.isFeatured) : false,
      isSuspended: false,
      isActive: true,
      rating: 0.0,
      reviewCount: 0,
      views: 0,
      uniqueVisitors: 0,
      favoriteCount: 0,
      phoneClicks: 0,
      whatsappClicks: 0,
      facebookClicks: 0,
      instagramClicks: 0,
      tiktokClicks: 0,
      telegramClicks: 0,
      subscriptionPlan: planTier,
      subscriptionStatus: "active",
      subscriptionStartDate: admin.firestore.Timestamp.fromDate(now),
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(endDate),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(shopRef, safeShopDoc);

    if (targetOwnerId) {
      const targetUserRef = db.collection("users").doc(targetOwnerId);
      tx.set(
        targetUserRef,
        {
          userType: "merchant",
          shopRole: "owner",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  });

  if (targetOwnerId) {
    await syncUserCustomClaims(targetOwnerId, "merchant", "owner", null);
  }

  return { success: true, shopId: shopRef.id };
});

// ════════════════════════════════════════════════════════════════════════════
// 6. تجديد اشتراك المحل بكود تفعيل ذرياً (renewShopSubscription — P0-2 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.renewShopSubscription = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const data = request.data || {};

  const shopId = typeof data.shopId === "string" ? data.shopId.trim() : "";
  const rawCode =
    typeof data.activationCode === "string"
      ? data.activationCode.trim().toUpperCase()
      : "";
  const requestedPlan =
    typeof data.planKey === "string" ? data.planKey.trim() : "monthly";

  if (!shopId || !rawCode) {
    throw new HttpsError(
      "invalid-argument",
      "معرف المحل وكود التجديد مطلوبان."
    );
  }

  const shopRef = db.collection("shops").doc(shopId);
  const codeRef = db.collection("activation_codes").doc(rawCode);
  const now = new Date();

  let resolvedEndDate = now;
  let resolvedPlanKey = requestedPlan;
  let resolvedPrice = 99;

  await db.runTransaction(async (tx) => {
    const [shopSnap, codeSnap] = await Promise.all([
      tx.get(shopRef),
      tx.get(codeRef),
    ]);

    if (!shopSnap.exists) {
      throw new HttpsError("not-found", "المحل غير موجود.");
    }
    const sData = shopSnap.data() || {};
    if (
      sData.ownerId !== callerUid &&
      !hasModeratorPermission(callerData, "manageShops")
    ) {
      throw new HttpsError(
        "permission-denied",
        "تجديد الاشتراك متاح لمالك المحل فقط."
      );
    }

    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "كود التجديد غير صحيح.");
    }
    const cData = codeSnap.data() || {};
    if (cData.isUsed === true || cData.type !== "shop_renewal") {
      throw new HttpsError(
        "failed-precondition",
        "كود التجديد غير صالح أو مستخدم مسبقاً."
      );
    }
    if (
      cData.expiresAt &&
      typeof cData.expiresAt.toDate === "function" &&
      cData.expiresAt.toDate() < now
    ) {
      throw new HttpsError("failed-precondition", "انتهت صلاحية كود التجديد.");
    }

    const codeTier =
      cData.tier && SUBSCRIPTION_TIERS[cData.tier] ? cData.tier : requestedPlan;
    const tierSpec =
      SUBSCRIPTION_TIERS[codeTier] || SUBSCRIPTION_TIERS.monthly;
    const effectiveDays = Number(cData.days || tierSpec.days);
    resolvedPrice = Number(cData.price || tierSpec.price);
    resolvedPlanKey = codeTier;

    let baseDate = now;
    if (
      sData.subscriptionEndDate &&
      typeof sData.subscriptionEndDate.toDate === "function"
    ) {
      const existingEnd = sData.subscriptionEndDate.toDate();
      if (existingEnd > now) {
        baseDate = existingEnd;
      }
    }
    resolvedEndDate = new Date(
      baseDate.getTime() + effectiveDays * 24 * 60 * 60 * 1000
    );

    tx.update(codeRef, {
      isUsed: true,
      usedBy: callerUid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      shopId,
    });

    tx.update(shopRef, {
      subscriptionPlan: resolvedPlanKey,
      subscriptionStartDate: admin.firestore.Timestamp.fromDate(now),
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(resolvedEndDate),
      subscriptionStatus: "active",
      lastRenewalAt: admin.firestore.FieldValue.serverTimestamp(),
      renewedBy: callerUid,
    });

    const historyRef = shopRef.collection("subscription_history").doc();
    tx.set(historyRef, {
      plan: resolvedPlanKey,
      price: resolvedPrice,
      startDate: admin.firestore.Timestamp.fromDate(now),
      endDate: admin.firestore.Timestamp.fromDate(resolvedEndDate),
      renewedBy: callerUid,
      activationCode: rawCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // إعادة إظهار منتجات وعروض المحل إذا كانت مخفية بسبب انتهاء الاشتراك
  const [hiddenProducts, hiddenOffers] = await Promise.all([
    db
      .collection("products")
      .where("shopId", "==", shopId)
      .where("isShopHidden", "==", true)
      .get(),
    db
      .collection("offers")
      .where("shopId", "==", shopId)
      .where("isShopHidden", "==", true)
      .get(),
  ]);

  const docsToUnhide = [...hiddenProducts.docs, ...hiddenOffers.docs];
  for (let i = 0; i < docsToUnhide.length; i += 450) {
    const batch = db.batch();
    for (const d of docsToUnhide.slice(i, i + 450)) {
      batch.update(d.ref, { isShopHidden: false });
    }
    await batch.commit();
  }

  return {
    success: true,
    planKey: resolvedPlanKey,
    price: resolvedPrice,
    newEndDateIso: resolvedEndDate.toISOString(),
  };
});

// ════════════════════════════════════════════════════════════════════════════
// 7. حرق كود إعلان تجاري أو إعلان سنهور ديلر (redeemAdCode & publishPaidDealerListing)
// ════════════════════════════════════════════════════════════════════════════

exports.redeemAdCode = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const data = request.data || {};
  const rawCode =
    typeof data.code === "string" ? data.code.trim().toUpperCase() : "";
  const shopId = typeof data.shopId === "string" ? data.shopId.trim() : "";

  if (!rawCode || !shopId) {
    throw new HttpsError("invalid-argument", "كود الإعلان ومعرف المحل مطلوبان.");
  }

  const shopSnap = await db.collection("shops").doc(shopId).get();
  if (!shopSnap.exists) {
    throw new HttpsError("not-found", "المحل غير موجود.");
  }
  const canManage =
    shopSnap.data().ownerId === callerUid ||
    (callerData.linkedShopId === shopId &&
      ["owner", "partner"].includes(callerData.shopRole)) ||
    hasModeratorPermission(callerData, "manageAds");

  if (!canManage) {
    throw new HttpsError(
      "permission-denied",
      "غير مصرح لك بتفعيل إعلان لهذا المحل."
    );
  }

  const codeRef = db.collection("activation_codes").doc(rawCode);
  await db.runTransaction(async (tx) => {
    const codeSnap = await tx.get(codeRef);
    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "كود الإعلان غير صحيح.");
    }
    const cData = codeSnap.data() || {};
    if (cData.isUsed === true || cData.type !== "ad_activation") {
      throw new HttpsError(
        "failed-precondition",
        "كود الإعلان غير صالح أو مستخدم مسبقاً."
      );
    }
    if (
      cData.expiresAt &&
      typeof cData.expiresAt.toDate === "function" &&
      cData.expiresAt.toDate() < new Date()
    ) {
      throw new HttpsError("failed-precondition", "انتهت صلاحية كود الإعلان.");
    }
    tx.update(codeRef, {
      isUsed: true,
      usedBy: callerUid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      shopId,
    });
  });

  return { success: true };
});

exports.publishPaidDealerListing = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const data = request.data || {};
  const rawCode =
    typeof data.code === "string" ? data.code.trim().toUpperCase() : "";
  const listing =
    data.listing && typeof data.listing === "object" ? data.listing : null;

  if (!rawCode || !listing) {
    throw new HttpsError(
      "invalid-argument",
      "كود الدفع وبيانات الإعلان مطلوبان."
    );
  }

  const codeRef = db.collection("activation_codes").doc(rawCode);
  const listingRef = db.collection("dealer_listings").doc();

  await db.runTransaction(async (tx) => {
    const codeSnap = await tx.get(codeRef);
    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "كود الدفع غير صحيح.");
    }
    const cData = codeSnap.data() || {};
    if (cData.isUsed === true || cData.type !== "dealer_listing_fee") {
      throw new HttpsError(
        "failed-precondition",
        "كود الدفع غير صالح أو مستخدم مسبقاً."
      );
    }
    if (
      cData.expiresAt &&
      typeof cData.expiresAt.toDate === "function" &&
      cData.expiresAt.toDate() < new Date()
    ) {
      throw new HttpsError("failed-precondition", "انتهت صلاحية كود الدفع.");
    }

    tx.update(codeRef, {
      isUsed: true,
      usedBy: callerUid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(listingRef, {
      ...listing,
      id: listingRef.id,
      sellerId: callerUid,
      title: String(listing.title || "").trim().slice(0, 200),
      isPaid: true,
      feeCodeId: rawCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, listingId: listingRef.id };
});

// ════════════════════════════════════════════════════════════════════════════
// 8. المطالبة الآمنة بالمحلات المعلقة برقم الهاتف (claimPendingShops — P0-3 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.claimPendingShops = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);

  // استخراج الرقم الموثق من وثيقة المستخدم أو البريد الاصطناعي u2010...@users.sanhour.online
  let verifiedPhone = String(callerData.phone || "").trim();
  const authEmail =
    (request.auth.token && request.auth.token.email) ||
    String(callerData.email || "");
  if (!verifiedPhone && authEmail.startsWith("u") && authEmail.includes("@")) {
    verifiedPhone = `+${authEmail.slice(1, authEmail.indexOf("@"))}`;
  }

  const candidates = phoneLookupCandidates(verifiedPhone);
  if (candidates.length === 0) {
    return { claimedCount: 0 };
  }

  const shopsSnap = await db
    .collection("shops")
    .where("pendingOwnerPhone", "in", candidates.slice(0, 10))
    .get();

  if (shopsSnap.empty) {
    return { claimedCount: 0 };
  }

  const batch = db.batch();
  for (const doc of shopsSnap.docs) {
    batch.update(doc.ref, {
      ownerId: callerUid,
      pendingOwnerPhone: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  if (callerData.userType === "customer" || !callerData.userType) {
    batch.update(db.collection("users").doc(callerUid), {
      userType: "merchant",
      shopRole: "owner",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  await syncUserCustomClaims(callerUid, "merchant", "owner", null);

  return { claimedCount: shopsSnap.size };
});

// ════════════════════════════════════════════════════════════════════════════
// 9. البحث الآمن عن مستخدم وإدارة فريق المتجر (P0-5 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.lookupUserPublicProfile = onCall(async (request) => {
  assertAuthenticatedUser(request);
  const rawQuery =
    request.data && typeof request.data.query === "string"
      ? request.data.query.trim().replace(/^@/, "")
      : "";

  if (!rawQuery) {
    return { found: false };
  }

  let snap = null;
  const candidates = phoneLookupCandidates(rawQuery);
  if (
    candidates.length > 0 &&
    /^(\+?20|0020)?0?1[0-9]{9}$/.test(rawQuery.replace(/[\s-]/g, ""))
  ) {
    snap = await db
      .collection("users")
      .where("phone", "in", candidates.slice(0, 10))
      .limit(1)
      .get();
  } else if (rawQuery.includes("@")) {
    snap = await db
      .collection("users")
      .where("email", "==", rawQuery.toLowerCase())
      .limit(1)
      .get();
  } else {
    snap = await db
      .collection("users")
      .where("username", "==", rawQuery.toLowerCase())
      .limit(1)
      .get();
  }

  if (!snap || snap.empty) {
    return { found: false };
  }

  const doc = snap.docs[0];
  const u = doc.data() || {};
  // ✅ إرجاع المعرف والاسم فقط بدون كشف رقم الهاتف أو البريد أو fcmToken
  return {
    found: true,
    id: doc.id,
    name: u.name || "مستخدم",
    username: u.username || "",
    userType: u.userType || "customer",
  };
});

exports.manageShopTeam = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const data = request.data || {};

  const shopId = typeof data.shopId === "string" ? data.shopId.trim() : "";
  const action = typeof data.action === "string" ? data.action.trim() : "";

  if (!shopId) {
    throw new HttpsError("invalid-argument", "معرف المحل مطلوب.");
  }

  const shopSnap = await db.collection("shops").doc(shopId).get();
  if (!shopSnap.exists) {
    throw new HttpsError("not-found", "المحل غير موجود.");
  }

  if (
    shopSnap.data().ownerId !== callerUid &&
    !hasModeratorPermission(callerData, "manageShops")
  ) {
    throw new HttpsError(
      "permission-denied",
      "إدارة فريق العمل متاحة لمالك المحل فقط."
    );
  }

  if (action === "list") {
    const snap = await db
      .collection("users")
      .where("linkedShopId", "==", shopId)
      .where("userType", "==", "merchant")
      .get();

    const members = snap.docs.map((d) => {
      const m = d.data() || {};
      return {
        id: d.id,
        name: m.name || "",
        username: m.username || "",
        phone: m.phone || "",
        shopRole: m.shopRole || "worker",
      };
    });
    return { success: true, members };
  }

  if (action === "add") {
    const phone = typeof data.phone === "string" ? data.phone.trim() : "";
    const role = data.role === "partner" ? "partner" : "worker";
    const candidates = phoneLookupCandidates(phone);
    if (candidates.length === 0) {
      throw new HttpsError("invalid-argument", "أدخل رقم هاتف مصري صحيح.");
    }

    const snap = await db
      .collection("users")
      .where("phone", "in", candidates.slice(0, 10))
      .limit(1)
      .get();

    if (snap.empty) {
      throw new HttpsError("not-found", "لم يُعثر على مستخدم بهذا الرقم.");
    }

    const targetDoc = snap.docs[0];
    const targetData = targetDoc.data() || {};
    if (targetData.userType !== "customer") {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن إضافة هذا المستخدم: حسابه ليس حساب عميل عادي."
      );
    }

    await targetDoc.ref.update({
      linkedShopId: shopId,
      shopRole: role,
      userType: "merchant",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await syncUserCustomClaims(targetDoc.id, "merchant", role, shopId);
    return { success: true, userId: targetDoc.id };
  }

  if (action === "remove") {
    const targetUserId =
      typeof data.userId === "string" ? data.userId.trim() : "";
    if (!targetUserId) {
      throw new HttpsError("invalid-argument", "معرف العضو مطلوب.");
    }
    const targetRef = db.collection("users").doc(targetUserId);
    const targetSnap = await targetRef.get();
    if (
      !targetSnap.exists ||
      targetSnap.data().linkedShopId !== shopId
    ) {
      throw new HttpsError("not-found", "هذا العضو غير مرتبط بهذا المحل.");
    }

    await targetRef.update({
      linkedShopId: null,
      shopRole: "owner",
      userType: "customer",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await syncUserCustomClaims(targetUserId, "customer", "owner", null);
    return { success: true };
  }

  throw new HttpsError("invalid-argument", "إجراء غير معروف.");
});

// ════════════════════════════════════════════════════════════════════════════
// 10. قبول دعوة قائمة مشتريات مشتركة بأمان (acceptCollectionInvite — P1-3 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.acceptCollectionInvite = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const inviteId =
    request.data && typeof request.data.inviteId === "string"
      ? request.data.inviteId.trim()
      : "";
  const accept = Boolean(request.data && request.data.accept !== false);

  if (!inviteId) {
    throw new HttpsError("invalid-argument", "معرف الدعوة مطلوب.");
  }

  const inviteRef = db.collection("collection_invites").doc(inviteId);
  await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "الدعوة غير موجودة.");
    }
    const inv = inviteSnap.data() || {};
    if (inv.inviteeId !== callerUid) {
      throw new HttpsError("permission-denied", "هذه الدعوة ليست موجهة لك.");
    }

    if (accept && inv.collectionId) {
      const colRef = db.collection("wishlists").doc(String(inv.collectionId));
      const colSnap = await tx.get(colRef);
      if (colSnap.exists) {
        tx.update(colRef, {
          collaborators: admin.firestore.FieldValue.arrayUnion(callerUid),
        });
      }
    }

    tx.update(inviteRef, {
      status: accept ? "accepted" : "rejected",
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// ════════════════════════════════════════════════════════════════════════════
// 11. الحذف المتسلسل الشامل للمحل ومرفقاته وفريقه (deleteShopCascade — P2 Fixed)
// ════════════════════════════════════════════════════════════════════════════

async function performShopCascadeDelete(shopId) {
  const shopRef = db.collection("shops").doc(shopId);
  const shopSnap = await shopRef.get();
  if (shopSnap.exists) {
    const shopMediaUrls = extractMediaUrlsFromDoc(shopSnap.data());
    await Promise.all(shopMediaUrls.map((u) => deleteStorageUrlIfPresent(u)));
  }

  // حذف مجلدات التخزين الخاصة بالمحل
  await Promise.all([
    deleteStoragePrefix(`shops/${shopId}/`),
    deleteStoragePrefix(`ads/${shopId}/`),
  ]);

  // فك ارتباط أعضاء فريق المحل وإعادتهم لحساب عميل
  const teamSnap = await db
    .collection("users")
    .where("linkedShopId", "==", shopId)
    .get();
  if (!teamSnap.empty) {
    const batch = db.batch();
    for (const memberDoc of teamSnap.docs) {
      batch.update(memberDoc.ref, {
        linkedShopId: null,
        shopRole: "owner",
        userType: "customer",
      });
    }
    await batch.commit();
  }

  // حذف المنتجات وجمع معرفاتها لحذف تقييماتها أيضاً
  const deletedProductIds = await deleteQueryBatch(
    db.collection("products").where("shopId", "==", shopId),
    true
  );

  // حذف تقييمات المنتجات المرتبطة بالمحل
  await deleteQueryBatch(
    db.collection("reviews").where("shopId", "==", shopId),
    true
  );
  for (let i = 0; i < deletedProductIds.length; i += 10) {
    const slice = deletedProductIds.slice(i, i + 10);
    if (slice.length > 0) {
      await deleteQueryBatch(
        db.collection("reviews").where("targetId", "in", slice),
        true
      );
    }
  }

  await Promise.all([
    deleteQueryBatch(db.collection("offers").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("services").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("ads").where("shopId", "==", shopId), true),
    deleteQueryBatch(db.collection("reviews").where("targetId", "==", shopId), true),
    deleteQueryBatch(shopRef.collection("daily_stats"), false),
    deleteQueryBatch(shopRef.collection("subscription_history"), false),
  ]);

  await shopRef.delete();
}

exports.deleteShopCascade = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);

  if (!hasModeratorPermission(callerData, "manageShops")) {
    throw new HttpsError(
      "permission-denied",
      "حذف المحلات متاح للإدارة فقط."
    );
  }

  const shopId = request.data && request.data.shopId;
  if (!shopId || typeof shopId !== "string") {
    throw new HttpsError("invalid-argument", "معرف المحل (shopId) مطلوب.");
  }

  await performShopCascadeDelete(shopId);
  return { success: true, shopId };
});

// ════════════════════════════════════════════════════════════════════════════
// 12. الحذف الشامل لحساب المستخدم وبياناته مع حماية السوبر أدمن (purgeAuthUser — P1-5 & P1-6 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.purgeAuthUser = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const callerData = await getCallerProfile(callerUid);
  const targetUserId =
    (request.data && typeof request.data.userId === "string" && request.data.userId.trim()) ||
    callerUid;

  if (targetUserId !== callerUid) {
    if (!isAdminRole(callerData.userType)) {
      throw new HttpsError("permission-denied", "غير مصرح لك بحذف هذا الحساب.");
    }
  }

  const targetRef = db.collection("users").doc(targetUserId);
  const targetSnap = await targetRef.get();
  const targetData = targetSnap.exists ? targetSnap.data() || {} : {};

  // ✅ P1-5 Fix: منع حذف حساب super_admin أو حذف أدمن آخر بواسطة أدمن عادي
  if (targetData.userType === "super_admin") {
    const superAdminsSnap = await db
      .collection("users")
      .where("userType", "==", "super_admin")
      .limit(2)
      .get();
    if (superAdminsSnap.size <= 1 || callerData.userType !== "super_admin") {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن حذف حساب المشرف الأعلى (Super Admin)."
      );
    }
  } else if (
    targetData.userType === "admin" &&
    targetUserId !== callerUid &&
    callerData.userType !== "super_admin"
  ) {
    throw new HttpsError(
      "permission-denied",
      "حذف حسابات المشرفين متاح للمشرف الأعلى فقط."
    );
  }

  // 1. حذف المحلات المملوكة للمستخدم
  const ownedShops = await db
    .collection("shops")
    .where("ownerId", "==", targetUserId)
    .get();
  for (const sDoc of ownedShops.docs) {
    await performShopCascadeDelete(sDoc.id);
  }

  // 2. حذف الصور والمجموعات المرتبطة بالمستخدم
  if (targetData.profileImageUrl || targetData.photoUrl) {
    await deleteStorageUrlIfPresent(
      targetData.profileImageUrl || targetData.photoUrl
    );
  }
  await deleteStoragePrefix(`users/${targetUserId}/`);
  await deleteStoragePrefix(`complaint_attachments/${targetUserId}/`);

  if (targetData.username) {
    await db
      .collection("usernames")
      .doc(String(targetData.username).toLowerCase())
      .delete()
      .catch(() => {});
  }

  await Promise.all([
    deleteQueryBatch(targetRef.collection("favorites"), false),
    deleteQueryBatch(
      db.collection("wishlists").where("ownerId", "==", targetUserId),
      false
    ),
    deleteQueryBatch(
      db.collection("dealer_listings").where("sellerId", "==", targetUserId),
      true
    ),
    deleteQueryBatch(
      db.collection("job_ads").where("posterId", "==", targetUserId),
      false
    ),
    db.collection("service_providers").doc(targetUserId).delete().catch(() => {}),
    db.collection("job_subscriptions").doc(targetUserId).delete().catch(() => {}),
    db
      .collection("provider_topic_subscriptions")
      .doc(targetUserId)
      .delete()
      .catch(() => {}),
  ]);

  await targetRef.delete().catch(() => {});

  // 3. حذف حساب Firebase Auth
  try {
    await admin.auth().deleteUser(targetUserId);
  } catch (err) {
    if (err.code !== "auth/user-not-found") {
      throw new HttpsError("internal", `تعذر حذف حساب المصادقة: ${err.message}`);
    }
  }

  return { success: true, userId: targetUserId };
});

// ════════════════════════════════════════════════════════════════════════════
// 13. نظام الإحالة الآمن على الخادم (getOrCreateReferralCode & redeemReferralCode — P0-6 Fixed)
// ════════════════════════════════════════════════════════════════════════════

function generateRandomReferralCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = "SAN";
  for (let i = 0; i < 6; i++) {
    out += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return out;
}

exports.getOrCreateReferralCode = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);
  const userRef = db.collection("users").doc(callerUid);
  const userSnap = await userRef.get();
  if (userSnap.exists && userSnap.data().referralCode) {
    return {
      referralCode: String(userSnap.data().referralCode),
      referralCount: Number(userSnap.data().referralCount || 0),
      bonusDaysEarned: Number(userSnap.data().referralBonusDaysEarned || 0),
    };
  }

  let code = generateRandomReferralCode();
  for (let i = 0; i < 8; i++) {
    const existing = await db
      .collection("users")
      .where("referralCode", "==", code)
      .limit(1)
      .get();
    if (existing.empty) break;
    code = generateRandomReferralCode();
  }

  await userRef.set(
    {
      referralCode: code,
      referralCount: 0,
      referralBonusDaysEarned: 0,
    },
    { merge: true }
  );

  return { referralCode: code, referralCount: 0, bonusDaysEarned: 0 };
});

exports.redeemReferralCode = onCall(async (request) => {
  const newUserId = assertAuthenticatedUser(request);
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

    const featuredUntilIso = new Date(
      Date.now() + 7 * 24 * 60 * 60 * 1000
    ).toISOString();

    tx.set(
      newUserRef,
      {
        referredBy: referrerId,
        referredByCode: rawCode,
        referredAt: admin.firestore.FieldValue.serverTimestamp(),
        referralAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
        featuredUntil: featuredUntilIso,
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
      referrerBonusDays: 7,
      newUserBenefit: "featured_7_days",
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

// ════════════════════════════════════════════════════════════════════════════
// 14. وكيل الذكاء الاصطناعي المحمي (askGemini — P0-8 Fixed)
// ════════════════════════════════════════════════════════════════════════════

const ALLOWED_GEMINI_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-1.5-flash",
]);

function sanitizeGeminiPayload(rawPayload) {
  if (!rawPayload || typeof rawPayload !== "object") {
    throw new HttpsError("invalid-argument", "بيانات الطلب غير صالحة.");
  }

  let totalChars = 0;
  const maxTotalChars = 6000;

  let systemInstruction = undefined;
  const rawSys =
    rawPayload.system_instruction || rawPayload.systemInstruction || null;
  if (rawSys && Array.isArray(rawSys.parts)) {
    const sysParts = [];
    for (const p of rawSys.parts.slice(0, 3)) {
      if (p && typeof p.text === "string") {
        const cleanText = p.text.slice(0, 2500);
        totalChars += cleanText.length;
        sysParts.push({ text: cleanText });
      }
    }
    if (sysParts.length > 0) {
      systemInstruction = { parts: sysParts };
    }
  }

  if (!Array.isArray(rawPayload.contents) || rawPayload.contents.length === 0) {
    throw new HttpsError("invalid-argument", "محتوى الرسالة مطلوب.");
  }

  const sanitizedContents = [];
  for (const item of rawPayload.contents.slice(-12)) {
    if (!item || !Array.isArray(item.parts)) continue;
    const role = item.role === "model" ? "model" : "user";
    const cleanParts = [];
    for (const p of item.parts.slice(0, 4)) {
      // ✅ P0-8 Fix: رفض أي صور أو ملفات مضمنة (inlineData / fileData) وقصر الطلب على النصوص
      if (p && (p.inlineData || p.inline_data || p.fileData || p.file_data)) {
        throw new HttpsError(
          "invalid-argument",
          "إرسال الصور أو الملفات غير مدعوم في المحادثة النصية."
        );
      }
      if (p && typeof p.text === "string" && p.text.trim()) {
        const sliced = p.text.trim().slice(0, 1500);
        totalChars += sliced.length;
        if (totalChars > maxTotalChars) {
          throw new HttpsError(
            "invalid-argument",
            "حجم النص يتجاوز الحد المسموح به."
          );
        }
        cleanParts.push({ text: sliced });
      }
    }
    if (cleanParts.length > 0) {
      sanitizedContents.push({ role, parts: cleanParts });
    }
  }

  if (sanitizedContents.length === 0) {
    throw new HttpsError("invalid-argument", "لا يوجد نص صالح في الطلب.");
  }

  return {
    ...(systemInstruction ? { system_instruction: systemInstruction } : {}),
    contents: sanitizedContents,
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 512,
      topK: 40,
      topP: 0.95,
    },
  };
}

exports.askGemini = onCall(async (request) => {
  const callerUid = assertAuthenticatedUser(request);

  // ✅ P0-8 Fix: تحديد معدل الاستخدام اليومي واللحظي لكل مستخدم على الخادم
  const rateRef = db.collection("gemini_rate_limits").doc(callerUid);
  const nowMs = Date.now();
  const todayKey = new Date(nowMs).toISOString().slice(0, 10);

  await db.runTransaction(async (tx) => {
    const rateSnap = await tx.get(rateRef);
    const rData = rateSnap.exists ? rateSnap.data() || {} : {};
    const lastMs = Number(rData.lastRequestMs || 0);
    if (nowMs - lastMs < 2000) {
      throw new HttpsError(
        "resource-exhausted",
        "يرجى الانتظار ثانيتين قبل إرسال رسالة أخرى."
      );
    }
    const countToday = rData.day === todayKey ? Number(rData.count || 0) : 0;
    if (countToday >= 40) {
      throw new HttpsError(
        "resource-exhausted",
        "لقد وصلت للحد الأقصى اليومي لاستخدام المساعد الذكي."
      );
    }
    tx.set(
      rateRef,
      {
        day: todayKey,
        count: countToday + 1,
        lastRequestMs: nowMs,
      },
      { merge: true }
    );
  });

  let apiKey = process.env.GEMINI_API_KEY || null;
  if (!apiKey || apiKey.trim() === "") {
    const secretDoc = await db.collection("settings_private").doc("gemini").get();
    apiKey = secretDoc.exists ? secretDoc.data().apiKey : null;
  }

  if (!apiKey || typeof apiKey !== "string" || apiKey.trim() === "") {
    throw new HttpsError("failed-precondition", "مفتاح الذكاء الاصطناعي غير مضبوط.");
  }

  const requestedModel = String(
    (request.data && request.data.model) || "gemini-2.5-flash"
  ).trim();
  const model = ALLOWED_GEMINI_MODELS.has(requestedModel)
    ? requestedModel
    : "gemini-2.5-flash";

  const safePayload = sanitizeGeminiPayload(request.data && request.data.payload);

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey.trim(),
    },
    body: JSON.stringify(safePayload),
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

// ════════════════════════════════════════════════════════════════════════════
// 15. جدولة إيقاف الاشتراكات المنتهية يومياً (expireSubscriptionsCron — P2 Fixed)
// ════════════════════════════════════════════════════════════════════════════

exports.expireSubscriptionsCron = onSchedule("every 24 hours", async () => {
  const now = admin.firestore.Timestamp.now();
  const expiredShopsSnap = await db
    .collection("shops")
    .where("subscriptionStatus", "==", "active")
    .where("subscriptionEndDate", "<", now)
    .get();

  if (expiredShopsSnap.empty) return;

  for (const shopDoc of expiredShopsSnap.docs) {
    const shopId = shopDoc.id;
    await shopDoc.ref.update({
      subscriptionStatus: "expired",
      isFeatured: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const [productsSnap, offersSnap] = await Promise.all([
      db
        .collection("products")
        .where("shopId", "==", shopId)
        .where("isShopHidden", "==", false)
        .get(),
      db
        .collection("offers")
        .where("shopId", "==", shopId)
        .where("isShopHidden", "==", false)
        .get(),
    ]);

    const toHide = [...productsSnap.docs, ...offersSnap.docs];
    for (let i = 0; i < toHide.length; i += 450) {
      const batch = db.batch();
      for (const d of toHide.slice(i, i + 450)) {
        batch.update(d.ref, { isShopHidden: true });
      }
      await batch.commit();
    }
  }
});
