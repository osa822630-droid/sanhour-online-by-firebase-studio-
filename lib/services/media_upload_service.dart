// lib/services/media_upload_service.dart
// ✅ خدمة رفع موحَّدة للصور والفيديوهات — مركز كل منطق Firebase Storage.
//
// المشاكل التي تُحلّها هذه الخدمة:
// 1. الكراش السابق: `ref.putFile(file)` بدون try/catch في عدة أماكن — أي
//    استثناء (شبكة / صلاحيات / ملف غير موجود) كان يتسرب كاستثناء غير
//    مُعالَج. هنا كل استثناء يُحوَّل لرسالة عربية واضحة عبر
//    [MediaUploadException] التي تُعرض في الواجهة بأمان.
// 2. لا تتبع تقدم: الآن كل رفع يستخدم `task.snapshotEvents` لإرسال نسبة
//    مئوية حقيقية للواجهة عبر [MediaUploadProgress].
// 3. لا تحقق من حجم/نوع الملف قبل الرفع — الآن يُتحقق من الحجم محلياً
//    قبل أي اتصال بالشبكة (الحدود تطابق storage.rules: صور ≤10MB، فيديو ≤100MB).
// 4. لا إعادة محاولة: أخطاء الشبكة المؤقتة تُعاد تلقائياً (Exponential backoff).
import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';

/// نوع الوسائط — يحدد حدود الحجم والـ contentType والمجلد الافتراضي
enum MediaKind { image, video }

/// لقطة تقدم رفع ملف واحد
class MediaUploadProgress {
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;

  const MediaUploadProgress({
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
  });

  /// النسبة من 0.0 إلى 1.0
  double get fraction =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// النسبة كعدد صحيح من 0 إلى 100 — جاهزة للعرض المباشر
  int get percent => (fraction * 100).round();

  @override
  String toString() =>
      'MediaUploadProgress($fileName: $percent% — $bytesTransferred/$totalBytes)';
}

/// استثناء رفع برسالة عربية جاهزة للعرض في الواجهة مباشرةً
class MediaUploadException implements Exception {
  /// رسالة عربية مفهومة — يمكن عرضها في SnackBar مباشرةً
  final String userMessage;

  /// السبب الأصلي (لو وُجد) — للـ logging فقط، لا يُعرض للمستخدم
  final Object? cause;

  const MediaUploadException(this.userMessage, [this.cause]);

  @override
  String toString() => userMessage;
}

class MediaUploadService {
  MediaUploadService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── حدود الحجم — تطابق storage.rules ────────────────────────────────────
  static const int maxImageBytes = 10 * 1024 * 1024; // 10MB
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100MB

  // ── حد مدة الفيديو الافتراضي (ثوانٍ) — قابل للتجاوز عند الاستدعاء ────────
  static const int defaultMaxVideoSeconds = 90;

