import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/org_settings_provider.dart';
import '../../services/org_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/org_logo.dart';
import '../login_screen.dart';

/// First-run wizard (or Settings edit) for configuring the deploying organization.
///
/// - [editMode] = false → shown on first launch; navigates to [LoginScreen] on save.
/// - [editMode] = true  → opened from Settings by a CRP; pops on save.
class OrgSetupScreen extends StatefulWidget {
  final bool editMode;
  const OrgSetupScreen({super.key, this.editMode = false});

  @override
  State<OrgSetupScreen> createState() => _OrgSetupScreenState();
}

class _OrgSetupScreenState extends State<OrgSetupScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _orgNameCtrl   = TextEditingController();
  final _appNameCtrl   = TextEditingController();
  final _prefixCtrl    = TextEditingController();
  final _taglineCtrl   = TextEditingController();
  final _sloganCtrl    = TextEditingController();
  String _logoPath     = '';
  bool   _isSaving     = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final s = await OrgSettingsService.load();
    final d = OrgSettings.defaults;
    if (!mounted) return;
    setState(() {
      _orgNameCtrl.text = s.orgName   != d.orgName   ? s.orgName   : '';
      _appNameCtrl.text = s.appName   != d.appName   ? s.appName   : '';
      _prefixCtrl.text  = s.missionPrefix;
      _taglineCtrl.text = s.tagline   != d.tagline   ? s.tagline   : '';
      _sloganCtrl.text  = s.slogan    != d.slogan    ? s.slogan    : '';
      _logoPath         = s.logoPath;
    });
  }

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _appNameCtrl.dispose();
    _prefixCtrl.dispose();
    _taglineCtrl.dispose();
    _sloganCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null || !mounted) return;

    // Copy to app documents directory so the path survives cache clears.
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/org_logo.png');
    await File(picked.path).copy(dest.path);

    setState(() => _logoPath = dest.path);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final d = OrgSettings.defaults;
    final settings = OrgSettings(
      orgName: _orgNameCtrl.text.trim().isNotEmpty
          ? _orgNameCtrl.text.trim() : d.orgName,
      appName: _appNameCtrl.text.trim().isNotEmpty
          ? _appNameCtrl.text.trim() : d.appName,
      missionPrefix: _prefixCtrl.text.trim().toUpperCase().isNotEmpty
          ? _prefixCtrl.text.trim().toUpperCase() : d.missionPrefix,
      tagline: _taglineCtrl.text.trim().isNotEmpty
          ? _taglineCtrl.text.trim() : d.tagline,
      slogan: _sloganCtrl.text.trim().isNotEmpty
          ? _sloganCtrl.text.trim() : d.slogan,
      logoPath: _logoPath,
    );

    if (!mounted) return;
    await context.read<OrgSettingsProvider>().save(settings);
    if (!mounted) return;

    setState(() => _isSaving = false);

    if (widget.editMode) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.editMode
          ? AppBar(title: const Text('Organization Settings'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.editMode) ...[
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.business_outlined,
                          color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Organization Setup',
                                style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('One-time configuration for your fleet.',
                                style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 13)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 28),
                ],

                // ── Required ───────────────────────────────────────────────
                _sectionLabel(context, 'REQUIRED'),
                const SizedBox(height: 10),

                _field(
                  controller: _orgNameCtrl,
                  label: 'Organization Name *',
                  hint: 'e.g. Davao UAS Operations',
                  icon: Icons.business_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _prefixCtrl,
                  label: 'Mission ID Prefix *',
                  hint: 'e.g. UAS  →  UAS-2025-001',
                  icon: Icons.tag_outlined,
                  maxLength: 8,
                  caps: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Z0-9\-]+$')
                        .hasMatch(v.trim().toUpperCase())) {
                      return 'Letters, numbers, and hyphens only';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── Branding (optional) ────────────────────────────────────
                _sectionLabel(context, 'BRANDING'),
                const SizedBox(height: 4),
                Text(
                  'Customize the app name, logo, and splash screen to match '
                  'your organization\'s identity.',
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11.5),
                ),
                const SizedBox(height: 12),

                // Logo picker tile
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(children: [
                      OrgLogo(
                          size: 56,
                          circular: false,
                          logoPathOverride:
                              _logoPath.isNotEmpty ? _logoPath : null),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Organization Logo',
                                style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              _logoPath.isNotEmpty
                                  ? 'Tap to change logo'
                                  : 'Tap to upload a logo from your gallery',
                              style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: context.colors.textMuted, size: 20),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),
                _field(
                  controller: _appNameCtrl,
                  label: 'Short App Name',
                  hint: 'e.g. ACME  (max 6 chars, shown on splash)',
                  icon: Icons.label_outline,
                  maxLength: 6,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _taglineCtrl,
                  label: 'App Tagline',
                  hint: 'e.g. UAS Fleet Management',
                  icon: Icons.format_quote_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _sloganCtrl,
                  label: 'Org Slogan',
                  hint: 'e.g. Safe  •  Responsible  •  Professional',
                  icon: Icons.star_border_outlined,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(_isSaving
                        ? 'Saving…'
                        : widget.editMode
                            ? 'Save Changes'
                            : 'Set Up Organization'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                if (!widget.editMode) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      child: Text('Skip for now',
                          style: TextStyle(
                              color: context.colors.textMuted, fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int? maxLength,
    bool caps = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.words,
      style: TextStyle(color: context.colors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: context.colors.textMuted, size: 18),
        counterText: '',
      ),
    );
  }
}
