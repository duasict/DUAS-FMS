import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CrewManagementScreen  (CRP-only)
//
//  Lists every member in the current organisation, supports:
//    • Changing a member's org-level role
//    • Removing a member from the org
//    • Copying the org join-code (organisation_id UUID)
// ─────────────────────────────────────────────────────────────────────────────

class CrewManagementScreen extends StatefulWidget {
  const CrewManagementScreen({super.key});

  @override
  State<CrewManagementScreen> createState() => _CrewManagementScreenState();
}

class _CrewManagementScreenState extends State<CrewManagementScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _error;

  // Profile-level roles (must match profiles.role CHECK constraint in schema)
  static const _orgRoles = ['vo', 'gcs', 'tech', 'pic', 'crp'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final orgId =
          context.read<UserProfileProvider>().profile.organizationId;
      if (orgId.isEmpty) {
        setState(() { _isLoading = false; _members = []; });
        return;
      }
      final rows = await SupabaseService.fetchOrgMembers(orgId);
      if (mounted) setState(() { _members = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Role change dialog ─────────────────────────────────────────────────────

  Future<void> _changeRole(Map<String, dynamic> member) async {
    final current = member['role'] as String? ?? 'vo';
    String selected = current;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: ctx.colors.card,
          title: Text('Change Role',
              style: TextStyle(color: ctx.colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member['name'] as String? ?? member['email'] as String? ?? '—',
                style: TextStyle(
                    color: ctx.colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ...(_orgRoles.map((r) {
                    final isSelected = r == selected;
                    return GestureDetector(
                      onTap: () => setInner(() => selected = r),
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : ctx.colors.border,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary
                                : ctx.colors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_roleLabel(r),
                                    style: TextStyle(
                                        color: ctx.colors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                                Text(_roleDesc(r),
                                    style: TextStyle(
                                        color: ctx.colors.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    );
                  })),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: ctx.colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selected == current
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService.updateMemberRole(
          member['id'] as String, selected);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update role: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  // ── Remove member dialog ───────────────────────────────────────────────────

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final name =
        member['name'] as String? ?? member['email'] as String? ?? '—';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: Text('Remove Member',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text(
          'Remove $name from your organisation?\n\n'
          'They will lose access to shared missions and records. '
          'Their account is not deleted.',
          style: TextStyle(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService.removeOrgMember(member['id'] as String);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name removed from organisation.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to remove member: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final orgId = profile.organizationId;
    final myId = profile.supabaseId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crew Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: Column(children: [
        // ── Org join code card ──────────────────────────────────────────────
        if (orgId.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Row(children: [
                Icon(Icons.key_outlined,
                    size: 13, color: AppColors.primaryLight),
                SizedBox(width: 6),
                Text('ORG JOIN CODE',
                    style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    orgId,
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: orgId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Join code copied to clipboard.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Copy',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'Share this code with pilots and VOs to let them join your organisation.',
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 11),
              ),
            ]),
          ),

        const SizedBox(height: 10),

        // ── Member count header ─────────────────────────────────────────────
        if (!_isLoading && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Text(
                '${_members.length} member${_members.length == 1 ? '' : 's'}',
                style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),

        const SizedBox(height: 6),

        // ── List body ───────────────────────────────────────────────────────
        Expanded(child: _buildBody(myId)),
      ]),
    );
  }

  Widget _buildBody(String myId) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              'Could not load members.\n$_error',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Text(
          'No members found in your organisation.',
          style: TextStyle(
              color: context.colors.textSecondary, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.colors.card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _members.length,
        itemBuilder: (_, i) {
        final m = _members[i];
        final isMe = (m['id'] as String?) == myId;
        final role = m['role'] as String? ?? 'vo';
        final licVerified = (m['license_verified'] as int? ?? 0) == 1;
        final email = m['email'] as String? ?? '';
        final name = m['name'] as String? ?? email;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            title: Row(children: [
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              if (isMe)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('YOU',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(email,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Row(children: [
                _RoleBadge(role: role),
                if (licVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 3),
                  const Text('Verified',
                      style: TextStyle(
                          color: AppColors.success, fontSize: 10)),
                ],
              ]),
            ]),
            trailing: isMe
                ? null
                : PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: context.colors.textMuted),
                    color: context.colors.card,
                    onSelected: (v) {
                      if (v == 'role') _changeRole(m);
                      if (v == 'remove') _removeMember(m);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'role',
                        child: Row(children: [
                          const Icon(Icons.manage_accounts_outlined,
                              size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 10),
                          Text('Change Role',
                              style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 13)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          const Icon(Icons.person_remove_outlined,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: 10),
                          const Text('Remove from Org',
                              style: TextStyle(
                                  color: AppColors.danger, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ),
            isThreeLine: true,
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
        );
        },
      ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'crp':   return 'CRP — Safety Officer';
      case 'rpic':  return 'RPIC — Pilot in Command';
      case 'admin': return 'Admin';
      default:      return 'VO — Visual Observer';
    }
  }

  String _roleDesc(String r) {
    switch (r) {
      case 'crp':   return 'Reviews missions, grants concurrence.';
      case 'rpic':  return 'Can create and lead missions.';
      case 'admin': return 'Full org management access.';
      default:      return 'Standard crew member, assigned to missions.';
    }
  }
}

// ── Role badge chip ──────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (role) {
      case 'crp':   color = AppColors.danger;  break;
      case 'rpic':  color = AppColors.primary; break;
      case 'admin': color = AppColors.accent;  break;
      default:      color = AppColors.success; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}
