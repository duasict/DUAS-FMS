class Aircraft {
  int? id;
  String name;
  String type; // multi-rotor, vtol, fixed-wing
  String model;
  String serialNumber;
  double mtow;
  String status; // serviceable, under_maintenance, unserviceable
  String photoPath;
  int batteriesNeeded;
  String organizationId;
  int isSynced;
  String createdAt;
  String? supabaseId;

  Aircraft({
    this.id,
    required this.name,
    required this.type,
    required this.model,
    this.serialNumber = '',
    required this.mtow,
    required this.status,
    this.photoPath = '',
    this.batteriesNeeded = 1,
    this.organizationId = '',
    this.isSynced = 0,
    this.createdAt = '',
    this.supabaseId,
  });

  factory Aircraft.fromMap(Map<String, dynamic> map) {
    return Aircraft(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      model: map['model'] as String,
      serialNumber: map['serial_number'] as String? ?? '',
      mtow: (map['mtow'] as num).toDouble(),
      status: map['status'] as String,
      photoPath: map['photo_path'] as String? ?? '',
      batteriesNeeded: map['batteries_needed'] as int? ?? 1,
      organizationId: map['organization_id'] as String? ?? '',
      isSynced: map['is_synced'] as int? ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      supabaseId: map['supabase_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'model': model,
      'serial_number': serialNumber,
      'mtow': mtow,
      'status': status,
      'photo_path': photoPath,
      'batteries_needed': batteriesNeeded,
      'organization_id': organizationId,
      'is_synced': isSynced,
      'created_at': createdAt,
      if (supabaseId != null) 'supabase_id': supabaseId,
    };
  }

  String get typeLabel => type == 'vtol' ? 'VTOL Fixed-Wing' : 'Multi-rotor';

  String get statusLabel {
    switch (status) {
      case 'serviceable':
        return 'Serviceable';
      case 'under_maintenance':
        return 'Under Maintenance';
      case 'unserviceable':
        return 'Unserviceable';
      default:
        return status;
    }
  }
}
