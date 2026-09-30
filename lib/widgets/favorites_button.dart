// lib/widgets/favorites_button.dart
// ✅ Fix #60: dispose _newCollectionController في dispose()
// ✅ Fix #187: AnimatedScale مع spring curve للأيقونة
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

class FavoriteButton extends StatelessWidget {
  final dynamic item;
  final double iconSize;
  final Color activeColor;
  final Color inactiveColor;

  const FavoriteButton({
    super.key,
    required this.item,
    this.iconSize = 28,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        bool isFav = false;
        try {
          isFav = provider.isFavorite('shop', item.id) ||
              provider.isFavorite('product', item.id) ||
              provider.isFavorite('offer', item.id) ||
              provider.isFavorite('service', item.id);
        } catch (_) {}

        return GestureDetector(
          onTap: () async {
            await provider.toggleFavorite(item);
            if (!context.mounted) return;
            if (!isFav) _showSaveToCollectionSheet(context, item);
          },
          onLongPress: () => _showSaveToCollectionSheet(context, item),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: isFav ? 1.2 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? activeColor : inactiveColor,
              size: iconSize,
            ),
          ),
        );
      },
    );
  }

  void _showSaveToCollectionSheet(BuildContext context, dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddToCollectionSheet(item: item),
    );
  }
}

class _AddToCollectionSheet extends StatefulWidget {
  final dynamic item;
  const _AddToCollectionSheet({required this.item});

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  bool _isCreating = false;
  // ✅ Fix #60: controller مُعرَّف هنا ليُؤبَّد في dispose()
  final TextEditingController _newCollectionController = TextEditingController();

  @override
  void dispose() {
    _newCollectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FavoritesProvider>(context);
    final collections = provider.collections;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('حفظ في قائمة خاصة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: collections.isEmpty
                ? const Center(child: Text('لا توجد قوائم. أنشئ واحدة!'))
                : ListView.builder(
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      final isIncluded =
                          collection.items.any((i) => i.id == widget.item.id);
                      return CheckboxListTile(
                        title: Text(collection.name),
                        subtitle: Text('${collection.items.length} عنصر'),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            image: collection.items.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                        collection.items.last.imageUrl),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: collection.items.isEmpty
                              ? const Icon(Icons.bookmark_border, size: 20)
                              : null,
                        ),
                        value: isIncluded,
                        activeColor: Theme.of(context).primaryColor,
                        onChanged: (val) async {
                          if (val == true) {
                            await provider.addItemToCollection(
                                collection.id, widget.item);
                          } else {
                            try {
                              final itemToRemove = collection.items
                                  .firstWhere((i) => i.id == widget.item.id);
                              await provider.removeItemFromCollection(
                                  collection.id, itemToRemove);
                            } catch (_) {}
                          }
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          if (_isCreating)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newCollectionController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'اسم القائمة (مثلاً: تجهيزات العيد)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () async {
                  if (_newCollectionController.text.isNotEmpty) {
                    await provider.createCollection(
                        _newCollectionController.text, false);
                    _newCollectionController.clear();
                    if (mounted) setState(() => _isCreating = false);
                  }
                },
              ),
            ])
          else
            ElevatedButton.icon(
              onPressed: () => setState(() => _isCreating = true),
              icon: const Icon(Icons.add),
              label: const Text('قائمة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                alignment: Alignment.centerLeft,
              ),
            ),
        ],
      ),
    );
  }
}
