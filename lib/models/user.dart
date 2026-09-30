// lib/models/user.dart
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
    };
  }

  // ✅ Fix #200: copyWith يدعم مسح profileImageUrl بـ null صريح
  // نستخدم sentinel لتمييز "لم يُمرَّر" عن "أُمرِّر null مقصوداً"
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
    );
  }
}

// ── Alias للتوافق مع الكود القديم ──────────────────────────────
// أي ملف كان يستورد User يعمل بشكل طبيعي بدون تعديل
typedef User = AppUser;
