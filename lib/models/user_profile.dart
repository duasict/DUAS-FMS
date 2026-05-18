class UserProfile {
  final int? id;
  final String name;
  final String rank;
  final String email;
  final String unit;
  final String licenseNumber;
  final String phone;
  final String? photoPath;

  const UserProfile({
    this.id,
    this.name = '',
    this.rank = '',
    this.email = '',
    this.unit = '',
    this.licenseNumber = '',
    this.phone = '',
    this.photoPath,
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        rank: m['rank'] as String? ?? '',
        email: m['email'] as String? ?? '',
        unit: m['unit'] as String? ?? '',
        licenseNumber: m['license_number'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        photoPath: (m['photo_path'] as String?)?.isEmpty == true
            ? null
            : m['photo_path'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'rank': rank,
        'email': email,
        'unit': unit,
        'license_number': licenseNumber,
        'phone': phone,
        'photo_path': photoPath ?? '',
      };

  UserProfile copyWith({
    String? name,
    String? rank,
    String? email,
    String? unit,
    String? licenseNumber,
    String? phone,
    String? photoPath,
    bool clearPhoto = false,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        rank: rank ?? this.rank,
        email: email ?? this.email,
        unit: unit ?? this.unit,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        phone: phone ?? this.phone,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      );

  String get displayName => name.isEmpty ? 'Unnamed User' : name;
  String get displayTitle {
    final parts = [rank, unit].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'UAS Operator' : parts.join('  ·  ');
  }
}
