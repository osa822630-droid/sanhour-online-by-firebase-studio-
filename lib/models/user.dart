// lib/models/user.dart
// ✅ إضافة حقول نظام الإحالات (referralCode, referredBy, referralCount, referralBonusDaysEarned)
// ✅ إضافة businessType ومصفوفة صلاحيات المشرف (ModeratorPermissions)

class ModeratorPermissions {
  final bool manageShops;
  final bool manageProducts;
  final bool manageOffers;
  final bool manageCategories;
  final bool manageAds;
  final bool manageActivationCodes;
  final bool manageUsers;
  final bool viewReports;
  final bool manageSettings;

  const ModeratorPermissions({
    this.manageShops = true,
    this.manageProducts = true,
    this.manageOffers = true,
    this.manageCategories = true,
    this.manageAds = true,
    this.manageActivationCodes = false,
    this.manageUsers = true,
    this.viewReports = true,
    this.manageSettings = false,
  });

  factory ModeratorPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ModeratorPermissions();
    return ModeratorPermissions(
      manageShops: map['manageShops'] as bool? ?? true,
      manageProducts: map['manageProducts'] as bool? ?? true,
      manageOffers: map['manageOffers'] as bool? ?? true,
      manageCategories: map['manageCategories'] as bool? ?? true,
      manageAds: map['manageAds'] as bool? ?? true,
      manageActivationCodes: map['manageActivationCodes'] as bool? ?? false,
      manageUsers: map['manageUsers'] as bool? ?? true,
      viewReports: map['viewReports'] as bool? ?? true,
      manageSettings: map['manageSettings'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'manageShops': manageShops,
        'manageProducts': manageProducts,
        'manageOffers': manageOffers,
        'manageCategories': manageCategories,
        'manageAds': manageAds,
        'manageActivationCodes': manageActivationCodes,
        'manageUsers': manageUsers,
        'viewReports': viewReports,
        'manageSettings': manageSettings,
      };
}

class AppUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  // userType: 'super_admin' | 'admin' | 'moderator' | 'merchant' | 'customer'
  final String userType;
  final String shopRole;
  final String? profileImageUrl;
  final String? linkedShopId;
  final String? businessType;
  final String? referralCode;
  final String? referredBy;
  final int referralCount;
  final int referralBonusDaysEarned;
  final ModeratorPermissions? moderatorPermissions;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.userType,
    this.shopRole = 'owner',
    this.profileImageUrl,
    this.linkedShopId,
    this.businessType,
    this.referralCode,
    this.referredBy,
    this.referralCount = 0,
    this.referralBonusDaysEarned = 0,
    this.moderatorPermissions,
  });

  // ── alias مريح للصورة ───────────────────────────────────────
  String? get photoUrl => profileImageUrl;

  // ── صلاحيات الأدمن ──────────────────────────────────────────
  bool get isSuperAdmin => userType == 'admin' || userType == 'super_admin';
  bool get isModerator => userType == 'moderator';
  bool get isAnyAdmin => isSuperAdmin || isModerator;
  bool get canViewFinancialStats => isSuperAdmin;

  // ── صلاحيات التاجر ──────────────────────────────────────────
  bool get isMerchant => userType == 'merchant';
  bool get isShopOwner => shopRole == 'owner';
  bool get isShopPartner => shopRole == 'partner';
  bool get isShopWorker => shopRole == 'worker';
  bool get canViewShopStats => isShopOwner || isShopPartner;
  bool get canManageSubscription => isShopOwner;
  bool get canManageProducts => isMerchant;
  bool get canManageOffers => isMerchant;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final rawPerms = map['moderatorPermissions'];
    return AppUser(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      userType: map['userType'] as String? ?? 'customer',
      shopRole: map['shopRole'] as String? ?? 'owner',
      profileImageUrl: (map['profileImageUrl'] as String?)?.isNotEmpty == true
          ? map['profileImageUrl'] as String
          : (map['photoUrl'] as String?),
      linkedShopId: map['linkedShopId'] as String?,
      businessType: map['businessType'] as String?,
      referralCode: map['referralCode'] as String?,
      referredBy: map['referredBy'] as String?,
      referralCount: (map['referralCount'] as num?)?.toInt() ?? 0,
      referralBonusDaysEarned:
          (map['referralBonusDaysEarned'] as num?)?.toInt() ?? 0,
      moderatorPermissions: rawPerms is Map
          ? ModeratorPermissions.fromMap(Map<String, dynamic>.from(rawPerms))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'userType': userType,
      'shopRole': shopRole,
      'profileImageUrl': profileImageUrl,
      'linkedShopId': linkedShopId,
      if (businessType != null) 'businessType': businessType,
      if (referralCode != null) 'referralCode': referralCode,
      if (referredBy != null) 'referredBy': referredBy,
      'referralCount': referralCount,
      'referralBonusDaysEarned': referralBonusDaysEarned,
      if (moderatorPermissions != null)
        'moderatorPermissions': moderatorPermissions!.toMap(),
    };
  }

  static const _sentinel = Object();

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? userType,
    String? shopRole,
    Object? profileImageUrl = _sentinel,
    String? linkedShopId,
    String? businessType,
    String? referralCode,
    String? referredBy,
    int? referralCount,
    int? referralBonusDaysEarned,
    ModeratorPermissions? moderatorPermissions,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      shopRole: shopRole ?? this.shopRole,
      profileImageUrl: identical(profileImageUrl, _sentinel)
          ? this.profileImageUrl
          : profileImageUrl as String?,
      linkedShopId: linkedShopId ?? this.linkedShopId,
      businessType: businessType ?? this.businessType,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
      referralBonusDaysEarned:
          referralBonusDaysEarned ?? this.referralBonusDaysEarned,
      moderatorPermissions: moderatorPermissions ?? this.moderatorPermissions,
    );
  }
}

typedef User = AppUser;
