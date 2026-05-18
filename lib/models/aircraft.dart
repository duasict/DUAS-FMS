class Aircraft {
  int? id;
  String name;
  String type; // multi-rotor, vtol
  String model;
  String serialNumber;
  double mtow;
  String status; // serviceable, under_maintenance, unserviceable

  Aircraft({
    this.id,
    required this.name,
    required this.type,
    required this.model,
    this.serialNumber = '',
    required this.mtow,
    required this.status,
  });

  factory Aircraft.fromMap(Map<String, dynamic> map) {
    return Aircraft(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      model: map['model'],
      serialNumber: map['serial_number'] as String? ?? '',
      mtow: (map['mtow'] as num).toDouble(),
      status: map['status'],
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
