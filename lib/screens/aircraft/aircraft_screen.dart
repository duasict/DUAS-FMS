import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/aircraft.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import 'aircraft_form_screen.dart';

class AircraftScreen extends StatelessWidget {
  const AircraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aircraft = context.watch<AppProvider>().aircraft;

    return Scaffold(
      appBar: AppBar(title: const Text('Aircraft Fleet')),
      body: aircraft.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: aircraft.length,
              itemBuilder: (context, i) =>
                  _AircraftCard(aircraft: aircraft[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Aircraft',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.air, size: 56, color: context.colors.textMuted),
        const SizedBox(height: 12),
        Text('No aircraft registered',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Tap + Add Aircraft to register your first platform.',
            style:
                TextStyle(color: context.colors.textMuted, fontSize: 13)),
      ]),
    );
  }

  void _openForm(BuildContext context, Aircraft? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AircraftFormScreen(aircraft: existing)),
    );
  }
}

class _AircraftCard extends StatelessWidget {
  final Aircraft aircraft;
  const _AircraftCard({required this.aircraft});

  Color _statusColor(String s) {
    switch (s) {
      case 'serviceable':
        return AppColors.success;
      case 'under_maintenance':
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(aircraft.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AircraftFormScreen(aircraft: aircraft)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(aircraft.typeLabel,
                        style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(aircraft.statusLabel,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(aircraft.name,
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _row(context, Icons.memory_outlined, 'Model', aircraft.model),
                if (aircraft.serialNumber.isNotEmpty)
                  _row(context, Icons.qr_code_outlined, 'Serial',
                      aircraft.serialNumber),
                _row(context, Icons.monitor_weight_outlined, 'MTOW',
                    '${aircraft.mtow} kg'),
              ]),
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        Icon(icon, size: 12, color: context.colors.textMuted),
        const SizedBox(width: 5),
        Text('$label: ',
            style: TextStyle(
                color: context.colors.textMuted, fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
