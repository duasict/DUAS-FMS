import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/alert_model.dart';
import '../../theme/app_theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alerts = provider.alerts;
    final unread = provider.unreadAlertCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Alerts'),
            if (unread > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread unread',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : alerts.isEmpty
              ? Center(
                  child: Text('No alerts.',
                      style: TextStyle(color: context.colors.textSecondary)))
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.card,
                  onRefresh: provider.refreshAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    itemCount: alerts.length,
                    itemBuilder: (ctx, i) =>
                        _AlertTile(alert: alerts[i]),
                  ),
                ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isConcurrence = alert.isConcurrence;
    final isPending = alert.isPending;
    final accentColor =
        isConcurrence ? AppColors.warning : AppColors.primaryLight;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: alert.isRead
            ? context.colors.card
            : accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isRead
              ? context.colors.border
              : accentColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isConcurrence
                      ? Icons.pending_actions
                      : Icons.notifications_outlined,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!alert.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            margin: EdgeInsets.only(right: 6, top: 1),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              fontWeight: alert.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isConcurrence)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPending
                                  ? 'PENDING APPROVAL'
                                  : alert.status.toUpperCase(),
                              style: TextStyle(
                                color: isPending
                                    ? AppColors.warning
                                    : AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Spacer(),
                        Text(
                          _formatDate(alert.createdAt),
                          style: TextStyle(
                              color: context.colors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  void _showDetail(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (!alert.isRead) provider.markAlertRead(alert.id!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AlertDetailSheet(alert: alert),
    );
  }
}

class _AlertDetailSheet extends StatelessWidget {
  final AlertModel alert;
  const _AlertDetailSheet({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isConcurrence = alert.isConcurrence;
    final accentColor =
        isConcurrence ? AppColors.warning : AppColors.primaryLight;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isConcurrence
                      ? Icons.pending_actions
                      : Icons.notifications,
                  color: accentColor,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 16),
          Text(
            alert.message,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (alert.missionTitle != null) ...[
            const SizedBox(height: 20),
            _DetailRow(
                icon: Icons.flight, label: 'Related Mission',
                value: alert.missionTitle!),
          ],
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Received',
            value: alert.createdAt.replaceFirst('T', '  '),
          ),
          if (isConcurrence && alert.isPending) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textMuted),
          SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
