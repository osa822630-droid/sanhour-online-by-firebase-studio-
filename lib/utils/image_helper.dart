// lib/utils/image_helper.dart
// ✅ إصلاح الكراش: ImageCropper مُغلَّف بـ try-catch مع Fallback للصورة الخام
// السبب الجذري: image_cropper تحتاج إعداداً خاصاً في AndroidManifest (FileProvider)
// الحل: إذا فشل القص، نعيد الصورة الخام بدلاً من إيقاف التطبيق
//
// ✅ نظام الميديا الاحترافي — إضافات هذا الإصدار:
// - pickVideo(): اختيار فيديو مع تحقق من الحجم والمدة قبل الإرجاع (لا كراش
//   عند اختيار فيديو ضخم — رسالة عربية واضحة بدلاً من ذلك).
// - getVideoDuration(): قراءة مدة الفيديو بأمان (يُؤبِّد الـ controller دائماً).
// - formatDuration(): تنسيق المدة كـ "م:ث" للعرض في الواجهة.
// - showMediaSourcePicker(): نافذة اختيار موحَّدة (صورة/فيديو × كاميرا/معرض).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:video_player/video_player.dart';
import '../services/media_upload_service.dart';

/// نسب الأبعاد لكل نوع محتوى
enum ImageRatio {
  square, // 1:1  — شعار المحل (لوجو)
  cover, // 3:2  — غلاف المحل (مثل غلاف فيسبوك)
  wideAd, // 16:9 — إعلان الرئيسية (أفقي)
  tallAd, // 9:16 — إعلان شاشة البدء والإعلانات (طولي)
  reel, // 9:16 — فيديو ريلز
  wide, // 16:9 — generic wide
  portrait, // 3:4
  free,
}

