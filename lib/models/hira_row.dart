import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HiraRow {
  int? id;
  int missionId;
  String hazard;
  int likelihood; // 1–5
  int impact; // 1–5
  String mitigation;
  int residualRisk; // 1–5

  HiraRow({
    this.id,
    required this.missionId,
    required this.hazard,
    required this.likelihood,
    required this.impact,
    required this.mitigation,
    required this.residualRisk,
  });

  int get risk => likelihood * impact;

  String get riskCategory => HiraRow.categoryForScore(risk);
  Color  get riskColor     => HiraRow.colorForScore(risk);

  /// Single source of truth for risk-score → label.
  /// Low ≤ 4  |  Medium ≤ 8  |  High > 8
  static String categoryForScore(int r) {
    if (r <= 4) return 'Low';
    if (r <= 8) return 'Medium';
    return 'High';
  }

  /// Single source of truth for risk-score → theme color.
  static Color colorForScore(int r) {
    if (r <= 4) return AppColors.success;
    if (r <= 8) return AppColors.warning;
    return AppColors.danger;
  }

  factory HiraRow.fromMap(Map<String, dynamic> map) {
    return HiraRow(
      id: map['id'],
      missionId: map['mission_id'],
      hazard: map['hazard'] ?? '',
      likelihood: map['likelihood'] ?? 1,
      impact: map['impact'] ?? 1,
      mitigation: map['mitigation'] ?? '',
      residualRisk: map['residual_risk'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'hazard': hazard,
      'likelihood': likelihood,
      'impact': impact,
      'mitigation': mitigation,
      'residual_risk': residualRisk,
    };
  }
}
