import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../providers/org_settings_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((i) { if (mounted) setState(() => _appVersion = i.version); });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signIn(email, password);

      // Sync remote profile into local DB before navigating so the rest of the
      // app immediately sees the correct name/role/org from Supabase.
      if (mounted) {
        await _syncProfileFromSupabase();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyAuthError(e.message));
    } catch (_) {
      setState(() =>
          _errorMessage = 'Unable to connect. Check your internet connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pull the signed-in user's profile from Supabase and write it to the
  /// local SQLite DB.  Non-fatal — if Supabase is unreachable we proceed with
  /// whatever is stored locally.
  Future<void> _syncProfileFromSupabase() async {
    final userId = SupabaseService.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    try {
      final remote = await SupabaseService.fetchProfile(userId);
      if (remote == null) return;

      // Use existing local record as the base so device-only fields
      // (photoPath, license scan data) are preserved.
      final existing = await DatabaseHelper.instance.getUserProfile();

      // Supabase stores license_verified / face_verified as PostgreSQL
      // booleans; the Dart client returns them as bool.
      bool remoteBool(String key, bool? fallback) {
        final v = remote[key];
        if (v is bool) return v;
        if (v is int) return v == 1;
        return fallback ?? false;
      }

      final updated = UserProfile(
        id: existing?.id,
        supabaseId: userId,
        name: (remote['name'] as String?)?.isNotEmpty == true
            ? remote['name'] as String
            : existing?.name ?? '',
        role: remote['role'] as String? ?? existing?.role ?? 'vo',
        email: remote['email'] as String? ?? existing?.email ?? '',
        unit: remote['unit'] as String? ?? existing?.unit ?? '',
        phone: remote['phone'] as String? ?? existing?.phone ?? '',
        organizationId:
            remote['organization_id'] as String? ?? existing?.organizationId ?? '',
        licenseNumber:
            remote['license_number'] as String? ?? existing?.licenseNumber ?? '',
        licenseExpiryDate: (remote['license_expiry_date'] as String?)?.isEmpty == true
            ? existing?.licenseExpiryDate
            : remote['license_expiry_date'] as String? ?? existing?.licenseExpiryDate,
        licenseVerified:
            remoteBool('license_verified', existing?.licenseVerified),
        faceVerified: remoteBool('face_verified', existing?.faceVerified),
        // photoPath is device-only — never overwrite from server
        photoPath: existing?.photoPath,
      );

      await DatabaseHelper.instance.saveUserProfile(updated);

      if (mounted) {
        await context.read<UserProfileProvider>().load();
      }
    } catch (_) {
      // Non-fatal — proceed with local profile
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(
          () => _errorMessage = 'Enter your email address above first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyAuthError(e.message));
    } catch (_) {
      setState(() => _errorMessage = 'Failed to send reset email.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgSettingsProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // App logo & branding
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.air, color: AppColors.primary, size: 36),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.appName,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      org.tagline,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 56),
              Text(
                'Sign In',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Authorized personnel only.',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // Email field
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: context.colors.textPrimary),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon:
                      Icon(Icons.email_outlined, color: context.colors.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              // Password field
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: TextStyle(color: context.colors.textPrimary),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: context.colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.colors.textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AppColors.primaryLight, fontSize: 13),
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              // Sign In button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ),

              const SizedBox(height: 60),

              // Footer badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    '🔒  ${org.orgName}${_appVersion.isNotEmpty ? '  ·  v$_appVersion' : ''}',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
