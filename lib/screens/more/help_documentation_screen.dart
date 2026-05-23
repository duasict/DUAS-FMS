import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HelpDocumentationScreen extends StatelessWidget {
  const HelpDocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Documentation')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _searchHint(context),
          const SizedBox(height: 16),
          _Section(
            icon: Icons.rocket_launch_outlined,
            title: 'Getting Started',
            children: const [
              _Entry(
                q: 'What is DUAS FMS?',
                a: 'DUAS FMS (Drone/UAS Fleet Management System) is an offline-first '
                    'mobile application for managing UAS flight operations in compliance '
                    'with CAAP SARP (Civil Aviation Authority of the Philippines '
                    'Standards and Recommended Practices) and ICAO Annex 2.',
              ),
              _Entry(
                q: 'How do I set up my profile?',
                a: 'Tap More → Profile. Fill in your name, position, and contact '
                    'details. If you hold a CAAP Remote Pilot License, tap '
                    '"License Verification" and scan your license card — the app '
                    'will OCR-read your license number and expiry date and assign '
                    'you the Pilot in Command (PIC) role.',
              ),
              _Entry(
                q: 'What roles are available?',
                a: 'CRP (Chief Remote Pilot) — mission authority, CRP concurrence\n'
                    'PIC (Pilot in Command) — licensed RPAS pilot, holds RPIC role during missions\n'
                    'VO (Visual Observer) — maintains situational awareness\n'
                    'GCS Operator — operates ground control station\n'
                    'Tech (Technical Crew Member) — equipment prep and maintenance\n\n'
                    'Roles are assigned at the organisation level in your profile. '
                    '"RPIC" is a mission-specific designation that maps to a verified PIC.',
              ),
            ],
          ),
          _Section(
            icon: Icons.route_outlined,
            title: 'Mission Workflow',
            children: const [
              _Entry(
                q: 'What is the full mission lifecycle?',
                a: '1. Create Mission — set title, date, location, aircraft, and crew\n'
                    '2. Flight Plan — area of operation, weather, NOTAMs, airspace, contingency\n'
                    '3. HIRA — identify hazards, assess likelihood × impact, set mitigations\n'
                    '4. CRP Approval — if any HIRA risk score ≥ 12, CRP must concur\n'
                    '5. Equipment Checklist — verify aircraft readiness\n'
                    '6. Fit-to-Fly — crew health and fitness declaration\n'
                    '7. Pre-flight Checklist — final on-site checks before launch\n'
                    '8. In-flight Checklist — active monitoring items\n'
                    '9. Post-flight Checklist — landing and pack-up verification\n'
                    '10. Flight Log — record actual sortie data, anomalies, next maintenance',
              ),
              _Entry(
                q: 'What triggers CRP Concurrence?',
                a: 'Any HIRA row with a residual risk score of 12 or higher '
                    '(Likelihood × Impact ≥ 12) automatically sets the mission flag '
                    '"CRP Concurrence Required". The CRP must review and approve '
                    'before flight operations begin.',
              ),
              _Entry(
                q: 'Can I complete the workflow without internet?',
                a: 'Yes. All data is stored locally in SQLite first. You can complete '
                    'the entire mission lifecycle offline. When connectivity is restored, '
                    'use More → Data & Storage → Sync to Cloud to push records to Supabase.',
              ),
            ],
          ),
          _Section(
            icon: Icons.shield_outlined,
            title: 'HIRA — Risk Matrix',
            children: const [
              _Entry(
                q: 'How is risk score calculated?',
                a: 'Risk Score = Likelihood × Impact\n\n'
                    'Likelihood scale (1–5):\n'
                    '  1 — Rare  2 — Unlikely  3 — Possible  4 — Likely  5 — Almost Certain\n\n'
                    'Impact scale (1–5):\n'
                    '  1 — Negligible  2 — Minor  3 — Moderate  4 — Major  5 — Catastrophic\n\n'
                    'Risk levels:\n'
                    '  1–4  → Low (green)\n'
                    '  5–9  → Medium (yellow)\n'
                    '  10–14 → High (orange) — CRP concurrence required\n'
                    '  15–25 → Critical (red) — CRP concurrence required',
              ),
              _Entry(
                q: 'What mitigations are required?',
                a: 'Every HIRA row must have a mitigation entered before the form can '
                    'be submitted. For high/critical risk rows, the mitigation must reduce '
                    'the residual risk to an acceptable level or the CRP concurrence '
                    'workflow is triggered.',
              ),
            ],
          ),
          _Section(
            icon: Icons.wifi_tethering_outlined,
            title: 'P2P Offline Concurrence',
            children: const [
              _Entry(
                q: 'What is P2P Concurrence?',
                a: 'When the CRP and RPIC are physically co-located but without internet, '
                    'the RPIC device can act as a local Wi-Fi hotspot and serve a web '
                    'interface for the CRP to review and approve/reject the mission from '
                    'any browser on port 7788.',
              ),
              _Entry(
                q: 'How do I use P2P Concurrence?',
                a: '1. Enable your device hotspot (Settings → Hotspot)\n'
                    '2. On the Mission Approval screen, tap "Start P2P Server"\n'
                    '3. The app shows a URL like http://192.168.43.1:7788\n'
                    '4. CRP connects to the hotspot and opens that URL in a browser\n'
                    '5. CRP reviews the HIRA summary and taps Approve or Reject\n'
                    '6. Result is recorded in the Alerts tab and the RPIC is notified',
              ),
            ],
          ),
          _Section(
            icon: Icons.build_circle_outlined,
            title: 'Maintenance & Records',
            children: const [
              _Entry(
                q: 'Where do I log maintenance?',
                a: 'More → Maintenance Log. Log scheduled/unscheduled maintenance, '
                    'post-incident inspections, and airworthiness status changes. '
                    'Records include parts replaced, flight hours, and sign-off.',
              ),
              _Entry(
                q: 'Where do I track battery health?',
                a: 'More → Battery Log. Record charge cycles, voltage before and after '
                    'charge, charge time, and battery status (Good / Degraded / Retired). '
                    'This helps comply with CAAP battery management requirements.',
              ),
              _Entry(
                q: 'When must I file an Incident Report?',
                a: 'CAAP requires reporting of any accident, serious incident, or '
                    'near-miss involving an RPAS. File via More → Incident Report. '
                    'Enable "Reported to CAAP" and enter the CAAP reference number '
                    'once you have submitted the official report.',
              ),
            ],
          ),
          _Section(
            icon: Icons.gavel_outlined,
            title: 'Regulatory References',
            children: const [
              _Entry(
                q: 'CAAP SARPs for RPAS',
                a: 'The app is designed to comply with the Civil Aviation Authority of '
                    'the Philippines Standards and Recommended Practices (CAAP SARPs) '
                    'for Remotely Piloted Aircraft Systems, covering:\n'
                    '  • Registration and airworthiness\n'
                    '  • Operational requirements and flight planning\n'
                    '  • Crew licensing (CAAP Remote Pilot License)\n'
                    '  • Incident and accident reporting',
              ),
              _Entry(
                q: 'ICAO Annex 2 — Rules of the Air',
                a: 'RPAS operations follow ICAO Annex 2 principles for right-of-way, '
                    'altitude limits, VLOS operations, and coordination with manned '
                    'aircraft. The checklist items reference these standards directly.',
              ),
              _Entry(
                q: 'Key altitude limits',
                a: 'Multi-rotor: RTH altitude ≥ 120 m AGL (Ch 3.4)\n'
                    'VTOL/Fixed-wing: RTH altitude ≥ 200 m AGL\n'
                    'Standard VLOS ceiling: 400 ft (≈ 120 m) AGL unless CAAP waiver obtained',
              ),
            ],
          ),
          _Section(
            icon: Icons.help_center_outlined,
            title: 'Troubleshooting',
            children: const [
              _Entry(
                q: 'OCR did not read my license correctly',
                a: 'Ensure good lighting with no glare on the card. Hold the phone '
                    'steady 15–25 cm from the card. The card must fill most of the '
                    'camera frame. Tap Retake if the preview is blurry or skewed.',
              ),
              _Entry(
                q: 'Sync is failing',
                a: '1. Check you are connected to Wi-Fi or mobile data\n'
                    '2. Ensure you are signed in (the app uses Supabase auth)\n'
                    '3. Confirm your organization ID is set in your profile\n'
                    '4. If the error persists, data is safely stored locally '
                    'and will retry on the next sync attempt.',
              ),
              _Entry(
                q: 'P2P server will not start',
                a: 'The app needs the device hotspot to be enabled first — the app '
                    'cannot enable it automatically due to Android restrictions. '
                    'Go to device Settings → Hotspot & Tethering, turn it on, '
                    'then return and tap "Start P2P Server" again.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        Icon(Icons.search, color: context.colors.textMuted, size: 18),
        const SizedBox(width: 8),
        Text('Scroll to browse topics',
            style:
                TextStyle(color: context.colors.textMuted, fontSize: 13)),
      ]),
    );
  }
}

// ── Collapsible section ───────────────────────────────────────────────────────

class _Section extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<_Entry> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(widget.icon, color: AppColors.primaryLight, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: context.colors.textMuted,
                size: 20,
              ),
            ]),
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: context.colors.border),
          ...widget.children.map((e) => _EntryTile(entry: e)),
        ],
      ]),
    );
  }
}

// ── Single Q&A entry ──────────────────────────────────────────────────────────

class _Entry {
  final String q;
  final String a;
  const _Entry({required this.q, required this.a});
}

class _EntryTile extends StatefulWidget {
  final _Entry entry;
  const _EntryTile({required this.entry});

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  _open
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.entry.q,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_open)
        Padding(
          padding: const EdgeInsets.fromLTRB(42, 0, 16, 14),
          child: Text(
            widget.entry.a,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
                height: 1.55),
          ),
        ),
      Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: context.colors.border.withValues(alpha: 0.5)),
    ]);
  }
}
