// lib/models/category_model.dart
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconName; // هنخزن اسم الأيقونة "fastfood"
  final int colorValue; // هنخزن اللون كرقم (0xFF...)
  final List<String> subCategories;
  final Map<String, List<String>> subSubCategories; // الفئات الدقيقة

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    required this.subCategories,
    required this.subSubCategories,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorValue': colorValue,
      'subCategories': subCategories,
      'subSubCategories': subSubCategories,
    };
  }

  Map<String, dynamic> toMapWithId() {
    final map = toMap();
    map['id'] = id;
    return map;
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'category',
      colorValue: map['colorValue'] ?? 0xFF2196F3,
      subCategories: List<String>.from(map['subCategories'] ?? []),
      subSubCategories: Map<String, List<String>>.from(
        (map['subSubCategories'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
    );
  }

  // ✅ مكتبة الأيقونات الموسّعة — 60+ أيقونة لجميع فئات المتجر
  static IconData getIconData(String name) {
    const map = <String, IconData>{
      // 🍔 طعام ومشروبات
      'fastfood': Icons.fastfood,
      'restaurant': Icons.restaurant,
      'local_cafe': Icons.local_cafe,
      'bakery': Icons.bakery_dining,
      'cake': Icons.cake,
      'local_pizza': Icons.local_pizza,
      'icecream': Icons.icecream,
      'rice_bowl': Icons.rice_bowl,
      'lunch_dining': Icons.lunch_dining,
      'set_meal': Icons.set_meal,
      // 🛒 تسوق وملابس
      'shopping_cart': Icons.shopping_cart,
      'checkroom': Icons.checkroom,
      'storefront': Icons.storefront,
      'diamond': Icons.diamond,
      'watch': Icons.watch,
      'dry_cleaning': Icons.dry_cleaning,
      'style': Icons.style,
      // 🏥 طب وصحة
      'local_hospital': Icons.local_hospital,
      'medical_services': Icons.medical_services,
      'medication': Icons.medication,
      'health_and_safety': Icons.health_and_safety,
      'dentistry': Icons.medical_services, // Fallback as dentistry might not be in all SDK versions
      'vaccines': Icons.vaccines,
      'psychology': Icons.psychology,
      'spa': Icons.spa,
      // 📚 تعليم
      'school': Icons.school,
      'menu_book': Icons.menu_book,
      'science': Icons.science,
      'calculate': Icons.calculate,
      'laptop': Icons.laptop,
      // 🔨 خدمات وصيانة
      'handyman': Icons.handyman,
      'build': Icons.build,
      'electrical_services': Icons.electrical_services,
      'plumbing': Icons.plumbing,
      'cleaning_services': Icons.cleaning_services,
      'hvac': Icons.hvac,
      // 🏠 عقارات وديكور
      'home_work': Icons.home_work,
      'chair': Icons.chair,
      'weekend': Icons.weekend,
      'roofing': Icons.roofing,
      'real_estate_agent': Icons.real_estate_agent,
      // 🚗 سيارات
      'directions_car': Icons.directions_car,
      'local_gas_station': Icons.local_gas_station,
      'car_repair': Icons.car_repair,
      'two_wheeler': Icons.two_wheeler,
      // 📱 إلكترونيات
      'phone_android': Icons.phone_android,
      'computer': Icons.computer,
      'camera_alt': Icons.camera_alt,
      'headphones': Icons.headphones,
      'tv': Icons.tv,
      'print': Icons.print,
      // ⚖️ قانون ومال
      'gavel': Icons.gavel,
      'account_balance': Icons.account_balance,
      'payments': Icons.payments,
      // 🎨 ترفيه وفنون
      'sports_soccer': Icons.sports_soccer,
      'sports_esports': Icons.sports_esports,
      'fitness_center': Icons.fitness_center,
      'music_note': Icons.music_note,
      'palette': Icons.palette,
      'local_movies': Icons.local_movies,
      // 🌿 متنوع
      'local_florist': Icons.local_florist,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
      'volunteer_activism': Icons.volunteer_activism,
      'category': Icons.category,
    };
    return map[name] ?? Icons.category;
  }

  /// قائمة كل الأيقونات للعرض في picker الأدمن
  static const List<Map<String, String>> iconList = [
    // طعام
    {'name': 'fastfood',    'label': '🍔 وجبات سريعة'},
    {'name': 'restaurant',  'label': '🍽️ مطعم'},
    {'name': 'local_cafe',  'label': '☕ كافيه'},
    {'name': 'bakery',      'label': '🥐 مخبوزات'},
    {'name': 'cake',        'label': '🎂 حلويات'},
    {'name': 'local_pizza', 'label': '🍕 بيتزا'},
    {'name': 'icecream',    'label': '🍦 آيس كريم'},
    {'name': 'rice_bowl',   'label': '🍚 أرز'},
    {'name': 'lunch_dining','label': '🥪 ساندوتشات'},
    {'name': 'set_meal',    'label': '🍱 وجبات'},
    // تسوق
    {'name': 'shopping_cart','label': '🛒 تسوق'},
    {'name': 'checkroom',   'label': '👗 ملابس'},
    {'name': 'storefront',  'label': '🏪 متجر'},
    {'name': 'diamond',     'label': '💎 مجوهرات'},
    {'name': 'watch',       'label': '⌚ ساعات'},
    {'name': 'dry_cleaning','label': '👔 تنظيف ملابس'},
    {'name': 'style',       'label': '✂️ موضة'},
    // طب
    {'name': 'local_hospital','label': '🏥 مستشفى'},
    {'name': 'medical_services','label': '💊 خدمات طبية'},
    {'name': 'medication',  'label': '💉 أدوية'},
    {'name': 'health_and_safety','label': '🩺 صحة'},
    {'name': 'dentistry',   'label': '🦷 أسنان'},
    {'name': 'spa',         'label': '🧖 سبا'},
    // تعليم
    {'name': 'school',      'label': '🏫 مدرسة'},
    {'name': 'menu_book',   'label': '📚 كتب'},
    {'name': 'science',     'label': '🔬 علوم'},
    {'name': 'calculate',   'label': '🧮 رياضيات'},
    {'name': 'laptop',      'label': '💻 تقنية'},
    // صيانة
    {'name': 'handyman',    'label': '🔧 صيانة'},
    {'name': 'build',       'label': '🛠️ أعمال'},
    {'name': 'electrical_services','label': '⚡ كهرباء'},
    {'name': 'plumbing',    'label': '🚿 سباكة'},
    {'name': 'cleaning_services','label': '🧹 تنظيف'},
    // عقارات
    {'name': 'home_work',   'label': '🏠 عقارات'},
    {'name': 'chair',       'label': '🛋️ أثاث'},
    {'name': 'weekend',     'label': '🛏️ نوم'},
    {'name': 'real_estate_agent','label': '🏡 وساطة'},
    // سيارات
    {'name': 'directions_car','label': '🚗 سيارات'},
    {'name': 'local_gas_station','label': '⛽ وقود'},
    {'name': 'car_repair',  'label': '🔩 إصلاح سيارات'},
    {'name': 'two_wheeler', 'label': '🛵 موتوسيكل'},
    // إلكترونيات
    {'name': 'phone_android','label': '📱 موبايل'},
    {'name': 'computer',    'label': '🖥️ كمبيوتر'},
    {'name': 'camera_alt',  'label': '📷 كاميرا'},
    {'name': 'headphones',  'label': '🎧 سماعات'},
    {'name': 'tv',          'label': '📺 تلفزيون'},
    // قانون ومال
    {'name': 'gavel',       'label': '⚖️ قانون'},
    {'name': 'account_balance','label': '🏦 بنوك'},
    {'name': 'payments',    'label': '💳 مدفوعات'},
    // ترفيه
    {'name': 'sports_soccer','label': '⚽ رياضة'},
    {'name': 'fitness_center','label': '🏋️ جيم'},
    {'name': 'music_note',  'label': '🎵 موسيقى'},
    {'name': 'palette',     'label': '🎨 فنون'},
    // متنوع
    {'name': 'local_florist','label': '🌸 ورود'},
    {'name': 'pets',         'label': '🐾 حيوانات'},
    {'name': 'child_care',  'label': '👶 أطفال'},
    {'name': 'category',    'label': '📦 عام'},
  ];
}