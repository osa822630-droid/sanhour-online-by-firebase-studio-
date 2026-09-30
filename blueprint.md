# Project Overview: Sanhour Online
A Flutter application for a marketplace/directory service (Sanhour Online).

## Features & Styles
- Material 3 Design.
- Dark/Light mode support.
- User, Merchant, and Admin dashboards.
- Product and Shop management.
- Ads and Offers system.
- Analytics and Reporting.
- Gemini AI integration.

## Current Task: Fixing Analysis Errors
The goal is to resolve 146 issues found by flutter analyze.

### Plan
1. Fix missing imports for commonly used widgets and services:
   - CachedImage (from lib/widgets/cached_image.dart)
   - AnalyticsService (from lib/services/analytics_service.dart)
   - ShopDetailScreen (from lib/screens/shop_detail_screen.dart)
   - ReviewScreen (from lib/screens/review_screen.dart)
   - EmptyStateWidget (from lib/widgets/empty_state_widget.dart)
   - ImageHelper (from lib/utils/image_helper.dart)
   - AppLogger (check lib/utils/logger.dart)
   - DatabaseSeeder (from lib/services/database_seeder.dart)
   - CustomAppBar (from lib/widgets/custom_app_bar.dart)
2. Resolve required parameter issues in AddOfferScreen and AddProductScreen.
3. Fix URI issues in CategoriesScreen.
4. Address type mismatches in ExcelUploadScreen and AdminUsersTab.
5. Fix deprecated member usage (withOpacity -> withValues).
6. Run flutter analyze again to verify progress.