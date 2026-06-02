import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/database_helper.dart';
import '../../models/user_profile.dart';
import '../../providers/org_settings_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Registration screen.
///
/// Requires a valid organization code (UUID) before the account can be
/// created.  On success the user is prompted to verify their email before
/// signing in for the first time.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _orgCodeCtrl  = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;
  bool _success         = false;
  String? _error;

  // UUID v4 pattern — org codes are Supabase UUIDs
  static final _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _orgCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final orgCode = _orgCodeCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || orgCode.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (!_uuidRe.hasMatch(orgCode)) {
      setState(() => _error =
          'Invalid organization code. Ask your CRP for the correct code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.signUp(email, pass);

      // Save name + org code locally so they are applied to the Supabase
      // profile on first login (in case email confirmation is required and
      // we don't have a session yet).
      await DatabaseHelper.instance.saveUserProfile(UserProfile(
        supabaseId: response.user?.id ?? '',
        name: name,
        email: email,
        organizationId: orgCode,
        role: 'vo',
      ));

      // If Supabase returned an immediate session (email confirmation
      // disabled), push the profile data now.
      if (response.session != null && response.user != null) {
        try {
          await SupabaseService.upsertProfile({
            'id': response.user!.id,
            'name': name,
            'organization_id': orgCode,
            'email': email,
            'role': 'vo',
          });
        } catch (_) {
          // Non-fatal — will be applied on first login
        }
      }

      if (mounted) setState(() { _isLoading = false; _success = true; });
    } on AuthException catch (e) {
      setState(() {
        _error = _friendlyError(e.message);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to connect. Check your internet connection.';
        _isLoading = false;
      });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('invalid email')) return 'Please enter a valid email address.';
    if (lower.contains('weak password') || lower.contains('password should')) {
      return 'Password is too weak. Use at least 6 characters.';
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
          child: _success ? _buildSuccess(context) : _buildForm(context, org),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, OrgSettingsProvider org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),

        // Branding header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child:
                const Icon(Icons.air, color: AppColors.primary, size: 36),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(org.appName,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5)),
              Text(org.tagline,
                  style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.3)),
            ],
          ),
        ]),

        const SizedBox(height: 40),
        Text('Create Account',
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('You will need an organization code from your CRP.',
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13)),

        const SizedBox(height: 28),

        // Full name
        _field(
          controller: _nameCtrl,
          label: 'Full Name',
          icon: Icons.person_outline,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Email
        _field(
          controller: _emailCtrl,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Password
        _passwordField(
          controller: _passwordCtrl,
          label: 'Password',
          obscure: _obscurePassword,
          onToggle: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Confirm password
        _passwordField(
          controller: _confirmCtrl,
          label: 'Confirm Password',
          obscure: _obscureConfirm,
          onToggle: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Org code
        TextField(
          controller: _orgCodeCtrl,
          style:
              TextStyle(color: context.colors.textPrimary, fontSize: 13),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signUp(),
          decoration: InputDecoration(
            labelText: 'Organization Code',
            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            hintStyle: TextStyle(
                color: context.colors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace'),
            prefixIcon: Icon(Icons.key_outlined,
                color: context.colors.textMuted, size: 18),
            helperText: 'Ask your CRP for this code.',
            helperStyle:
                TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ),

        // Error banner
        if (_error != null) ...[
          const SizedBox(height: 16),
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
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // Sign Up button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Create Account'),
          ),
        ),

        const SizedBox(height: 16),

        // Back to login
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Already have an account?',
              style: TextStyle(
                  color: context.colors.textMuted, fontSize: 13)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sign in',
                style: TextStyle(
                    color: AppColors.primaryLight, fontSize: 13)),
          ),
        ]),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4), width: 1.5),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 28),
        Text('Account Created!',
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'Check your email to verify your account,\nthen sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          _emailCtrl.text.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: action,
      style: TextStyle(color: context.colors.textPrimary),
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, color: context.colors.textMuted, size: 18),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      style: TextStyle(color: context.colors.textPrimary),
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(Icons.lock_outline, color: context.colors.textMuted, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: context.colors.textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
