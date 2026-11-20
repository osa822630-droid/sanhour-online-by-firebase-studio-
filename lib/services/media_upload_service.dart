// lib/services/media_upload_service.dart
// ✅ خدمة رفع موحَّدة للصور والفيديوهات — مركز كل منطق Firebase Storage.
import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
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
  final String userMessage;
  final Object? cause;

  const MediaUploadException(this.userMessage, [this.cause]);

  @override
  String toString() => userMessage;
}

class MediaUploadService {
  MediaUploadService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static String? _fallbackBucket;

  // ── حدود الحجم — تطابق storage.rules ────────────────────────────────────
  static const int maxImageBytes = 10 * 1024 * 1024; // 10MB
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100MB
  static const int defaultMaxVideoSeconds = 90;

  static String _arabicErrorFor(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthorized':
        case 'permission-denied':
          return 'لا تملك صلاحية لرفع هذا الملف. تحقق من تسجيل الدخول.';
        case 'canceled':
          return 'تم إلغاء عملية الرفع.';
        case 'object-not-found':
          return 'تعذّر الوصول لمساحة تخزين الصور (تأكد من تفعيل Firebase Storage ومطابقة اسم الباكيت في لوحة Firebase).';
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

  static String _safeFileName(File file, MediaKind kind) {
    final ext = kind == MediaKind.video ? 'mp4' : 'jpg';
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${ts}_$ext.$ext';
  }

  /// دالة مساعدة مختصرة لرفع صورة واحدة مع نسبة تقدم مباشرة (0.0 → 1.0)
  static Future<String?> uploadImageWithProgress({
    required File file,
    required String folder,
    void Function(double fraction)? onProgress,
  }) async {
    return uploadFile(
      file: file,
      folder: folder,
      kind: MediaKind.image,
      onProgress: onProgress == null ? null : (p) => onProgress(p.fraction),
    );
  }

  static Future<String> uploadFile({
    required File file,
    required String folder,
    MediaKind kind = MediaKind.image,
    String? fileName,
    void Function(MediaUploadProgress progress)? onProgress,
    int maxRetries = 2,
  }) async {
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
        final activeStorage = (attempt > 1 && _fallbackBucket != null)
            ? FirebaseStorage.instanceFor(bucket: _fallbackBucket!)
            : _storage;
        final ref = activeStorage.ref().child(path);
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: contentType,
            customMetadata: uid.isNotEmpty ? {'ownerId': uid} : null,
          ),
        );
        task = uploadTask;

        if (onProgress != null) {
          progressSub = uploadTask.snapshotEvents.listen(
            (snapshot) {
              onProgress(MediaUploadProgress(
                fileName: name,
                bytesTransferred: snapshot.bytesTransferred,
                totalBytes: snapshot.totalBytes,
              ));
            },
            onError: (_) {},
          );
        }

        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            uploadTask.cancel();
            throw const MediaUploadException(
              'انتهت مهلة رفع الصورة. تحقق من اتصال الإنترنت أو قواعد التخزين وحاول مجدداً.',
            );
          },
        );
        final url = await snapshot.ref.getDownloadURL().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw const MediaUploadException(
            'انتهت مهلة استلام رابط الصورة. حاول مجدداً.',
          ),
        );

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

        try {
          await task?.cancel();
        } catch (_) {}

        if (e is FirebaseException &&
            e.code == 'object-not-found' &&
            attempt == 1 &&
            _storage.bucket.endsWith('.firebasestorage.app')) {
          final projectPrefix =
              _storage.bucket.replaceAll('.firebasestorage.app', '');
          _fallbackBucket = 'gs://$projectPrefix.appspot.com';
          continue;
        }

        final isTransient = e is FirebaseException &&
            (e.code == 'retry-limit-exceeded' ||
                e.code == 'unknown' ||
                e.code == 'network-request-failed' ||
                e.code == 'cancelled');

        if (isTransient && attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }

        if (e is MediaUploadException) rethrow;
        throw MediaUploadException(_arabicErrorFor(e), e);
      } finally {
        await progressSub?.cancel();
      }
    }
  }

  static Future<List<String>> uploadMultiple({
    required List<File> files,
    required String folder,
    MediaKind kind = MediaKind.image,
    void Function(double overallFraction)? onOverallProgress,
  }) async {
    if (files.isEmpty) return [];

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

  static Future<void> deleteByUrl(String downloadUrl) async {
    if (downloadUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      developer.log('MediaUploadService.deleteByUrl skipped: $e',
          name: 'MediaUploadService');
    }
  }
}
