// lib/widgets/favorites_button.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
            final auth = context.read<AuthProvider>();
            if (auth.isGuest) {
              _showGuestMessage(context);
              return;
            }
            await provider.toggleFavorite(item);
            if (!context.mounted) return;
            if (!isFav) _showSaveToCollectionSheet(context, item);
          },
          onLongPress: () {
            final auth = context.read<AuthProvider>();
            if (auth.isGuest) {
              _showGuestMessage(context);
              return;
            }
            _showSaveToCollectionSheet(context, item);
          },
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

  void _showGuestMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('سجّل دخولك أولاً لحفظ العناصر في المفضلة'),
        action: SnackBarAction(
          label: 'دخول',
          textColor: Colors.amber,
          onPressed: () => Navigator.pushNamed(context, '/login'),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: collections.isEmpty
                  ? const Center(child: Text('لا توجد قوائم بعد. أنشئ قائمة جديدة!'))
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
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              image: collection.items.isNotEmpty &&
                                      collection.items.last.imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          collection.items.last.imageUrl),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: collection.items.isEmpty ||
                                    collection.items.last.imageUrl.isEmpty
                                ? const Icon(Icons.bookmark_border, size: 20)
                                : null,
                          ),
                          value: isIncluded,
                          activeColor: Color(0xFF3D6B5E),
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
                    if (_newCollectionController.text.trim().isNotEmpty) {
                      await provider.createCollection(
                          _newCollectionController.text.trim(), false);
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
                  backgroundColor:
                      isDark ? Color(0xFF232927) : Colors.grey[100],
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerRight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
