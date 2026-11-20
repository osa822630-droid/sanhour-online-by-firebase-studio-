// lib/screens/excel_upload_screen.dart
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class ExcelUploadScreen extends StatefulWidget {
  final String shopId; // الرقم التعريفي للمحل (ضروري جداً)

  const ExcelUploadScreen({super.key, required this.shopId});

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  bool _isUploading = false;
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _uploadResult;

  // --- دوال اللوجيك (Logic) ---

  Future<void> _pickFile() async {
    try {
      setState(() {
        _uploadResult = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _selectedFileName = _selectedFile!.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر اختيار الملف، حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _uploadResult = null;
    });
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _selectedFile!.path == null) return;

    setState(() {
      _isUploading = true;
      _uploadResult = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await ApiService.importProductsExcel(
          widget.shopId, _selectedFile!.path!);

      if (!mounted) return;

      setState(() {
        _uploadResult = result;
        _isUploading = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadResult = {'success': false, 'message': 'فشل غير متوقع: $e'};
        _isUploading = false;
      });
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      // الصف الأول: عناوين الأعمدة
      sheet.appendRow([
        TextCellValue('اسم المنتج'),
        TextCellValue('السعر'),
        TextCellValue('الوصف'),
        TextCellValue('التصنيف'),
      ]);

      // صف تجريبي استرشادي
      sheet.appendRow([
        TextCellValue('طقم خروج رجالي'),
        DoubleCellValue(450.0),
        TextCellValue('قطن مصري ممتاز - جميع المقاسات متاحة'),
        TextCellValue('ملابس رجالي'),
      ]);

      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('تعذّر توليد ملف القالب');
      }

      final xfile = XFile.fromData(
        Uint8List.fromList(encoded),
        name: 'sanhour_products_template.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
          text: 'نموذج رفع المنتجات الجاهز لتطبيق سنهور أونلاين',
          subject: 'sanhour_products_template.xlsx',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر تصدير النموذج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- بناء الواجهة (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رفع منتجات (Excel)'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. كارت التعليمات
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('تعليمات الملف',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    _instructionItem('1', 'العمود الأول: اسم المنتج (مطلوب)'),
                    _instructionItem('2', 'العمود الثاني: السعر (أرقام فقط)'),
                    _instructionItem('3', 'العمود الثالث: الوصف (اختياري)'),
                    _instructionItem('4', 'العمود الرابع: التصنيف (اختياري)'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('تحميل نموذج Excel جاهز (.xlsx)'),
                        onPressed: _downloadTemplate,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. منطقة اختيار الملف
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                      width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.description
                              : Icons.cloud_upload_outlined,
                          size: 50,
                          color: _selectedFile != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            _selectedFileName ??
                                'اضغط هنا لاختيار ملف Excel (.xlsx)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedFile != null
                                  ? Colors.green[800]
                                  : Colors.grey[600],
                              fontWeight: _selectedFile != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFile != null && !_isUploading)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _clearFile,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. حالة الرفع والنتيجة
            if (_isUploading) ...[
              const LinearProgressIndicator(minHeight: 6),
              const SizedBox(height: 10),
              const Text('جاري قراءة الملف ورفع المنتجات... يرجى الانتظار',
                  style: TextStyle(color: Colors.grey)),
            ] else if (_uploadResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _uploadResult!['success']
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _uploadResult!['success']
                          ? Colors.green
                          : Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(
                      _uploadResult!['success']
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          _uploadResult!['success'] ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadResult!['message'],
                        style: TextStyle(
                          color: _uploadResult!['success']
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 4. زر التنفيذ
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_selectedFile == null || _isUploading)
                    ? null
                    : _uploadFile,
                icon: const Icon(Icons.save),
                label: const Text('رفع البيانات للقاعدة',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3D6B5E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instructionItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(num,
                    style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
