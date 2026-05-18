class AlertModel {
  int? id;
  String type; // notification, concurrence
  String title;
  String message;
  String status; // pending, approved, rejected, info
  int? missionId;
  String? missionTitle;
  bool isRead;
  String createdAt;
  bool isSynced;

  AlertModel({
    this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.status,
    this.missionId,
    this.missionTitle,
    this.isRead = false,
    required this.createdAt,
    this.isSynced = false,
  });

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      id: map['id'],
      type: map['type'],
      title: map['title'],
      message: map['message'],
      status: map['status'],
      missionId: map['mission_id'],
      missionTitle: map['mission_title'],
      isRead: map['is_read'] == 1,
      createdAt: map['created_at'],
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'title': title,
      'message': message,
      'status': status,
      'mission_id': missionId,
      'mission_title': missionTitle,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  bool get isConcurrence => type == 'concurrence';
  bool get isPending => status == 'pending';
}
