import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _phoneCtrl;

  String _role = 'rpic';
  String? _licenseExpiryDate; // ISO date string
  String? _photoPath;
  bool _isSaving = false;
  bool _isDirty = false;

  static const _roles = [
    ('crp', 'Chief Remote Pilot', Icons.stars_outlined),
    ('rpic', 'Remote Pilot in Command', Icons.flight_takeoff_outlined),
    ('vo', 'Visual Observer', Icons.visibility_outlined),
    ('gcs', 'GCS Operator', Icons.settings_remote_outlined),
    ('tech', 'Technician', Icons.build_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _nameCtrl = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _unitCtrl = TextEditingController(text: p.unit);
    _licenseCtrl = TextEditingController(text: p.licenseNumber);
    _phoneCtrl = TextEditingController(text: p.phone);
    _role = p.role;
    _licenseExpiryDate = p.licenseExpiryDate;
    _photoPath = p.photoPath;

    for (final c in [_nameCtrl, _emailCtrl, _unitCtrl, _licenseCtrl, _phoneCtrl]) {
      c.addListener(() => setState(() => _isDirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _unitCtrl, _licenseCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_photo.jpg');
    await File(picked.path).copy(dest.path);

    setState(() {
      _photoPath = dest.path;
      _isDirty = true;
    });
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: _sheetIcon(Icons.photo_camera_outlined, AppColors.primary),
            title: Text('Take Photo',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          ListTile(
            leading: _sheetIcon(Icons.photo_library_outlined, AppColors.primary),
            title: Text('Choose from Gallery',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          if (_photoPath != null)
            ListTile(
              leading: _sheetIcon(Icons.delete_outline, AppColors.danger),
              title: Text('Remove Photo',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _photoPath = null;
                  _isDirty = true;
                });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sheetIcon(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      );

  Future<void> _pickExpiryDate() async {
    final initial = _licenseExpiryDate != null
        ? DateTime.tryParse(_licenseExpiryDate!) ?? DateTime.now()
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'License Expiry Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _licenseExpiryDate = DateFormat('yyyy-MM-dd').format(picked);
        _isDirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name is required.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isSaving = true);

    final existing = context.read<UserProfileProvider>().profile;
    final updated = UserProfile(
      id: existing.id,
      supabaseId: existing.supabaseId,
      name: _nameCtrl.text.trim(),
      role: _role,
      email: _emailCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      licenseNumber: _licenseCtrl.text.trim(),
      licenseExpiryDate: _licenseExpiryDate,
      phone: _phoneCtrl.text.trim(),
      photoPath: _photoPath,
      organizationId: existing.organizationId,
    );

    await context.read<UserProfileProvider>().update(updated);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isDirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile saved.'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Text('Save',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          _avatarSection(),
          const SizedBox(height: 28),

          _sectionLabel('PERSONAL INFORMATION'),
          const SizedBox(height: 10),
          _field(
            controller: _nameCtrl,
            label: 'Full Name',
            hint: 'e.g. Juan B. dela Cruz',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emailCtrl,
            label: 'Email Address',
            hint: 'e.g. jbdelacruz@unit.mil',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _phoneCtrl,
            label: 'Phone Number',
            hint: 'e.g. +63 917 123 4567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),

          _sectionLabel('ROLE & UNIT'),
          const SizedBox(height: 10),
          _roleSelector(),
          const SizedBox(height: 14),
          _field(
            controller: _unitCtrl,
            label: 'Unit / Organization',
            hint: 'e.g. UAS Operations Unit, 1st Aviation Bn',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 28),

          _sectionLabel('CERTIFICATION'),
          const SizedBox(height: 10),
          _field(
            controller: _licenseCtrl,
            label: 'UAS License Number',
            hint: 'e.g. CAAP-UAS-2024-00123',
            icon: Icons.badge_outlined,
            highlighted: true,
          ),
          const SizedBox(height: 14),
          _expiryDateField(),

          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isSaving || !_isDirty) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: _showPhotoSheet,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4), width: 2),
                image: _photoPath != null
                    ? DecorationImage(
                        image: FileImage(File(_photoPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _photoPath == null
                  ? const Icon(Icons.person,
                      color: AppColors.primaryLight, size: 48)
                  : null,
            ),
          ),
          GestureDetector(
            onTap: _showPhotoSheet,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0B0F1A), width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(children: [
              Icon(Icons.badge_outlined,
                  size: 16, color: context.colors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Role',
                style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
          const Divider(height: 1),
          ...List.generate(_roles.length, (i) {
            final (code, label, icon) = _roles[i];
            final selected = _role == code;
            return InkWell(
              onTap: () => setState(() {
                _role = code;
                _isDirty = true;
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  border: i < _roles.length - 1
                      ? Border(
                          bottom: BorderSide(
                              color: context.colors.border, width: 0.5))
                      : null,
                  borderRadius: i == _roles.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(10))
                      : null,
                ),
                child: Row(children: [
                  Icon(icon,
                      size: 16,
                      color: selected
                          ? AppColors.primary
                          : context.colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 16),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _expiryDateField() {
    final hasDate = _licenseExpiryDate != null && _licenseExpiryDate!.isNotEmpty;
    String displayText = 'Tap to select expiry date';
    Color textColor = context.colors.textMuted;

    if (hasDate) {
      try {
        final dt = DateTime.parse(_licenseExpiryDate!);
        displayText = DateFormat('dd MMMM yyyy').format(dt);
        final daysLeft = dt.difference(DateTime.now()).inDays;
        if (daysLeft < 0) {
          textColor = AppColors.danger;
          displayText += '  ·  EXPIRED';
        } else if (daysLeft <= 30) {
          textColor = AppColors.warning;
          displayText += '  ·  ${daysLeft}d left';
        } else {
          textColor = context.colors.textPrimary;
        }
      } catch (_) {
        displayText = _licenseExpiryDate!;
        textColor = context.colors.textPrimary;
      }
    }

    return GestureDetector(
      onTap: _pickExpiryDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'License Expiry Date',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(displayText,
                    style: TextStyle(color: textColor, fontSize: 14)),
              ],
            ),
          ),
          if (hasDate)
            GestureDetector(
              onTap: () => setState(() {
                _licenseExpiryDate = null;
                _isDirty = true;
              }),
              child: Icon(Icons.close,
                  size: 16, color: context.colors.textMuted),
            )
          else
            Icon(Icons.chevron_right, size: 18, color: context.colors.textMuted),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool highlighted = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon,
            size: 18,
            color: highlighted ? AppColors.primary : context.colors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: highlighted
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: highlighted
            ? AppColors.primary.withValues(alpha: 0.04)
            : context.colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
