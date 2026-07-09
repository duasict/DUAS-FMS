import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';

const _typeLabels = {
  'travel_order': 'Travel Order',
  'site_permission': 'Site Permission',
  'property_owner': 'Property Owner',
};

const _typeIcons = {
  'travel_order': Icons.description_outlined,
  'site_permission': Icons.verified_outlined,
  'property_owner': Icons.house_outlined,
};

/// Single-row display for a mission_documents record.
/// Pass [onOpen] to enable the tap-to-open action; omit it to render read-only.
class MissionDocumentRow extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool allowOpen;

  const MissionDocumentRow({
    super.key,
    required this.doc,
    this.allowOpen = false,
  });

  String get _type => doc['document_type'] as String? ?? '';
  String get _permType => doc['permission_type'] as String? ?? '';
  String get _path => doc['file_path'] as String? ?? '';
  String get _name =>
      _path.isNotEmpty ? _path.split(Platform.pathSeparator).last : '—';
  bool get _isPdf => _name.toLowerCase().endsWith('.pdf');
  String get _label => _typeLabels[_type] ?? _type;
  IconData get _icon => _typeIcons[_type] ?? Icons.insert_drive_file_outlined;
  String get _subtitle =>
      (_type == 'site_permission' && _permType.isNotEmpty) ? _permType : '';

  Future<void> _open(BuildContext context) async {
    if (_path.isEmpty) return;
    final result = await OpenFile.open(_path);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open file — it may have been moved or deleted.'),
        backgroundColor: Color(0xFFDC2626),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Icon(_icon, size: 15, color: context.colors.textMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _subtitle.isNotEmpty ? '$_label — $_subtitle' : _label,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          Text(
            _name,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
      if (allowOpen && _path.isNotEmpty) ...[
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.open_in_new, size: 11, color: AppColors.primary),
              SizedBox(width: 3),
              Text('Open',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ] else
        Icon(
          _isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          size: 13,
          color: _isPdf ? AppColors.danger : context.colors.textMuted,
        ),
    ]);

    return row;
  }
}
