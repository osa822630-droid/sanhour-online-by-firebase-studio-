import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/shop.dart';

class MerchantServicesTab extends StatefulWidget {
  final Shop currentShop;
  const MerchantServicesTab({super.key, required this.currentShop});

  @override
  State<MerchantServicesTab> createState() => _MerchantServicesTabState();
}

class _MerchantServicesTabState extends State<MerchantServicesTab> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  // ✅ Fix #102: تخزين رسالة الخطأ لعرضها في الـ UI
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final data = await ApiService.getServices(shopId: widget.currentShop.id);
      if (mounted) {
        setState(() {
          _services = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ✅ Fix #102: تخزين رسالة الخطأ وعرضها
      if (mounted) {
        setState(() {
        _isLoading = false;
        _errorMsg = 'تعذّر تحميل الخدمات. اضغط للمحاولة مجدداً.';
      });
      }
    }
  }

  Future<void> _deleteService(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الخدمة'),
        content: const Text('هل أنت متأكد من حذف هذه الخدمة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.deleteService(id);
      _loadServices();
    }
  }

  void _showServiceDialog([Map<String, dynamic>? service]) {
    final nameCtrl = TextEditingController(text: service?['name'] ?? '');
    final descCtrl = TextEditingController(text: service?['description'] ?? '');
    final priceCtrl = TextEditingController(text: service?['price']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 20, left: 16, right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(service == null ? 'إضافة خدمة جديدة' : 'تعديل الخدمة',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الخدمة *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), foregroundColor: Colors.white),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final data = {
                    'shopId': widget.currentShop.id,
                    'ownerId': widget.currentShop.ownerId,
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                  };
                  if (service == null) {
                    await ApiService.addService(data);
                  } else {
                    await ApiService.updateService(service['id'], data);
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadServices();
                },
                child: Text(service == null ? 'إضافة' : 'حفظ التعديلات'),
              ),
            ),
          ],
        ),
      ),
    // ✅ Fix #62: dispose controllers بعد إغلاق الـ bottom sheet
    ).whenComplete(() {
      nameCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadServices,
        color: const Color(0xFF5E35B1),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            // ✅ Fix #102: عرض حالة الخطأ مع زر إعادة المحاولة
            : _errorMsg != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(_errorMsg!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadServices,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _services.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _services.length,
                        itemBuilder: (ctx, i) => _buildServiceCard(_services[i]),
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // To allow pull to refresh
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Center(
          child: Column(
            children: [
              Icon(Icons.miscellaneous_services_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('لا توجد خدمات مضافة حالياً', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final bool isVisible = service['isVisible'] ?? true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (service['description']?.isNotEmpty == true)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(service['description'], maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 8),
            Text('${service['price']} ج.م', style: const TextStyle(color: Color(0xFF5E35B1), fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: isVisible ? Colors.green : Colors.grey),
              onPressed: () async {
                await ApiService.updateService(service['id'], {'isVisible': !isVisible});
                _loadServices();
              },
            ),
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showServiceDialog(service)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteService(service['id'])),
          ],
        ),
      ),
    );
  }
}