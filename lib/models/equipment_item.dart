class EquipmentItem {
  int? id;
  String equipmentCode;  // auto-generated: BAT-001, CHG-001, etc.
  String name;
  String type;           // battery | charger | ground_support | ppe | tool | other
  String serialNumber;
  String model;
  String manufacturer;
  String description;
  // Battery-specific fields
  String batteryType;    // '1S','2S','4S','6S', etc.
  int capacityMah;
  // General
  String condition;      // serviceable | unserviceable | retired
  int quantity;
  String storageLocation;
  String purchaseDate;
  String notes;
  String organizationId;
  String createdAt;
  int isSynced;

  EquipmentItem({
    this.id,
    this.equipmentCode = '',
    required this.name,
    required this.type,
    this.serialNumber = '',
    this.model = '',
    this.manufacturer = '',
    this.description = '',
    this.batteryType = '',
    this.capacityMah = 0,
    this.condition = 'serviceable',
    this.quantity = 1,
    this.storageLocation = '',
    this.purchaseDate = '',
    this.notes = '',
    this.organizationId = '',
    required this.createdAt,
    this.isSynced = 0,
  });

  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    return EquipmentItem(
      id: map['id'] as int?,
      equipmentCode: map['equipment_code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'other',
      serialNumber: map['serial_number'] as String? ?? '',
      model: map['model'] as String? ?? '',
      manufacturer: map['manufacturer'] as String? ?? '',
      description: map['description'] as String? ?? '',
      batteryType: map['battery_type'] as String? ?? '',
      capacityMah: map['capacity_mah'] as int? ?? 0,
      condition: map['condition'] as String? ?? 'serviceable',
      quantity: map['quantity'] as int? ?? 1,
      storageLocation: map['storage_location'] as String? ?? '',
      purchaseDate: map['purchase_date'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      organizationId: map['organization_id'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      isSynced: map['is_synced'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'equipment_code': equipmentCode,
      'name': name,
      'type': type,
      'serial_number': serialNumber,
      'model': model,
      'manufacturer': manufacturer,
      'description': description,
      'battery_type': batteryType,
      'capacity_mah': capacityMah,
      'condition': condition,
      'quantity': quantity,
      'storage_location': storageLocation,
      'purchase_date': purchaseDate,
      'notes': notes,
      'organization_id': organizationId,
      'created_at': createdAt,
      'is_synced': isSynced,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'battery':       return 'Battery';
      case 'charger':       return 'Charger';
      case 'ground_support': return 'Ground Support';
      case 'ppe':           return 'PPE';
      case 'tool':          return 'Tool';
      default:              return 'Other';
    }
  }

  String get conditionLabel {
    switch (condition) {
      case 'serviceable':   return 'Serviceable';
      case 'unserviceable': return 'Unserviceable';
      case 'retired':       return 'Retired';
      default:              return condition;
    }
  }

  bool get isBattery => type == 'battery';
}
