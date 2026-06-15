import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class DocumentSubmissionScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const DocumentSubmissionScreen({
    super.key,
    required this.missionId,
    required this.missionTitle,
  });

  @override
  State<DocumentSubmissionScreen> createState() =>
      _DocumentSubmissionScreenState();
}

class _DocumentSubmissionScreenState extends State<DocumentSubmissionScreen> {
  final db = DatabaseHelper.instance;

  _DocEntry _travelOrder = _DocEntry();
  _DocEntry _sitePermission = _DocEntry(permissionType: 'CAAP');
  _DocEntry _propertyOwner = _DocEntry();

  bool _isLoading = true;
  bool _isSaving = false;

  static const _permissionTypes = [
    'CAAP',
    'Agency',
    'Police / Military',
    'LGU',
    'Barangay',
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final docs = await db.getMissionDocuments(widget.missionId);
    for (final doc in docs) {
      final type = doc['document_type'] as String;
      final path = doc['file_path'] as String? ?? '';
      final id = doc['id'] as int;
      if (type == 'travel_order') {
        _travelOrder = _DocEntry(existingId: id, filePath: path.isEmpty ? null : path);
      } else if (type == 'site_permission') {
        _sitePermission = _DocEntry(
          existingId: id,
          filePath: path.isEmpty ? null : path,
          permissionType: doc['permission_type'] as String? ?? 'CAAP',
        );
      } else if (type == 'property_owner') {
        _propertyOwner = _DocEntry(existingId: id, filePath: path.isEmpty ? null : path);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pick(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    setState(() {
      if (docType == 'travel_order') _travelOrder.filePath = path;
      if (docType == 'site_permission') _sitePermission.filePath = path;
      if (docType == 'property_owner') _propertyOwner.filePath = path;
    });
  }

  void _clear(String docType) {
    setState(() {
      if (docType == 'travel_order') _travelOrder.filePath = null;
      if (docType == 'site_permission') _sitePermission.filePath = null;
      if (docType == 'property_owner') _propertyOwner.filePath = null;
    });
  }

  bool get _canSubmit =>
      _travelOrder.hasFile && _sitePermission.hasFile;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSaving = true);
    final missionId = widget.missionId;
    final now = DateTime.now().toIso8601String();

    await _saveDoc(
      entry: _travelOrder,
      docType: 'travel_order',
      permissionType: '',
      missionId: missionId,
      now: now,
    );
    await _saveDoc(
      entry: _sitePermission,
      docType: 'site_permission',
      permissionType: _sitePermission.permissionType,
      missionId: missionId,
      now: now,
    );
    await _saveDoc(
      entry: _propertyOwner,
      docType: 'property_owner',
      permissionType: '',
      missionId: missionId,
      now: now,
    );

    final mission = await db.getMissionById(missionId);
    if (mission != null) {
      mission.hasDocumentsComplete = true;
      if (mounted) await context.read<AppProvider>().updateMission(mission);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveDoc({
    required _DocEntry entry,
    required String docType,
    required String permissionType,
    required int missionId,
    required String now,
  }) async {
    if (entry.existingId != null) {
      await db.deleteMissionDocument(entry.existingId!);
    }
    if (entry.hasFile) {
      await db.insertMissionDocument({
        'mission_id': missionId,
        'document_type': docType,
        'permission_type': permissionType,
        'file_path': entry.filePath!,
        'file_url': '',
        'notes': '',
        'created_at': now,
        'is_synced': 0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mission Documents',
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(widget.missionTitle,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
        ]),
        iconTheme: IconThemeData(color: context.colors.textSecondary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _infoBox(context),
                const SizedBox(height: 16),
                _docCard(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Travel Order',
                  subtitle: 'Official authorization to travel to the area of operation',
                  required: true,
                  entry: _travelOrder,
                  docType: 'travel_order',
                ),
                const SizedBox(height: 12),
                _docCard(
                  context,
                  icon: Icons.verified_outlined,
                  title: 'Site Permission',
                  subtitle: 'Written clearance to operate within the site boundaries',
                  required: true,
                  entry: _sitePermission,
                  docType: 'site_permission',
                  permissionTypeSelector: true,
                ),
                const SizedBox(height: 12),
                _docCard(
                  context,
                  icon: Icons.house_outlined,
                  title: 'Property Owner Consent',
                  subtitle: 'Consent from the land or property owner (if applicable)',
                  required: false,
                  entry: _propertyOwner,
                  docType: 'property_owner',
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _canSubmit && !_isSaving ? _submit : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Submit Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Travel Order and Site Permission are required before proceeding to flight planning. '
            'Accepted formats: PDF, PNG, JPG.',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _docCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool required,
    required _DocEntry entry,
    required String docType,
    bool permissionTypeSelector = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (required && !entry.hasFile)
              ? AppColors.warning.withValues(alpha: 0.4)
              : context.colors.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          _requiredBadge(context, required),
        ]),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
        if (permissionTypeSelector) ...[
          const SizedBox(height: 10),
          _permissionTypeRow(context),
        ],
        const SizedBox(height: 12),
        if (entry.hasFile)
          _fileRow(context, entry.filePath!, docType)
        else
          _emptyState(context),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pick(docType),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(children: [
              Icon(Icons.attach_file_outlined,
                  size: 16, color: context.colors.textSecondary),
              const SizedBox(width: 8),
              Text(entry.hasFile ? 'Replace File' : 'Select File',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _permissionTypeRow(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Permission Type',
          style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final type in _permissionTypes)
          GestureDetector(
            onTap: () =>
                setState(() => _sitePermission.permissionType = type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _sitePermission.permissionType == type
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _sitePermission.permissionType == type
                      ? AppColors.primary
                      : context.colors.border,
                ),
              ),
              child: Text(type,
                  style: TextStyle(
                      color: _sitePermission.permissionType == type
                          ? AppColors.primary
                          : context.colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    ]);
  }

  Widget _fileRow(BuildContext context, String path, String docType) {
    final name = path.split(Platform.pathSeparator).last;
    final isPdf = name.toLowerCase().endsWith('.pdf');
    return Row(children: [
      Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          size: 15,
          color: isPdf ? AppColors.danger : context.colors.textSecondary),
      const SizedBox(width: 6),
      Expanded(
        child: Text(name,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      GestureDetector(
        onTap: () => _clear(docType),
        child: Icon(Icons.close, size: 16, color: context.colors.textMuted),
      ),
    ]);
  }

  Widget _emptyState(BuildContext context) {
    return Row(children: [
      Icon(Icons.upload_file_outlined, size: 15, color: context.colors.textMuted),
      const SizedBox(width: 6),
      Text('No file selected',
          style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
    ]);
  }

  Widget _requiredBadge(BuildContext context, bool required) {
    final color = required ? AppColors.warning : context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(required ? 'REQUIRED' : 'OPTIONAL',
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _DocEntry {
  int? existingId;
  String? filePath;
  String permissionType;

  _DocEntry({this.existingId, this.filePath, this.permissionType = ''});

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
}
