class ChecklistItem {
  int? id;
  int missionId;
  String checklistType; // preflight, inflight, postflight
  String section;
  int itemIndex;
  String itemText;
  int status; // 0=unchecked, 1=pass, 2=fail
  String remark;

  ChecklistItem({
    this.id,
    required this.missionId,
    required this.checklistType,
    required this.section,
    required this.itemIndex,
    required this.itemText,
    this.status = 0,
    this.remark = '',
  });

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'],
      missionId: map['mission_id'],
      checklistType: map['checklist_type'],
      section: map['section'],
      itemIndex: map['item_index'],
      itemText: map['item_text'],
      status: map['status'] ?? 0,
      remark: map['remark'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'checklist_type': checklistType,
      'section': section,
      'item_index': itemIndex,
      'item_text': itemText,
      'status': status,
      'remark': remark,
    };
  }

  bool get isPassed => status == 1;
  bool get isFailed => status == 2;
  bool get isChecked => status != 0;
}