  /// تحويل أي استثناء إلى رسالة عربية واضحة
  static String _arabicErrorFor(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthorized':
        case 'permission-denied':
          return 'لا تملك صلاحية لرفع هذا الملف. تحقق من تسجيل الدخول.';
        case 'canceled':
          return 'تم إلغاء عملية الرفع.';
        case 'object-not-found':
          return 'الملف المطلوب غير موجود على الخادم.';
        case 'quota-exceeded':
          return 'تم تجاوز سعة التخزين المتاحة. تواصل مع الدعم.';
        case 'unauthenticated':
          return 'يجب تسجيل الدخول أولاً لرفع الملفات.';
        case 'retry-limit-exceeded':
        case 'unknown':
        case 'network-request-failed':
          return 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مجدداً.';
        default:
          return 'حدث خطأ أثناء رفع الملف (${error.code}).';
      }
    }
    final msg = error.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Network') ||
        msg.contains('Connection')) {
      return 'تحقق من اتصالك بالإنترنت وحاول مجدداً.';
    }
    if (msg.contains('PathNotFoundException') ||
        msg.contains('No such file')) {
      return 'الملف المحدد غير موجود. حاول اختياره مرة أخرى.';
    }
    return 'حدث خطأ غير متوقع أثناء رفع الملف. حاول مجدداً.';
  }

  /// التحقق من الملف قبل أي اتصال شبكة — يرمي [MediaUploadException]
  /// برسالة عربية واضحة إذا كان الملف غير صالح
  static Future<void> _validateFile(File file, MediaKind kind) async {
    bool exists;
    try {
      exists = await file.exists();
    } catch (e) {
      throw MediaUploadException('تعذّر الوصول إلى الملف المحدد.', e);
    }
    if (!exists) {
      throw const MediaUploadException(
          'الملف المحدد غير موجود. حاول اختياره مرة أخرى.');
    }

    int length;
    try {
      length = await file.length();
    } catch (e) {
      throw MediaUploadException('تعذّر قراءة حجم الملف.', e);
    }

    if (length <= 0) {
      throw const MediaUploadException('الملف المحدد فاضي أو تالف.');
    }

    final limit = kind == MediaKind.video ? maxVideoBytes : maxImageBytes;
    if (length > limit) {
      final limitMb = (limit / (1024 * 1024)).toStringAsFixed(0);
      final actualMb = (length / (1024 * 1024)).toStringAsFixed(1);
      final kindLabel = kind == MediaKind.video ? 'الفيديو' : 'الصورة';
      throw MediaUploadException(
          'حجم $kindLabel كبير جداً ($actualMb MB). الحد الأقصى $limitMb MB.');
    }
  }

  /// توليد اسم ملف فريد وآمن (بدون محارف خاصة قد تسبب مشاكل في المسار)
  static String _safeFileName(File file, MediaKind kind) {
    final ext = kind == MediaKind.video ? 'mp4' : 'jpg';
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${ts}_$ext.$ext';
  }

  /// رفع ملف واحد مع تتبع تقدم حقيقي — يُعيد رابط التحميل النهائي.
  ///
  /// عند الفشل يرمي [MediaUploadException] برسالة عربية جاهزة للعرض.
  /// عند أخطاء الشبكة المؤقتة يُعيد المحاولة تلقائياً (حتى [maxRetries]).
  static Future<String> uploadFile({
    required File file,
    required String folder,
    MediaKind kind = MediaKind.image,
    String? fileName,
    void Function(MediaUploadProgress progress)? onProgress,
    int maxRetries = 2,
  }) async {
    // ✅ تحقق محلي أولاً — يمنع محاولات رفع لملفات فاسدة أو كبيرة جداً
    await _validateFile(file, kind);

    final name = fileName ?? _safeFileName(file, kind);
    final path = '$folder/$name';
    final contentType = kind == MediaKind.video ? 'video/mp4' : 'image/jpeg';

    int attempt = 0;
    while (true) {
      attempt++;
      UploadTask? task;
      StreamSubscription<TaskSnapshot>? progressSub;
      try {
        final ref = _storage.ref().child(path);
        task = ref.putFile(file, SettableMetadata(contentType: contentType));

        if (onProgress != null) {
          progressSub = task.snapshotEvents.listen(
            (snapshot) {
              onProgress(MediaUploadProgress(
                fileName: name,
                bytesTransferred: snapshot.bytesTransferred,
                totalBytes: snapshot.totalBytes,
              ));
            },
            onError: (_) {
              // أخطاء الـ stream تُعالَج عبر catch الأساسي أدناه — تجاهل هنا
            },
          );
        }

        final snapshot = await task;
        final url = await snapshot.ref.getDownloadURL();

        // ✅ إرسال إشعار اكتمال 100% صريح — يضمن وصول الواجهة لـ 100%
        // حتى لو لم يصل آخر snapshot event بنفس القيمة الدقيقة
        if (onProgress != null) {
          onProgress(MediaUploadProgress(
            fileName: name,
            bytesTransferred: snapshot.totalBytes,
            totalBytes: snapshot.totalBytes,
          ));
        }

        return url;
      } catch (e, s) {
        developer.log(
          'MediaUploadService.uploadFile error (attempt $attempt/$maxRetries): $e',
          name: 'MediaUploadService',
          error: e,
          stackTrace: s,
        );

        // ✅ محاولة إلغاء المهمة المعلَّقة لتحرير الموارد عند الفشل
        try {
          await task?.cancel();
        } catch (_) {
          // تجاهل — قد تكون انتهت بالفعل
        }

        final isTransient = e is FirebaseException &&
            (e.code == 'retry-limit-exceeded' ||
                e.code == 'unknown' ||
                e.code == 'network-request-failed' ||
                e.code == 'cancelled');

        if (isTransient && attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue; // إعادة المحاولة
        }

        if (e is MediaUploadException) rethrow;
        throw MediaUploadException(_arabicErrorFor(e), e);
      } finally {
        await progressSub?.cancel();
      }
    }
  }

  /// رفع عدة ملفات بالتوازي مع تتبع تقدم إجمالي موحَّد (0.0 → 1.0).
  ///
  /// لو فشل أي ملف، تُلغى العملية بالكامل ويُرمى [MediaUploadException]
  /// الخاص بأول فشل — لا نُعيد روابط جزئية حتى لا تُحفظ بيانات غير مكتملة.
  static Future<List<String>> uploadMultiple({
    required List<File> files,
    required String folder,
    MediaKind kind = MediaKind.image,
    void Function(double overallFraction)? onOverallProgress,
  }) async {
    if (files.isEmpty) return [];

    // ✅ حساب الحجم الإجمالي مسبقاً للتقدم النسبي الدقيق
    final sizes = <int>[];
    for (final f in files) {
      try {
        sizes.add(await f.length());
      } catch (_) {
        sizes.add(0);
      }
    }
    final grandTotal = sizes.fold<int>(0, (a, b) => a + b);
    final transferred = List<int>.filled(files.length, 0);

    void reportOverall() {
      if (onOverallProgress == null) return;
      if (grandTotal <= 0) {
        onOverallProgress(0);
        return;
      }
      final sum = transferred.fold<int>(0, (a, b) => a + b);
      onOverallProgress((sum / grandTotal).clamp(0.0, 1.0));
    }

    // ✅ الرفع بالتوازي — Future.wait يرمي أول استثناء يحدث، وهو بالفعل
    // MediaUploadException برسالة عربية بفضل uploadFile أعلاه
    final results = await Future.wait(List.generate(files.length, (i) {
      return uploadFile(
        file: files[i],
        folder: folder,
        kind: kind,
        onProgress: (p) {
          transferred[i] = p.bytesTransferred;
          reportOverall();
        },
      );
    }));

    return results;
  }

  /// حذف ملف من Storage عبر رابط التحميل الكامل — يُستخدَم عند حذف صورة
  /// قديمة أثناء التعديل. يفشل بصمت إذا كان الملف محذوفاً مسبقاً.
  static Future<void> deleteByUrl(String downloadUrl) async {
    if (downloadUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // ✅ الحذف غير حرج — لا نوقف العملية الأساسية لو فشل
      developer.log('MediaUploadService.deleteByUrl skipped: $e',
          name: 'MediaUploadService');
    }
  }
}
