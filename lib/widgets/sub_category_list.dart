// lib_widgets_sub_category_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanhour_online/providers/favorites_provider.dart';
import 'package:sanhour_online/screens/shop_detail_screen.dart';
import '../providers/shops_provider.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../models/category_model.dart';
import '../screens/detail_screen.dart';
import '../widgets/cached_image.dart';

class SubCategoryList extends StatefulWidget {
  final String mainCategory;
  final String subCategory;
  final Function(String) onSubSubCategorySelected;

  const SubCategoryList(
      {super.key,
      required this.mainCategory,
      required this.subCategory,
      required this.onSubSubCategorySelected});

  @override
  State<SubCategoryList> createState() => _SubCategoryListState();
}

class _SubCategoryListState extends State<SubCategoryList>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  late List<String> _currentSubCategories;

  @override
  void initState() {
    super.initState();
    _initializeTabs();
  }

  void _initializeTabs() {
    List<String>? subCats;
    if (widget.mainCategory != 'الكل') {
      final provider = Provider.of<ShopsProvider>(context, listen: false);
      try {
        final categoryModel = provider.categories.firstWhere(
          (c) => c.name == widget.mainCategory,
          orElse: () => CategoryModel(
              id: '',
              name: '',
              iconName: '',
              colorValue: 0,
              subCategories: [],
              subSubCategories: {}),
        );

        if (categoryModel.subCategories.isNotEmpty) {
          subCats = ['الكل', ...categoryModel.subCategories];
        }
      } catch (e) {
        // Fallback
      }
    }

    _currentSubCategories = subCats ?? ['الكل'];
    _tabController =
        TabController(length: _currentSubCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ Fix #73: إعادة بناء TabController عند تغيير الفئة الرئيسية
  @override
  void didUpdateWidget(covariant SubCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mainCategory != widget.mainCategory) {
      _tabController.dispose();
      _initializeTabs();
      setState(() {});
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
            tabs: _currentSubCategories.map((sub) => Tab(text: sub)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _currentSubCategories
                .map((sub) => _SubCategoryPage(
                      subCategory: sub,
                      mainCategory: widget.mainCategory,
                      type: widget.subCategory,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SubCategoryPage extends StatefulWidget {
  final String subCategory;
  final String mainCategory;
  final String type;

  const _SubCategoryPage({
    required this.subCategory,
    required this.mainCategory,
    required this.type,
  });

  @override
  State<_SubCategoryPage> createState() => _SubCategoryPageState();
}

class _SubCategoryPageState extends State<_SubCategoryPage>
    with AutomaticKeepAliveClientMixin {
  String _selectedSubSub = 'الكل';
  String _sortBy = 'default'; // ✅ فلتر الترتيب مضاف هنا لحل مشكلة undefined identifier

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<ShopsProvider>(context, listen: false);

     List<String>? subSubOptions;
    try {
      subSubOptions = provider.categories
          .firstWhere((c) => c.name == widget.mainCategory)
          .subSubCategories[widget.subCategory];
    } catch (e) {
      subSubOptions = null;
    }

    final bool hasFilters = subSubOptions != null && subSubOptions.isNotEmpty;

    return Column(
      children: [
        if (hasFilters)
          Container(
            height: 50,
            color: Colors.grey[50],
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: subSubOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filterName = subSubOptions![index];
                final isSelected = _selectedSubSub == filterName;

                return ChoiceChip(
                  label: Text(filterName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedSubSub = filterName);
                    }
                  },
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
        Expanded(
          child: Consumer<ShopsProvider>(
            builder: (context, shopsProvider, _) {
              final rawItems = _filterItems(shopsProvider);
              final items = _applySortToItems(rawItems);

              return Column(children: [
                // ✅ شريط الترتيب (سهمان متعاكسان)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(children: [
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (v) => setState(() => _sortBy = v),
                      icon: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.swap_vert, size: 18, color: Color(0xFF5E35B1)),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy == 'default' ? 'ترتيب' :
                          _sortBy == 'rating' ? 'التقييم' :
                          _sortBy == 'views' ? 'المشاهدات' : 'المفضلة',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF5E35B1)),
                        ),
                      ]),
                      itemBuilder: (_) => [
                        _menuItem('default',   '🔢 الافتراضي'),
                        _menuItem('rating',    '⭐ التقييم الأعلى'),
                        _menuItem('views',     '👁️ الأكثر مشاهدة'),
                        _menuItem('favorites', '❤️ الأكثر إضافة للمفضلة'),
                      ],
                    ),
                  ]),
                ),

                if (items.isEmpty)
                  Expanded(child: _buildEmptyState())
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: items.length,
                      cacheExtent: 500,
                      itemBuilder: (ctx, index) => _ListItem(item: items[index]),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            _selectedSubSub == 'الكل'
                ? 'لا توجد عناصر في "${widget.subCategory}"'
                : 'لا توجد نتائج لـ "$_selectedSubSub"',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        if (_sortBy == value)
          const Icon(Icons.check, color: Color(0xFF5E35B1), size: 16)
        else
          const SizedBox(width: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  List<dynamic> _applySortToItems(List<dynamic> items) {
    final sorted = List<dynamic>.from(items);
    switch (_sortBy) {
      case 'rating':
        sorted.sort((a, b) {
          final ra = a is Shop ? a.rating : (a is Product ? a.rating : 0.0);
          final rb = b is Shop ? b.rating : (b is Product ? b.rating : 0.0);
          return (rb).compareTo(ra);
        });
        break;
      case 'views':
        sorted.sort((a, b) {
          final va = a is Shop ? a.uniqueVisitors : (a is Product ? a.views : 0);
          final vb = b is Shop ? b.uniqueVisitors : (b is Product ? b.views : 0);
          return vb.compareTo(va);
        });
        break;
      case 'favorites':
        sorted.sort((a, b) {
          final fa = a is Shop ? a.favoriteCount : 0;
          final fb = b is Shop ? b.favoriteCount : 0;
          return fb.compareTo(fa);
        });
        break;
      default:
        break;
    }
    return sorted;
  }

  List<dynamic> _filterItems(ShopsProvider provider) {
    List<dynamic> baseList;
    switch (widget.type) {
      case 'shops':
        baseList = provider.shops;
        break;
      case 'products':
        baseList = provider.products;
        break;
      case 'offers':
        baseList = provider.offers;
        break;
      default:
        baseList = [];
    }

    return baseList.where((item) {
      String name = '';
      String cat = '';
      String desc = '';

      if (item is Shop) {
        name = item.name;
        cat = item.category;
        desc = item.description;
      } else if (item is Product) {
        name = item.name;
        cat = item.category;
        desc = item.description;
      } else if (item is Offer) {
        name = item.title;
      }

      if (widget.mainCategory != 'الكل' && widget.mainCategory != 'all') {
        if (item is Shop && item.category != widget.mainCategory) return false;
      }

      if (widget.subCategory != 'الكل') {
        if (!(name.contains(widget.subCategory) ||
            cat.contains(widget.subCategory) ||
            desc.contains(widget.subCategory))) {
          return false;
        }
      }

      if (_selectedSubSub != 'الكل') {
        if (!(name.contains(_selectedSubSub) ||
            desc.contains(_selectedSubSub) ||
            cat.contains(_selectedSubSub))) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

class _ListItem extends StatelessWidget {
  final dynamic item;

  const _ListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

    String imageUrl = '';
    String title = '';
    String subtitle = '';
    String itemType = '';

    if (item is Shop) {
      imageUrl = item.imageUrl;
      title = item.name;
      subtitle = '⭐ ${item.rating} • ${item.category}';
      const serviceCategories = [
        'Medical Services',
        'Educational Services',
        'Workshops & Crafts',
        'Legal Affairs',
        'General Services',
        'Event Planning',
        'Shipping & Logistics'
      ];
      bool isService = serviceCategories.any(
          (cat) => item.category.contains(cat) || item.category == cat);
      itemType = isService ? 'service' : 'shop';
    } else if (item is Product) {
      imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
      title = item.name;
      subtitle = '${item.price} ج.م';
      itemType = 'product';
    } else if (item is Offer) {
      imageUrl = item.imageUrl;
      title = item.title;
      subtitle = 'خصم ${item.discount}%';
      itemType = 'offer';
    }

    final bool isFav =
        itemType.isNotEmpty ? favoritesProvider.isFavorite(itemType, item.id) : false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: SizedBox(
            width: 60,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: imageUrl, fit: BoxFit.cover, width: 60, height: 60),
            ),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.grey),
            onPressed: () {
              favoritesProvider.toggleFavorite(item);
            },
          ),
          onTap: () {
            if (item is Shop) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(shop: item)));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
            }
          }),
    );
  }
}