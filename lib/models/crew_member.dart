class CrewMember {
  int? id;
  int? missionId;
  String name;
  String role;

  CrewMember({
    this.id,
    this.missionId,
    required this.name,
    required this.role,
  });

  factory CrewMember.fromMap(Map<String, dynamic> map) {
    return CrewMember(
      id: map['id'],
      missionId: map['mission_id'],
      name: map['name'],
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      'name': name,
      'role': role,
    };
  }
}
