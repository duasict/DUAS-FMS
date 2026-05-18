import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late final TextEditingController _rankCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _phoneCtrl;

  String? _photoPath;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _nameCtrl = TextEditingController(text: p.name);
    _rankCtrl = TextEditingController(text: p.rank);
    _emailCtrl = TextEditingController(text: p.email);
    _unitCtrl = TextEditingController(text: p.unit);
    _licenseCtrl = TextEditingController(text: p.licenseNumber);
    _phoneCtrl = TextEditingController(text: p.phone);
    _photoPath = p.photoPath;

    for (final c in [
      _nameCtrl,
      _rankCtrl,
      _emailCtrl,
      _unitCtrl,
      _licenseCtrl,
      _phoneCtrl
    ]) {
      c.addListener(() => setState(() => _isDirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _rankCtrl,
      _emailCtrl,
      _unitCtrl,
      _licenseCtrl,
      _phoneCtrl
    ]) {
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
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary, size: 20),
            ),
            title: Text('Take Photo',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary, size: 20),
            ),
            title: Text('Choose from Gallery',
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          if (_photoPath != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 20),
              ),
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name is required.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isSaving = true);

    final updated = UserProfile(
      id: context.read<UserProfileProvider>().profile.id,
      name: _nameCtrl.text.trim(),
      rank: _rankCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      licenseNumber: _licenseCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      photoPath: _photoPath,
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
            controller: _rankCtrl,
            label: 'Rank / Title',
            hint: 'e.g. Captain, 1Lt., Major',
            icon: Icons.military_tech_outlined,
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
          _sectionLabel('UNIT & CERTIFICATION'),
          const SizedBox(height: 10),
          _field(
            controller: _unitCtrl,
            label: 'Unit / Organization',
            hint: 'e.g. UAS Operations Unit, 1st Aviation Bn',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _licenseCtrl,
            label: 'UAS License Number',
            hint: 'e.g. CAAP-UAS-2024-00123',
            icon: Icons.badge_outlined,
            highlighted: true,
          ),
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
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
