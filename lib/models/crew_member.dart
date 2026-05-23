class CrewMember {
  int? id;
  int? missionId;
  String name;
  String role;
  /// Supabase auth.users UUID — links this slot to a verified UserProfile.
  /// Null for legacy / manually-entered crew that pre-dates identity linking.
  String? userId;

  CrewMember({
    this.id,
    this.missionId,
    required this.name,
    required this.role,
    this.userId,
  });

  factory CrewMember.fromMap(Map<String, dynamic> map) {
    return CrewMember(
      id: map['id'],
      missionId: map['mission_id'],
      name: map['name'],
      role: map['role'],
      userId: map['user_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      'name': name,
      'role': role,
      'user_id': userId,
    };
  }
}
