// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanhour_online/models/ad_model.dart';
import 'package:sanhour_online/models/job_ad_model.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/service_request_model.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/user.dart';
import 'package:sanhour_online/services/deep_link_service.dart';
import 'package:sanhour_online/services/subscription_service.dart';
import 'package:sanhour_online/utils/constants.dart';
import 'package:sanhour_online/widgets/empty_state_widget.dart';
import 'package:sanhour_online/widgets/error_state_widget.dart';
import 'package:sanhour_online/widgets/stat_card.dart';

void main() {
  group('Models, Security & Business Logic Unit Tests', () {
    test('AppUser roles distinguish super_admin vs admin and default moderator permissions to false', () {
      final superAdmin = AppUser.fromMap({
        'id': 'sa1',
        'name': 'سوبر أدمن',
        'username': 'superadmin',
        'email': 'sa1@users.sanhour.online',
        'phone': '+201008908728',
        'userType': 'super_admin',
      });
      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.isAdmin, isTrue);
      expect(superAdmin.canViewFinancialStats, isTrue);

      final regularAdmin = AppUser.fromMap({
        'id': 'a1',
        'name': 'أدمن',
        'username': 'admin1',
        'email': 'a1@users.sanhour.online',
        'phone': '+201000000001',
        'userType': 'admin',
      });
      expect(regularAdmin.isSuperAdmin, isFalse);
      expect(regularAdmin.isAdmin, isTrue);

      final moderatorEmptyPerms = AppUser.fromMap({
        'id': 'm1',
        'name': 'مشرف',
        'username': 'mod1',
        'email': 'm1@users.sanhour.online',
        'phone': '+201000000002',
        'userType': 'moderator',
        'moderatorPermissions': <String, dynamic>{},
      });
      expect(moderatorEmptyPerms.isModerator, isTrue);
      expect(moderatorEmptyPerms.isAdmin, isFalse);
      expect(moderatorEmptyPerms.moderatorPermissions?.manageShops, isFalse);
      expect(moderatorEmptyPerms.moderatorPermissions?.manageUsers, isFalse);
      expect(moderatorEmptyPerms.moderatorPermissions?.manageSettings, isFalse);

      final owner = AppUser.fromMap({
        'id': 'u1',
        'name': 'أسامة',
        'username': 'osama',
        'email': 'u1@users.sanhour.online',
        'phone': '+201008908728',
        'userType': 'merchant',
        'shopRole': 'owner',
      });
      expect(owner.canViewShopStats, isTrue);
      expect(owner.canManageSubscription, isTrue);

      final partner = AppUser.fromMap({
        'id': 'u2',
        'name': 'شريك',
        'username': 'partner1',
        'email': 'u2@users.sanhour.online',
        'phone': '+201112223334',
        'userType': 'merchant',
        'shopRole': 'partner',
        'linkedShopId': 'shop_1',
      });
      expect(partner.canViewShopStats, isTrue);
      expect(partner.canManageSubscription, isFalse);
      expect(partner.linkedShopId, equals('shop_1'));

      final worker = AppUser.fromMap({
        'id': 'u3',
        'name': 'عامل',
        'username': 'worker1',
        'email': 'u3@users.sanhour.online',
        'phone': '+201234567890',
        'userType': 'merchant',
        'shopRole': 'worker',
        'linkedShopId': 'shop_1',
      });
      expect(worker.canViewShopStats, isFalse);
      expect(worker.canManageSubscription, isFalse);
    });

    test('AppConstants phone normalization handles Arabic digits and E.164', () {
      expect(
        AppConstants.arabicToEnglishDigits('٠١٠٠٨٩٠٨٧٢٨'),
        equals('01008908728'),
      );
      expect(
        AppConstants.normalizePhoneToE164('٠١٠٠٨٩٠٨٧٢٨'),
        equals('+201008908728'),
      );
      final candidates = AppConstants.phoneLookupCandidates('01008908728');
      expect(candidates, contains('+201008908728'));
      expect(candidates, contains('01008908728'));
    });

    test('AdModel parses clickCount, externalUrl, and video fields properly', () {
      final ad = AdModel.fromMap({
        'shopId': 's1',
        'imageUrl': 'https://example.com/ad.jpg',
        'text': 'إعلان تجريبي',
        'clickCount': 42,
        'externalUrl': 'https://sanhour.online/promo',
        'startDate': DateTime(2026, 1, 1).toIso8601String(),
        'endDate': DateTime(2026, 2, 1).toIso8601String(),
      }, 'ad_1');

      expect(ad.id, equals('ad_1'));
      expect(ad.clickCount, equals(42));
      expect(ad.text, equals('إعلان تجريبي'));
      expect(ad.externalUrl, equals('https://sanhour.online/promo'));
    });

    test('Product model preserves sortOrder and listName for pinned items', () {
      final p = Product.fromMap({
        'shopId': 's1',
        'name': 'منتج مثبت',
        'price': 250.0,
        'oldPrice': 300.0,
        'hasPriceDrop': true,
        'sortOrder': 1,
        'listName': 'الأكثر مبيعاً',
      }, 'prod_1');

      expect(p.id, equals('prod_1'));
      expect(p.sortOrder, equals(1));
      expect(p.listName, equals('الأكثر مبيعاً'));
      expect(p.hasDiscount, isTrue);
    });

    test('Shop, Offer, JobAdModel, and ServiceRequestModel serialize cleanly', () {
      final shop = Shop.fromMap({
        'name': 'ملابس الشروق',
        'category': 'ملابس',
        'phone': '01000000000',
        'location': 'وسط البلد',
        'ownerId': 'owner_1',
      }, 'shop_1');
      expect(shop.name, equals('ملابس الشروق'));

      final offer = Offer.fromMap({
        'shopId': 'shop_1',
        'title': 'خصم خاص',
        'discount': 20,
        'type': 'price_drop',
        'oldPrice': 500,
        'newPrice': 400,
      }, 'offer_1');
      expect(offer.discount, equals(20));
      expect(offer.type, equals('price_drop'));

      expect(
        JobAdModel.categoryLabel(JobCategory.sales),
        isNotEmpty,
      );
      expect(
        ServiceRequestModel.categoryLabel(ServiceRequestCategory.plumbing),
        isNotEmpty,
      );
    });

    test('SubscriptionService.calculateNewExpiry extends active and expired dates', () {
      final now = DateTime.now();
      final futureEnd = now.add(const Duration(days: 10));
      final extended = SubscriptionService.calculateNewExpiry(futureEnd, 30);
      expect(extended.difference(futureEnd).inDays, equals(30));

      final pastEnd = now.subtract(const Duration(days: 10));
      final renewedFromNow = SubscriptionService.calculateNewExpiry(pastEnd, 30);
      expect(renewedFromNow.isAfter(now.add(const Duration(days: 28))), isTrue);
    });

    test('DeepLinkService builds valid sanitized URLs', () {
      final link = DeepLinkService.buildLink(
        type: ShareableType.shop,
        id: 'shop_123',
      );
      expect(link, equals('https://sanhour.online/shop/shop_123'));
      expect(AppConstants.geminiModel, equals('gemini-2.5-flash'));
    });
  });

  group('Core UI Widgets Smoke Tests', () {
    testWidgets('EmptyStateWidget and ErrorStateWidget render properly',
        (WidgetTester tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(
                  child: EmptyStateWidget(
                    message: 'لا توجد عناصر حالياً',
                    icon: Icons.inbox_outlined,
                  ),
                ),
                Expanded(
                  child: ErrorStateWidget(
                    message: 'حدث خطأ في الشبكة',
                    onRetry: () => retried = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('لا توجد عناصر حالياً'), findsOneWidget);
      expect(find.text('حدث خطأ في الشبكة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });

    testWidgets('StatCard renders title and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                StatCard(
                  title: 'إجمالي المستخدمين',
                  value: '150',
                  icon: Icons.people,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('إجمالي المستخدمين'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });
  });
}