/// نتيجة اختيار مصدر الوسائط من [ImageHelper.showMediaSourcePicker]
class MediaPickChoice {
  final ImageSource source;
  final bool isVideo;
  const MediaPickChoice({required this.source, required this.isVideo});
}

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  // ════════════════════════════════════════════════════════════════════
  // ── الصور ───────────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════

  /// اختيار صورة مع قص — يعود بالصورة الخام في حالة فشل القص
  static Future<File?> pickAndCrop({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    ImageRatio ratio = ImageRatio.square,
    int imageQuality = 85,
    String? hint,
  }) async {
    if (hint != null && context.mounted) {
      await _showHintSnackbar(context, hint);
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth:
            ratio == ImageRatio.tallAd || ratio == ImageRatio.reel ? 1080 : 1400,
        maxHeight:
            ratio == ImageRatio.tallAd || ratio == ImageRatio.reel ? 1920 : 1400,
      );
      if (picked == null) return null;

      final rawFile = File(picked.path);

      // ✅ محاولة القص — إذا فشلت (مثلاً FileProvider غير مُعدّ) نعود بالصورة الخام
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: _getAspectRatio(ratio),
          compressQuality: imageQuality,
          compressFormat: ImageCompressFormat.jpg,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: _getTitle(ratio),
              toolbarColor: const Color(0xFF5E35B1),
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: const Color(0xFF5E35B1),
              initAspectRatio: _getInitAspectRatio(ratio),
              lockAspectRatio: ratio != ImageRatio.free,
              hideBottomControls: false,
              statusBarLight: false,
            ),
            IOSUiSettings(
              title: _getTitle(ratio),
              cancelButtonTitle: 'إلغاء',
              doneButtonTitle: 'تم',
              aspectRatioLockEnabled: ratio != ImageRatio.free,
              resetAspectRatioEnabled: ratio == ImageRatio.free,
            ),
          ],
        );

        if (cropped != null) return File(cropped.path);
        // المستخدم ألغى القص — نعود بالصورة الخام
        return rawFile;
      } catch (cropError) {
        // ✅ fallback: القص فشل بسبب إعداد AndroidManifest أو مشكلة Platform
        debugPrint('ImageCropper fallback: $cropError');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذّر فتح أداة القص، تم استخدام الصورة كاملة'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return rawFile; // ← الإصلاح: نعود بالصورة بدون قص
      }
    } catch (e) {
      debugPrint('ImageHelper.pickAndCrop error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر تحديد الصورة. تحقق من الصلاحيات.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// اختيار صورة بدون قص (أسرع)
  static Future<File?> pickOnly({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: 1400,
      );
      return picked != null ? File(picked.path) : null;
    } catch (e) {
      debugPrint('ImageHelper.pickOnly error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر تحديد الصورة.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // ── الفيديو ──────────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════

  /// اختيار فيديو مع تحقق كامل من الحجم والمدة قبل الإرجاع.
  ///
  /// لو تجاوز الفيديو الحدود المسموحة (الحجم من [MediaUploadService]،
  /// والمدة من [maxDurationSeconds])، يُعرَض تنبيه عربي واضح ويُعاد `null`
  /// بدلاً من تمرير ملف غير صالح للرفع (وهو ما كان يسبب الكراش سابقاً).
  static Future<File?> pickVideo({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    int maxDurationSeconds = MediaUploadService.defaultMaxVideoSeconds,
  }) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: maxDurationSeconds),
      );
      if (picked == null) return null;

      final file = File(picked.path);

      // ✅ تحقق من وجود الملف فعلياً (بعض المنصات تُعيد مساراً غير صالح
      // في حالات نادرة مثل إلغاء الكاميرا أثناء المعالجة)
      if (!await file.exists()) {
        if (context.mounted) {
          _showErrorSnackbar(context, 'تعذّر الوصول إلى الفيديو المحدد.');
        }
        return null;
      }

      // ✅ تحقق من الحجم محلياً قبل أي محاولة رفع
      final length = await file.length();
      if (length <= 0) {
        if (context.mounted) {
          _showErrorSnackbar(context, 'الفيديو المحدد فاضي أو تالف.');
        }
        return null;
      }
      if (length > MediaUploadService.maxVideoBytes) {
        final limitMb =
            (MediaUploadService.maxVideoBytes / (1024 * 1024)).toStringAsFixed(0);
        final actualMb = (length / (1024 * 1024)).toStringAsFixed(1);
        if (context.mounted) {
          _showErrorSnackbar(
            context,
            'حجم الفيديو كبير جداً ($actualMb MB). الحد الأقصى $limitMb MB.',
          );
        }
        return null;
      }

      // ✅ تحقق احتياطي من المدة — maxDuration في image_picker قد لا يُطبَّق
      // على كل المنصات بنفس الصرامة، فنتحقق بأنفسنا أيضاً
      final duration = await getVideoDuration(file);
      if (duration != null && duration.inSeconds > maxDurationSeconds + 2) {
        if (context.mounted) {
          _showErrorSnackbar(
            context,
            'مدة الفيديو طويلة جداً (${formatDuration(duration)}). '
            'الحد الأقصى ${formatDuration(Duration(seconds: maxDurationSeconds))}.',
          );
        }
        return null;
      }

      return file;
    } catch (e) {
      debugPrint('ImageHelper.pickVideo error: $e');
      if (context.mounted) {
        _showErrorSnackbar(context, 'تعذّر تحديد الفيديو. تحقق من الصلاحيات.');
      }
      return null;
    }
  }

  /// قراءة مدة فيديو من ملف محلي بأمان — يُؤبِّد الـ controller دائماً
  /// حتى لو فشلت التهيئة، لمنع تسريب موارد المُشغِّل (memory leak).
  static Future<Duration?> getVideoDuration(File file) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize().timeout(const Duration(seconds: 8));
      return controller.value.duration;
    } catch (e) {
      debugPrint('ImageHelper.getVideoDuration error: $e');
      return null;
    } finally {
      // ✅ التأبيد في finally يضمن التحرير دائماً — نجح التهيئة أو فشلت
      await controller?.dispose();
    }
  }

  /// تنسيق مدة لعرضها كـ "م:ث" مثل "1:24"
  static String formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════════════════
  // ── نوافذ اختيار المصدر ─────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════

  /// اختيار مصدر الصورة (كاميرا أو معرض) — للسياقات التي تقبل صوراً فقط
  static Future<ImageSource?> showSourcePicker(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر مصدر الصورة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _sourceButton(
                    context,
                    icon: Icons.camera_alt,
                    label: 'الكاميرا',
                    // ✅ Item #9: النافذة معرّفة showModalBottomSheet<ImageSource>
                    // فلازم الزرار يرجّع ImageSource (مش MediaPickChoice).
                    result: ImageSource.camera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceButton(
                    context,
                    icon: Icons.photo_library,
                    label: 'المعرض',
                    result: ImageSource.gallery,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// نافذة اختيار موحَّدة للصور والفيديو معاً.
  ///
  /// تُعيد [MediaPickChoice] تحدد المصدر (كاميرا/معرض) ونوع الوسيط
  /// (صورة/فيديو)، أو `null` إذا أُلغيت. تُستخدَم في أي مكان يحتاج رفع
  /// صور وفيديوهات معاً (مثل معرض وسائط المحل).
  static Future<MediaPickChoice?> showMediaSourcePicker(
    BuildContext context, {
    bool allowVideo = true,
  }) async {
    return showModalBottomSheet<MediaPickChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'إضافة صورة',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E35B1)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _sourceButton(
                    context,
                    icon: Icons.camera_alt,
                    label: 'كاميرا',
                    result: const MediaPickChoice(
                        source: ImageSource.camera, isVideo: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceButton(
                    context,
                    icon: Icons.photo_library,
                    label: 'المعرض',
                    result: const MediaPickChoice(
                        source: ImageSource.gallery, isVideo: false),
                  ),
                ),
              ]),
              if (allowVideo) ...[
                const SizedBox(height: 18),
                const Text(
                  'إضافة فيديو',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E35B1)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _sourceButton(
                      context,
                      icon: Icons.videocam_outlined,
                      label: 'تسجيل فيديو',
                      result: const MediaPickChoice(
                          source: ImageSource.camera, isVideo: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceButton(
                      context,
                      icon: Icons.video_library_outlined,
                      label: 'من المعرض',
                      result: const MediaPickChoice(
                          source: ImageSource.gallery, isVideo: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'الحد الأقصى للفيديو: ${MediaUploadService.defaultMaxVideoSeconds} ثانية، '
                      '${(MediaUploadService.maxVideoBytes / (1024 * 1024)).toStringAsFixed(0)} MB',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sourceButton(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required dynamic result,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF5E35B1).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF5E35B1), size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF5E35B1), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  static Future<void> _showHintSnackbar(BuildContext ctx, String hint) async {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(hint, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: const Color(0xFF5E35B1),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    await Future.delayed(const Duration(milliseconds: 400));
  }

  static void _showErrorSnackbar(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ════════════════════════════════════════════════════════════════════
  // ── أبعاد القص ───────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════

  static CropAspectRatio? _getAspectRatio(ImageRatio r) {
    switch (r) {
      case ImageRatio.square:
        return const CropAspectRatio(ratioX: 1, ratioY: 1);
      case ImageRatio.cover:
        return const CropAspectRatio(ratioX: 3, ratioY: 2);
      case ImageRatio.wideAd:
      case ImageRatio.wide:
        return const CropAspectRatio(ratioX: 16, ratioY: 9);
      case ImageRatio.tallAd:
      case ImageRatio.reel:
        return const CropAspectRatio(ratioX: 9, ratioY: 16);
      case ImageRatio.portrait:
        return const CropAspectRatio(ratioX: 3, ratioY: 4);
      case ImageRatio.free:
        return null;
    }
  }

  static CropAspectRatioPreset _getInitAspectRatio(ImageRatio r) {
    switch (r) {
      case ImageRatio.square:
        return CropAspectRatioPreset.square;
      case ImageRatio.cover:
      case ImageRatio.wideAd:
      case ImageRatio.wide:
        return CropAspectRatioPreset.ratio16x9;
      default:
        return CropAspectRatioPreset.original;
    }
  }

  static String _getTitle(ImageRatio r) {
    switch (r) {
      case ImageRatio.square:
        return 'قص اللوجو (1:1)';
      case ImageRatio.cover:
        return 'قص صورة الغلاف (3:2)';
      case ImageRatio.wideAd:
        return 'قص إعلان الرئيسية (16:9)';
      case ImageRatio.tallAd:
        return 'قص إعلان البدء (9:16)';
      case ImageRatio.reel:
        return 'قص مقطع ريلز (9:16)';
      case ImageRatio.wide:
        return 'قص الصورة (16:9)';
      case ImageRatio.portrait:
        return 'قص الصورة (3:4)';
      case ImageRatio.free:
        return 'قص الصورة';
    }
  }
}
