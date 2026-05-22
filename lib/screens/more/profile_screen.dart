import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../license/license_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _phoneCtrl;

  String _role = 'vo';
  String? _photoPath;
  bool _isSaving = false;
  bool _isDirty = false;

  // Roles the user can manually select. 'pic' is auto-assigned by license
  // verification; 'crp' is admin-assigned — neither appears here as a tap target.
  static const _selectableRoles = [
    ('vo',   'Visual Observer',  Icons.visibility_outlined),
    ('gcs',  'GCS Operator',     Icons.settings_remote_outlined),
    ('tech', 'Technical Crew Member', Icons.build_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _nameCtrl  = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _unitCtrl  = TextEditingController(text: p.unit);
    _phoneCtrl = TextEditingController(text: p.phone);
    // Only set a selectable role; crp/pic kept as-is
    _role      = p.role;
    _photoPath = p.photoPath;

    for (final c in [_nameCtrl, _emailCtrl, _unitCtrl, _phoneCtrl]) {
      c.addListener(() => setState(() => _isDirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _unitCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_photo.jpg');
    await File(picked.path).copy(dest.path);

    setState(() {
      _photoPath = dest.path;
      _isDirty   = true;
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
            width: 36, height: 4,
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
                  _isDirty   = true;
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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name is required.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isSaving = true);

    final existing = context.read<UserProfileProvider>().profile;

    // Preserve license fields — they come only from LicenseVerificationScreen.
    // Preserve role if CRP or PIC (those are not manually selectable here).
    final finalRole = (existing.role == 'crp' || existing.role == 'pic')
        ? existing.role
        : _role;

    final updated = existing.copyWith(
      name:          _nameCtrl.text.trim(),
      role:          finalRole,
      email:         _emailCtrl.text.trim(),
      unit:          _unitCtrl.text.trim(),
      phone:         _phoneCtrl.text.trim(),
      photoPath:     _photoPath,
      clearPhoto:    _photoPath == null,
    );

    await context.read<UserProfileProvider>().update(updated);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isDirty  = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile saved.'), backgroundColor: AppColors.success));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch so the certification card refreshes after returning from verification
    final profile = context.watch<UserProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16, height: 16,
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

          // ── Personal ────────────────────────────────────────────────────
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

          // ── Role ────────────────────────────────────────────────────────
          _sectionLabel('ROLE & UNIT'),
          const SizedBox(height: 10),
          _roleSelector(profile),
          const SizedBox(height: 14),
          _field(
            controller: _unitCtrl,
            label: 'Unit / Organization',
            hint: 'e.g. UAS Operations Unit, 1st Aviation Bn',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 28),

          // ── Certification ────────────────────────────────────────────────
          _sectionLabel('CAAP LICENSE'),
          const SizedBox(height: 10),
          _certificationCard(profile),
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
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _avatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: _showPhotoSheet,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4), width: 2),
                image: _photoPath != null
                    ? DecorationImage(
                        image: FileImage(File(_photoPath!)),
                        fit: BoxFit.cover)
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
              width: 30, height: 30,
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

  // ── Role selector ──────────────────────────────────────────────────────────

  Widget _roleSelector(UserProfile profile) {
    final isCrp = profile.role == 'crp';
    final isPic = profile.role == 'pic';

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
              Text('Role',
                  style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          const Divider(height: 1),

          // CRP / PIC — read-only header rows
          if (isCrp)
            _roleRow(
              icon: Icons.stars_outlined,
              label: 'Chief Remote Pilot',
              sublabel: 'Assigned by organization — cannot be changed',
              selected: true,
              locked: true,
              isLast: false,
            ),
          if (isPic)
            _roleRow(
              icon: Icons.verified_outlined,
              label: 'Pilot in Command',
              sublabel: 'Granted via CAAP license verification',
              selected: true,
              locked: true,
              isLast: false,
            ),

          // PIC hint row — shown when NOT already pic/crp
          if (!isCrp && !isPic)
            _roleRow(
              icon: Icons.lock_outline,
              label: 'Pilot in Command',
              sublabel: 'Scan your CAAP license to unlock',
              selected: false,
              locked: true,
              isLast: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LicenseVerificationScreen()),
              ),
            ),

          // Selectable roles (only enabled for non-crp / non-pic)
          ...List.generate(_selectableRoles.length, (i) {
            final (code, label, icon) = _selectableRoles[i];
            final isLast = i == _selectableRoles.length - 1;
            final selected = !isCrp && !isPic && _role == code;
            final disabled = isCrp || isPic;
            return _roleRow(
              icon: icon,
              label: label,
              selected: selected,
              locked: disabled,
              isLast: isLast,
              onTap: disabled
                  ? null
                  : () => setState(() {
                        _role    = code;
                        _isDirty = true;
                      }),
            );
          }),
        ],
      ),
    );
  }

  Widget _roleRow({
    required IconData icon,
    required String label,
    String? sublabel,
    required bool selected,
    required bool locked,
    required bool isLast,
    VoidCallback? onTap,
  }) {
    final effectiveColor = locked && !selected
        ? context.colors.textMuted
        : selected
            ? AppColors.primary
            : context.colors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: !isLast
              ? Border(
                  bottom: BorderSide(
                      color: context.colors.border, width: 0.5))
              : null,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(10))
              : null,
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: effectiveColor,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal)),
                if (sublabel != null)
                  Text(sublabel,
                      style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 10)),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          if (locked && !selected && onTap != null)
            Icon(Icons.chevron_right,
                color: context.colors.textMuted, size: 16),
        ]),
      ),
    );
  }

  // ── Certification card ─────────────────────────────────────────────────────

  Widget _certificationCard(UserProfile profile) {
    final verified  = profile.licenseVerified;
    final expired   = profile.isLicenseExpired;
    final soonExp   = profile.isLicenseExpiringSoon;
    final hasLicense = profile.licenseNumber.isNotEmpty;

    Color borderColor;
    Color iconColor;
    IconData statusIcon;
    String statusText;

    if (verified && !expired) {
      borderColor = soonExp
          ? AppColors.warning.withValues(alpha: 0.4)
          : AppColors.success.withValues(alpha: 0.3);
      iconColor   = soonExp ? AppColors.warning : AppColors.success;
      statusIcon  = soonExp ? Icons.warning_amber_outlined : Icons.verified_outlined;
      statusText  = soonExp ? 'Expiring Soon' : 'Verified';
    } else if (verified && expired) {
      borderColor = AppColors.danger.withValues(alpha: 0.4);
      iconColor   = AppColors.danger;
      statusIcon  = Icons.error_outline;
      statusText  = 'Expired — Re-verify';
    } else {
      borderColor = context.colors.border;
      iconColor   = context.colors.textMuted;
      statusIcon  = Icons.badge_outlined;
      statusText  = 'Not Verified';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(children: [
            Icon(statusIcon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(statusText,
                style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (profile.faceVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.face, color: AppColors.success, size: 11),
                  const SizedBox(width: 3),
                  const Text('Face',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),

          if (hasLicense) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _certRow(Icons.badge_outlined, 'License No.',
                profile.licenseNumber),
            if (profile.licenseExpiryDate != null) ...[
              const SizedBox(height: 6),
              _certRow(
                Icons.event_outlined,
                'Valid Until',
                _fmtExpiry(profile.licenseExpiryDate!),
                valueColor: expired
                    ? AppColors.danger
                    : soonExp
                        ? AppColors.warning
                        : context.colors.textPrimary,
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No license on record. Scan your CAAP Remote Pilot '
              'Certificate to verify and receive PIC status.',
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  height: 1.4),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LicenseVerificationScreen()),
              ),
              icon: const Icon(Icons.document_scanner_outlined, size: 16),
              label: Text(hasLicense ? 'Re-Verify License' : 'Verify License',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _certRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(children: [
      Icon(icon, size: 13, color: context.colors.textMuted),
      const SizedBox(width: 8),
      SizedBox(
          width: 90,
          child: Text('$label:',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12))),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
              color: valueColor ?? context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: label == 'License No.' ? 'monospace' : null),
        ),
      ),
    ]);
  }

  String _fmtExpiry(String isoDate) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
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
