class UserProfile {
  final int? id;               // SQLite local PK
  final String supabaseId;     // Supabase auth.users UUID
  final String name;
  // Profile roles: crp | pic | vo | gcs | tech
  // 'pic' (Person in Command) is AUTO-ASSIGNED when licenseVerified=true
  //   and license is not expired. Replaces 'rpic' at the profile level.
  //   'rpic' (Remote Pilot in Command) is mission-specific only (crew role).
  final String role;
  final String email;
  final String unit;
  // License fields — populated ONLY via LicenseVerificationScreen (OCR scan).
  // These cannot be manually edited.
  final String licenseNumber;
  final String? licenseExpiryDate;  // ISO-8601: 'YYYY-MM-DD'
  final bool licenseVerified;       // true = scanned & OCR-confirmed
  final bool faceVerified;          // true = selfie matched ID photo
  final String phone;
  final String? photoPath;
  final String organizationId; // Supabase organization UUID (empty = not linked)

  const UserProfile({
    this.id,
    this.supabaseId = '',
    this.name = '',
    this.role = 'vo',
    this.email = '',
    this.unit = '',
    this.licenseNumber = '',
    this.licenseExpiryDate,
    this.licenseVerified = false,
    this.faceVerified = false,
    this.phone = '',
    this.photoPath,
    this.organizationId = '',
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as int?,
        supabaseId: m['supabase_id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        role: _migrateRole(m['role'] as String? ?? 'vo'),
        email: m['email'] as String? ?? '',
        unit: m['unit'] as String? ?? '',
        licenseNumber: m['license_number'] as String? ?? '',
        licenseExpiryDate:
            (m['license_expiry_date'] as String?)?.isEmpty == true
                ? null
                : m['license_expiry_date'] as String?,
        licenseVerified: (m['license_verified'] as int? ?? 0) == 1,
        faceVerified: (m['face_verified'] as int? ?? 0) == 1,
        phone: m['phone'] as String? ?? '',
        photoPath: (m['photo_path'] as String?)?.isEmpty == true
            ? null
            : m['photo_path'] as String?,
        organizationId: m['organization_id'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'supabase_id': supabaseId,
        'name': name,
        'role': role,
        'email': email,
        'unit': unit,
        'license_number': licenseNumber,
        'license_expiry_date': licenseExpiryDate ?? '',
        'license_verified': licenseVerified ? 1 : 0,
        'face_verified': faceVerified ? 1 : 0,
        'phone': phone,
        'photo_path': photoPath ?? '',
        'organization_id': organizationId,
      };

  UserProfile copyWith({
    String? supabaseId,
    String? name,
    String? role,
    String? email,
    String? unit,
    String? licenseNumber,
    String? licenseExpiryDate,
    bool clearLicenseExpiry = false,
    bool? licenseVerified,
    bool? faceVerified,
    String? phone,
    String? photoPath,
    bool clearPhoto = false,
    String? organizationId,
  }) =>
      UserProfile(
        id: id,
        supabaseId: supabaseId ?? this.supabaseId,
        name: name ?? this.name,
        role: role ?? this.role,
        email: email ?? this.email,
        unit: unit ?? this.unit,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        licenseExpiryDate: clearLicenseExpiry
            ? null
            : (licenseExpiryDate ?? this.licenseExpiryDate),
        licenseVerified: licenseVerified ?? this.licenseVerified,
        faceVerified: faceVerified ?? this.faceVerified,
        phone: phone ?? this.phone,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        organizationId: organizationId ?? this.organizationId,
      );

  // ── Computed ───────────────────────────────────────────────────────────────

  String get displayName => name.isEmpty ? 'Unnamed User' : name;

  String get roleLabel {
    switch (role) {
      case 'crp':
        return 'Chief Remote Pilot';
      case 'pic':
        return 'Person in Command';
      case 'vo':
        return 'Visual Observer';
      case 'gcs':
        return 'GCS Operator';
      case 'tech':
        return 'Technician';
      default:
        return role.toUpperCase();
    }
  }

  String get displayTitle {
    final parts = [roleLabel, unit].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'UAS Operator' : parts.join('  ·  ');
  }

  bool get isLicenseExpiringSoon {
    if (licenseExpiryDate == null) return false;
    try {
      final expiry = DateTime.parse(licenseExpiryDate!);
      final daysLeft = expiry.difference(DateTime.now()).inDays;
      return daysLeft >= 0 && daysLeft <= 30;
    } catch (_) {
      return false;
    }
  }

  bool get isLicenseExpired {
    if (licenseExpiryDate == null) return false;
    try {
      return DateTime.parse(licenseExpiryDate!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// True when this profile qualifies for PIC/RPIC mission assignment.
  bool get isEligibleRpic =>
      licenseVerified && licenseNumber.isNotEmpty && !isLicenseExpired;

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Convert legacy 'rpic' profile roles to 'pic' on read.
  static String _migrateRole(String r) => r == 'rpic' ? 'pic' : r;
}
