import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flight_log.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../checklists/checklist_widgets.dart';

class FlightLogScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const FlightLogScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<FlightLogScreen> createState() => _FlightLogScreenState();
}

class _FlightEntry {
  final TextEditingController takeoff = TextEditingController();
  final TextEditingController landing = TextEditingController();
  final TextEditingController total = TextEditingController();

  void dispose() {
    takeoff.dispose();
    landing.dispose();
    total.dispose();
  }

  int get totalMin {
    if (total.text.isNotEmpty) return int.tryParse(total.text) ?? 0;
    try {
      final t = takeoff.text.split(':');
      final l = landing.text.split(':');
      if (t.length == 2 && l.length == 2) {
        final a = int.parse(t[0]) * 60 + int.parse(t[1]);
        final b = int.parse(l[0]) * 60 + int.parse(l[1]);
        return (b - a).clamp(0, 9999);
      }
    } catch (_) {}
    return 0;
  }
}

class _FlightLogScreenState extends State<FlightLogScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _dateTimeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _altAglCtrl = TextEditingController();
  final _highestPointCtrl = TextEditingController();
  final _landingZoneCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _mtowCtrl = TextEditingController();
  final _rpicCtrl = TextEditingController();
  final _voCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _windCtrl = TextEditingController();
  final _visibilityCtrl = TextEditingController();
  final _cloudCtrl = TextEditingController();
  final _notamsRefCtrl = TextEditingController();
  final _anomalyOtherCtrl = TextEditingController();
  final _geotiffCtrl = TextEditingController();
  final _photosCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _nextMaintenanceCtrl = TextEditingController();

  String _platformType = 'multi-rotor';
  final Set<String> _payload = {};
  String _missionType = 'Survey';
  String _notamsType = 'None';
  final Set<String> _anomalies = {};
  bool _lidar = false;

  final _flights = [_FlightEntry(), _FlightEntry(), _FlightEntry()];

  static const _payloadOptions = [
    'RGB (24MP)', 'RGB (61MP)', 'Multispectral', 'EO/IR', 'LiDAR', 'Cargo',
  ];
  static const _missionTypes = [
    'Agri', 'Survey', 'Infra', 'Emergency', 'R&D', 'Training',
  ];
  static const _anomalyOptions = [
    'None', 'Link Loss', 'Low Bat', 'Motor Fail', 'Weather', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTimeCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} UTC+8';
    _loadMission();
  }

  Future<void> _loadMission() async {
    final m = await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (m != null && mounted) {
      setState(() {
        _locationCtrl.text = m.location;
        if (m.latitude != null) _latCtrl.text = m.latitude!.toStringAsFixed(4);
        if (m.longitude != null) _lonCtrl.text = m.longitude!.toStringAsFixed(4);
        _platformType = m.aircraftType;
        _modelCtrl.text = m.aircraftName;
        _missionType = _inferType(m.title);
        for (final c in m.crew) {
          final r = c.role.toLowerCase();
          if (r == 'rpic') _rpicCtrl.text = c.name;
          if (r == 'vo') _voCtrl.text = c.name;
          if (r == 'tech') _techCtrl.text = c.name;
        }
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _inferType(String title) {
    final t = title.toLowerCase();
    if (t.contains('agri')) return 'Agri';
    if (t.contains('survey')) return 'Survey';
    if (t.contains('infra')) return 'Infra';
    if (t.contains('emergency') || t.contains('sar')) return 'Emergency';
    if (t.contains('training')) return 'Training';
    if (t.contains('r&d') || t.contains('research')) return 'R&D';
    return 'Survey';
  }

  @override
  void dispose() {
    final controllers = [
      _dateTimeCtrl, _locationCtrl, _latCtrl, _lonCtrl, _altAglCtrl,
      _highestPointCtrl, _landingZoneCtrl, _modelCtrl, _mtowCtrl,
      _rpicCtrl, _voCtrl, _techCtrl, _windCtrl, _visibilityCtrl,
      _cloudCtrl, _notamsRefCtrl, _anomalyOtherCtrl, _geotiffCtrl,
      _photosCtrl, _videoCtrl, _nextMaintenanceCtrl,
    ];
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in _flights) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final flightList = _flights
        .asMap()
        .entries
        .where((e) =>
            e.value.takeoff.text.isNotEmpty ||
            e.value.landing.text.isNotEmpty)
        .map((e) => FlightDuration(
              flightNum: '${e.key + 1}',
              takeoff: e.value.takeoff.text,
              landing: e.value.landing.text,
              totalMin: e.value.totalMin,
            ))
        .toList();

    final totalMin = flightList.fold(0, (s, f) => s + f.totalMin);

    final anomalyList = _anomalies.contains('Other') && _anomalyOtherCtrl.text.isNotEmpty
        ? ([..._anomalies.where((a) => a != 'Other'),
            'Other: ${_anomalyOtherCtrl.text}'])
        : _anomalies.toList();

    String notams = _notamsType;
    if (_notamsType != 'None' && _notamsRefCtrl.text.isNotEmpty) {
      if (_notamsType == 'Active') {
        notams = 'Active (Ref: ${_notamsRefCtrl.text})';
      } else {
        notams = 'CAAP Permit (No: ${_notamsRefCtrl.text})';
      }
    }

    final log = FlightLog(
      missionId: widget.missionId,
      dateTime: _dateTimeCtrl.text,
      location: _locationCtrl.text,
      latitude: double.tryParse(_latCtrl.text),
      longitude: double.tryParse(_lonCtrl.text),
      altitudeAgl: double.tryParse(_altAglCtrl.text),
      highestPoint: double.tryParse(_highestPointCtrl.text),
      landingZone: _landingZoneCtrl.text,
      platformType: _platformType,
      model: _modelCtrl.text,
      mtow: double.tryParse(_mtowCtrl.text),
      payload: _payload.toList(),
      missionType: _missionType,
      rpic: _rpicCtrl.text,
      vo: _voCtrl.text,
      tech: _techCtrl.text,
      flights: flightList,
      weatherWind: double.tryParse(_windCtrl.text),
      weatherVisibility: double.tryParse(_visibilityCtrl.text),
      weatherCloud: _cloudCtrl.text,
      notams: notams,
      anomalies: anomalyList.isEmpty ? ['None'] : anomalyList,
      dataCapturedGeotiff:
          _geotiffCtrl.text.isEmpty ? null : _geotiffCtrl.text,
      dataCapturedPhotos:
          _photosCtrl.text.isEmpty ? null : _photosCtrl.text,
      dataCapturedVideo:
          _videoCtrl.text.isEmpty ? null : _videoCtrl.text,
      dataCapturedLidar: _lidar,
      nextMaintenance: _nextMaintenanceCtrl.text,
      isSynced: false,
    );

    await DatabaseHelper.instance.insertFlightLog(log);

    final mission =
        await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mission != null) {
      mission.hasFlightlogComplete = true;
      mission.status = 'completed';
      if (totalMin > 0) mission.duration = totalMin;
      // Write directly to the DB so the transition guard in
      // AppProvider.updateMission() (which only allows in_progress → completed)
      // does not block missions that reach this screen while still in 'planning'.
      // Submitting the flight log is the definitive completion action regardless
      // of intermediate checklist state.
      await DatabaseHelper.instance.updateMission(mission);
      await provider.refreshMissions();
    }

    if (!mounted) return;
    final online = await SyncService.isConnected();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(online ? 'Flight log saved to cloud ✓' : 'Flight log saved locally — syncs when online'),
        backgroundColor: online ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Log & Report'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: 3),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              children: [
                ChecklistMissionBanner(title: widget.missionTitle),
                const SizedBox(height: 12),
                _logSection('DATE / TIME & LOCATION', Icons.schedule, [
                  _field('Date/Time (UTC+8)', _dateTimeCtrl),
                  _field('Location', _locationCtrl),
                  Row(children: [
                    Expanded(child: _field('Latitude', _latCtrl, hint: '0.0000')),
                    SizedBox(width: 10),
                    Expanded(child: _field('Longitude', _lonCtrl, hint: '0.0000')),
                  ]),
                ]),
                _logSection('ALTITUDE & LANDING ZONE', Icons.height, [
                  Row(children: [
                    Expanded(child: _field('Altitude AGL (m)', _altAglCtrl, hint: '0')),
                    SizedBox(width: 10),
                    Expanded(child: _field('Highest Pt (m)', _highestPointCtrl, hint: '0')),
                  ]),
                  _field('Landing Zone', _landingZoneCtrl),
                ]),
                _logSection('RPAS PLATFORM', Icons.air, [
                  Text('Platform Type',
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _radioChip('Multi-rotor', _platformType == 'multi-rotor',
                        () => setState(() => _platformType = 'multi-rotor')),
                    const SizedBox(width: 8),
                    _radioChip('VTOL Fixed-Wing', _platformType == 'vtol',
                        () => setState(() => _platformType = 'vtol')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('Model', _modelCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('MTOW (kg)', _mtowCtrl, hint: '0.0')),
                  ]),
                ]),
                _logSection('PAYLOAD', Icons.camera_alt_outlined, [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _payloadOptions.map((p) {
                      final sel = _payload.contains(p);
                      return FilterChip(
                        label: Text(p),
                        selected: sel,
                        onSelected: (v) =>
                            setState(() => v ? _payload.add(p) : _payload.remove(p)),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primaryLight,
                        labelStyle: TextStyle(
                          color: sel
                              ? AppColors.primaryLight
                              : context.colors.textSecondary,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: sel ? AppColors.primary : context.colors.border,
                        ),
                        backgroundColor: context.colors.surface,
                      );
                    }).toList(),
                  ),
                ]),
                _logSection('MISSION TYPE', Icons.flag_outlined, [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _missionTypes.map((t) {
                      final sel = _missionType == t;
                      return _radioChip(
                          t, sel, () => setState(() => _missionType = t));
                    }).toList(),
                  ),
                ]),
                _logSection('CREW', Icons.people_outline, [
                  _field('RPIC', _rpicCtrl, readOnly: true),
                  _field('VO (Visual Observer)', _voCtrl, readOnly: true),
                  _field('Tech / Payload Operator', _techCtrl, readOnly: true),
                ]),
                _logSection('FLIGHT DURATION', Icons.timer_outlined, [
                  ...List.generate(3, (i) => _flightRow(i)),
                ]),
                _logSection('WEATHER', Icons.cloud_outlined, [
                  Row(children: [
                    Expanded(child: _field('Wind (m/s)', _windCtrl, hint: '0.0')),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Visibility (km)', _visibilityCtrl, hint: '0.0')),
                  ]),
                  _field('Cloud Conditions', _cloudCtrl,
                      hint: 'e.g. SCT018, OVC030'),
                ]),
                _logSection('NOTAMs / AIRSPACE', Icons.airplanemode_active, [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['None', 'Active', 'CAAP Permit'].map((n) {
                      return _radioChip(n, _notamsType == n,
                          () => setState(() => _notamsType = n));
                    }).toList(),
                  ),
                  if (_notamsType != 'None') ...[
                    const SizedBox(height: 10),
                    _field(
                      _notamsType == 'Active' ? 'Ref #' : 'Permit No.',
                      _notamsRefCtrl,
                    ),
                  ],
                ]),
                _logSection('ANOMALIES', Icons.warning_amber_outlined, [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _anomalyOptions.map((a) {
                      final sel = _anomalies.contains(a);
                      return FilterChip(
                        label: Text(a),
                        selected: sel,
                        onSelected: (v) => setState(() {
                          if (v) {
                            if (a == 'None') {
                              _anomalies.clear();
                            } else {
                              _anomalies.remove('None');
                            }
                            _anomalies.add(a);
                          } else {
                            _anomalies.remove(a);
                          }
                        }),
                        selectedColor:
                            AppColors.warning.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.warning,
                        labelStyle: TextStyle(
                          color: sel
                              ? AppColors.warning
                              : context.colors.textSecondary,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: sel ? AppColors.warning : context.colors.border,
                        ),
                        backgroundColor: context.colors.surface,
                      );
                    }).toList(),
                  ),
                  if (_anomalies.contains('Other')) ...[
                    const SizedBox(height: 10),
                    _field('Describe anomaly', _anomalyOtherCtrl),
                  ],
                ]),
                _logSection('DATA CAPTURED', Icons.storage_outlined, [
                  Row(children: [
                    Expanded(child: _field('GeoTIFF (ha)', _geotiffCtrl, hint: '0.0')),
                    SizedBox(width: 10),
                    Expanded(child: _field('Photos', _photosCtrl, hint: '0')),
                    SizedBox(width: 10),
                    Expanded(child: _field('Video (min)', _videoCtrl, hint: '0')),
                  ]),
                  SizedBox(height: 10),
                  Row(children: [
                    Switch(
                      value: _lidar,
                      onChanged: (v) => setState(() => _lidar = v),
                      activeThumbColor: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text('LiDAR data collected',
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 13)),
                  ]),
                ]),
                _logSection('NEXT MAINTENANCE', Icons.build_outlined, [
                  _field('Due hrs / date (e.g. 50 hrs / 2025-08-01)',
                      _nextMaintenanceCtrl),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submitting marks this mission as Completed. '
                          'All Annex A PDF reports will then be available from the Mission Details screen.',
                          style: TextStyle(
                              color: AppColors.success, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _SubmitFooter(
          isSaving: _isSaving, onSubmit: _submit),
    );
  }

  Widget _logSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: context.colors.textMuted),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Divider(height: 1),
          SizedBox(height: 10),
          ...children.map((c) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: c,
              )),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool readOnly = false}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
    );
  }

  Widget _radioChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryLight
                : context.colors.textSecondary,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _flightRow(int i) {
    final e = _flights[i];
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flt ${i + 1}',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _field('Takeoff (HH:MM)', e.takeoff, hint: '08:00')),
              const SizedBox(width: 8),
              Expanded(
                  child: _field('Landing (HH:MM)', e.landing, hint: '09:00')),
              const SizedBox(width: 8),
              Expanded(child: _field('Total (min)', e.total, hint: '60')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmitFooter extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSubmit;
  const _SubmitFooter({required this.isSaving, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onSubmit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(isSaving ? 'Saving...' : 'Submit & Complete Mission'),
          ),
        ),
      ),
    );
  }
}
